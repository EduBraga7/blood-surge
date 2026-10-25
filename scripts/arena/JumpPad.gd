extends Area3D
class_name JumpPad

@export var launch_force: float = 18.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.velocity.y = launch_force
		if body.has_method("add_trauma"):
			body.add_trauma(0.3)
		# Launch Audio
		var audio = AudioStreamPlayer.new()
		audio.stream = load("res://assets/audio/dash.wav")
		audio.pitch_scale = randf_range(1.4, 1.6)
		audio.volume_db = 1.0
		audio.bus = &"SFX"
		add_child(audio)
		audio.play()
		audio.finished.connect(audio.queue_free)

		var light = $OmniLight3D
		if light:
			light.light_energy = 8.0
			var tween = create_tween()
			tween.tween_property(light, "light_energy", 2.0, 0.3)
