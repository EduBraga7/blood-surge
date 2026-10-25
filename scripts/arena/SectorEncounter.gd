extends Area3D
class_name SectorEncounter

@export var sector_name: String = "SECTOR A"
@export var entry_gate: Node3D
@export var exit_gate: Node3D
@export var target_kills: int = 5

var is_active: bool = false
var is_cleared: bool = false
var current_kills: int = 0
var spawned_count: int = 0
var resolved_sp: Array[Node3D] = []

var husk_scene = preload("res://scenes/enemies/Husk.tscn")
var sentinel_scene = preload("res://scenes/enemies/Sentinel.tscn")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	for c in get_children():
		if c is Node3D and c.name.begins_with("SP"):
			resolved_sp.append(c)

	if exit_gate and exit_gate.has_method("close_gate"):
		exit_gate.close_gate(true)
	if entry_gate and entry_gate.has_method("open_gate"):
		entry_gate.open_gate(true)

func _on_body_entered(body: Node3D) -> void:
	if not is_active and not is_cleared and body.is_in_group("player"):
		start_encounter()

func start_encounter() -> void:
	is_active = true
	Global.set_combat_state(true)
	Global.add_style(100, "+ " + sector_name + " ENGAGED")
	Global.screen_shake_requested.emit(0.3)
	Global.play_sub_bass_kick(2.5, 0.75)

	if entry_gate and entry_gate.has_method("close_gate"):
		entry_gate.close_gate()
	if exit_gate and exit_gate.has_method("close_gate"):
		exit_gate.close_gate()

	# 0.4s grace period so gates shut before enemies spawn
	await get_tree().create_timer(0.4).timeout
	if not is_inside_tree() or is_cleared:
		return

	_spawn_wave()

func _spawn_wave() -> void:
	if is_cleared or resolved_sp.is_empty():
		return

	for sp in resolved_sp:
		if spawned_count >= target_kills:
			break
		spawned_count += 1
		
		var enemy: Node3D
		if spawned_count % 3 == 0:
			enemy = sentinel_scene.instantiate()
		else:
			enemy = husk_scene.instantiate()

		get_parent().add_child(enemy)
		enemy.global_position = sp.global_position
		enemy.tree_exited.connect(_on_enemy_defeated)

func _on_enemy_defeated() -> void:
	if not is_active or is_cleared:
		return

	current_kills += 1
	if current_kills >= target_kills:
		clear_encounter()
	elif spawned_count < target_kills:
		_spawn_wave()

func clear_encounter() -> void:
	is_cleared = true
	is_active = false
	Global.set_combat_state(false)
	Global.add_style(500, "+ " + sector_name + " CLEARED")
	Global.duck_music(2.0, 0.4)

	if exit_gate and exit_gate.has_method("open_gate"):
		exit_gate.open_gate()

	var audio = AudioStreamPlayer.new()
	audio.stream = load("res://assets/audio/blood_heal.wav")
	audio.pitch_scale = 1.3
	audio.bus = &"SFX"
	add_child(audio)
	if audio.is_inside_tree():
		audio.play()
	else:
		audio.ready.connect(audio.play)
	audio.finished.connect(audio.queue_free)
