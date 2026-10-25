extends CanvasLayer
class_name HUD

@onready var hp_label: Label = $Margin/BottomLeft/VBox/HPLabel
@onready var hp_bar: ProgressBar = $Margin/BottomLeft/VBox/HPBar
@onready var dash_container: HBoxContainer = $Margin/BottomLeft/VBox/DashContainer

@onready var crosshair: Control = $CenterContainer/Crosshair
@onready var reload_bar: ProgressBar = $CenterContainer/Crosshair/ReloadBar
@onready var shell_pip1: ColorRect = $CenterContainer/Crosshair/AmmoContainer/ShellPip1
@onready var shell_pip2: ColorRect = $CenterContainer/Crosshair/AmmoContainer/ShellPip2
@onready var hitmarker: Control = $CenterContainer/Hitmarker

@onready var style_label: Label = $Margin/RightSide/VBox/StyleLabel
@onready var score_label: Label = $Margin/RightSide/VBox/ScoreLabel
@onready var kills_label: Label = $Margin/RightSide/VBox/KillsLabel

@onready var blood_vignette: ColorRect = $BloodVignette
@onready var death_panel: PanelContainer = $DeathPanel
@onready var victory_panel: PanelContainer = $VictoryPanel
@onready var victory_rank: Label = get_node_or_null("VictoryPanel/Margin/VBox/RankLabel")
@onready var victory_stats: Label = get_node_or_null("VictoryPanel/Margin/VBox/StatsLabel")
@onready var victory_next_btn: Button = get_node_or_null("VictoryPanel/Margin/VBox/NextLevelBtn")
@onready var victory_replay_btn: Button = get_node_or_null("VictoryPanel/Margin/VBox/ReplayBtn")
@onready var victory_menu_btn: Button = get_node_or_null("VictoryPanel/Margin/VBox/MainMenuBtn")

@onready var pause_menu: Control = get_node_or_null("PauseMenu")
@onready var resume_btn: Button = get_node_or_null("PauseMenu/Center/Panel/Margin/VBox/ResumeBtn")
@onready var restart_btn: Button = get_node_or_null("PauseMenu/Center/Panel/Margin/VBox/RestartBtn")
@onready var controls_btn: Button = get_node_or_null("PauseMenu/Center/Panel/Margin/VBox/ControlsBtn")
@onready var main_menu_btn: Button = get_node_or_null("PauseMenu/Center/Panel/Margin/VBox/MainMenuBtn")
@onready var quit_btn: Button = get_node_or_null("PauseMenu/Center/Panel/Margin/VBox/QuitBtn")
@onready var controls_modal: PanelContainer = get_node_or_null("PauseMenu/ControlsModal")
@onready var close_controls_btn: Button = get_node_or_null("PauseMenu/ControlsModal/Margin/VBox/CloseControlsBtn")

var hitmarker_timer: float = 0.0

func _ready() -> void:
	Global.player_hp_changed.connect(_on_hp_changed)
	Global.dash_charges_changed.connect(_on_dash_charges_changed)
	Global.style_changed.connect(_on_style_changed)
	Global.hit_registered.connect(_on_hit_registered)
	Global.level_completed.connect(_on_level_completed)

	if hitmarker:
		hitmarker.visible = false
	if reload_bar:
		reload_bar.visible = false
	if death_panel:
		death_panel.visible = false
	if victory_panel:
		victory_panel.visible = false
	if blood_vignette:
		blood_vignette.modulate.a = 0.0
	if pause_menu:
		pause_menu.visible = false
	if controls_modal:
		controls_modal.visible = false

	if resume_btn:
		resume_btn.pressed.connect(_on_resume_pressed)
	if restart_btn:
		restart_btn.pressed.connect(_on_restart_pressed)
	if controls_btn:
		controls_btn.pressed.connect(_on_controls_pressed)
	if close_controls_btn:
		close_controls_btn.pressed.connect(_on_close_controls_pressed)
	if main_menu_btn:
		main_menu_btn.pressed.connect(_on_main_menu_pressed)
	if quit_btn:
		quit_btn.pressed.connect(_on_quit_pressed)

	if victory_next_btn:
		victory_next_btn.pressed.connect(_on_victory_next_pressed)
	if victory_replay_btn:
		victory_replay_btn.pressed.connect(_on_victory_replay_pressed)
	if victory_menu_btn:
		victory_menu_btn.pressed.connect(_on_victory_menu_pressed)

	_update_dash_icons(Global.dash_charges, Global.max_dash_charges)
	_on_hp_changed(Global.player_hp, Global.player_max_hp)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if controls_modal and controls_modal.visible:
				controls_modal.visible = false
			else:
				toggle_pause()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_R:
			if get_tree().paused or (death_panel and death_panel.visible) or (victory_panel and victory_panel.visible):
				_on_restart_pressed()
				get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	if death_panel and death_panel.visible:
		return
	if victory_panel and victory_panel.visible:
		return

	var is_paused = not get_tree().paused
	get_tree().paused = is_paused
	if pause_menu:
		pause_menu.visible = is_paused
	if controls_modal:
		controls_modal.visible = false

	if is_paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if resume_btn:
			resume_btn.grab_focus()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_resume_pressed() -> void:
	toggle_pause()

func _on_restart_pressed() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Global.reset_game_state()
	get_tree().reload_current_scene.call_deferred()

func _on_controls_pressed() -> void:
	if controls_modal:
		controls_modal.visible = not controls_modal.visible
		if controls_modal.visible and close_controls_btn:
			close_controls_btn.grab_focus()

func _on_close_controls_pressed() -> void:
	if controls_modal:
		controls_modal.visible = false
	if controls_btn:
		controls_btn.grab_focus()

func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Global.reset_game_state()
	get_tree().change_scene_to_file.call_deferred("res://scenes/ui/MainMenu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _process(delta: float) -> void:
	if hitmarker_timer > 0.0:
		hitmarker_timer -= delta
		if hitmarker_timer <= 0.0 and hitmarker:
			hitmarker.visible = false

	if blood_vignette:
		if Global.player_hp > 0.0 and Global.player_hp <= 35.0:
			# Pulsing red adrenaline vignette in sync with the sub-bass heartbeat
			var pulse = (sin(Time.get_ticks_msec() * 0.0075) * 0.5 + 0.5) * 0.3
			blood_vignette.color = Color(0.9, 0.05, 0.05, 1.0)
			blood_vignette.modulate.a = maxf(blood_vignette.modulate.a, 0.12 + pulse)
		elif blood_vignette.modulate.a > 0.0:
			blood_vignette.modulate.a = max(0.0, blood_vignette.modulate.a - delta * 3.5)

	if is_instance_valid(Global.player_node) and Global.player_node.weapons.size() > 0:
		var p = Global.player_node
		var gun = p.weapons[p.current_weapon_index] if p.current_weapon_index < p.weapons.size() else null
		if gun and is_instance_valid(gun):
			var is_revolver = (gun.name == "Revolver")
			if "is_reloading" in gun and gun.is_reloading:
				if reload_bar:
					reload_bar.visible = true
					var r_dur = gun.reload_duration if "reload_duration" in gun else 0.8
					var r_tim = gun.reload_timer if "reload_timer" in gun else 0.0
					var progress = 1.0 - clampf(r_tim / maxf(r_dur, 0.001), 0.0, 1.0)
					reload_bar.value = progress
					reload_bar.modulate = Color(0.2, 0.85, 1.0, 0.95) if is_revolver else Color(1.0, 0.35, 0.15, 0.95)
				var pulse = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
				if shell_pip1:
					shell_pip1.color = Color(0.2, 0.8, 1.0, pulse) if is_revolver else Color(1.0, 0.6, 0.1, pulse)
				if shell_pip2:
					shell_pip2.color = Color(0.2, 0.8, 1.0, pulse) if is_revolver else Color(1.0, 0.6, 0.1, pulse)
			else:
				if reload_bar:
					var can_sh = gun.can_shoot if "can_shoot" in gun else true
					var f_tim = gun.fire_timer if "fire_timer" in gun else 0.0
					var f_rat = gun.fire_rate if "fire_rate" in gun else 0.2
					if not can_sh:
						reload_bar.visible = true
						var progress = 1.0 - clampf(f_tim / maxf(f_rat, 0.001), 0.0, 1.0)
						reload_bar.value = progress
						reload_bar.modulate = Color(0.2, 0.9, 1.0, 0.8) if is_revolver else Color(1.0, 0.75, 0.2, 0.8)
					else:
						if reload_bar.visible:
							reload_bar.visible = false
				var cur_am = gun.current_ammo if "current_ammo" in gun else 0
				if shell_pip1:
					var active_col = Color(0.2, 0.9, 1.0, 0.95) if is_revolver else Color(0.9, 0.15, 0.15, 0.95)
					shell_pip1.color = active_col if cur_am >= 1 else Color(0.2, 0.22, 0.25, 0.4)
				if shell_pip2:
					var active_col = Color(0.2, 0.9, 1.0, 0.95) if is_revolver else Color(0.9, 0.15, 0.15, 0.95)
					shell_pip2.color = active_col if (cur_am >= 3 if is_revolver else cur_am >= 2) else Color(0.2, 0.22, 0.25, 0.4)

	if kills_label:
		kills_label.text = "KILLS: %d" % Global.kills_count

func _on_hp_changed(current: float, max_hp: float) -> void:
	if hp_label:
		hp_label.text = "+ %d" % int(current)
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current

	if current <= 0.0:
		if death_panel:
			death_panel.visible = true
	else:
		if death_panel:
			death_panel.visible = false

func _on_dash_charges_changed(charges: int, max_charges: int) -> void:
	_update_dash_icons(charges, max_charges)

func _update_dash_icons(charges: int, max_charges: int) -> void:
	if not dash_container:
		return
	var children = dash_container.get_children()
	for i in range(children.size()):
		if i < charges:
			children[i].modulate = Color(0.2, 0.9, 1.0, 1.0) # Active Cyan
		else:
			children[i].modulate = Color(0.2, 0.2, 0.25, 0.5) # Depleted

func _on_style_changed(style_name: String, style_color: Color, score: int) -> void:
	if style_label:
		style_label.text = style_name
		style_label.modulate = style_color
	if score_label:
		score_label.text = "%d PTS" % score

func _on_level_completed(time_taken: float, total_kills: int, final_rank: String, final_score: int) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if victory_panel:
		victory_panel.visible = true
	if victory_rank:
		victory_rank.text = final_rank
	if victory_stats:
		var mins = int(time_taken) / 60
		var secs = fmod(time_taken, 60.0)
		victory_stats.text = "TIME: %02d:%04.1f\nKILLS: %d\nSTYLE: %d PTS" % [mins, secs, total_kills, final_score]

	if victory_next_btn:
		if Global.next_level_path != "":
			victory_next_btn.visible = true
			victory_next_btn.grab_focus()
		else:
			victory_next_btn.visible = false
			if victory_replay_btn:
				victory_replay_btn.grab_focus()

func _on_victory_next_pressed() -> void:
	if Global.next_level_path != "":
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		Global.reset_game_state()
		get_tree().change_scene_to_file.call_deferred(Global.next_level_path)

func _on_victory_replay_pressed() -> void:
	_on_restart_pressed()

func _on_victory_menu_pressed() -> void:
	_on_main_menu_pressed()

func _on_hit_registered(is_kill: bool, damage: float) -> void:
	if hitmarker:
		hitmarker.visible = true
		hitmarker.modulate = Color(1.0, 0.1, 0.1) if is_kill else Color(1.0, 1.0, 1.0)
		hitmarker_timer = 0.14

	if is_kill and blood_vignette:
		# Green/Cyan healing flash
		blood_vignette.color = Color(0.1, 0.9, 0.5, 0.3)
		blood_vignette.modulate.a = 0.4
