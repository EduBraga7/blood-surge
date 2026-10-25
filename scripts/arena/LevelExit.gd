extends Area3D
class_name LevelExit

@export var next_scene_path: String = ""
var has_triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not has_triggered and body.is_in_group("player"):
		has_triggered = true
		Global.finish_level(next_scene_path)
		# Fanfare
		var audio = AudioStreamPlayer.new()
		audio.stream = load("res://assets/audio/blood_heal.wav")
		audio.pitch_scale = 1.4
		add_child(audio)
		audio.play()
