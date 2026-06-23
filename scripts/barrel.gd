extends StaticBody3D
class_name Barrel
## A bomb barrel dropped by the truck. It's a "pickup", so the tornado sucks it up like
## other debris — but once grabbed it arms, pulses, and after a short fuse weakens the
## tornado (shrinks its Fujita size). Picking things up indiscriminately has a cost.

@export var weaken_amount: float = 3.0
@export var fuse: float = 1.5

var _armed: bool = false
var _t: float = 0.0
var _base_scale: Vector3

func _ready() -> void:
	add_to_group("pickup")
	_base_scale = scale

## Called by the tornado when it sucks the barrel in — start the fuse.
func grab() -> void:
	collision_layer = 0
	remove_from_group("pickup")
	_armed = true

func _process(delta: float) -> void:
	if not _armed:
		return
	_t += delta
	# Pulse harder as the fuse burns down.
	var pulse := 1.0 + sin(_t * 25.0) * 0.12 * clampf(_t / fuse, 0.0, 1.0)
	scale = _base_scale * pulse
	if _t >= fuse:
		_explode()

func _explode() -> void:
	var t := get_tree().get_first_node_in_group("tornado")
	if t and t.has_method("take_hit"):
		t.take_hit(weaken_amount)
	queue_free()
