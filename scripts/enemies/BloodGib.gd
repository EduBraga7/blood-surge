extends RigidBody3D
class_name BloodGib

func _ready() -> void:
	# Random impulse
	var impulse = Vector3(
		randf_range(-6.0, 6.0),
		randf_range(4.0, 10.0),
		randf_range(-6.0, 6.0)
	)
	apply_central_impulse(impulse)
	apply_torque_impulse(Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10)))

	# Freeze body after arc to free physics cycles, then despawn
	get_tree().create_timer(1.2).timeout.connect(func(): freeze = true)
	get_tree().create_timer(2.4).timeout.connect(queue_free)
