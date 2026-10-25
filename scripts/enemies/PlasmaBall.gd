extends Area3D
class_name PlasmaBall

@export var speed: float = 16.0
@export var damage: float = 25.0
var direction: Vector3 = Vector3.FORWARD
var lifetime: float = 5.0
var is_parried: bool = false

@onready var light: OmniLight3D = $OmniLight3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func parry(new_dir: Vector3) -> void:
	if is_parried:
		return
	is_parried = true
	direction = new_dir.normalized()
	speed = speed * 2.4
	damage = 120.0
	lifetime = 4.0
	collision_mask = 1 | 4 # Hit World and Enemies

	if light:
		light.light_color = Color(0.2, 0.9, 1.0)
		light.light_energy = 8.0

	if mesh_instance:
		var parry_mat = StandardMaterial3D.new()
		parry_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
		parry_mat.albedo_color = Color(0.3, 0.95, 1.0)
		mesh_instance.material_override = parry_mat

func _on_body_entered(body: Node3D) -> void:
	if is_parried:
		if body.is_in_group("enemies"):
			if body.has_method("take_damage"):
				body.take_damage(damage, global_position, -direction, false)
			Global.add_style(300, "+ PARRY EXPLOSION")
			Global.screen_shake_requested.emit(0.5)
			queue_free()
		elif not body.is_in_group("player"):
			queue_free()
	else:
		if body.is_in_group("player"):
			if body.has_method("take_damage"):
				body.take_damage(damage)
			queue_free()
		elif not body.is_in_group("enemies"):
			# Hit wall or floor
			queue_free()
