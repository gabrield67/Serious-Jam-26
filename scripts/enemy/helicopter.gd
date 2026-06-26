extends Enemy
## Helicopter NPC — flies in toward the tornado (nose pointed at it), hovers and charges
## up a shot, fires, then banks around slowly and leaves. It only ever drives forward, so
## the player can ram it with the tornado on its way in or during its lazy exit turn.

@export_group("Rotors")
@export var main_rotor_path: NodePath = "Rotor_002"
@export var tail_rotor_path: NodePath = "Rotor_Back_004"
@export var main_speed: float = 1600.0
@export var tail_speed: float = 2200.0

@export_group("Flight")
## Height above the tornado it flies at.
@export var altitude: float = 18.0
## Speed flying in toward the tornado.
@export var approach_speed: float = 35.0
## Speed flying away after its run.
@export var leave_speed: float = 26.0
## Acceleration when speeding up (units/sec²).
@export var accel: float = 40.0
## Deceleration when slowing down — lower = a longer, gentler glide to a stop.
@export var decel: float = 22.0
## Starts easing off the throttle this far out from firing range, so it coasts in.
@export var brake_distance: float = 35.0
## Minimum creep speed on approach so it always closes the last bit into firing range.
@export var approach_creep: float = 6.0
## How fast it yaws to face the tornado on the way in (deg/sec).
@export var turn_rate: float = 120.0
## How slowly it banks around to leave (deg/sec) — lower = a longer, rammable exit.
@export var leave_turn_rate: float = 35.0
## Once it gets this far from the tornado on the way out, it's gone.
@export var despawn_distance: float = 240.0
## Yaw correction if the model's nose faces the wrong way.
@export var facing_offset: float = 0.0
## For testing: loop back and run again instead of despawning after it leaves.
@export var loop_runs: bool = false

@export_subgroup("Bob")
## Height of the vertical bobbing.
@export var bob_amplitude: float = 0.7
## Speed of the vertical bobbing.
@export var bob_speed: float = 2.2

@export_subgroup("Caught")
## If the tornado column gets this close (horizontally), the heli is sucked in.
@export var catch_radius: float = 14.0
## How long the caught-and-spinning moment lasts before it despawns.
@export var caught_time: float = 0.9
## How high up the funnel it's lifted while being pulled in.
@export var catch_lift: float = 40.0
## How fast it spins while caught (deg/sec).
@export var catch_spin: float = 720.0
## How hard it's pulled toward the funnel while caught.
@export var catch_pull: float = 4.0

@export_group("Shooting")
## Wind-up after it's in position before the first shot.
@export var boot_time: float = 1.2
## Shots fired per run before it leaves.
@export var burst_count: int = 1
## Spacing between shots within the burst.
@export var fire_cooldown: float = 0.4
## How long it hovers in place after firing before it turns to leave.
@export var linger_time: float = 1.0
@export var projectile_speed: float = 50.0
@export var muzzle_offset: float = 3.0
## Aims this far up the funnel (so shots hit the body, not the base).
@export var aim_height: float = 5.0
@export var projectile_scene: PackedScene = preload("res://scenes/items/heli_projectile.tscn")

@onready var _main: Node3D = get_node_or_null(main_rotor_path)
@onready var _tail: Node3D = get_node_or_null(tail_rotor_path)

enum State { APPROACH, CHARGE, FIRE, LINGER, LEAVE, CAUGHT }

var _target: Node3D
var _state: State = State.APPROACH
var _heading: float = 0.0   # yaw of the travel direction
var _facing: float = 0.0    # yaw the nose points
var _speed: float = 0.0     # current forward speed (eased toward a target)
var _leave_yaw: float = 0.0 # heading it banks toward on the way out
var _bob_t: float = 0.0
var _charge: float = 0.0
var _linger: float = 0.0
var _caught_t: float = 0.0
var _init_scale: Vector3 = Vector3.ONE
var _cooldown: float = 0.0
var _shots_left: int = 0

func _ready() -> void:
	_heading = rotation.y
	_facing = rotation.y
	_bob_t = randf() * TAU

func _physics_process(delta: float) -> void:
	if _main:
		_main.rotate_y(deg_to_rad(main_speed) * delta)
	if _tail:
		_tail.rotate_x(deg_to_rad(tail_speed) * delta)

	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("tornado")
		if _target == null:
			return

	var c := _target.global_position
	var to_t := Vector2(c.x - global_position.x, c.z - global_position.z)
	var dist := to_t.length()
	var yaw_to_tornado := atan2(to_t.x, to_t.y) if dist > 0.001 else _facing

	# Sucked into the tornado on contact — spin up the funnel, then despawn.
	if _state == State.CAUGHT:
		_update_caught(delta, c)
		return
	if dist <= catch_radius * _tornado_size():
		_state = State.CAUGHT
		_caught_t = caught_time
		_init_scale = scale
		_update_caught(delta, c)
		return

	var target_speed := 0.0
	match _state:
		State.APPROACH:
			# Fly straight in, nose on the tornado, easing off the throttle as it nears
			# firing range so it coasts to a stop instead of stopping dead.
			_heading = rotate_toward(_heading, yaw_to_tornado, deg_to_rad(turn_rate) * delta)
			_facing = _heading
			var brake := clampf((dist - attack_range) / maxf(brake_distance, 0.001), 0.0, 1.0)
			target_speed = maxf(approach_speed * brake, approach_creep)
			if dist <= attack_range:
				_state = State.CHARGE
				_charge = boot_time
		State.CHARGE:
			# Hold position (coasting to a stop) and keep aim while the shot spins up.
			_facing = rotate_toward(_facing, yaw_to_tornado, deg_to_rad(turn_rate) * delta)
			target_speed = 0.0
			_charge -= delta
			if _charge <= 0.0:
				_state = State.FIRE
				_shots_left = maxi(burst_count, 1)
				_cooldown = 0.0
		State.FIRE:
			_facing = rotate_toward(_facing, yaw_to_tornado, deg_to_rad(turn_rate) * delta)
			target_speed = 0.0
			_cooldown -= delta
			if _cooldown <= 0.0:
				_fire()
				_shots_left -= 1
				_cooldown = fire_cooldown
				if _shots_left <= 0:
					_state = State.LINGER
					_linger = linger_time
		State.LINGER:
			# Hold a beat after firing before peeling off.
			_facing = rotate_toward(_facing, yaw_to_tornado, deg_to_rad(turn_rate) * delta)
			target_speed = 0.0
			_linger -= delta
			if _linger <= 0.0:
				_state = State.LEAVE
				_leave_yaw = atan2(-to_t.x, -to_t.y)  # bank toward directly away
		State.LEAVE:
			# Slowly turn away and fly off; despawn (or loop) once it's left the view.
			_heading = rotate_toward(_heading, _leave_yaw, deg_to_rad(leave_turn_rate) * delta)
			_facing = _heading
			target_speed = leave_speed
			if _has_left_view(dist):
				if loop_runs:
					_state = State.APPROACH
				else:
					queue_free()
					return

	# Ease the throttle toward the target so accel/decel are smooth, then advance.
	var rate := accel if target_speed > _speed else decel
	_speed = move_toward(_speed, target_speed, rate * delta)
	_advance(delta, c)

	var r := rotation
	r.y = _facing + facing_offset
	rotation = r

## The tornado's current funnel-width multiplier (1.0 if it can't report one), so contact
## ranges grow with the storm.
func _tornado_size() -> float:
	if _target and _target.has_method("get_size_factor"):
		return _target.get_size_factor()
	return 1.0

## Caught in the tornado: spiral up into the funnel, spinning and shrinking, then despawn.
func _update_caught(delta: float, c: Vector3) -> void:
	_caught_t -= delta
	# Pull toward the funnel axis while rising up it.
	var target := c + Vector3(0, catch_lift, 0)
	global_position = global_position.lerp(target, clampf(catch_pull * delta, 0.0, 1.0))
	# Spin wildly and tumble.
	_facing += deg_to_rad(catch_spin) * delta
	rotation = Vector3(deg_to_rad(25.0), _facing, 0.0)
	# Shrink away as it's drawn in.
	scale = _init_scale * clampf(_caught_t / maxf(caught_time, 0.001), 0.0, 1.0)
	if _caught_t <= 0.0:
		award_kill()  # sucked into the funnel counts as a kill
		queue_free()

## True once it's flown out of the camera frame (with a distance fallback if there's no
## camera), so it leaves the view before despawning instead of vanishing on screen.
func _has_left_view(dist: float) -> bool:
	if dist < attack_range:
		return false  # still close in — definitely on screen
	var cam := get_viewport().get_camera_3d()
	if cam and not cam.is_position_in_frustum(global_position):
		return true
	return dist >= despawn_distance

## Fly forward along _heading at the current eased _speed, holding bob altitude.
func _advance(delta: float, c: Vector3) -> void:
	# Weave around buildings tall enough to reach our altitude (only while actually moving).
	if _speed > 1.0:
		var push := obstacle_push(global_position, true)
		if push.length() > 0.001:
			var dir := Vector2(sin(_heading), cos(_heading)) + Vector2(push.x, push.z) * avoid_strength
			if dir.length() > 0.01:
				_heading = rotate_toward(_heading, atan2(dir.x, dir.y), deg_to_rad(avoid_turn_speed) * delta)
				_facing = _heading
	var fwd := Vector2(sin(_heading), cos(_heading))
	var pos := global_position
	pos.x += fwd.x * _speed * delta
	pos.z += fwd.y * _speed * delta
	_bob_t += bob_speed * delta
	pos.y = c.y + altitude + sin(_bob_t) * bob_amplitude
	global_position = pos

func _fire() -> void:
	if projectile_scene == null:
		return
	var aim := _target.global_position + Vector3(0, aim_height, 0)
	var dir := aim - global_position
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	var p := projectile_scene.instantiate()
	get_tree().current_scene.add_child(p)
	p.global_position = global_position + dir * muzzle_offset
	if p.has_method("launch"):
		p.launch(dir * projectile_speed)
