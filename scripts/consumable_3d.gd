extends RigidBody3D
class_name Consumable3D
## An object the tornado can run down and destroy. Small consume_cost = breaks almost
## on contact ("run down"); larger = needs a sustained sweep over it.

@export var mass_value: float = 1.0
## Seconds of contact (at the maw's chew_rate) needed to destroy it.
@export var consume_cost: float = 0.4

signal consumed(value: float)

var _progress: float = 0.0
var _base_scale: Vector3

func _ready() -> void:
	add_to_group("consumable")
	_base_scale = scale

## Apply chew work this frame. Returns true once destroyed.
func chew(amount: float) -> bool:
	_progress += amount
	scale = _base_scale * lerpf(1.0, 0.1, chew_ratio())  # crumble as it goes
	if _progress >= consume_cost:
		consumed.emit(mass_value)
		queue_free()
		return true
	return false

func chew_ratio() -> float:
	return clampf(_progress / consume_cost, 0.0, 1.0)
