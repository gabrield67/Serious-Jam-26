extends Enemy
## Plane NPC — flies in, circles the tornado a couple of times at a constant distance
## (banking into the turn), then peels off and flies straight away until it leaves the
## view. It tracks the live tornado so it always stays the same distance out — the player
## can't catch it; it's just a flyby. Carries a world-space dust trail child.

@export_group("Flight")
## Horizontal orbit distance at the tornado's smallest size; scales up with the funnel
## width so the plane keeps a consistent gap from the storm as it grows.
@export var orbit_radius: float = 55.0
## Height it flies at.
@export var altitude: float = 30.0
## How fast it circles the tornado (deg/sec).
@export var orbit_speed: float = 45.0
## Top flight speed — kept well above the orbit's own pace so it flies in and tracks the
## moving tornado tightly without lagging behind.
@export var flight_speed: float = 90.0
## Number of full loops before it peels off and leaves.
@export var loops: int = 2
## Speed when flying straight away after its loops.
@export var leave_speed: float = 70.0
## Degrees of roll into the turn (flip the sign if it banks the wrong way).
@export var bank_angle: float = 22.0
## Yaw correction if the model's nose faces the wrong way.
@export var facing_offset: float = PI
## Distance fallback for despawn if there's no camera to test against.
@export var despawn_distance: float = 400.0

@export_group("Dust damage")
## Damage per second dealt to the tornado while it sits in the dust trail.
@export var trail_damage: float = 4.0
## How close (horizontally) the tornado must be to a dust puff to take damage; scales with
## the funnel width so a bigger storm catches the dust from farther out.
@export var trail_radius: float = 8.0
## Seconds between dropping damage points along the path (denser = smoother coverage).
@export var trail_interval: float = 0.12
## How long each dust point stays harmful — match the visual trail's lifetime.
@export var trail_lifetime: float = 3.0

enum State { ORBIT, LEAVE }

var _target: Node3D
var _state: State = State.ORBIT
var _angle: float = 0.0
var _swept: float = 0.0      # total radians circled, to count loops
var _leave_dir: Vector3 = Vector3.FORWARD
var _leave_yaw: float = 0.0
var _trail: Array[Vector3] = []     # recent path points that still carry damaging dust
var _trail_age: Array[float] = []   # parallel: how long each has lingered
var _drop_t: float = 0.0

func _ready() -> void:
	_angle = randf() * TAU

func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("tornado")
		if _target == null:
			return
	var c := _target.global_position
	match _state:
		State.ORBIT:
			_orbit(delta, c)
		State.LEAVE:
			_leave(delta, c)
	_update_trail(delta, c)

func _orbit(delta: float, c: Vector3) -> void:
	_angle += deg_to_rad(orbit_speed) * delta
	_swept += deg_to_rad(orbit_speed) * delta
	var radius := orbit_radius * _tornado_size()
	# Circle the live tornado at a constant distance, chasing the orbit point at a capped
	# speed so it flies in and tracks the moving storm smoothly.
	var target := c + Vector3(cos(_angle) * radius, altitude, sin(_angle) * radius)
	# Bulge the orbit outward around buildings tall enough to reach our altitude.
	var push := obstacle_push(global_position, true)
	if push.length() > 0.001:
		target += Vector3(push.x, 0.0, push.z) * avoid_range
	global_position = global_position.move_toward(target, flight_speed * _tornado_size() * delta)

	# Face the direction of travel (tangent of the circle) and bank into the turn.
	var tangent := Vector3(-sin(_angle), 0.0, cos(_angle))
	_leave_yaw = atan2(tangent.x, tangent.z) + facing_offset
	rotation = Vector3(0.0, _leave_yaw, deg_to_rad(-bank_angle))

	# Done looping — peel off straight along the current travel direction.
	if _swept >= float(loops) * TAU:
		_state = State.LEAVE
		_leave_dir = tangent.normalized()

func _leave(delta: float, c: Vector3) -> void:
	# Fly straight away at altitude, leveling out the bank, until it's gone from view.
	global_position += _leave_dir * leave_speed * delta
	var r := rotation
	r.y = _leave_yaw
	r.z = lerp_angle(r.z, 0.0, clampf(3.0 * delta, 0.0, 1.0))
	rotation = r

	if _has_left_view(c):
		queue_free()

## Leave damaging dust along the flight path; the tornado takes damage over time whenever
## it sits in one of the still-lingering puffs.
func _update_trail(delta: float, c: Vector3) -> void:
	_drop_t -= delta
	if _drop_t <= 0.0:
		_drop_t = trail_interval
		_trail.append(global_position)
		_trail_age.append(0.0)

	var reach := trail_radius * _tornado_size()
	var in_dust := false
	for i in range(_trail.size() - 1, -1, -1):
		_trail_age[i] += delta
		if _trail_age[i] >= trail_lifetime:
			_trail.remove_at(i)
			_trail_age.remove_at(i)
		elif Vector2(c.x - _trail[i].x, c.z - _trail[i].z).length() <= reach:
			in_dust = true

	if in_dust and _target.has_method("take_hit"):
		_target.take_hit(trail_damage * delta)

## The tornado's current funnel-width multiplier (1.0 if it can't report one).
func _tornado_size() -> float:
	if _target and _target.has_method("get_size_factor"):
		return _target.get_size_factor()
	return 1.0

## True once it's flown out of the camera frame (distance fallback if there's no camera).
func _has_left_view(c: Vector3) -> bool:
	var flat := Vector2(global_position.x - c.x, global_position.z - c.z).length()
	if flat < orbit_radius * _tornado_size():
		return false  # still close in
	var cam := get_viewport().get_camera_3d()
	if cam and not cam.is_position_in_frustum(global_position):
		return true
	return flat >= despawn_distance
