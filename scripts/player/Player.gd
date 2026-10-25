extends CharacterBody3D
class_name Player

@export var mouse_sensitivity: float = 0.0022
@export var base_speed: float = 13.5
@export var sprint_speed: float = 16.0
@export var jump_velocity: float = 9.8
@export var gravity: float = 26.0

# Dash
@export var dash_speed: float = 32.0
@export var dash_duration: float = 0.18
var is_dashing: bool = false
var dash_timer: float = 0.0
var dash_direction: Vector3 = Vector3.ZERO

# Slide
@export var slide_start_speed: float = 22.0
@export var slide_friction: float = 4.5
var is_sliding: bool = false
var slide_direction: Vector3 = Vector3.ZERO
var slide_speed: float = 0.0
var original_cam_y: float = 1.65
var slide_cam_y: float = 0.75

# Camera & Trauma
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var weapon_holder: Node3D = $Head/Camera3D/WeaponHolder
@onready var shotgun: Node3D = get_node_or_null("Head/Camera3D/WeaponHolder/Shotgun")
@onready var revolver: Node3D = get_node_or_null("Head/Camera3D/WeaponHolder/Revolver")
@onready var melee_arm: Node3D = $Head/Camera3D/MeleeArm

var weapons: Array[Node3D] = []
var current_weapon_index: int = 0
@onready var slide_sparks: CPUParticles3D = $SlideSparks
@onready var dash_audio: AudioStreamPlayer = $DashAudio
@onready var heal_audio: AudioStreamPlayer = $HealAudio
@onready var hurt_audio: AudioStreamPlayer = $HurtAudio
@onready var punch_whiff_audio: AudioStreamPlayer = $PunchWhiffAudio
@onready var punch_hit_audio: AudioStreamPlayer = $PunchHitAudio

var trauma: float = 0.0
var trauma_decay: float = 2.5
var max_shake_pitch: float = 0.08
var max_shake_yaw: float = 0.08
var max_shake_roll: float = 0.06

# Recoil kickback from weapon
var recoil_pitch: float = 0.0
var recoil_recovery: float = 14.0

# Melee
var melee_cooldown: float = 0.0
var melee_rate: float = 0.38
var original_arm_pos: Vector3 = Vector3(-0.28, -0.55, -0.2)
var punch_tween: Tween = null

# Invulnerability & Void Recovery
var is_invulnerable: bool = false
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var last_safe_pos: Vector3 = Vector3(0, 1.0, 54.0)
var void_recovery_cooldown: float = 0.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Global.player_node = self
	Global.screen_shake_requested.connect(add_trauma)
	Global.player_hp_changed.connect(_on_hp_changed)
	Global.reset_game_state()
	last_safe_pos = global_position
	weapons = []
	if shotgun:
		weapons.append(shotgun)
		shotgun.visible = true
	if revolver:
		weapons.append(revolver)
		revolver.visible = false
	current_weapon_index = 0

	if melee_arm:
		melee_arm.visible = false
		original_arm_pos = melee_arm.position

func switch_weapon(new_index: int) -> void:
	if new_index == current_weapon_index or new_index < 0 or new_index >= weapons.size():
		return
	var old_w = weapons[current_weapon_index]
	current_weapon_index = new_index
	var new_w = weapons[current_weapon_index]

	if old_w and old_w.has_method("unequip"):
		old_w.unequip()
	elif old_w:
		old_w.visible = false

	if new_w and new_w.has_method("equip"):
		new_w.equip()
	elif new_w:
		new_w.visible = true

	Global.add_style(50, "+ QUICK DRAW")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
		if current_weapon_index < weapons.size() and weapons[current_weapon_index]:
			var cur = weapons[current_weapon_index]
			if cur.has_method("add_mouse_motion"):
				cur.add_mouse_motion(event.relative)

	# Weapon Quick-Switch
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			switch_weapon(0)
		elif event.keycode == KEY_2:
			switch_weapon(1)
		elif event.keycode == KEY_Q:
			switch_weapon(1 if current_weapon_index == 0 else 0)

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			switch_weapon((current_weapon_index - 1 + weapons.size()) % weapons.size())
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			switch_weapon((current_weapon_index + 1) % weapons.size())

	# Mouse Click Fire Handling
	if event is InputEventMouseButton:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		var cur_w = weapons[current_weapon_index] if current_weapon_index < weapons.size() else null
		if cur_w:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				if cur_w.has_method("fire"):
					cur_w.fire()
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				if cur_w == shotgun and event.pressed and shotgun.has_method("fire_alt"):
					shotgun.fire_alt()
				elif cur_w == revolver:
					if event.pressed and revolver.has_method("start_alt_charge"):
						revolver.start_alt_charge()
					elif not event.pressed and revolver.has_method("release_alt_charge"):
						revolver.release_alt_charge()

	if event.is_action_pressed("restart") or (event is InputEventKey and event.keycode == KEY_R and event.pressed):
		if Global.player_hp <= 0:
			get_tree().reload_current_scene()
		else:
			var cur_w = weapons[current_weapon_index] if current_weapon_index < weapons.size() else null
			if cur_w and cur_w.has_method("start_reload"):
				cur_w.start_reload()

	if event is InputEventKey and event.pressed and (event.keycode == KEY_T or event.keycode == KEY_I):
		var cur_w = weapons[current_weapon_index] if current_weapon_index < weapons.size() else null
		if cur_w and cur_w.has_method("inspect"):
			cur_w.inspect()

	if event.is_action_pressed("melee") or (event is InputEventKey and event.keycode == KEY_F and event.pressed):
		if melee_cooldown <= 0.0 and Global.player_hp > 0:
			perform_melee()

func _physics_process(delta: float) -> void:
	if Global.player_hp <= 0:
		velocity.x = move_toward(velocity.x, 0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 10.0 * delta)
		velocity.y -= gravity * delta
		move_and_slide()
		return

	# Continuous shoot trigger
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_pressed("shoot"):
		var cur_w = weapons[current_weapon_index] if current_weapon_index < weapons.size() else null
		if cur_w and cur_w.has_method("fire") and "can_shoot" in cur_w and cur_w.can_shoot:
			cur_w.fire()

	if melee_cooldown > 0.0:
		melee_cooldown = max(0.0, melee_cooldown - delta)

	# Coyote time & Jump buffer
	if is_on_floor():
		coyote_timer = 0.15
	else:
		coyote_timer = max(0.0, coyote_timer - delta)

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = 0.15
	else:
		jump_buffer_timer = max(0.0, jump_buffer_timer - delta)

	# Direction input
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Handle Dash Input
	if Input.is_action_just_pressed("dash") and not is_dashing and Global.consume_dash():
		_start_dash()

	# Process Dash
	if is_dashing:
		dash_timer -= delta
		velocity = dash_direction * dash_speed
		if dash_timer <= 0.0:
			is_dashing = false
			is_invulnerable = false
			# Momentum preservation on exit
			if move_direction.length() > 0.1:
				velocity.x = dash_direction.x * sprint_speed
				velocity.z = dash_direction.z * sprint_speed
		move_and_slide()
		_process_camera_shake(delta)
		_check_void_and_safe_ground(delta)
		return

	# Handle Slide Input
	if Input.is_action_pressed("slide") and is_on_floor() and not is_sliding:
		if move_direction.length() > 0.1:
			_start_slide(move_direction)
		else:
			_start_slide(-transform.basis.z)
	elif not Input.is_action_pressed("slide") and is_sliding:
		_stop_slide()

	# Process Slide
	if is_sliding:
		slide_speed = max(base_speed, slide_speed - slide_friction * delta)
		velocity.x = slide_direction.x * slide_speed
		velocity.z = slide_direction.z * slide_speed

		# Jump out of slide (Slide Hop!)
		if jump_buffer_timer > 0.0:
			velocity.y = jump_velocity * 1.1
			velocity.x = slide_direction.x * (slide_speed * 1.18)
			velocity.z = slide_direction.z * (slide_speed * 1.18)
			jump_buffer_timer = 0.0
			coyote_timer = 0.0
			_stop_slide()
	else:
		if not is_on_floor():
			velocity.y -= gravity * delta

		if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
			velocity.y = jump_velocity
			jump_buffer_timer = 0.0
			coyote_timer = 0.0

		var target_speed = base_speed
		var accel = 160.0 if is_on_floor() else 75.0
		var deaccel = 130.0 if is_on_floor() else 25.0

		if move_direction:
			velocity.x = move_toward(velocity.x, move_direction.x * target_speed, accel * delta)
			velocity.z = move_toward(velocity.z, move_direction.z * target_speed, accel * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, deaccel * delta)
			velocity.z = move_toward(velocity.z, 0, deaccel * delta)

	move_and_slide()
	_process_camera_shake(delta)
	_check_void_and_safe_ground(delta)

	# Dynamic Speed FOV Kick (Adrenaline feedback)
	var h_vel = Vector2(velocity.x, velocity.z).length()
	var base_fov = 95.0
	var target_fov = base_fov
	if is_sliding:
		target_fov = 104.0
	elif h_vel > 14.0:
		target_fov = clampf(remap(h_vel, 14.0, 28.0, base_fov, 108.0), base_fov, 108.0)
	camera.fov = lerpf(camera.fov, target_fov, 8.0 * delta)

func _check_void_and_safe_ground(delta: float) -> void:
	if void_recovery_cooldown > 0.0:
		void_recovery_cooldown = max(0.0, void_recovery_cooldown - delta)

	# Only track safe floor if on solid ground above the acid pit floor
	if is_on_floor() and global_position.y >= -1.0:
		last_safe_pos = global_position

	# Limbo / Void Fall Protection
	if global_position.y < -12.0 and void_recovery_cooldown <= 0.0:
		_recover_from_void()

func _recover_from_void() -> void:
	void_recovery_cooldown = 1.0
	is_dashing = false
	is_sliding = false
	velocity = Vector3.ZERO
	take_damage(20.0)
	add_trauma(0.7)

	if Global.player_hp > 0:
		global_position = last_safe_pos + Vector3(0, 1.2, 0)

func _start_dash() -> void:
	is_dashing = true
	is_invulnerable = true
	dash_timer = dash_duration
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input_dir.length() > 0.1:
		dash_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	else:
		dash_direction = -transform.basis.z

	if dash_audio and dash_audio.stream:
		dash_audio.play()

	var tween = create_tween()
	tween.tween_property(camera, "fov", 104.0, 0.08)
	tween.tween_property(camera, "fov", 90.0, 0.14)
	add_trauma(0.2)

func _start_slide(direction: Vector3) -> void:
	is_sliding = true
	slide_direction = direction
	slide_speed = slide_start_speed
	var tween = create_tween()
	tween.tween_property(head, "position:y", slide_cam_y, 0.1)
	collision_shape.scale.y = 0.5
	collision_shape.position.y = 0.45
	add_trauma(0.15)
	if slide_sparks:
		slide_sparks.emitting = true

func _stop_slide() -> void:
	is_sliding = false
	var tween = create_tween()
	tween.tween_property(head, "position:y", original_cam_y, 0.12)
	collision_shape.scale.y = 1.0
	collision_shape.position.y = 0.9
	if slide_sparks:
		slide_sparks.emitting = false

func perform_melee() -> void:
	melee_cooldown = melee_rate

	# Whiff audio
	if punch_whiff_audio:
		punch_whiff_audio.pitch_scale = randf_range(1.6, 2.0)
		punch_whiff_audio.play()

	# Visual punch tween on robotic fist (whipping from below the screen and instantly retracting)
	if melee_arm:
		if punch_tween and punch_tween.is_valid():
			punch_tween.kill()

		melee_arm.visible = true
		melee_arm.position = Vector3(-0.25, -0.42, -0.20)
		melee_arm.rotation = Vector3(deg_to_rad(15), deg_to_rad(-10), deg_to_rad(-12))

		punch_tween = create_tween()
		# Fast thrust towards center
		punch_tween.tween_property(melee_arm, "position", Vector3(-0.06, -0.10, -0.42), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		punch_tween.parallel().tween_property(melee_arm, "rotation", Vector3(deg_to_rad(-6), deg_to_rad(6), deg_to_rad(6)), 0.06)
		# Snap retraction back down out of the viewport
		punch_tween.tween_property(melee_arm, "position", Vector3(-0.28, -0.55, -0.20), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		punch_tween.parallel().tween_property(melee_arm, "rotation", Vector3(deg_to_rad(20), deg_to_rad(-15), 0), 0.12)
		# Hide completely when done so screen remains clean
		punch_tween.tween_callback(func(): melee_arm.visible = false)

	# Camera punch trauma & micro forward lunge
	add_trauma(0.2)
	velocity += -transform.basis.z * 4.0

	# Raycast check (3.4m reach)
	var space_state = get_world_3d().direct_space_state
	var cam_pos = camera.global_position
	var cam_forward = -camera.global_transform.basis.z
	var punch_end = cam_pos + cam_forward * 3.4

	var query = PhysicsRayQueryParameters3D.create(cam_pos, punch_end)
	query.collision_mask = 1 | 4 | 8 # World (1), Enemies (4), Projectiles (8)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [self]

	var result = space_state.intersect_ray(query)
	if result:
		var hit_collider = result["collider"]
		var hit_point = result["position"]
		var hit_normal = result["normal"]

		# 1. PARRY PROJECTILE!
		if hit_collider is PlasmaBall or hit_collider.has_method("parry"):
			hit_collider.parry(cam_forward)
			Global.heal_player(100.0) # Full heal on successful parry (Ultrakill rule!)
			Global.trigger_hitstop(0.08)
			Global.add_style(500, "+ PROJECTILE PARRY")
			Global.play_sub_bass_kick(4.0, 0.85)
			Global.play_parry_chime()
			Global.duck_music(5.0, 0.2)
			add_trauma(0.6)
			if punch_hit_audio:
				punch_hit_audio.pitch_scale = 1.3
				punch_hit_audio.play()
			return

		# 2. PUNCH ENEMY!
		if hit_collider and hit_collider.has_method("take_damage"):
			var damage = 50.0
			var is_kill = hit_collider.take_damage(damage, hit_point, hit_normal, true)
			if "knockback" in hit_collider:
				hit_collider.knockback = cam_forward * 22.0 + Vector3(0, 4, 0)
			elif hit_collider is CharacterBody3D:
				hit_collider.velocity = cam_forward * 22.0 + Vector3(0, 4, 0)

			Global.heal_player(25.0)
			Global.trigger_hitstop(0.06)
			Global.add_style(150, "+ DISRESPECT PUNCH" if not is_kill else "+ PUNCH KILL")
			Global.play_sub_bass_kick(2.0, 1.1)
			Global.duck_music(2.5, 0.08)
			add_trauma(0.4)
			if punch_hit_audio:
				punch_hit_audio.pitch_scale = randf_range(0.85, 1.05)
				punch_hit_audio.play()
			return

		# 3. PUNCH EXPLOSIVE BARREL!
		if hit_collider and hit_collider.is_in_group("explosives"):
			hit_collider.take_damage(999.0, hit_point, hit_normal, true)
			Global.add_style(200, "+ BARREL SMASH")
			Global.play_sub_bass_kick(3.5, 0.7)
			Global.duck_music(4.0, 0.15)
			add_trauma(0.5)
			if punch_hit_audio:
				punch_hit_audio.play()

func add_trauma(amount: float) -> void:
	trauma = min(1.0, trauma + amount)

func add_recoil(pitch_kick: float) -> void:
	recoil_pitch += pitch_kick
	add_trauma(0.3)

func _process_camera_shake(delta: float) -> void:
	if recoil_pitch > 0.0:
		var recovery = recoil_recovery * delta
		head.rotation.x -= min(recoil_pitch, recovery)
		recoil_pitch = max(0.0, recoil_pitch - recovery)

	if trauma > 0.0:
		trauma = max(0.0, trauma - trauma_decay * delta)
		var shake = trauma * trauma
		camera.rotation.x = (randf_range(-1.0, 1.0) * max_shake_pitch) * shake
		camera.rotation.y = (randf_range(-1.0, 1.0) * max_shake_yaw) * shake
		camera.rotation.z = (randf_range(-1.0, 1.0) * max_shake_roll) * shake
	else:
		camera.rotation = camera.rotation.lerp(Vector3.ZERO, delta * 15.0)

func take_damage(amount: float) -> void:
	if is_invulnerable or Global.player_hp <= 0:
		return
	Global.damage_player(amount)
	if hurt_audio and hurt_audio.stream:
		hurt_audio.play()

func _on_hp_changed(current: float, max_hp: float) -> void:
	if current > 0 and heal_audio and current > Global.player_hp:
		heal_audio.play()
