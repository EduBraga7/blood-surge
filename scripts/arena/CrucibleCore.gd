extends Node3D

@onready var core_light: OmniLight3D = $CoreLight
@onready var magnetic_ring: MeshInstance3D = $MagneticRing

func _process(delta: float) -> void:
	if magnetic_ring:
		magnetic_ring.rotate_y(delta * 0.75)
		magnetic_ring.rotate_x(delta * 0.35)
	if core_light:
		core_light.light_energy = 7.0 + sin(Time.get_ticks_msec() * 0.004) * 2.0
