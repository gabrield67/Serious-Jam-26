extends StaticBody3D
class_name Barrel
## A bomb barrel dropped by the truck. It's a "pickup", so the tornado sucks it up like
## other debris — but once grabbed it arms, pulses, and after a short fuse weakens the
## tornado (shrinks its Fujita size). Picking things up indiscriminately has a cost.

@export var weaken_amount: float = 3.0
## Time after being swept up before it detonates — the window the player has to expel it.
@export var fuse: float = 2.5
## How far it's flung when the player expels it in time.
@export var eject_speed: float = 22.0

var _armed: bool = false
var _ejected: bool = false
var _t: float = 0.0
var _base_scale: Vector3       # original (scene-space) scale, restored on eject
var _carry_base: Vector3       # local scale once swirling — the funnel's scale is baked in
var _carry_captured: bool = false
var _eject_vel: Vector3 = Vector3.ZERO

func _ready() -> void:
	add_to_group("pickup")
	_base_scale = scale

## Called by the tornado when it sucks the barrel in — start the fuse.
func grab() -> void:
	collision_layer = 0
	remove_from_group("pickup")
	_armed = true

## Player expelled it in time — defuse, fling it clear, and let it tumble away harmlessly.
func eject() -> void:
	if not _armed or _ejected:
		return
	_armed = false
	_ejected = true
	scale = _base_scale
	var dir := Vector3(randf() - 0.5, 0.6, randf() - 0.5).normalized()
	_eject_vel = dir * eject_speed

func _process(delta: float) -> void:
	if _ejected:
		_eject_vel.y -= 30.0 * delta
		global_position += _eject_vel * delta
		rotation.x += delta * 6.0
		if global_position.y <= 0.0:
			queue_free()
		return
	if not _armed:
		return
	# Capture the local scale now that we're parented under the (scaled) funnel, so the
	# pulse stays around the right size instead of resetting to the unscaled scene size.
	if not _carry_captured:
		_carry_base = scale
		_carry_captured = true
	_t += delta
	# Pulse harder as the fuse burns down.
	var pulse := 1.0 + sin(_t * 25.0) * 0.12 * clampf(_t / fuse, 0.0, 1.0)
	scale = _carry_base * pulse
	if _t >= fuse:
		_explode()

func _explode() -> void:
	var t := get_tree().get_first_node_in_group("tornado")
	if t and t.has_method("take_hit"):
		t.take_hit(weaken_amount)
	queue_free()
