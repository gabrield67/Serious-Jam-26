extends Node3D
## Truck NPC — never stops. It steers toward the tornado but can only turn so fast, so it
## overshoots and sweeps past in drive-by arcs, leaving a trail of bomb barrels on the
## ground. The tornado's indiscriminate suck then grabs them (see barrel.gd).

@export_group("Drive")
@export var speed: float = 12.0
## How sharply it steers toward the tornado (deg/sec). Lower = wider drive-by passes.
@export var turn_speed: float = 110.0
## Yaw correction if the model's nose faces the wrong way.
@export var facing_offset: float = 0.0

@export_group("Barrel drop")
## Distance between dropped barrels (the spacing of the trail).
@export var drop_spacing: float = 12.0
## Only drops barrels when the tornado is at least this close.
@export var drop_range: float = 70.0
## Height the barrel spawns at (on the ground).
@export var drop_height: float = 1.0
@export var barrel_scene: PackedScene = preload("res://scenes/Barrel.tscn")

var _target: Node3D
var _heading: float = 0.0       # travel direction (yaw), independent of facing_offset
var _ground_y: float = 0.0
var _dist_since_drop: float = 0.0

func _ready() -> void:
	add_to_group("enemy")
	_ground_y = global_position.y       # stay at the height it was placed at
	_heading = rotation.y - facing_offset

func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("tornado")
		if _target == null:
			return

	var to_t := _target.global_position - global_position
	to_t.y = 0.0
	var dist := to_t.length()

	# Steer toward the tornado, but only so fast — so it overshoots and passes by.
	if dist > 0.01:
		var desired := atan2(to_t.x, to_t.z)
		_heading = rotate_toward(_heading, desired, deg_to_rad(turn_speed) * delta)

	# Always drive forward along the heading.
	var forward := Vector3(sin(_heading), 0.0, cos(_heading))
	var pos := global_position + forward * speed * delta
	pos.y = _ground_y
	global_position = pos

	var r := rotation
	r.y = _heading + facing_offset
	rotation = r

	# Leave a trail of barrels as it drives past.
	_dist_since_drop += speed * delta
	if dist <= drop_range and _dist_since_drop >= drop_spacing:
		_dist_since_drop = 0.0
		_drop_barrel()

func _drop_barrel() -> void:
	if barrel_scene == null:
		return
	var b := barrel_scene.instantiate()
	get_tree().current_scene.add_child(b)
	b.global_position = Vector3(global_position.x, drop_height, global_position.z)
