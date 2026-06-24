extends Node
class_name FujitaManager
## Owns the tornado's Fujita scale. It grows as the tornado destroys things, decays over
## time (so you must keep destroying to hold a level), and takes a hit on heavy damage.
## The level drives the tornado's size, its destruction power, and its health cap.

signal changed(level: int, value: float)

## Minimum F-value to reach each level F0..F5.
@export var thresholds: Array[int] = [0, 3, 6, 10, 15, 21]
## F-value gained per point of a destroyed object's value.
@export var gain_per_value: float = 1.0
## F-value lost per second — must keep destroying to maintain a level.
@export var decay_per_sec: float = 0.3
@export var min_value: float = 0.0

@export_group("Health cap")
## Max health at F0.
@export var base_health: float = 10.0
## Extra max health per Fujita level.
@export var health_per_level: float = 5.0

@export_group("Damage")
## A single hit at or above this also knocks the F-scale down.
@export var heavy_hit_threshold: float = 3.0
## F-value removed by a heavy hit.
@export var heavy_hit_loss: float = 3.0

var value: float = 0.0

func _process(delta: float) -> void:
	if decay_per_sec > 0.0 and value > min_value:
		value = maxf(min_value, value - decay_per_sec * delta)
		changed.emit(level(), value)

## The tornado destroyed something worth `v`.
func add(v: float) -> void:
	value += v * gain_per_value
	changed.emit(level(), value)

## Took a hit of `amount`; heavy hits also dent the scale.
func on_hit(amount: float) -> void:
	if amount >= heavy_hit_threshold:
		value = maxf(min_value, value - heavy_hit_loss)
		changed.emit(level(), value)

func level() -> int:
	var lvl := 0
	for i in thresholds.size():
		if value >= float(thresholds[i]):
			lvl = i
	return lvl

func max_health() -> float:
	return base_health + level() * health_per_level

## Progress info for the HUD: current level + how far past the previous / to the next.
func progress() -> Dictionary:
	var lvl := level()
	var prev := float(thresholds[lvl])
	var at_max := lvl + 1 >= thresholds.size()
	var next := prev if at_max else float(thresholds[lvl + 1])
	return {
		"level": lvl,
		"value": value,
		"since_prev": value - prev,
		"to_next": (next - value) if not at_max else 0.0,
		"at_max": at_max,
	}
