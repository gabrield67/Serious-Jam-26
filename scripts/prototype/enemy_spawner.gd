extends Node2D
## Spawns enemies from a ring around the tornado.

@export var enemy_scene: PackedScene = preload("res://scenes/prototype/enemy.tscn")
@export var spawn_radius: float = 900.0
@export var start_delay: float = 3.0

@export_group("Cap scaling")
## Enemies allowed before any growth.
@export var base_cap: int = 1
## Extra cap per Fujita level (size pressure).
@export var per_fujita: int = 1
## Extra cap per wave (time pressure).
@export var per_wave: int = 1
## Absolute ceiling no matter what.
@export var hard_max: int = 10

@export_group("Pacing")
## Seconds per wave — each wave raises the cap and tightens spawn interval.
@export var wave_duration: float = 20.0
@export var base_interval: float = 6.0
@export var min_interval: float = 2.0
## How much each wave shortens the spawn interval.
@export var interval_speedup_per_wave: float = 0.5

var _elapsed: float = 0.0
var _timer: float = 0.0
var _wave: int = 0

func _ready() -> void:
	add_to_group("spawner")
	# Count the grace period as time already elapsed toward the first spawn.
	_timer = base_interval - start_delay

func _process(delta: float) -> void:
	_elapsed += delta
	_wave = int(_elapsed / wave_duration)

	_timer += delta
	var interval := maxf(min_interval, base_interval - _wave * interval_speedup_per_wave)
	if _timer >= interval:
		_timer = 0.0
		_spawn()

func _spawn() -> void:
	if enemy_scene == null:
		return
	if get_tree().get_nodes_in_group("enemy").size() >= current_cap():
		return
	var tornado := get_tree().get_first_node_in_group("tornado")
	var center: Vector2 = tornado.global_position if tornado else global_position
	var angle := randf() * TAU
	var enemy := enemy_scene.instantiate()
	add_child(enemy)
	enemy.global_position = center + Vector2(cos(angle), sin(angle)) * spawn_radius

## Current enemy ceiling = base + size pressure + wave pressure, clamped.
func current_cap() -> int:
	var lvl := 0
	var tornado := get_tree().get_first_node_in_group("tornado")
	if tornado and tornado.has_method("get_level"):
		lvl = tornado.get_level()
	return mini(hard_max, base_cap + lvl * per_fujita + _wave * per_wave)

func get_wave() -> int:
	return _wave
