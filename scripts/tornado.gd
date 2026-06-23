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

@export_group("Power-up")
## Movement speed multiplier while powered up.
@export var powerup_speed_mult: float = 1.6
## Maw destroy-speed multiplier while powered up.
@export var powerup_chew_mult: float = 3.0

@export_group("Fujita / size")
## Size gained per point of a consumed object's value.
@export var size_per_value: float = 1.0
@export var start_size: float = 1.0
## Width (x/z) growth added per Fujita level — makes the funnel fatter.
@export var width_per_level: float = 0.45
## Height (y) growth added per Fujita level.
@export var height_per_level: float = 0.25
## How quickly the visual eases toward its target size.
@export var grow_lerp: float = 4.0

@export_group("Carry")
## Orbit radius for carried pickups (scales with the tornado's width).
@export var carry_radius: float = 6.0
## Height above the ground that carried pickups swirl at.
@export var carry_height: float = 5.0
## How fast carried pickups orbit the funnel (deg/sec).
@export var carry_orbit_speed: float = 120.0
## How fast each carried pickup spins on its own axis (deg/sec).
@export var carry_item_spin: float = 180.0

@export_group("Throw")
## Right-click flings a carried pickup toward the cursor at this speed.
@export var throw_speed: float = 32.0
## Upward kick added to the throw for an arc.
@export var throw_lift: float = 7.0
@export var throw_gravity: float = 22.0
## Seconds before an airborne throw despawns (also despawns on landing).
@export var throw_lifetime: float = 5.0
@export var throw_spin: float = 360.0

## Minimum SIZE for each Fujita level F0..F5.
const FUJITA_MIN := [0, 3, 6, 10, 15, 21]

signal fujita_changed(level: int)

@onready var _vfx_normal: Node3D = get_node_or_null("VFX")
@onready var _vfx_fire: Node3D = get_node_or_null("VFXFire")
@onready var _maw: Node = get_node_or_null("Maw")

var _target: Vector3
var _seeking: bool = false  # actively traveling to a committed destination

var _powerup_time: float = 0.0
var _base_max_speed: float = 0.0
var _base_chew: float = 1.0

var _size: float = 1.0
var _level: int = -1
var _target_scale: Vector3 = Vector3.ONE
var _cur_scale: Vector3 = Vector3.ONE

var _carry_root: Node3D
var _carried: Array[Node3D] = []
var _carry_angle: float = 0.0
var _thrown: Array = []  # [{node, vel, life}]

func _ready() -> void:
	add_to_group("tornado")
	_target = global_position
	_base_max_speed = max_speed
	_carry_root = Node3D.new()
	_carry_root.name = "CarryRoot"
	add_child(_carry_root)
	if _maw:
		_base_chew = _maw.chew_rate
		if _maw.has_signal("consumed"):
			_maw.consumed.connect(_on_consumed)
		if _maw.has_signal("grabbed"):
			_maw.grabbed.connect(_on_grabbed)
	_size = start_size
	_set_fire(false)
	_refresh_fujita()
	_cur_scale = _target_scale

## Briefly powers up the tornado: fire VFX + faster movement & destruction.
func power_up(duration: float) -> void:
	_powerup_time = maxf(_powerup_time, duration)
	max_speed = _base_max_speed * powerup_speed_mult
	if _maw:
		_maw.chew_rate = _base_chew * powerup_chew_mult
	_set_fire(true)

func _end_power_up() -> void:
	max_speed = _base_max_speed
	if _maw:
		_maw.chew_rate = _base_chew
	_set_fire(false)

func _set_fire(on: bool) -> void:
	_set_vfx_active(_vfx_normal, not on)
	_set_vfx_active(_vfx_fire, on)

## Show + process the active VFX; hide + fully disable the inactive one (no wasted
## particle/animation simulation while it's not the current tornado).
func _set_vfx_active(vfx: Node, active: bool) -> void:
	if vfx == null:
		return
	vfx.visible = active
	vfx.process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED

func _unhandled_input(event: InputEvent) -> void:
	# A click commits a destination (even a quick press-and-release).
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _set_target_from_mouse(get_viewport().get_mouse_position()):
			_seeking = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_throw_debris()

func _physics_process(delta: float) -> void:
	if _powerup_time > 0.0:
		_powerup_time -= delta
		if _powerup_time <= 0.0:
			_end_power_up()

	# Ease the tornado's visual size toward its Fujita target.
	_cur_scale = _cur_scale.lerp(_target_scale, clampf(grow_lerp * delta, 0.0, 1.0))
	_apply_vfx_scale(_cur_scale)

	_update_carry(delta)
	_update_thrown(delta)

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

# --- Carrying pickups ---

func _on_grabbed(body: Node) -> void:
	# Defer: we can't reparent during the physics body_entered callback.
	call_deferred("_grab_deferred", body)

func _grab_deferred(body: Node) -> void:
	if not is_instance_valid(body) or _carried.has(body):
		return
	if body.has_method("grab"):
		body.grab()
	if body is Node3D:
		body.reparent(_carry_root)  # keep world transform, then we drive its position
		_carried.append(body)

func _throw_debris() -> void:
	if _carried.is_empty():
		return
	var item: Node3D = _carried.pop_back()
	if not is_instance_valid(item):
		return

	# Aim from the tornado toward the point under the cursor.
	var aim := _ground_point_from_mouse() - global_position
	aim.y = 0.0
	var dir := aim.normalized() if aim.length() > 0.01 else -global_transform.basis.z

	var gpos := item.global_position
	item.reparent(get_parent())  # out of the orbit, into the world
	item.global_position = gpos

	var vel := dir * throw_speed + Vector3.UP * throw_lift
	_thrown.append({"node": item, "vel": vel, "life": 0.0})

func _update_thrown(delta: float) -> void:
	if _thrown.is_empty():
		return
	for entry in _thrown.duplicate():
		var node: Node3D = entry["node"]
		if not is_instance_valid(node):
			_thrown.erase(entry)
			continue
		var v: Vector3 = entry["vel"]
		v.y -= throw_gravity * delta
		entry["vel"] = v
		node.global_position += v * delta
		node.rotation.x += deg_to_rad(throw_spin) * delta
		entry["life"] += delta
		if node.global_position.y <= 0.0 or entry["life"] >= throw_lifetime:
			node.queue_free()
			_thrown.erase(entry)

func _ground_point_from_mouse() -> Vector3:
	var cam := get_viewport().get_camera_3d()
	if not cam:
		return global_position
	var mp := get_viewport().get_mouse_position()
	var o := cam.project_ray_origin(mp)
	var d := cam.project_ray_normal(mp)
	if is_zero_approx(d.y):
		return global_position
	var t := -o.y / d.y
	if t < 0.0:
		return global_position
	return o + d * t

func _update_carry(delta: float) -> void:
	if _carried.is_empty():
		return
	_carry_angle += deg_to_rad(carry_orbit_speed) * delta
	var radius := carry_radius * _cur_scale.x  # widens as the funnel grows
	var n := _carried.size()
	for i in n:
		var item := _carried[i]
		if not is_instance_valid(item):
			continue
		var a := _carry_angle + TAU * float(i) / float(n)
		item.position = Vector3(cos(a) * radius, carry_height, sin(a) * radius)
		item.rotation.y += deg_to_rad(carry_item_spin) * delta

# --- Fujita / size ---

func _on_consumed(value: float) -> void:
	_size += value * size_per_value
	_refresh_fujita()

func _refresh_fujita() -> void:
	var lvl := _compute_level(_size)
	var w := 1.0 + lvl * width_per_level
	var h := 1.0 + lvl * height_per_level
	_target_scale = Vector3(w, h, w)
	if lvl != _level:
		_level = lvl
		fujita_changed.emit(lvl)
		if _maw and _maw.has_method("set_intensity"):
			_maw.set_intensity(lvl)  # bigger storm -> wider destruction reach

func _compute_level(size: float) -> int:
	var lvl := 0
	for i in FUJITA_MIN.size():
		if size >= FUJITA_MIN[i]:
			lvl = i
	return lvl

func _apply_vfx_scale(s: Vector3) -> void:
	if _vfx_normal:
		_vfx_normal.scale = s
	if _vfx_fire:
		_vfx_fire.scale = s

func get_level() -> int:
	return _level

## The committed destination, for the ground marker to display.
func get_destination() -> Vector3:
	return _target

## True while traveling to a committed point (false once arrived / idle).
func is_seeking() -> bool:
	return _seeking
