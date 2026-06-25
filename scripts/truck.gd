extends Enemy
## "Storm Chaser" truck — races to a spot in front of the tornado (along its heading), drops
## a single barrel in its path, then turns and drives away WITHOUT driving into the storm. If
## the player steers the tornado into it, though, it gets swept up like other debris.

@export_group("Drive")
@export var speed: float = 40.0
@export var turn_speed: float = 160.0
## Yaw correction if the model's nose faces the wrong way.
@export var facing_offset: float = 0.0
## How far in front of the tornado (along its heading) it plants the barrel.
@export var lead_distance: float = 40.0
## It won't close nearer than this to the tornado on its run — drops early and peels off if
## its path would bring it closer, so it never drives into the funnel on its own.
@export var min_clearance: float = 28.0
## Close enough to the drop point to release the barrel.
@export var drop_threshold: float = 6.0
## Distance fallback for despawn if there's no camera to test against.
@export var despawn_distance: float = 320.0

@export_group("Barrel")
@export var drop_height: float = 1.0
@export var barrel_scene: PackedScene = preload("res://scenes/debris/Barrel.tscn")

@export_group("Caught")
## If the tornado column gets this close (horizontally), the truck is swept up.
@export var catch_radius: float = 14.0
## How long the caught-and-spinning moment lasts before it despawns.
@export var caught_time: float = 0.9
## How high up the funnel it's lifted while being pulled in.
@export var catch_lift: float = 40.0
## How fast it tumbles while caught (deg/sec).
@export var catch_spin: float = 720.0
## How hard it's pulled toward the funnel while caught.
@export var catch_pull: float = 4.0

enum State { RUN, LEAVE, CAUGHT }

var _target: Node3D
var _state: State = State.RUN
var _heading: float = 0.0       # travel direction (yaw), independent of facing_offset
var _ground_y: float = 0.0
var _leave_dir: Vector3 = Vector3.FORWARD
var _caught_t: float = 0.0
var _spin: float = 0.0
var _init_scale: Vector3 = Vector3.ONE

func _ready() -> void:
	add_to_group("enemy")
	_ground_y = global_position.y
	_heading = rotation.y - facing_offset

func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("tornado")
		if _target == null:
			return
	var c := _target.global_position

	# Swept into the tornado on contact (the player drove it into us).
	if _state == State.CAUGHT:
		_update_caught(delta, c)
		return
	var flat := Vector2(global_position.x - c.x, global_position.z - c.z).length()
	if flat <= catch_radius * _tornado_size():
		_state = State.CAUGHT
		_caught_t = caught_time
		_init_scale = scale
		_update_caught(delta, c)
		return

	match _state:
		State.RUN:
			_run(delta, c)
		State.LEAVE:
			_leave(delta, c)

func _run(delta: float, c: Vector3) -> void:
	# Aim for a point in front of the tornado along the way it's headed. If the storm is
	# idle there's no "front", so fall back to a point on our own approach side — never on
	# top of it.
	var dir := Vector3.ZERO
	if _target.has_method("get_heading"):
		dir = _target.get_heading()
	if dir == Vector3.ZERO:
		dir = global_position - c
		dir.y = 0.0
		dir = dir.normalized() if dir.length() > 0.01 else Vector3(sin(_heading), 0.0, cos(_heading))
	var drop_point := c + dir * lead_distance

	var to := drop_point - global_position
	to.y = 0.0
	var dist := to.length()
	if dist > 0.01:
		_heading = rotate_toward(_heading, atan2(to.x, to.z), deg_to_rad(turn_speed) * delta)
	_drive(delta)

	# Drop on reaching the spot, or early if we'd otherwise close inside the clearance.
	var to_tornado := Vector2(global_position.x - c.x, global_position.z - c.z).length()
	if dist <= drop_threshold or to_tornado <= min_clearance:
		_drop_barrel()
		_state = State.LEAVE
		var away := global_position - c
		away.y = 0.0
		_leave_dir = away.normalized() if away.length() > 0.01 else Vector3(sin(_heading), 0.0, cos(_heading))

func _leave(delta: float, c: Vector3) -> void:
	var yaw := atan2(_leave_dir.x, _leave_dir.z)
	_heading = rotate_toward(_heading, yaw, deg_to_rad(turn_speed) * delta)
	_drive(delta)
	if _has_left_view(c):
		queue_free()

func _drive(delta: float) -> void:
	var forward := Vector3(sin(_heading), 0.0, cos(_heading))
	var pos := global_position + forward * speed * delta
	pos.y = _ground_y
	global_position = pos
	var r := rotation
	r.y = _heading + facing_offset
	rotation = r

func _drop_barrel() -> void:
	if barrel_scene == null:
		return
	var b := barrel_scene.instantiate()
	get_tree().current_scene.add_child(b)
	b.global_position = Vector3(global_position.x, drop_height, global_position.z)

## Caught in the tornado: lifted and tumbling up the funnel, shrinking, then despawn.
func _update_caught(delta: float, c: Vector3) -> void:
	_caught_t -= delta
	var target := c + Vector3(0, catch_lift, 0)
	global_position = global_position.lerp(target, clampf(catch_pull * delta, 0.0, 1.0))
	_spin += deg_to_rad(catch_spin) * delta
	rotation = Vector3(deg_to_rad(20.0) * sin(_spin * 0.5), _spin, deg_to_rad(18.0))
	scale = _init_scale * clampf(_caught_t / maxf(caught_time, 0.001), 0.0, 1.0)
	if _caught_t <= 0.0:
		queue_free()

## The tornado's current funnel-width multiplier (1.0 if it can't report one).
func _tornado_size() -> float:
	if _target and _target.has_method("get_size_factor"):
		return _target.get_size_factor()
	return 1.0

## True once it's driven out of the camera frame (distance fallback if there's no camera).
func _has_left_view(c: Vector3) -> bool:
	var flat := Vector2(global_position.x - c.x, global_position.z - c.z).length()
	if flat < lead_distance:
		return false
	var cam := get_viewport().get_camera_3d()
	if cam and not cam.is_position_in_frustum(global_position):
		return true
	return flat >= despawn_distance
