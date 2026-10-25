extends CharacterBody3D
class_name EnemyHusk

@export var max_hp: float = 65.0
@export var speed: float = 8.0
@export var attack_damage: float = 20.0
@export var attack_rate: float = 1.0

var current_hp: float = 65.0
var attack_timer: float = 0.4
var attack_windup: float = 0.0
var is_winding_up: bool = false
var spawn_cooldown: float = 0.55
var knockback: Vector3 = Vector3.ZERO
var gravity: float = 20.0

@onready var model_root: Node3D = get_node_or_null("Model")
@onready var eyes_light: OmniLight3D = get_node_or_null("EyesLight")
var mesh_instances: Array[MeshInstance3D] = []

var blood_gib_scene = preload("res://scenes/enemies/BloodGib.tscn")

func _ready() -> void:
	add_to_group("enemies")
	current_hp = max_hp
	attack_timer = 0.4
	spawn_cooldown = 0.55
	if eyes_light:
		eyes_light.light_energy = 3.0
	
	if model_root:
		for child in model_root.find_children("*", "MeshInstance3D", true):
			if child is MeshInstance3D:
				mesh_instances.append(child)
	elif has_node("MeshInstance3D"):
		var m = get_node("MeshInstance3D") as MeshInstance3D
		if m:
			mesh_instances.append(m)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Decay knockback
	knockback = knockback.lerp(Vector3.ZERO, delta * 8.0)

	# Spawn activation pause
	if spawn_cooldown > 0.0:
		spawn_cooldown -= delta
		velocity.x = knockback.x
		velocity.z = knockback.z
		if eyes_light:
			eyes_light.light_energy = lerp(4.0, 1.5, 1.0 - spawn_cooldown / 0.55)
		move_and_slide()
		return

	var player = Global.player_node
	if player and Global.player_hp > 0:
		var target_pos = player.global_position
		var diff = target_pos - global_position
		var dist = diff.length()

		# Look towards player
		var look_target = Vector3(target_pos.x, global_position.y, target_pos.z)
		if global_position.distance_squared_to(look_target) > 0.1:
			look_at(look_target, Vector3.UP)

		if is_winding_up:
			attack_windup -= delta
			velocity.x = knockback.x
			velocity.z = knockback.z
			if eyes_light:
				eyes_light.light_color = Color(1.0, 0.9, 0.2)
				eyes_light.light_energy = 5.0
			if attack_windup <= 0.0:
				is_winding_up = false
				if eyes_light:
					eyes_light.light_color = Color(1.0, 0.15, 0.15)
					eyes_light.light_energy = 1.5
				if dist <= 2.2 and player.has_method("take_damage"):
					player.take_damage(attack_damage)
				attack_timer = attack_rate
		elif dist > 1.8:
			var dir = diff.normalized()
			velocity.x = dir.x * speed + knockback.x
			velocity.z = dir.z * speed + knockback.z
			attack_timer = max(0.0, attack_timer - delta)
		else:
			velocity.x = knockback.x
			velocity.z = knockback.z
			attack_timer = max(0.0, attack_timer - delta)
			if attack_timer <= 0.0:
				is_winding_up = true
				attack_windup = 0.28
	else:
		velocity.x = knockback.x
		velocity.z = knockback.z

	move_and_slide()

func take_damage(amount: float, hit_point: Vector3 = Vector3.ZERO, hit_normal: Vector3 = Vector3.UP, is_point_blank: bool = false) -> bool:
	current_hp -= amount
	# Apply knockback
	knockback = -hit_normal * (amount * 0.4)
	knockback.y = 2.0

	_flash()

	if current_hp <= 0:
		_die(is_point_blank)
		return true
	return false

func _flash() -> void:
	if mesh_instances.is_empty():
		return
	var flash_mat = StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.0, 0.9, 0.9)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1.0, 0.3, 0.3)
	flash_mat.emission_energy_multiplier = 4.0
	for m in mesh_instances:
		m.set_surface_override_material(0, flash_mat)
	await get_tree().create_timer(0.06).timeout
	for m in mesh_instances:
		m.set_surface_override_material(0, null)

func _die(is_point_blank: bool) -> void:
	var parent = get_parent()
	var spawn_center = global_position
	# Spawn blood gibs
	for i in range(randi_range(3, 5)):
		var gib = blood_gib_scene.instantiate()
		parent.add_child(gib)
		gib.global_position = spawn_center + Vector3(randf_range(-0.3, 0.3), randf_range(0.5, 1.4), randf_range(-0.3, 0.3))

	# Sound (SFX bus with organic pitch variation)
	var audio = AudioStreamPlayer3D.new()
	audio.stream = load("res://assets/audio/enemy_die.wav")
	audio.pitch_scale = randf_range(0.85, 1.15)
	audio.bus = &"SFX"
	parent.add_child(audio)
	audio.global_position = spawn_center
	audio.play()
	audio.finished.connect(audio.queue_free)

	# Splatter blood decals on floor and nearby surfaces
	var space = get_world_3d().direct_space_state
	var down_ray = PhysicsRayQueryParameters3D.create(spawn_center + Vector3.UP * 0.5, spawn_center + Vector3.DOWN * 4.0)
	down_ray.collision_mask = 1
	var down_res = space.intersect_ray(down_ray)
	if down_res:
		Global.spawn_blood_splat(down_res["position"], down_res["normal"], randf_range(2.0, 3.2))

	for a in [randf_range(0, TAU), randf_range(0, TAU)]:
		var wall_dir = Vector3(cos(a), randf_range(-0.2, 0.4), sin(a)).normalized()
		var wall_ray = PhysicsRayQueryParameters3D.create(spawn_center + Vector3.UP * 0.8, spawn_center + wall_dir * 6.0)
		wall_ray.collision_mask = 1
		var wall_res = space.intersect_ray(wall_ray)
		if wall_res:
			Global.spawn_blood_splat(wall_res["position"], wall_res["normal"], randf_range(1.4, 2.4))

	queue_free()
