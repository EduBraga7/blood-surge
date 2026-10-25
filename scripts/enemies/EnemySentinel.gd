extends CharacterBody3D
class_name EnemySentinel

@export var max_hp: float = 45.0
@export var hover_height: float = 3.2
@export var move_speed: float = 5.0
@export var fire_interval: float = 2.4

var current_hp: float = 45.0
var fire_timer: float = 1.0
var is_charging: bool = false
var charge_timer: float = 0.0

@onready var model_root: Node3D = get_node_or_null("Model")
@onready var eye_light: OmniLight3D = get_node_or_null("EyeLight")
@onready var charge_beam: MeshInstance3D = get_node_or_null("ChargeBeam")
var mesh_instances: Array[MeshInstance3D] = []

var ring_pitch: Node3D = null
var ring_yaw: Node3D = null

var plasma_ball_scene = preload("res://scenes/enemies/PlasmaBall.tscn")
var blood_gib_scene = preload("res://scenes/enemies/BloodGib.tscn")

func _ready() -> void:
	add_to_group("enemies")
	current_hp = max_hp
	if charge_beam:
		charge_beam.visible = false
	if model_root:
		for child in model_root.find_children("*", "MeshInstance3D", true):
			if child is MeshInstance3D:
				mesh_instances.append(child)
		ring_pitch = model_root.find_child("GyroRing_Pitch", true, false) as Node3D
		ring_yaw = model_root.find_child("GyroRing_Yaw", true, false) as Node3D
	elif has_node("MeshInstance3D"):
		var m = get_node("MeshInstance3D") as MeshInstance3D
		if m:
			mesh_instances.append(m)

func _physics_process(delta: float) -> void:
	# Kinetic visual gyro-spin for retro-modern mechanical drone feel
	if ring_pitch:
		ring_pitch.rotate_x(delta * 2.8)
	if ring_yaw:
		ring_yaw.rotate_y(delta * 4.2)

	var player = Global.player_node
	if not player or Global.player_hp <= 0:
		return

	var target_pos = player.global_position
	# Look at player
	look_at(target_pos, Vector3.UP)

	# Hovering height logic
	var desired_y = hover_height
	var diff = target_pos - global_position
	var dist = diff.length()

	# Repositioning: maintain 10-15m distance
	var dir = diff.normalized()
	if dist < 9.0:
		velocity.x = -dir.x * move_speed
		velocity.z = -dir.z * move_speed
	elif dist > 16.0:
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
	else:
		# Strafe left/right
		var strafe = transform.basis.x * sin(Time.get_ticks_msec() * 0.002) * (move_speed * 0.7)
		velocity.x = strafe.x
		velocity.z = strafe.z

	velocity.y = (desired_y - global_position.y) * 3.0
	move_and_slide()

	# Shooting loop
	if is_charging:
		charge_timer -= delta
		if eye_light:
			eye_light.light_energy = randf_range(2.0, 5.0)
		if charge_timer <= 0.0:
			_fire_plasma(player.global_position)
	else:
		fire_timer -= delta
		if fire_timer <= 0.0:
			_start_charging()

func _start_charging() -> void:
	is_charging = true
	charge_timer = 0.8
	if charge_beam:
		charge_beam.visible = true

func _fire_plasma(target_point: Vector3) -> void:
	is_charging = false
	fire_timer = fire_interval
	if charge_beam:
		charge_beam.visible = false
	if eye_light:
		eye_light.light_energy = 1.5

	var spawn_pos = global_position - transform.basis.z * 1.2
	var ball = plasma_ball_scene.instantiate()
	get_parent().add_child(ball)
	ball.global_position = spawn_pos
	ball.direction = (target_point + Vector3(0, 0.5, 0) - spawn_pos).normalized()

func take_damage(amount: float, hit_point: Vector3 = Vector3.ZERO, hit_normal: Vector3 = Vector3.UP, is_point_blank: bool = false) -> bool:
	current_hp -= amount
	_flash()
	if current_hp <= 0:
		_die()
		return true
	return false

func _flash() -> void:
	if mesh_instances.is_empty():
		return
	var flash_mat = StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.0, 0.9, 0.9)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1.0, 0.2, 0.2)
	flash_mat.emission_energy_multiplier = 4.0
	for m in mesh_instances:
		m.set_surface_override_material(0, flash_mat)
	await get_tree().create_timer(0.06).timeout
	for m in mesh_instances:
		m.set_surface_override_material(0, null)

func _die() -> void:
	var parent = get_parent()
	var spawn_center = global_position
	# Spawn blood/oil explosion gibs
	for i in range(randi_range(4, 6)):
		var gib = blood_gib_scene.instantiate()
		parent.add_child(gib)
		gib.global_position = spawn_center + Vector3(randf_range(-0.4, 0.4), randf_range(-0.2, 0.4), randf_range(-0.4, 0.4))

	# Explosion sound
	var audio = AudioStreamPlayer3D.new()
	audio.stream = load("res://assets/audio/enemy_die.wav")
	audio.pitch_scale = randf_range(1.2, 1.45)
	audio.bus = &"SFX"
	parent.add_child(audio)
	audio.global_position = spawn_center
	audio.play()
	audio.finished.connect(audio.queue_free)

	# Splatter blood decals on floor and nearby surfaces
	var space = get_world_3d().direct_space_state
	var down_ray = PhysicsRayQueryParameters3D.create(spawn_center, spawn_center + Vector3.DOWN * 8.0)
	down_ray.collision_mask = 1
	var down_res = space.intersect_ray(down_ray)
	if down_res:
		Global.spawn_blood_splat(down_res["position"], down_res["normal"], randf_range(2.2, 3.4))

	for a in [randf_range(0, TAU), randf_range(0, TAU)]:
		var wall_dir = Vector3(cos(a), randf_range(-0.3, 0.3), sin(a)).normalized()
		var wall_ray = PhysicsRayQueryParameters3D.create(spawn_center, spawn_center + wall_dir * 7.0)
		wall_ray.collision_mask = 1
		var wall_res = space.intersect_ray(wall_ray)
		if wall_res:
			Global.spawn_blood_splat(wall_res["position"], wall_res["normal"], randf_range(1.6, 2.6))

	queue_free()
