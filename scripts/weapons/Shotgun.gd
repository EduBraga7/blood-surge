extends Node3D
class_name Shotgun

# --- Balanço & Knobs (Regras AGENTS.md / GDD.md) ---
@export_group("Shooting")
@export var damage_per_pellet: float = 14.0
@export var pellet_count: int = 10
@export var spread_angle: float = 0.065
@export var max_range: float = 42.0
@export var fire_rate: float = 0.22

@export_group("Ammo & Reload")
@export var max_ammo: int = 2
@export var current_ammo: int = 2
@export var reload_duration: float = 0.65
@export var casing_scene: PackedScene

@export_group("Viewmodel Feel")
@export var sway_amount: float = 0.0016
@export var sway_max: float = 0.035
@export var sway_smooth: float = 16.0
@export var bob_amount: float = 0.012
@export var bob_speed: float = 12.0

# --- Estado do Sistema ---
var can_shoot: bool = true
var is_reloading: bool = false
var is_inspecting: bool = false

var fire_timer: float = 0.0
var reload_timer: float = 0.0
var inspect_timer: float = 0.0
var auto_reload_delay: float = 0.0

var muzzle_flash_timer: float = 0.0
var tracer_timer: float = 0.0

# Recuo e Sway
var original_pos: Vector3 = Vector3.ZERO
var original_rot: Vector3 = Vector3.ZERO
var target_pos: Vector3 = Vector3.ZERO
var target_rot: Vector3 = Vector3.ZERO

var sway_offset: Vector3 = Vector3.ZERO
var sway_rot: Vector3 = Vector3.ZERO
var mouse_input_accum: Vector2 = Vector2.ZERO
var bob_phase: float = 0.0

# Nodes e Referências
@onready var rig: Node3D = $Rig
@onready var model: Node3D = $Rig/Model
@onready var muzzle_light: OmniLight3D = $Rig/MuzzleLight
@onready var muzzle_flash_mesh: MeshInstance3D = $Rig/MuzzleFlash
@onready var barrel_smoke: CPUParticles3D = $Rig/BarrelSmoke
@onready var breach_smoke: CPUParticles3D = $Rig/BreachSmoke

@onready var shoot_audio: AudioStreamPlayer = $ShootAudio
@onready var hitmarker_audio: AudioStreamPlayer = $HitmarkerAudio
@onready var open_audio: AudioStreamPlayer = $OpenAudio
@onready var eject_audio: AudioStreamPlayer = $EjectAudio
@onready var insert_audio: AudioStreamPlayer = $InsertAudio
@onready var close_audio: AudioStreamPlayer = $CloseAudio

# Partes móveis da Super Shotgun
var hinge_node: Node3D = null
var muzzle_marker: Node3D = null
var shell_meshes: Array[MeshInstance3D] = []

# Pre-allocated pooled VFX
var tracer_mesh_inst: MeshInstance3D = null
var tracer_imm: ImmediateMesh = null
var spark_pool: Array[CPUParticles3D] = []
var spark_index: int = 0

# Rastreamento dos passos da animação de recarga
var reload_step_open: bool = false
var reload_step_eject: bool = false
var reload_step_insert: bool = false
var reload_step_close: bool = false

func _ready() -> void:
	original_pos = position
	original_rot = rotation
	target_pos = original_pos
	target_rot = original_rot

	if muzzle_light:
		muzzle_light.visible = false
	if muzzle_flash_mesh:
		muzzle_flash_mesh.visible = false

	# Busca as partes articuladas dentro da malha .glb
	if model:
		hinge_node = model.find_child("Hinge", true, false) as Node3D
		muzzle_marker = model.find_child("MuzzleMarker", true, false) as Node3D

		# Coleta todos os fragmentos visíveis dos cartuchos na câmara
		for child_name in ["Shell_L_Brass", "Shell_L_Hull", "Shell_L_Primer", "Shell_R_Brass", "Shell_R_Hull", "Shell_R_Primer"]:
			var s_node = model.find_child(child_name, true, false) as MeshInstance3D
			if s_node:
				shell_meshes.append(s_node)

	# Setup persistent tracer mesh
	tracer_imm = ImmediateMesh.new()
	tracer_mesh_inst = MeshInstance3D.new()
	tracer_mesh_inst.mesh = tracer_imm
	var t_mat = StandardMaterial3D.new()
	t_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	t_mat.albedo_color = Color(1.0, 0.85, 0.2, 0.85)
	tracer_mesh_inst.material_override = t_mat
	tracer_mesh_inst.top_level = true
	add_child(tracer_mesh_inst)
	tracer_mesh_inst.visible = false

	# Setup pre-allocated spark emitter pool
	var spark_mat = StandardMaterial3D.new()
	spark_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.albedo_color = Color(1.0, 0.75, 0.2)
	var spark_mesh = BoxMesh.new()
	spark_mesh.size = Vector3(0.05, 0.05, 0.05)
	spark_mesh.material = spark_mat

	for i in range(4):
		var p = CPUParticles3D.new()
		p.emitting = false
		p.one_shot = true
		p.explosiveness = 1.0
		p.amount = 6
		p.lifetime = 0.18
		p.spread = 40.0
		p.initial_velocity_min = 4.0
		p.initial_velocity_max = 7.0
		p.gravity = Vector3(0, -12, 0)
		p.mesh = spark_mesh
		p.top_level = true
		add_child(p)
		spark_pool.append(p)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouse_input_accum.x += event.relative.x
		mouse_input_accum.y += event.relative.y

func _process(delta: float) -> void:
	_process_timers(delta)
	_process_reload(delta)
	_process_inspect(delta)
	_process_sway_and_recoil(delta)

	# Disparo automático se segurar botão esquerdo e pronto para atirar
	if (Input.is_action_pressed("shoot") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) and can_shoot and not is_reloading and Global.player_hp > 0:
		fire()

func _process_timers(delta: float) -> void:
	if not can_shoot and not is_reloading:
		fire_timer -= delta
		if fire_timer <= 0.0:
			can_shoot = true

	# Auto-reload timer após esvaziar os 2 cartuchos
	if auto_reload_delay > 0.0:
		auto_reload_delay -= delta
		if auto_reload_delay <= 0.0 and current_ammo <= 0 and not is_reloading:
			start_reload()

	# Muzzle flash timer
	if muzzle_flash_timer > 0.0:
		muzzle_flash_timer -= delta
		if muzzle_flash_timer <= 0.0:
			if muzzle_light:
				muzzle_light.visible = false
			if muzzle_flash_mesh:
				muzzle_flash_mesh.visible = false

	# Tracer fade timer
	if tracer_timer > 0.0:
		tracer_timer -= delta
		if tracer_timer <= 0.0 and tracer_mesh_inst:
			tracer_mesh_inst.visible = false

func _process_sway_and_recoil(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	var is_sliding = player.is_sliding if player and "is_sliding" in player else false
	var vel_len = player.velocity.length() if player else 0.0

	# 1. Mouse Sway
	var target_sway_x = clampf(-mouse_input_accum.x * sway_amount, -sway_max, sway_max)
	var target_sway_y = clampf(-mouse_input_accum.y * sway_amount, -sway_max, sway_max)
	mouse_input_accum = mouse_input_accum.lerp(Vector2.ZERO, delta * 12.0)

	sway_offset.x = lerpf(sway_offset.x, target_sway_x, delta * sway_smooth)
	sway_offset.y = lerpf(sway_offset.y, target_sway_y, delta * sway_smooth)
	sway_rot.y = lerpf(sway_rot.y, target_sway_x * 0.8, delta * sway_smooth)
	sway_rot.x = lerpf(sway_rot.x, -target_sway_y * 0.8, delta * sway_smooth)

	# 2. Movement Bobbing
	var bob_x: float = 0.0
	var bob_y: float = 0.0
	if player and player.is_on_floor() and vel_len > 1.0 and not is_sliding:
		bob_phase += delta * bob_speed * (vel_len / 12.0)
		bob_x = cos(bob_phase * 0.5) * bob_amount * 0.6
		bob_y = abs(sin(bob_phase)) * bob_amount
	else:
		bob_phase = 0.0

	# 3. Slide Lean (Arma deita de lado no slide!)
	var slide_tilt = deg_to_rad(-22.0) if is_sliding else 0.0

	# 4. Interpolate Viewmodel Pos & Rot
	target_pos = target_pos.lerp(original_pos, delta * 14.0)
	target_rot = target_rot.lerp(original_rot, delta * 14.0)

	position = target_pos + sway_offset + Vector3(bob_x, bob_y - (0.05 if is_sliding else 0.0), 0.0)
	rotation = target_rot + sway_rot + Vector3(0.0, 0.0, slide_tilt)

# --- SISTEMA DE RECARGA (Break-Action Double-Barrel) ---

func start_reload() -> void:
	if is_reloading or current_ammo >= max_ammo or Global.player_hp <= 0:
		return

	is_reloading = true
	can_shoot = false
	is_inspecting = false
	reload_timer = reload_duration

	reload_step_open = false
	reload_step_eject = false
	reload_step_insert = false
	reload_step_close = false

	# Tilt da arma para preparar abertura do cano
	target_pos = original_pos + Vector3(0.02, -0.04, 0.06)
	target_rot = original_rot + Vector3(deg_to_rad(12.0), deg_to_rad(-8.0), deg_to_rad(14.0))

func _process_reload(delta: float) -> void:
	if not is_reloading:
		return

	reload_timer -= delta
	var elapsed = reload_duration - reload_timer

	# Passo 1: Abrir o cano (0.08s) - Quebra mecânica afiada
	if elapsed >= 0.08 and not reload_step_open:
		reload_step_open = true
		if open_audio:
			open_audio.pitch_scale = randf_range(0.96, 1.04)
			open_audio.play()
		if hinge_node:
			hinge_node.rotation.x = deg_to_rad(52.0)
		if breach_smoke:
			breach_smoke.restart()
			breach_smoke.emitting = true

	# Passo 2: Ejeção das cápsulas vazias (0.20s)
	if elapsed >= 0.20 and not reload_step_eject:
		reload_step_eject = true
		if eject_audio:
			eject_audio.pitch_scale = randf_range(0.95, 1.05)
			eject_audio.play()

		# Esconde cartuchos da câmara
		for s in shell_meshes:
			s.visible = false

		# Ejeta cápsulas físicas com impulso 3D
		_spawn_physical_casing(-0.025)
		_spawn_physical_casing(0.025)

	# Passo 3: Inserção de 2 novos cartuchos vermelhos na câmara (0.42s)
	if elapsed >= 0.42 and not reload_step_insert:
		reload_step_insert = true
		if insert_audio:
			insert_audio.pitch_scale = randf_range(0.98, 1.02)
			insert_audio.play()

		# Novos cartuchos brilham na câmara
		for s in shell_meshes:
			s.visible = true

	# Passo 4: Fechamento violento do cano (0.54s) - Latch snap!
	if elapsed >= 0.54 and not reload_step_close:
		reload_step_close = true
		if close_audio:
			close_audio.pitch_scale = randf_range(0.98, 1.03)
			close_audio.play()

		if hinge_node:
			hinge_node.rotation.x = 0.0

		# Recuo seco de travamento e micro camera shake
		target_pos = original_pos + Vector3(0.0, 0.03, 0.04)
		target_rot = original_rot + Vector3(deg_to_rad(-6.0), 0.0, 0.0)

		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("add_trauma"):
			player.add_trauma(0.18)

	# Conclusão da recarga
	if reload_timer <= 0.0:
		is_reloading = false
		current_ammo = max_ammo
		can_shoot = true
		if hinge_node:
			hinge_node.rotation.x = 0.0
		for s in shell_meshes:
			s.visible = true

func _spawn_physical_casing(x_offset: float) -> void:
	if not casing_scene:
		return

	var casing = casing_scene.instantiate() as RigidBody3D
	if not casing:
		return

	var spawn_trans = global_transform
	casing.global_position = spawn_trans.origin + (spawn_trans.basis * Vector3(x_offset, 0.02, 0.0))
	casing.global_basis = spawn_trans.basis

	get_tree().current_scene.add_child(casing)

	# Impulso para trás e para cima, com rotação caótica
	var eject_dir = (-spawn_trans.basis.z * -4.2) + (spawn_trans.basis.y * 3.4) + (spawn_trans.basis.x * randf_range(-0.8, 0.8))
	casing.linear_velocity = eject_dir
	casing.angular_velocity = Vector3(randf_range(-25, 25), randf_range(-30, 30), randf_range(-25, 25))

# --- INSPEÇÃO DA ARMA (Tecla T ou I) ---

func inspect() -> void:
	if is_reloading or is_inspecting or Global.player_hp <= 0:
		return

	is_inspecting = true
	inspect_timer = 0.85

	# Flica a arma levemente para cima e quebra o cano num ângulo sutil
	target_pos = original_pos + Vector3(-0.04, -0.02, 0.08)
	target_rot = original_rot + Vector3(deg_to_rad(14.0), deg_to_rad(18.0), deg_to_rad(-10.0))

	if open_audio:
		open_audio.pitch_scale = 1.2
		open_audio.play()

	if hinge_node:
		hinge_node.rotation.x = deg_to_rad(28.0)

func _process_inspect(delta: float) -> void:
	if not is_inspecting:
		return

	inspect_timer -= delta
	if inspect_timer <= 0.35 and hinge_node and hinge_node.rotation.x > 0.0:
		hinge_node.rotation.x = 0.0
		if close_audio:
			close_audio.pitch_scale = 1.15
			close_audio.play()

	if inspect_timer <= 0.0:
		is_inspecting = false
		if hinge_node:
			hinge_node.rotation.x = 0.0

# --- DISPARO PRIMÁRIO (LMB: 1 Cano - Rápido) ---

func fire() -> void:
	if not can_shoot or is_reloading or current_ammo <= 0 or Global.player_hp <= 0:
		if current_ammo <= 0 and not is_reloading:
			start_reload()
		return

	can_shoot = false
	fire_timer = fire_rate
	current_ammo -= 1

	# Recuo no viewmodel
	target_pos = original_pos + Vector3(0.0, 0.09, 0.24)
	target_rot = original_rot + Vector3(deg_to_rad(18.0), randf_range(-0.04, 0.04), randf_range(-0.06, 0.06))

	# Player camera recoil & trauma
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_recoil"):
		player.add_recoil(deg_to_rad(2.6))

	# Áudio pesado
	if shoot_audio:
		shoot_audio.pitch_scale = randf_range(0.94, 1.06)
		shoot_audio.play()
	Global.play_sub_bass_kick(1.6, randf_range(0.95, 1.05))
	Global.duck_music(3.5, 0.12)

	# VFX
	_flash_muzzle()
	if barrel_smoke:
		barrel_smoke.restart()
		barrel_smoke.emitting = true

	# Raycast Pellets
	_fire_pellets(pellet_count, damage_per_pellet, spread_angle)

	# Se a munição acabou, prepara auto-reload
	if current_ammo <= 0:
		auto_reload_delay = 0.18

# --- DISPARO SECUNDÁRIO / ALT-FIRE (RMB: Super Blast - Ambos os canos!) ---

func fire_alt() -> void:
	if not can_shoot or is_reloading or current_ammo <= 0 or Global.player_hp <= 0:
		if current_ammo <= 0 and not is_reloading:
			start_reload()
		return

	can_shoot = false
	var barrels_to_fire = current_ammo
	current_ammo = 0
	fire_timer = fire_rate * 1.5

	# Recuo monstruoso
	target_pos = original_pos + Vector3(0.0, 0.16, 0.38)
	target_rot = original_rot + Vector3(deg_to_rad(32.0), randf_range(-0.06, 0.06), randf_range(-0.08, 0.08))

	# Impulso de propulsão no jogador (Shotgun Jump!)
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if player.has_method("add_recoil"):
			player.add_recoil(deg_to_rad(5.5))
		# Se estiver no ar, empurra para trás e para cima!
		if not player.is_on_floor():
			var cam = get_viewport().get_camera_3d()
			if cam:
				player.velocity += cam.global_transform.basis.z * 16.0 + Vector3(0, 5.0, 0)

	# Áudio estrondeante
	if shoot_audio:
		shoot_audio.pitch_scale = 0.82
		shoot_audio.play()
	Global.play_sub_bass_kick(3.5, 0.75)
	Global.duck_music(6.0, 0.25)

	# VFX dobrado
	_flash_muzzle(true)
	if barrel_smoke:
		barrel_smoke.amount = 24
		barrel_smoke.restart()
		barrel_smoke.emitting = true

	# Raycasts com 2x pellets
	_fire_pellets(pellet_count * barrels_to_fire, damage_per_pellet, spread_angle * 1.35)

	# Inicia recarga imediata
	auto_reload_delay = 0.22

# --- CÁLCULO DE BALINS (Raycasts & Feedback) ---

func _fire_pellets(count: int, dmg_each: float, spread: float) -> void:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return

	var player = get_tree().get_first_node_in_group("player")
	var space_state = get_world_3d().direct_space_state
	var cam_pos = camera.global_position
	var cam_forward = -camera.global_transform.basis.z
	var muzzle_pos = cam_pos + (camera.global_transform.basis * Vector3(0.25, -0.18, -0.7))

	var hits_landed = 0
	var kill_registered = false
	var tracer_endpoints: Array[Vector3] = []

	for i in range(count):
		var spread_x = randf_range(-spread, spread)
		var spread_y = randf_range(-spread, spread)
		var spread_dir = (cam_forward + (camera.global_transform.basis.x * spread_x) + (camera.global_transform.basis.y * spread_y)).normalized()

		var end_pos = cam_pos + spread_dir * max_range
		var query = PhysicsRayQueryParameters3D.create(cam_pos, end_pos)
		query.collision_mask = 1 | 4 # World (1) and Enemies (4)
		if player:
			query.exclude = [player]

		var result = space_state.intersect_ray(query)
		var hit_target_pos = end_pos

		if result:
			var hit_collider = result["collider"]
			var hit_point = result["position"]
			var hit_normal = result["normal"]
			var dist = cam_pos.distance_to(hit_point)
			hit_target_pos = hit_point

			if hit_collider and hit_collider.has_method("take_damage"):
				hits_landed += 1
				var damage = dmg_each
				if dist > 8.0:
					damage = max(damage * 0.45, damage * (1.0 - (dist - 8.0) / (max_range - 8.0)))

				var died = hit_collider.take_damage(damage, hit_point, hit_normal, dist <= 4.5)
				if died:
					kill_registered = true

				Global.report_hit(died, damage, dist)
			else:
				if i % 3 == 0:
					_trigger_pooled_spark(hit_point, hit_normal)

		if i % 2 == 0:
			tracer_endpoints.append(hit_target_pos)

	_render_batched_tracers(muzzle_pos, tracer_endpoints)

	if hits_landed > 0 and hitmarker_audio:
		hitmarker_audio.pitch_scale = 1.25 if kill_registered else randf_range(0.95, 1.05)
		hitmarker_audio.play()

func _flash_muzzle(is_alt: bool = false) -> void:
	muzzle_flash_timer = 0.05
	if muzzle_light:
		muzzle_light.light_energy = 8.0 if is_alt else 5.0
		muzzle_light.visible = true
	if muzzle_flash_mesh:
		muzzle_flash_mesh.visible = true
		muzzle_flash_mesh.rotation.z = randf_range(0, TAU)
		var s = randf_range(1.2, 1.6) if is_alt else randf_range(0.85, 1.15)
		muzzle_flash_mesh.scale = Vector3(s, s, s)

func _render_batched_tracers(from_pos: Vector3, endpoints: Array[Vector3]) -> void:
	if not tracer_imm or not tracer_mesh_inst or endpoints.is_empty():
		return
	tracer_imm.clear_surfaces()
	tracer_imm.surface_begin(Mesh.PRIMITIVE_LINES)
	for end_p in endpoints:
		tracer_imm.surface_add_vertex(from_pos)
		tracer_imm.surface_add_vertex(end_p)
	tracer_imm.surface_end()
	tracer_mesh_inst.visible = true
	tracer_timer = 0.05

func _trigger_pooled_spark(pos: Vector3, normal: Vector3) -> void:
	if spark_pool.is_empty():
		return
	var p = spark_pool[spark_index % spark_pool.size()]
	spark_index += 1
	p.global_position = pos
	p.direction = normal
	p.restart()
	p.emitting = true
