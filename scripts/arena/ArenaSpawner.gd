extends Node3D
class_name ArenaSpawner

@export var max_active_enemies: int = 8
@export var spawn_interval: float = 2.2

var husk_scene = preload("res://scenes/enemies/Husk.tscn")
var sentinel_scene = preload("res://scenes/enemies/Sentinel.tscn")

var spawn_timer: float = 0.5
@onready var spawn_points: Node3D = $SpawnPoints
@onready var metal_music: AudioStreamPlayer = $MetalMusic

func _ready() -> void:
	if metal_music:
		metal_music.stop()

func _process(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = spawn_interval
		_check_and_spawn()

func _check_and_spawn() -> void:
	var current_enemies = get_tree().get_nodes_in_group("enemies").size()
	if current_enemies >= max_active_enemies:
		return

	if not spawn_points or spawn_points.get_child_count() == 0:
		return

	# Pick random spawn point
	var sp_index = randi() % spawn_points.get_child_count()
	var sp = spawn_points.get_child(sp_index) as Node3D

	# 75% Husk, 25% Sentinel
	var enemy = null
	if randf() < 0.75 or current_enemies < 2:
		enemy = husk_scene.instantiate()
	else:
		enemy = sentinel_scene.instantiate()

	get_parent().add_child(enemy)
	enemy.global_position = sp.global_position
