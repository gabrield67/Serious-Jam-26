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
## Width (x/z) growth added per Fujita level — makes the funnel fatter.
## Height stays fixed; the storm only widens as it climbs the Fujita scale.
@export var width_per_level: float = 0.45
## How quickly the visual eases toward its target size.
@export var grow_lerp: float = 4.0
## Destruction-speed multiplier added per Fujita level (damage to destructibles).
@export var chew_per_level: float = 0.5

@export_group("Carry")
## Orbit radius for carried pickups, in the tornado's LOCAL space — so the real-world
## orbit is this × the tornado's node scale. Keep it tight (near the funnel) so the
## swirling debris stays on screen.
@export var carry_radius: float = 2.5
## Height above the ground that carried pickups swirl at (also × node scale).
@export var carry_height: float = 4.0
## How fast carried pickups orbit the funnel (deg/sec).
@export var carry_orbit_speed: float = 120.0
## How fast each carried pickup spins on its own axis (deg/sec).
@export var carry_item_spin: float = 180.0
## Debris you can hold at F0.
@export var carry_base_capacity: int = 2
## Extra debris capacity per Fujita level.
@export var carry_per_level: int = 2
## Vertical spread of carried debris (column height around carry_height).
@export var carry_height_spread: float = 2.0
## Per-item radius variation (fraction of carry_radius).
@export var carry_radius_var: float = 0.45
## Per-item orbit-speed variation (fraction).
@export var carry_speed_var: float = 0.5
## Vertical bob amplitude / speed of carried debris.
@export var carry_bob_amp: float = 0.7
@export var carry_bob_speed: float = 2.5

@export_group("Throw")
## Right-click flings a carried pickup toward the cursor at this speed.
@export var throw_speed: float = 32.0
## Upward kick added to the throw for an arc.
@export var throw_lift: float = 7.0
@export var throw_gravity: float = 22.0
## Seconds before an airborne throw despawns (also despawns on landing).
@export var throw_lifetime: float = 5.0
@export var throw_spin: float = 360.0

signal fujita_changed(level: int)

@export_group("Style")
## Name of the child VFX under "Styles" shown by default.
@export var default_style: String = "Base"
## Style swapped to while powered up.
@export var powerup_style: String = "Fire"

@onready var _styles: Node3D = get_node_or_null("Styles")
@onready var _maw: Node = get_node_or_null("Maw")

var _current_style: String = ""

var _target: Vector3
var _seeking: bool = false  # actively traveling to a committed destination

var _powerup_time: float = 0.0
var _base_max_speed: float = 0.0
var _base_chew: float = 1.0

var _slow_time: float = 0.0
var _slow_factor: float = 1.0

var _target_scale: Vector3 = Vector3.ONE
var _cur_scale: Vector3 = Vector3.ONE
var _fujita: FujitaManager
var _health: HealthManager

var _carry_root: Node3D
var _carried: Array[Node3D] = []
var _carry_angle: float = 0.0
var _carry_time: float = 0.0
var _thrown: Array = []  # [{node, vel, life}]

func _ready() -> void:
	add_to_group("tornado")
	_target = global_position
	_base_max_speed = max_speed
	_carry_root = Node3D.new()
	_carry_root.name = "CarryRoot"
	add_child(_carry_root)

	_fujita = FujitaManager.new()
	_fujita.name = "FujitaManager"
	add_child(_fujita)
	_health = HealthManager.new()
	_health.name = "HealthManager"
	add_child(_health)
	_fujita.changed.connect(_on_fujita_changed)
	_health.died.connect(_on_died)
	_health.set_max(_fujita.max_health())

	if _maw:
		_base_chew = _maw.chew_rate
		if _maw.has_signal("consumed"):
			_maw.consumed.connect(_on_consumed)
		if _maw.has_signal("grabbed"):
			_maw.grabbed.connect(_on_grabbed)

	set_style(default_style)
	_on_fujita_changed(_fujita.level(), _fujita.value)
	_cur_scale = _target_scale

## Briefly powers up the tornado: fire VFX + faster movement & destruction.
func power_up(duration: float) -> void:
	_powerup_time = maxf(_powerup_time, duration)
	_update_chew()
	set_style(powerup_style)

func _end_power_up() -> void:
	_update_chew()
	set_style(default_style)

## Laser/etc. slow — multiplies movement speed by `factor` for `duration` seconds.
func apply_slow(factor: float, duration: float) -> void:
	_slow_factor = factor
	_slow_time = maxf(_slow_time, duration)

## Combined movement-speed multiplier from power-up (faster) and slow (slower).
func _speed_mult() -> float:
	var m := 1.0
	if _powerup_time > 0.0:
		m *= powerup_speed_mult
	if _slow_time > 0.0:
		m *= _slow_factor
	return m

## Switch the active style (a child of "Styles" by name); others hide + disable.
func set_style(style_name: String) -> void:
	_current_style = style_name
	if _styles == null:
		return
	for child in _styles.get_children():
		_set_vfx_active(child, child.name == style_name)

## Debug: cycle to the next style under "Styles".
func _cycle_style() -> void:
	if _styles == null:
		return
	var children := _styles.get_children()
	if children.is_empty():
		return
	var idx := 0
	for i in children.size():
		if children[i].name == _current_style:
			idx = i
			break
	set_style(children[(idx + 1) % children.size()].name)

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
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		_cycle_style()  # debug: cycle through the VFX styles

func _physics_process(delta: float) -> void:
	if _powerup_time > 0.0:
		_powerup_time -= delta
		if _powerup_time <= 0.0:
			_end_power_up()
	if _slow_time > 0.0:
		_slow_time -= delta

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
		var ms := max_speed * _speed_mult()
		var speed := ms
		if distance < arrive_radius * 4.0:
			speed = ms * (distance / (arrive_radius * 4.0))
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
	if _carried.size() >= carry_capacity():
		return  # full for this F-scale — leave it on the ground
	if body.has_method("grab"):
		body.grab()
	if body is Node3D:
		body.reparent(_carry_root)  # keep world transform, then we drive its position
		_carried.append(body)
		_assign_orbit(body)

## Public: add a debris chunk to the swirl (e.g. a piece of a fully-destroyed building).
## Respects carry capacity; the item is freed if there's no room. Pass a plain Node3D —
## it gets position-driven in the orbit, so it shouldn't simulate physics.
func collect_debris(item: Node3D) -> void:
	call_deferred("_collect_deferred", item)

func _collect_deferred(item: Node3D) -> void:
	if not is_instance_valid(item) or _carried.has(item):
		return
	if _carried.size() >= carry_capacity():
		item.queue_free()  # no room in the swirl — discard
		return
	if item.has_method("grab"):
		item.grab()
	item.reparent(_carry_root)
	_carried.append(item)
	_assign_orbit(item)

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

## Give a freshly-grabbed item its own orbit params so the debris swirls in a column
## (varied height, radius, speed and phase) rather than sitting in a flat even ring.
func _assign_orbit(item: Node3D) -> void:
	item.set_meta("c_phase", randf() * TAU)
	item.set_meta("c_height", carry_height + randf_range(-0.5, 0.5) * carry_height_spread)
	item.set_meta("c_radius", 1.0 + randf_range(-1.0, 1.0) * carry_radius_var)
	item.set_meta("c_speed", 1.0 + randf_range(-1.0, 1.0) * carry_speed_var)
	item.set_meta("c_bobphase", randf() * TAU)

func _update_carry(delta: float) -> void:
	if _carried.is_empty():
		return
	_carry_angle -= deg_to_rad(carry_orbit_speed) * delta
	_carry_time += delta
	for item in _carried:
		if not is_instance_valid(item):
			continue
		var a: float = _carry_angle * float(item.get_meta("c_speed", 1.0)) + float(item.get_meta("c_phase", 0.0))
		var r: float = carry_radius * float(item.get_meta("c_radius", 1.0)) * _cur_scale.x
		var bob: float = sin(_carry_time * carry_bob_speed + float(item.get_meta("c_bobphase", 0.0))) * carry_bob_amp
		var h: float = float(item.get_meta("c_height", carry_height)) + bob
		item.position = Vector3(cos(a) * r, h, sin(a) * r)
		item.rotation.y += deg_to_rad(carry_item_spin) * delta
		item.rotation.x += deg_to_rad(carry_item_spin * 0.5) * delta

# --- Fujita / size ---

func _on_consumed(value: float) -> void:
	_fujita.add(value)

## Damage from enemies — chips health; heavy hits also dent the Fujita scale.
func take_hit(amount: float) -> void:
	_health.take_damage(amount)
	_fujita.on_hit(amount)

func _on_fujita_changed(level: int, _value: float) -> void:
	var w := 1.0 + level * width_per_level
	_target_scale = Vector3(w, 1.0, w)  # width only — height stays constant
	# Chew reach now tracks the visible funnel continuously via _apply_vfx_scale, so it
	# grows smoothly with the storm instead of stepping per level here.
	_update_chew()
	if _health:
		_health.set_max(_fujita.max_health())  # F-scale raises the health cap
	_enforce_carry_capacity()                  # ...and limits how much debris you hold
	fujita_changed.emit(level)

## Debris-hold limit: grows with the Fujita level.
func carry_capacity() -> int:
	return carry_base_capacity + (_fujita.level() if _fujita else 0) * carry_per_level

## Shrinking lowers the cap — any carried debris over it is released.
func _enforce_carry_capacity() -> void:
	var cap := carry_capacity()
	while _carried.size() > cap:
		var item: Node3D = _carried.pop_back()
		if is_instance_valid(item):
			item.queue_free()

## Destruction speed = base * (1 + level*chew_per_level), boosted while powered up.
func _update_chew() -> void:
	if _maw == null:
		return
	var mult := 1.0 + _fujita.level() * chew_per_level
	if _powerup_time > 0.0:
		mult *= powerup_chew_mult
	_maw.chew_rate = _base_chew * mult

func _on_died() -> void:
	pass  # no fail state yet

func _apply_vfx_scale(s: Vector3) -> void:
	if _styles == null:
		return
	for child in _styles.get_children():
		if child is Node3D:
			child.scale = s

func get_level() -> int:
	return _fujita.level() if _fujita else 0

func get_health() -> Vector2:
	return Vector2(_health.current, _health.max_health) if _health else Vector2.ZERO

func get_fujita_progress() -> Dictionary:
	return _fujita.progress() if _fujita else {}

func get_debris() -> Vector2:
	return Vector2(_carried.size(), carry_capacity())

## The committed destination, for the ground marker to display.
func get_destination() -> Vector3:
	return _target

## True while traveling to a committed point (false once arrived / idle).
func is_seeking() -> bool:
	return _seeking
