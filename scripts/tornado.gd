extends CharacterBody3D
## Click/hold-to-move controller for the tornado.
##   Click  -> commit a destination on the ground and travel to it.
##   Hold   -> keep re-targeting to the live cursor (follow).
##   The committed point holds until the tornado arrives there, or you click again.

@export var max_speed: float = 25.0
@export var acceleration: float = 70.0
@export var friction: float = 40.0
@export var arrive_radius: float = 2.0
@export var push_force: float = 14.0

var _target: Vector3
var _seeking: bool = false  # actively traveling to a committed destination

func _ready() -> void:
	add_to_group("tornado")
	_target = global_position

func _unhandled_input(event: InputEvent) -> void:
	# A click commits a destination (even a quick press-and-release).
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _set_target_from_mouse(get_viewport().get_mouse_position()):
			_seeking = true

func _physics_process(delta: float) -> void:
	# While the button is held, keep following the cursor.
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if _set_target_from_mouse(get_viewport().get_mouse_position()):
			_seeking = true

	var to_target := _target - global_position
	to_target.y = 0.0
	var distance := to_target.length()

	# Arrived at the committed point — stop and hold here.
	if _seeking and distance <= arrive_radius:
		_seeking = false

	var desired := Vector3.ZERO
	if _seeking:
		var speed := max_speed
		if distance < arrive_radius * 4.0:
			speed = max_speed * (distance / (arrive_radius * 4.0))
		desired = to_target.normalized() * speed

	var rate := acceleration if desired != Vector3.ZERO else friction
	velocity.x = move_toward(velocity.x, desired.x, rate * delta)
	velocity.z = move_toward(velocity.z, desired.z, rate * delta)
	velocity.y = 0.0

	move_and_slide()
	global_position.y = 0.0

	# Shove debris we slide into.
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var collider := c.get_collider()
		if collider is RigidBody3D:
			var dir := -c.get_normal()
			dir.y = 0.2
			collider.apply_central_impulse(dir.normalized() * push_force)

## Projects a screen position onto the ground plane (Y = 0). Returns false if it can't.
func _set_target_from_mouse(screen_pos: Vector2) -> bool:
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return false
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if is_zero_approx(dir.y):
		return false
	var t := -origin.y / dir.y
	if t < 0.0:
		return false
	_target = origin + dir * t
	return true

## The committed destination, for the ground marker to display.
func get_destination() -> Vector3:
	return _target

## True while traveling to a committed point (false once arrived / idle).
func is_seeking() -> bool:
	return _seeking
