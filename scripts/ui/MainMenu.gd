extends Control

@onready var start_btn: Button = $CenterContainer/VBox/MenuButtons/StartBtn
@onready var level_select_btn: Button = get_node_or_null("CenterContainer/VBox/MenuButtons/LevelSelectBtn")
@onready var controls_btn: Button = $CenterContainer/VBox/MenuButtons/ControlsBtn
@onready var quit_btn: Button = $CenterContainer/VBox/MenuButtons/QuitBtn

@onready var controls_modal: PanelContainer = $ControlsModal
@onready var close_controls_btn: Button = $ControlsModal/Margin/VBox/CloseControlsBtn

@onready var level_select_modal: PanelContainer = get_node_or_null("LevelSelectModal")
@onready var level0_btn: Button = get_node_or_null("LevelSelectModal/Margin/VBox/LevelsVBox/Level0Btn")
@onready var level1_btn: Button = get_node_or_null("LevelSelectModal/Margin/VBox/LevelsVBox/Level1Btn")
@onready var level2_btn: Button = get_node_or_null("LevelSelectModal/Margin/VBox/LevelsVBox/Level2Btn")
@onready var close_level_select_btn: Button = get_node_or_null("LevelSelectModal/Margin/VBox/CloseLevelSelectBtn")

@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Global.reset_game_state()

	if controls_modal:
		controls_modal.visible = false
	if level_select_modal:
		level_select_modal.visible = false

	if start_btn:
		start_btn.pressed.connect(_on_start_pressed)
		start_btn.mouse_entered.connect(_on_button_hover)
		start_btn.grab_focus()

	if level_select_btn:
		level_select_btn.pressed.connect(_on_level_select_pressed)
		level_select_btn.mouse_entered.connect(_on_button_hover)

	if controls_btn:
		controls_btn.pressed.connect(_on_controls_pressed)
		controls_btn.mouse_entered.connect(_on_button_hover)

	if quit_btn:
		quit_btn.pressed.connect(_on_quit_pressed)
		quit_btn.mouse_entered.connect(_on_button_hover)

	if close_controls_btn:
		close_controls_btn.pressed.connect(_on_close_controls_pressed)
		close_controls_btn.mouse_entered.connect(_on_button_hover)

	if close_level_select_btn:
		close_level_select_btn.pressed.connect(_on_close_level_select_pressed)
		close_level_select_btn.mouse_entered.connect(_on_button_hover)

	if level0_btn:
		level0_btn.pressed.connect(func(): _load_level("res://scenes/arena/TestArena.tscn"))
		level0_btn.mouse_entered.connect(_on_button_hover)
	if level1_btn:
		level1_btn.pressed.connect(func(): _load_level("res://scenes/arena/Level01_Incinerator.tscn"))
		level1_btn.mouse_entered.connect(_on_button_hover)
	if level2_btn:
		level2_btn.pressed.connect(func(): _load_level("res://scenes/arena/Level02_Cathedral.tscn"))
		level2_btn.mouse_entered.connect(_on_button_hover)

	if music_player and not music_player.playing:
		music_player.play()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if level_select_modal and level_select_modal.visible:
				level_select_modal.visible = false
				if level_select_btn:
					level_select_btn.grab_focus()
			elif controls_modal and controls_modal.visible:
				controls_modal.visible = false
				if controls_btn:
					controls_btn.grab_focus()

func _on_button_hover() -> void:
	if sfx_player:
		sfx_player.stream = load("res://assets/audio/shells_insert.wav")
		sfx_player.volume_db = -8.0
		sfx_player.pitch_scale = randf_range(1.1, 1.3)
		sfx_player.play()

func _on_start_pressed() -> void:
	_load_level("res://scenes/arena/Level01_Incinerator.tscn")

func _on_level_select_pressed() -> void:
	if level_select_modal:
		level_select_modal.visible = true
		if level1_btn:
			level1_btn.grab_focus()

func _on_close_level_select_pressed() -> void:
	if level_select_modal:
		level_select_modal.visible = false
	if level_select_btn:
		level_select_btn.grab_focus()

func _load_level(scene_path: String) -> void:
	if not is_inside_tree() or not get_tree():
		return
	get_tree().paused = false
	Global.reset_game_state()
	if sfx_player:
		sfx_player.stream = load("res://assets/audio/shotgun.wav")
		sfx_player.volume_db = 0.0
		sfx_player.pitch_scale = 1.0
		sfx_player.play()
	get_tree().change_scene_to_file.call_deferred(scene_path)

func _on_controls_pressed() -> void:
	if controls_modal:
		controls_modal.visible = true
		if close_controls_btn:
			close_controls_btn.grab_focus()

func _on_close_controls_pressed() -> void:
	if controls_modal:
		controls_modal.visible = false
	if controls_btn:
		controls_btn.grab_focus()

func _on_quit_pressed() -> void:
	get_tree().quit()
