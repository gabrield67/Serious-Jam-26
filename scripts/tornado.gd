extends CharacterBody3D
## Mouse-follow controller for the tornado

@export var max_speed: float = 25.0  
@export var acceleration: float = 70.0
@export var friction: float = 40.0 
@export var arrive_radius: float = 2.0
@export var push_force: float = 14.0

var _target: Vector3
var _has_target: bool = false

func _ready() -> void:
	_target = global_position

func _physics_process(delta: float) -> void:
	# Continuously steer toward whatever the cursor is hovering over.
	_set_target_from_mouse(get_viewport().get_mouse_position())

	var to_target := _target - global_position
	to_target.y = 0.0
	var distance := to_target.length()

	var desired := Vector3.ZERO
	if _has_target and distance > arrive_radius:
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

	# throw debris idk
	# FIXME fr
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var collider := c.get_collider()
		if collider is RigidBody3D:
			var dir := -c.get_normal()
			dir.y = 0.2
			collider.apply_central_impulse(dir.normalized() * push_force)

func _set_target_from_mouse(screen_pos: Vector2) -> void:
	## Projects a screen position onto the ground plane (Y = 0) and stores it as the target.
	var camera := get_viewport().get_camera_3d()
	if not camera:
		return
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if is_zero_approx(dir.y):
		return
	var t := -origin.y / dir.y
	if t < 0.0:
		return 
	_target = origin + dir * t
	_has_target = true
