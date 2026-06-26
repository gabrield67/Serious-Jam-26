extends RigidBody2D
class_name Consumable
## A thing the tornado can eat. Bigger items cost more sustained "chew" time.

## Mass the tornado gains once this is fully consumed.
@export var mass_value: float = 1.0
## Seconds of sustained chewing (at the maw's base chew_rate) needed to consume it.
@export var consume_cost: float = 1.0

signal consumed(value: float)

var _progress: float = 0.0
var _base_scale: Vector2

func _ready() -> void:
	add_to_group("consumable")
	gravity_scale = 0.0  # top-down: no falling, the maw moves things
	_base_scale = scale

## Apply `amount` of chew work this frame. Returns true once fully consumed.
func chew(amount: float) -> bool:
	_progress += amount
	# Visual feedback: tear apart / shrink as it's eaten.
	scale = _base_scale * lerpf(1.0, 0.15, chew_ratio())
	if _progress >= consume_cost:
		consumed.emit(mass_value)
		queue_free()
		return true
	return false

## 0.0 = untouched, 1.0 = about to pop. Handy for HUD / shader feedback.
func chew_ratio() -> float:
	return clampf(_progress / consume_cost, 0.0, 1.0)
