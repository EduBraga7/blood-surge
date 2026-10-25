extends StaticBody3D
class_name ExplosiveBarrel

@export var max_hp: float = 15.0
@export var explosion_damage: float = 90.0
@export var explosion_radius: float = 6.5

var current_hp: float = 15.0
var has_exploded: bool = false

@onready var mesh: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	add_to_group("explosives")
	current_hp = max_hp

func take_damage(amount: float, hit_point: Vector3 = Vector3.ZERO, hit_normal: Vector3 = Vector3.ZERO, is_point_blank: bool = false) -> bool:
	if has_exploded:
		return false

	current_hp -= amount
	if current_hp <= 0.0:
		explode()
		return true
	return false

func explode() -> void:
	if has_exploded:
		return
	has_exploded = true

	var explode_pos = global_position + Vector3(0, 0.8, 0)
	Global.screen_shake_requested.emit(0.7)

	# Audio (Heavy explosion on Combat bus + sub-bass drop)
	var audio = AudioStreamPlayer3D.new()
	audio.stream = load("res://assets/audio/enemy_die.wav")
	audio.pitch_scale = randf_range(0.55, 0.68)
	audio.bus = &"Combat"
	get_parent().add_child(audio)
	audio.global_position = explode_pos
	audio.play()
	audio.finished.connect(audio.queue_free)

	Global.play_sub_bass_kick(4.5, 0.65)
	Global.duck_music(4.5, 0.18)

	# Fireball Flash
	var light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.1)
	light.light_energy = 10.0
	light.omni_range = 10.0
	get_parent().add_child(light)
	light.global_position = explode_pos
	var tween = light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.3)
	tween.tween_callback(light.queue_free)

	# Particle explosion
	var p = CPUParticles3D.new()
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 24
	p.lifetime = 0.45
	p.spread = 180.0
	p.initial_velocity_min = 8.0
	p.initial_velocity_max = 16.0
	p.gravity = Vector3(0, -6, 0)

	var mat = StandardMaterial3D.new()
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.45, 0.1)
	var box = BoxMesh.new()
	box.size = Vector3(0.18, 0.18, 0.18)
	box.material = mat
	p.mesh = box

	get_parent().add_child(p)
	p.global_position = explode_pos
	get_tree().create_timer(0.6).timeout.connect(p.queue_free)

	# Damage query
	var space = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = explosion_radius
	query.shape = sphere
	query.transform = Transform3D(Basis(), explode_pos)
	query.collision_mask = 1 | 2 | 4 | 16 # World, Player, Enemies, Gibs

	var results = space.intersect_shape(query)
	for r in results:
		var col = r["collider"]
		if col == self:
			continue

		var dist = explode_pos.distance_to(col.global_position)
		var dmg_falloff = max(0.2, 1.0 - (dist / explosion_radius))
		var final_dmg = explosion_damage * dmg_falloff

		if col.is_in_group("enemies") and col.has_method("take_damage"):
			var dir = (col.global_position - explode_pos).normalized()
			col.take_damage(final_dmg, col.global_position, -dir, false)
			Global.add_style(50, "+ EXPLODED")
		elif col.is_in_group("player") and col.has_method("take_damage"):
			col.take_damage(final_dmg * 0.4) # Reduced self-damage
		elif col.is_in_group("explosives") and col.has_method("explode"):
			get_tree().create_timer(0.08).timeout.connect(col.explode)
		elif col is RigidBody3D:
			var impulse = (col.global_position - explode_pos).normalized() * 14.0
			col.apply_central_impulse(impulse)

	queue_free()
