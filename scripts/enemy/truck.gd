extends Enemy
## "Storm Chaser" truck. If spawned on a road (place_on_road), it drives along the lane and
## drops its barrel at the point on the road nearest the tornado. With no roads it falls back
## to free-driving: races to a spot in front of the tornado and drops a barrel there. Either
## way, if the player steers the tornado into it, it gets swept up like other debris.

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

@export_group("Obstacle avoidance")
## Max sideways slide off a road lane when dodging an item (world units). The rest of the
## avoidance knobs (range, strength, turn speed) live on the Enemy base class.
@export var avoid_max_offset: float = 7.0

enum State { RUN, LEAVE, CAUGHT }

var _target: Node3D
var _state: State = State.RUN
var _heading: float = 0.0       # travel direction (yaw), independent of facing_offset
var _ground_y: float = 0.0
var _ground_set: bool = false   # capture the spawn surface on the first physics frame
var _ride: float = 0.0          # lift so the wheels rest on the surface, not sink through it
var _leave_dir: Vector3 = Vector3.FORWARD
var _caught_t: float = 0.0
var _spin: float = 0.0
var _init_scale: Vector3 = Vector3.ONE

# Road following (set by place_on_road).
var _lane: Path3D = null
var _offset: float = 0.0        # distance along the lane curve
var _dir: float = 1.0           # travel direction along the lane (+1 / -1)
var _lane_len: float = 0.0
var _dropped: bool = false

func _ready() -> void:
	add_to_group("enemy")
	_heading = rotation.y - facing_offset
	_ride = _compute_ride()

func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("tornado")
		if _target == null:
			return
	# Lock onto the surface the director dropped us on (it placed us after _ready ran).
	if not _ground_set:
		_ground_y = global_position.y
		_ground_set = true
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

	# On a road: follow the lane and drop at its closest point to the tornado.
	if _lane != null and is_instance_valid(_lane):
		_road_drive(delta, c)
		return

	# No road: free-drive in front of the tornado.
	match _state:
		State.RUN:
			_run(delta, c)
		State.LEAVE:
			_leave(delta, c)

## Spawn the truck onto a road lane (group "road_lanes"), starting from an OFF-SCREEN end and
## driving past the point closest to the tornado (where it drops its barrel). Prefers lanes
## whose start end is out of frame; among those, the one that gets nearest the tornado. Returns
## false if there are no roads.
func place_on_road() -> bool:
	var torn := get_tree().get_first_node_in_group("tornado")
	var tpos: Vector3 = torn.global_position if torn else global_position
	var cam := get_viewport().get_camera_3d()
	var best: Path3D = null
	var best_score := INF
	var best_offset := 0.0
	var best_dir := 1.0
	for n in get_tree().get_nodes_in_group("road_lanes"):
		var path := n as Path3D
		if path == null or path.curve == null or path.curve.get_baked_length() <= 0.1:
			continue
		var length := path.curve.get_baked_length()
		# How near the road gets to the tornado (for the barrel drop).
		var co := path.curve.get_closest_offset(path.to_local(tpos))
		var near_d := path.to_global(path.curve.sample_baked(co)).distance_to(tpos)
		# Start at the end farther from the tornado, driving toward the near end so it passes the
		# closest point along the way.
		var p0 := path.to_global(path.curve.sample_baked(0.0))
		var p1 := path.to_global(path.curve.sample_baked(length))
		var offset := 0.0
		var dir := 1.0
		var start_pos := p0
		if p1.distance_to(tpos) > p0.distance_to(tpos):
			offset = length
			dir = -1.0
			start_pos = p1
		# Heavily penalize lanes whose start would be on-camera, so off-screen ones always win.
		var on_screen := cam != null and cam.is_position_in_frustum(start_pos)
		var score := near_d + (100000.0 if on_screen else 0.0)
		if score < best_score:
			best_score = score
			best = path
			best_offset = offset
			best_dir = dir
	if best == null:
		return false
	_lane = best
	_lane_len = best.curve.get_baked_length()
	_offset = best_offset
	_dir = best_dir
	_dropped = false
	_place_on_lane()
	return true

func _road_drive(delta: float, c: Vector3) -> void:
	_offset += _dir * speed * delta
	# Drop at the point on the lane closest to the tornado (as close as the road gets).
	if not _dropped:
		var co := _lane.curve.get_closest_offset(_lane.to_local(c))
		if (_dir > 0.0 and _offset >= co) or (_dir < 0.0 and _offset <= co):
			_drop_barrel()
			_dropped = true
	# Drove off the end of the lane — drop if we somehow haven't, then despawn.
	if _offset <= -2.0 or _offset >= _lane_len + 2.0:
		if not _dropped:
			_drop_barrel()
			_dropped = true
		queue_free()
		return
	_place_on_lane()

## Snap to the lane at the current offset, facing along the travel direction.
func _place_on_lane() -> void:
	var o := clampf(_offset, 0.0, _lane_len)
	var lane_pos := _lane.to_global(_lane.curve.sample_baked(o))
	var ahead := clampf(o + _dir * 2.0, 0.0, _lane_len)
	var t := _lane.to_global(_lane.curve.sample_baked(ahead)) - lane_pos
	t.y = 0.0
	if t.length() > 0.01:
		_heading = atan2(t.x, t.z)
	# Slide sideways off the lane to dodge items, while staying roughly on the road.
	if avoid_enabled and t.length() > 0.01:
		var push := obstacle_push(lane_pos)
		if push.length() > 0.001:
			var right := Vector3(t.z, 0.0, -t.x).normalized()  # lane perpendicular on the ground
			var slide := clampf(push.dot(right) * avoid_strength, -avoid_max_offset, avoid_max_offset)
			lane_pos += right * slide
	lane_pos.y += _ride  # rest on the road surface instead of sinking into it
	global_position = lane_pos
	rotation = Vector3(0.0, _heading + facing_offset, 0.0)

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
	_heading = _avoid_heading(_heading, delta)  # swerve around items in the way
	var forward := Vector3(sin(_heading), 0.0, cos(_heading))
	var pos := global_position + forward * speed * delta
	pos.y = _ground_y + _ride  # rest on the ground instead of sinking into it
	global_position = pos
	var r := rotation
	r.y = _heading + facing_offset
	rotation = r

## Distance from this node's origin down to the lowest point of its model (the origin is at the
## body's centre), so placement can lift the truck to rest on the surface. Computed once.
func _compute_ride() -> float:
	var lowest := INF
	for n in _model_meshes(self, []):
		var m := n as MeshInstance3D
		if m == null or m.mesh == null:
			continue
		var aabb := m.mesh.get_aabb()
		for i in 8:
			var corner := aabb.position + Vector3(
				aabb.size.x if (i & 1) else 0.0,
				aabb.size.y if (i & 2) else 0.0,
				aabb.size.z if (i & 4) else 0.0)
			lowest = minf(lowest, (m.global_transform * corner).y)
	if lowest == INF:
		return 0.0
	return maxf(global_position.y - lowest, 0.0)

func _model_meshes(node: Node, acc: Array) -> Array:
	if node is MeshInstance3D:
		acc.append(node)
	for c in node.get_children():
		_model_meshes(c, acc)
	return acc

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

## Bend a heading away from nearby items, capped at avoid_turn_speed (used while free-driving).
func _avoid_heading(heading: float, delta: float) -> float:
	var push := obstacle_push(global_position)  # ground vehicle: avoid everything (no fly-over)
	if push.length() < 0.001:
		return heading
	var steer := Vector3(sin(heading), 0.0, cos(heading)) + push * avoid_strength
	if steer.length() < 0.01:
		return heading
	return rotate_toward(heading, atan2(steer.x, steer.z), deg_to_rad(avoid_turn_speed) * delta)

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
