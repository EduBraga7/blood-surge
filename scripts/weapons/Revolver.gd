extends Node3D
class_name Revolver

signal ammo_changed(current: int, max_val: int)
signal fired()

# --- Balance & Knobs (AGENTS.md / GDD.md) ---
@export_group("Shooting")
@export var damage: float = 65.0
@export var piercer_damage: float = 175.0
@export var fire_rate: float = 0.32
@export var max_range: float = 75.0

@export_group("Ammo & Reload")
@export var max_ammo: int = 6
@export var current_ammo: int = 6
@export var reload_duration: float = 0.8

@export_group("Viewmodel Feel")
@export var sway_amount: float = 0.0016
@export var sway_max: float = 0.035
@export var sway_smooth: float = 16.0
@export var bob_amount: float = 0.010
@export var bob_speed: float = 12.0

# --- State ---
var can_shoot: bool = true
var is_reloading: bool = false
var is_charging_alt: bool = false
var charge_timer: float = 0.0
var max_charge_time: float = 0.65

var fire_timer: float = 0.0
var reload_timer: float = 0.0
var muzzle_flash_timer: float = 0.0

# Sway & Recoil
var original_pos: Vector3 = Vector3.ZERO
var original_rot: Vector3 = Vector3.ZERO
var target_pos: Vector3 = Vector3.ZERO
var target_rot: Vector3 = Vector3.ZERO
var sway_offset: Vector3 = Vector3.ZERO
var sway_rot: Vector3 = Vector3.ZERO
var mouse_input_accum: Vector2 = Vector2.ZERO
var bob_phase: float = 0.0

@onready var rig: Node3D = $Rig
@onready var model: Node3D = $Rig/Model
@onready var muzzle_light: OmniLight3D = $Rig/MuzzleLight
@onready var muzzle_flash: MeshInstance3D = $Rig/MuzzleFlash

@onready var shoot_audio: AudioStreamPlayer = $ShootAudio
@onready var charge_audio: AudioStreamPlayer = $ChargeAudio
@onready var pierce_audio: AudioStreamPlayer = $PierceAudio
@onready var reload_audio: AudioStreamPlayer = $ReloadAudio

var tracer_mesh_inst: MeshInstance3D = null
var tracer_imm: ImmediateMesh = null
var tracer_timer: float = 0.0

func _ready() -> void:
	original_pos = position
	original_rot = rotation
	target_pos = original_pos
	target_rot = original_rot

	if muzzle_light:
		muzzle_light.visible = false
	if muzzle_flash:
		muzzle_flash.visible = false

	# Setup immediate mesh for hyper-beam tracers
	tracer_imm = ImmediateMesh.new()
	tracer_mesh_inst = MeshInstance3D.new()
	tracer_mesh_inst.mesh = tracer_imm
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.2, 0.95, 1.0, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.95, 1.0, 1.0)
	mat.emission_energy_multiplier = 8.0
	tracer_mesh_inst.material_override = mat
	add_child(tracer_mesh_inst)
	tracer_mesh_inst.top_level = true
	tracer_mesh_inst.visible = false

func _process(delta: float) -> void:
	if fire_timer > 0.0:
		fire_timer -= delta
		if fire_timer <= 0.0 and not is_reloading:
			can_shoot = true

	if is_reloading:
		reload_timer -= delta
		if reload_timer <= 0.0:
			is_reloading = false
			current_ammo = max_ammo
			can_shoot = true
			ammo_changed.emit(current_ammo, max_ammo)

	if muzzle_flash_timer > 0.0:
		muzzle_flash_timer -= delta
		if muzzle_flash_timer <= 0.0:
			if muzzle_light:
				muzzle_light.visible = false
			if muzzle_flash:
				muzzle_flash.visible = false

	if tracer_timer > 0.0:
		tracer_timer -= delta
		if tracer_timer <= 0.0 and tracer_mesh_inst:
			tracer_mesh_inst.visible = false

	# Process Piercer Beam Charge (RMB held)
	if is_charging_alt:
		charge_timer = min(max_charge_time, charge_timer + delta)
		# Vibrate model with raw energy
		var shake = (charge_timer / max_charge_time) * 0.004
		rig.position = Vector3(randf_range(-shake, shake), randf_range(-shake, shake), randf_range(-shake, shake))
		if charge_timer >= max_charge_time and not charge_audio.playing:
			pass
	else:
		rig.position = Vector3.ZERO

	_process_sway_and_bob(delta)

func _process_sway_and_bob(delta: float) -> void:
	# Mouse sway
	var target_sway_x = clampf(-mouse_input_accum.x * sway_amount, -sway_max, sway_max)
	var target_sway_y = clampf(-mouse_input_accum.y * sway_amount, -sway_max, sway_max)
	sway_offset.x = lerpf(sway_offset.x, target_sway_x, sway_smooth * delta)
	sway_offset.y = lerpf(sway_offset.y, target_sway_y, sway_smooth * delta)
	sway_rot.z = lerpf(sway_rot.z, -target_sway_x * 0.8, sway_smooth * delta)
	sway_rot.x = lerpf(sway_rot.x, target_sway_y * 0.6, sway_smooth * delta)
	mouse_input_accum = Vector2.ZERO

	# Movement bobbing
	var p = Global.player_node
	if p and p is CharacterBody3D and p.is_on_floor() and p.velocity.length() > 0.5:
		bob_phase += delta * bob_speed
		var bob_x = cos(bob_phase * 0.5) * bob_amount
		var bob_y = abs(sin(bob_phase)) * bob_amount
		target_pos = original_pos + Vector3(bob_x, -bob_y, 0) + sway_offset
	else:
		bob_phase = 0.0
		target_pos = original_pos + sway_offset

	target_rot = original_rot + sway_rot
	position = position.lerp(target_pos, 14.0 * delta)
	rotation = rotation.lerp(target_rot, 14.0 * delta)

func add_mouse_motion(motion: Vector2) -> void:
	mouse_input_accum += motion

func fire() -> void:
	if not can_shoot or is_reloading:
		return
	if current_ammo <= 0:
		start_reload()
		return

	can_shoot = false
	fire_timer = fire_rate
	current_ammo -= 1
	ammo_changed.emit(current_ammo, max_ammo)
	fired.emit()

	# Visual & Audio
	if shoot_audio:
		shoot_audio.pitch_scale = randf_range(0.96, 1.05)
		shoot_audio.play()

	_trigger_muzzle_flash(Color(0.2, 0.9, 1.0))
	_apply_recoil(0.18, 0.04)

	# Single pinpoint hitscan
	var p = Global.player_node
	if not p or not is_instance_valid(p.camera):
		return

	var cam = p.camera
	var space_state = get_world_3d().direct_space_state
	var from = cam.global_position
	var forward = -cam.global_transform.basis.z
	var to = from + forward * max_range

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1 | 4 | 8 # World, Enemies, Projectiles
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [p]

	var result = space_state.intersect_ray(query)
	var hit_pos = to
	if result:
		hit_pos = result["position"]
		var col = result["collider"]
		var norm = result["normal"]

		if col and col.has_method("take_damage"):
			var dist = from.distance_to(hit_pos)
			var local_hit_y = hit_pos.y - col.global_position.y
			var is_husk = col.name.begins_with("Husk")
			var is_sentinel = col.name.begins_with("Sentinel")
			var is_headshot = (local_hit_y > 1.35) if is_husk else (local_hit_y > 0.15 if is_sentinel else local_hit_y > 1.1)
			var actual_dmg = damage * (2.0 if is_headshot else 1.0)
			var is_kill = col.take_damage(actual_dmg, hit_pos, norm, is_headshot)
			Global.report_hit(is_kill, actual_dmg, dist)
			if is_headshot:
				Global.add_style(120, "+ HEADSHOT")
			Global.spawn_blood_splat(hit_pos, norm, 1.4)
		elif col and col.is_in_group("explosives") and col.has_method("take_damage"):
			col.take_damage(999.0, hit_pos, norm)
		elif col and col.has_method("parry"):
			col.parry(forward)

	_draw_tracer(from + forward * 0.4 + cam.global_transform.basis.x * 0.15 - cam.global_transform.basis.y * 0.1, hit_pos, Color(0.2, 0.9, 1.0))

func start_alt_charge() -> void:
	if not can_shoot or is_reloading or is_charging_alt:
		return
	is_charging_alt = true
	charge_timer = 0.0
	if charge_audio:
		charge_audio.play()

func release_alt_charge() -> void:
	if not is_charging_alt:
		return
	is_charging_alt = false
	if charge_audio:
		charge_audio.stop()

	if charge_timer >= max_charge_time * 0.7:
		fire_piercer_beam()
	else:
		charge_timer = 0.0

func fire_piercer_beam() -> void:
	if current_ammo <= 0:
		start_reload()
		return

	can_shoot = false
	fire_timer = fire_rate * 2.0
	current_ammo = max(0, current_ammo - 2)
	ammo_changed.emit(current_ammo, max_ammo)

	if pierce_audio:
		pierce_audio.play()

	_trigger_muzzle_flash(Color(1.0, 1.0, 1.0), 10.0)
	_apply_recoil(0.40, 0.12)
	Global.play_sub_bass_kick(4.5, 0.9)
	Global.trigger_hitstop(0.08)

	var p = Global.player_node
	if not p or not is_instance_valid(p.camera):
		return

	var cam = p.camera
	p.add_trauma(0.45)
	var from = cam.global_position
	var forward = -cam.global_transform.basis.z
	var max_beam_dist = 85.0
	var beam_end = from + forward * max_beam_dist

	# Piercing ray that punches through ALL entities
	var space_state = get_world_3d().direct_space_state
	var current_from = from
	var hit_count = 0

	for _step in range(8):
		var query = PhysicsRayQueryParameters3D.create(current_from, beam_end)
		query.collision_mask = 1 | 4 | 8
		query.collide_with_areas = true
		query.collide_with_bodies = true
		query.exclude = [p]

		var result = space_state.intersect_ray(query)
		if not result:
			break

		var hit_pos = result["position"]
		var col = result["collider"]
		var norm = result["normal"]

		if col and col.has_method("take_damage"):
			hit_count += 1
			var is_kill = col.take_damage(piercer_damage, hit_pos, norm, true)
			Global.report_hit(is_kill, piercer_damage, from.distance_to(hit_pos))
			Global.spawn_blood_splat(hit_pos, norm, 2.4)
			# Advance slightly past the hit enemy to penetrate
			current_from = hit_pos + forward * 0.4
		elif col and col.is_in_group("explosives") and col.has_method("take_damage"):
			col.take_damage(999.0, hit_pos, norm)
			current_from = hit_pos + forward * 0.4
		else:
			# Hit solid world wall, beam stops
			beam_end = hit_pos
			Global.spawn_blood_splat(hit_pos, norm, 1.8)
			break

	if hit_count > 1:
		Global.add_style(250 * hit_count, "+ MULTI-PIERCE x%d" % hit_count)
	elif hit_count == 1:
		Global.add_style(180, "+ PIERCED")

	_draw_tracer(from + forward * 0.4, beam_end, Color(0.9, 0.95, 1.0), 0.22)

func start_reload() -> void:
	if is_reloading or current_ammo == max_ammo:
		return
	is_reloading = true
	can_shoot = false
	reload_timer = reload_duration
	if reload_audio:
		reload_audio.play()

	# Fast cylinder spin visual
	var tween = create_tween()
	tween.tween_property(rig, "rotation:z", deg_to_rad(360), reload_duration * 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): rig.rotation.z = 0.0)

func _trigger_muzzle_flash(col: Color = Color(0.2, 0.9, 1.0), energy: float = 6.0) -> void:
	if muzzle_light:
		muzzle_light.light_color = col
		muzzle_light.light_energy = energy
		muzzle_light.visible = true
	if muzzle_flash:
		muzzle_flash.visible = true
	muzzle_flash_timer = 0.05

func _apply_recoil(pitch_kick: float, push_back: float) -> void:
	position.z += push_back
	rotation.x += pitch_kick
	var p = Global.player_node
	if p and "recoil_pitch" in p:
		p.recoil_pitch += pitch_kick * 0.4

func _draw_tracer(start_pos: Vector3, end_pos: Vector3, col: Color, duration: float = 0.12) -> void:
	if not tracer_imm:
		return
	tracer_imm.clear_surfaces()
	tracer_imm.surface_begin(Mesh.PRIMITIVE_LINES)
	tracer_imm.surface_set_color(col)
	tracer_imm.surface_add_vertex(start_pos)
	tracer_imm.surface_add_vertex(end_pos)
	tracer_imm.surface_end()
	tracer_mesh_inst.visible = true
	tracer_timer = duration

func equip() -> void:
	visible = true
	can_shoot = true
	is_reloading = false
	is_charging_alt = false
	position.y = original_pos.y - 0.25
	rotation.x = original_rot.x - deg_to_rad(25)
	var tween = create_tween()
	tween.tween_property(self, "position:y", original_pos.y, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "rotation:x", original_rot.x, 0.14)
	if reload_audio:
		reload_audio.pitch_scale = 1.4
		reload_audio.play()
	ammo_changed.emit(current_ammo, max_ammo)

func unequip() -> void:
	if is_charging_alt:
		release_alt_charge()
	var tween = create_tween()
	tween.tween_property(self, "position:y", original_pos.y - 0.25, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): visible = false)
