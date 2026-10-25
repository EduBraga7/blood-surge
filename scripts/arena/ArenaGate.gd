extends Node3D
class_name ArenaGate

@export var is_initially_open: bool = false
@export var open_height: float = 5.5

var is_open: bool = false

@onready var door_body: AnimatableBody3D = $DoorBody
@onready var beacon_light: OmniLight3D = $BeaconLight

var closed_y: float = 0.0

func _ready() -> void:
	closed_y = door_body.position.y
	if is_initially_open:
		open_gate(true)
	else:
		close_gate(true)

func open_gate(instant: bool = false) -> void:
	is_open = true
	if beacon_light:
		beacon_light.light_color = Color(0.2, 1.0, 0.3)
	
	var target_y = closed_y + open_height
	if instant:
		door_body.position.y = target_y
	else:
		var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(door_body, "position:y", target_y, 1.0)
		# Audio hiss
		_play_gate_sfx(1.1)

func close_gate(instant: bool = false) -> void:
	is_open = false
	if beacon_light:
		beacon_light.light_color = Color(1.0, 0.2, 0.1)

	if instant:
		door_body.position.y = closed_y
	else:
		var tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tween.tween_property(door_body, "position:y", closed_y, 0.7)
		_play_gate_sfx(0.7)
		Global.screen_shake_requested.emit(0.3)

func _play_gate_sfx(pitch: float) -> void:
	if not is_inside_tree():
		return
	var audio = AudioStreamPlayer3D.new()
	audio.stream = load("res://assets/audio/dash.wav")
	audio.pitch_scale = pitch
	audio.bus = &"SFX"
	add_child(audio)
	if audio.is_inside_tree():
		audio.play()
	else:
		audio.ready.connect(audio.play)
	audio.finished.connect(audio.queue_free)
