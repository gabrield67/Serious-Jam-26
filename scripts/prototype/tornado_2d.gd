extends CharacterBody2D
## Click-to-move tornado with two independent resources:
##   SIZE (Fujita rating) 
##   DEBRIS (ammo)

@export_group("Movement")
@export var max_speed: float = 600.0
@export var acceleration: float = 2400.0
@export var friction: float = 1600.0
@export var arrive_radius: float = 16.0
@export var spin_speed: float = 720.0  # deg/sec, visual only

@export_group("Size & hunger")
@export var start_size: float = 1.0
## Size gained per point of a consumed object's value.
@export var size_per_value: float = 1.0
## Size lost per second when not consuming (starvation).
@export var starve_rate: float = 0.3
## Floor the storm can't shrink below (F0).
@export var min_size: float = 1.0

@export_group("Debris (ammo)")
## Debris you can hold at F0.
@export var base_capacity: int = 3
## Extra debris capacity per Fujita level.
@export var capacity_per_level: int = 3
@export var orbit_radius_base: float = 55.0
@export var orbit_radius_per_debris: float = 2.5
@export var orbit_speed: float = 160.0  # deg/sec
@export var throw_speed: float = 1400.0
@export var debris_projectile: PackedScene = preload("res://scenes/prototype/debris_projectile.tscn")

## Minimum SIZE for each Fujita level F0..F5.
const FUJITA_MIN := [0, 3, 6, 10, 15, 21]

signal fujita_changed(level: int)
signal debris_changed(count: int, level: int)

@onready var _visual: Node2D = get_node_or_null("Visual")
@onready var _maw: Node = get_node_or_null("Maw")
@onready var _orbit_root: Node2D = get_node_or_null("OrbitRoot")

var _target: Vector2
var _has_target: bool = false
var _size: float = 1.0
var _orbit: Array[Node2D] = []
var _orbit_angle: float = 0.0
var _level: int = -1

func _ready() -> void:
	add_to_group("tornado")
	_size = start_size
	_target = global_position
	if _maw and _maw.has_signal("consumed"):
		_maw.consumed.connect(_on_consumed)
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_target = get_global_mouse_position()
			_has_target = true
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_throw_debris()

func _physics_process(delta: float) -> void:
	_move(delta)
	# Starvation: shrink over time unless you keep eating.
	if _size > min_size:
		_size = maxf(min_size, _size - starve_rate * delta)
		_refresh()
	_update_orbit(delta)
	if _visual:
		_visual.rotation += deg_to_rad(spin_speed) * delta

func _move(delta: float) -> void:
	var to_target := _target - global_position
	var distance := to_target.length()
	var desired := Vector2.ZERO
	if _has_target and distance > arrive_radius:
		var speed := max_speed
		if distance < arrive_radius * 6.0:
			speed = max_speed * (distance / (arrive_radius * 6.0))
		desired = to_target.normalized() * speed
	var rate := acceleration if desired != Vector2.ZERO else friction
	velocity = velocity.move_toward(desired, rate * delta)
	move_and_slide()

func _update_orbit(delta: float) -> void:
	var count := _orbit.size()
	if count == 0:
		return
	_orbit_angle += deg_to_rad(orbit_speed) * delta
	var radius := orbit_radius_base + count * orbit_radius_per_debris
	for i in count:
		var a := _orbit_angle + TAU * float(i) / float(count)
		_orbit[i].position = Vector2(cos(a), sin(a)) * radius

# --- Consuming: grows size AND yields debris (up to capacity) ---

func _on_consumed(value: float) -> void:
	_size += value * size_per_value
	var chunks := int(round(value))
	var room := capacity() - _orbit.size()
	var add := mini(chunks, maxi(0, room))
	for i in add:
		_add_orbit_chunk()
	_refresh()

func _add_orbit_chunk() -> void:
	if _orbit_root == null:
		return
	var chunk := Polygon2D.new()
	chunk.polygon = PackedVector2Array([Vector2(-6, -6), Vector2(6, -6), Vector2(6, 6), Vector2(-6, 6)])
	chunk.color = Color(0.82, 0.72, 0.5)
	_orbit_root.add_child(chunk)
	_orbit.append(chunk)

# --- Throwing: spends debris only (size untouched) ---

func _throw_debris() -> void:
	if _orbit.is_empty():
		return
	var chunk: Node2D = _orbit.pop_back()
	var spawn_pos := chunk.global_position
	chunk.queue_free()

	var dir := get_global_mouse_position() - global_position
	if dir.length() < 0.001:
		dir = Vector2.RIGHT
	dir = dir.normalized()

	if debris_projectile:
		var proj := debris_projectile.instantiate()
		get_parent().add_child(proj)
		proj.global_position = spawn_pos
		if proj.has_method("launch"):
			proj.launch(dir * throw_speed)
	_refresh()

# --- Damage: enemy hits shrink SIZE only, never debris ---

func take_hit(amount: float) -> void:
	_size = maxf(min_size, _size - amount)
	_refresh()

# --- Stats ---

func capacity() -> int:
	return base_capacity + _compute_level(_size) * capacity_per_level

func get_debris_count() -> int:
	return _orbit.size()

func get_capacity() -> int:
	return capacity()

func get_level() -> int:
	return _level

func _refresh() -> void:
	var lvl := _compute_level(_size)
	if lvl != _level:
		_level = lvl
		fujita_changed.emit(lvl)
		if _maw and _maw.has_method("set_intensity"):
			_maw.set_intensity(lvl)
	_enforce_capacity()
	debris_changed.emit(_orbit.size(), _level)
	if _visual:
		_visual.scale = Vector2.ONE * (1.0 + _level * 0.22)

## Shrinking lowers capacity — any debris over the new cap falls out of orbit.
func _enforce_capacity() -> void:
	var cap := capacity()
	while _orbit.size() > cap:
		var chunk: Node2D = _orbit.pop_back()
		chunk.queue_free()

func _compute_level(size: float) -> int:
	var lvl := 0
	for i in FUJITA_MIN.size():
		if size >= FUJITA_MIN[i]:
			lvl = i
	return lvl
