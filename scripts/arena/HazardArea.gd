extends Area3D
class_name HazardArea

@export var dps: float = 28.0
@export var tick_interval: float = 0.35

var tick_timer: float = 0.0
var overlapping_bodies: Array[Node3D] = []

@onready var toxic_light: OmniLight3D = $ToxicLight

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	if toxic_light:
		toxic_light.light_energy = 3.2 + sin(Time.get_ticks_msec() * 0.005) * 1.0

	if overlapping_bodies.is_empty():
		return

	tick_timer -= delta
	if tick_timer <= 0.0:
		tick_timer = tick_interval
		for body in overlapping_bodies:
			if is_instance_valid(body):
				if body.is_in_group("player"):
					Global.damage_player(dps * tick_interval)
				elif body.has_method("take_damage"):
					body.take_damage(dps * tick_interval)

func _on_body_entered(body: Node3D) -> void:
	if not overlapping_bodies.has(body):
		overlapping_bodies.append(body)

func _on_body_exited(body: Node3D) -> void:
	overlapping_bodies.erase(body)
