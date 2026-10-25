extends Node

signal hit_registered(is_kill: bool, damage: float)
signal player_hp_changed(current: float, max_hp: float)
signal dash_charges_changed(charges: int, max_charges: int)
signal style_changed(style_name: String, style_color: Color, score: int)
signal screen_shake_requested(trauma: float)
signal level_completed(time_taken: float, total_kills: int, final_rank: String, final_score: int)

var player_max_hp: float = 100.0
var player_hp: float = 100.0

var level_timer: float = 0.0
var is_level_active: bool = true

var max_dash_charges: int = 3
var dash_charges: int = 3
var dash_recharge_time: float = 1.1
var dash_timer: float = 0.0

# Style rank system (Ultrakill style)
var style_score: int = 0
var style_decay_timer: float = 0.0
var current_rank_index: int = 0

const RANKS = [
	{"name": "FRESH", "color": Color(0.4, 0.8, 1.0), "threshold": 0},
	{"name": "CARNAGE", "color": Color(0.2, 0.9, 0.3), "threshold": 300},
	{"name": "BRUTAL", "color": Color(1.0, 0.85, 0.1), "threshold": 800},
	{"name": "ANARCHIC", "color": Color(1.0, 0.5, 0.1), "threshold": 1500},
	{"name": "SUPREME", "color": Color(1.0, 0.2, 0.2), "threshold": 2500},
	{"name": "SSADISTIC", "color": Color(0.9, 0.1, 0.8), "threshold": 4000},
	{"name": "ULTRAKILL", "color": Color(1.0, 1.0, 1.0), "threshold": 6000}
]

var kills_count: int = 0
var player_node: Node3D = null

# Blood Decal System
var blood_decal_tex: Texture2D = null
var active_decals: Array[Decal] = []
const MAX_DECALS: int = 48

func spawn_blood_splat(pos: Vector3, normal: Vector3, splat_size: float = 1.6) -> void:
	if not player_node or not is_instance_valid(player_node):
		return
	var root = player_node.get_parent()
	if not root:
		return

	if not blood_decal_tex:
		if ResourceLoader.exists("res://assets/textures/tex_blood_splat.png"):
			blood_decal_tex = load("res://assets/textures/tex_blood_splat.png") as Texture2D
		if not blood_decal_tex:
			return

	var decal = Decal.new()
	decal.texture_albedo = blood_decal_tex
	decal.size = Vector3(splat_size, 0.4, splat_size)
	decal.modulate = Color(randf_range(0.75, 1.0), 0.08, 0.12, 0.92)

	root.add_child(decal)
	decal.global_position = pos + normal * 0.05
	if normal.abs().is_equal_approx(Vector3.UP):
		decal.look_at(decal.global_position + normal, Vector3.FORWARD)
	else:
		decal.look_at(decal.global_position + normal, Vector3.UP)
	decal.rotate_object_local(Vector3.FORWARD, randf_range(0, TAU))

	active_decals.append(decal)
	if active_decals.size() > MAX_DECALS:
		var old = active_decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()

	var tween = decal.create_tween()
	tween.tween_interval(18.0)
	tween.tween_property(decal, "modulate:a", 0.0, 4.0)
	tween.tween_callback(func():
		if is_instance_valid(decal):
			active_decals.erase(decal)
			decal.queue_free()
	)

# Combat Audio & Synthesis Systems
var is_in_combat: bool = false
var heartbeat_timer: float = 0.0

var sub_bass_kick: AudioStreamWAV = null
var heartbeat_stream: AudioStreamWAV = null
var parry_chime_stream: AudioStreamWAV = null

var sub_bass_player: AudioStreamPlayer = null
var heartbeat_player: AudioStreamPlayer = null
var parry_chime_player: AudioStreamPlayer = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Procedurally generate heavy audio elements (Zero external dependencies)
	sub_bass_kick = _generate_sub_bass()
	heartbeat_stream = _generate_heartbeat()
	parry_chime_stream = _generate_parry_chime()

	sub_bass_player = AudioStreamPlayer.new()
	sub_bass_player.stream = sub_bass_kick
	sub_bass_player.bus = &"Combat"
	add_child(sub_bass_player)

	heartbeat_player = AudioStreamPlayer.new()
	heartbeat_player.stream = heartbeat_stream
	heartbeat_player.bus = &"SFX"
	add_child(heartbeat_player)

	parry_chime_player = AudioStreamPlayer.new()
	parry_chime_player.stream = parry_chime_stream
	parry_chime_player.bus = &"Combat"
	add_child(parry_chime_player)

func _process(delta: float) -> void:
	if is_level_active:
		level_timer += delta

	_update_audio(delta)

	# Dash recharge logic
	if dash_charges < max_dash_charges:
		dash_timer += delta
		if dash_timer >= dash_recharge_time:
			dash_charges += 1
			dash_timer = 0.0
			dash_charges_changed.emit(dash_charges, max_dash_charges)

	# Style score decay
	if style_score > 0:
		style_decay_timer += delta
		if style_decay_timer >= 0.1:
			style_decay_timer = 0.0
			style_score = max(0, style_score - 15)
			_update_rank()

func consume_dash() -> bool:
	if dash_charges > 0:
		dash_charges -= 1
		dash_charges_changed.emit(dash_charges, max_dash_charges)
		return true
	return false

func add_style(points: int, reason: String = "") -> void:
	style_score += points
	_update_rank()

func _update_rank() -> void:
	var target_index = 0
	for i in range(RANKS.size() - 1, -1, -1):
		if style_score >= RANKS[i]["threshold"]:
			target_index = i
			break
	current_rank_index = target_index
	var r = RANKS[target_index]
	style_changed.emit(r["name"], r["color"], style_score)

func report_hit(is_kill: bool, damage: float, distance: float) -> void:
	if is_kill:
		kills_count += 1
		if distance <= 4.5:
			add_style(150, "+ POINT BLANK KILL")
			heal_player(25.0)
		else:
			add_style(80, "+ KILL")
		trigger_hitstop(0.05)
	else:
		add_style(int(damage * 1.5))
	
	hit_registered.emit(is_kill, damage)

func heal_player(amount: float) -> void:
	player_hp = min(player_max_hp, player_hp + amount)
	player_hp_changed.emit(player_hp, player_max_hp)

func damage_player(amount: float) -> void:
	player_hp = max(0.0, player_hp - amount)
	player_hp_changed.emit(player_hp, player_max_hp)
	screen_shake_requested.emit(0.5)

var is_in_hitstop: bool = false

func trigger_hitstop(duration: float = 0.04) -> void:
	if is_in_hitstop:
		return
	is_in_hitstop = true
	Engine.time_scale = 0.08
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	is_in_hitstop = false

var next_level_path: String = ""

func finish_level(next_scene: String = "") -> void:
	is_level_active = false
	next_level_path = next_scene
	var rank_name = RANKS[current_rank_index]["name"]
	level_completed.emit(level_timer, kills_count, rank_name, style_score)

func reset_game_state() -> void:
	player_hp = player_max_hp
	dash_charges = max_dash_charges
	style_score = 0
	kills_count = 0
	level_timer = 0.0
	is_level_active = true
	is_in_combat = false
	player_hp_changed.emit(player_hp, player_max_hp)
	dash_charges_changed.emit(dash_charges, max_dash_charges)
	_update_rank()

func _update_audio(delta: float) -> void:
	# Low Health Heartbeat Alert
	if player_hp > 0.0 and player_hp <= 35.0:
		heartbeat_timer += delta
		if heartbeat_timer >= 0.82:
			heartbeat_timer = 0.0
			play_heartbeat()
	else:
		heartbeat_timer = 0.0

func set_combat_state(active: bool) -> void:
	is_in_combat = active

func duck_music(_amount_db: float = 3.5, _duration: float = 0.12) -> void:
	pass

func play_sub_bass_kick(vol_boost_db: float = 0.0, pitch: float = 1.0) -> void:
	if sub_bass_player and sub_bass_player.is_inside_tree():
		sub_bass_player.volume_db = vol_boost_db
		sub_bass_player.pitch_scale = pitch
		sub_bass_player.play()

func play_heartbeat() -> void:
	if heartbeat_player and heartbeat_player.is_inside_tree():
		heartbeat_player.pitch_scale = randf_range(0.96, 1.04)
		heartbeat_player.play()

func play_parry_chime() -> void:
	if parry_chime_player and parry_chime_player.is_inside_tree():
		parry_chime_player.play()

func _generate_sub_bass() -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.mix_rate = 44100
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false
	var total_samples = int(44100.0 * 0.24)
	var data = PackedByteArray()
	data.resize(total_samples * 2)
	var phase: float = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var freq = lerpf(135.0, 36.0, t * t)
		phase += (freq * TAU) / 44100.0
		var env = exp(-t * 6.5) * (1.0 - exp(-t * 90.0))
		var s = tanh(sin(phase) * env * 1.5)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	stream.data = data
	return stream

func _generate_heartbeat() -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.mix_rate = 44100
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false
	var total_samples = int(44100.0 * 0.18)
	var data = PackedByteArray()
	data.resize(total_samples * 2)
	var phase: float = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		var freq = lerpf(58.0, 28.0, t)
		phase += (freq * TAU) / 44100.0
		var env = exp(-t * 8.5) * (1.0 - exp(-t * 50.0))
		var s = sin(phase) * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	stream.data = data
	return stream

func _generate_parry_chime() -> AudioStreamWAV:
	var stream = AudioStreamWAV.new()
	stream.mix_rate = 44100
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = false
	var total_samples = int(44100.0 * 0.32)
	var data = PackedByteArray()
	data.resize(total_samples * 2)
	var phase1: float = 0.0
	var phase2: float = 0.0
	for i in range(total_samples):
		var t = float(i) / float(total_samples)
		phase1 += (1760.0 * TAU) / 44100.0
		phase2 += (3520.0 * TAU) / 44100.0
		var env = exp(-t * 10.0) * (1.0 - exp(-t * 120.0))
		var s = (sin(phase1) * 0.7 + sin(phase2) * 0.3) * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	stream.data = data
	return stream
