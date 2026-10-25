extends RigidBody3D
class_name ShotgunShellCasing

@export var lifetime: float = 3.0

var _timer: float = 0.0

func _ready() -> void:
	# Add slight initial random angular velocity for tumbling
	angular_velocity = Vector3(
		randf_range(-15.0, 15.0),
		randf_range(-20.0, 20.0),
		randf_range(-15.0, 15.0)
	)

func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer >= lifetime:
		queue_free()
