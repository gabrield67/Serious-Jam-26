extends Node
class_name FujitaManager
## The tornado's single combined meter: its "health" IS its Fujita scale. Destroying things
## fills it (climbing F0 -> F5); enemy damage and going too long without destroying drain it.
## Because the same value drives the tier, a bigger storm also has a bigger buffer before it
## dies — size literally is health. You start at F1, can fall to F0, and die at the bottom of F0.

signal changed(level: int, value: float)  # level is the 0-based tier index (0 = F0)
signal died

## Lower-bound value of each tier, in order: F0, F1, F2, F3, F4, F5.
@export var thresholds: Array[float] = [0.0, 6.0, 14.0, 26.0, 42.0, 62.0]
## F-number shown for the first tier, so tier index 0 displays as "F0".
const BASE_LABEL := 0
## Value gained per point of a destroyed object's value.
@export var gain_per_value: float = 1.0
## Where the storm starts (within the F1 band — you can fall to F0, or climb to F5).
@export var start_value: float = 9.0

@export_group("Drain")
## Seconds of not destroying anything before idle decay kicks in.
@export var idle_grace: float = 4.0
## Value drained per second while idle (past the grace period).
@export var idle_decay: float = 1.5
## Idle decay won't push below this — starvation drops you toward F0 but only enemy damage kills.
@export var idle_floor: float = 2.0

@export_group("Death")
## Value at or below this = death.
@export var death_value: float = 0.0

var value: float = 0.0
var _idle: float = 0.0
var _dead: bool = false

func _ready() -> void:
	value = start_value
	changed.emit(level(), value)

func _process(delta: float) -> void:
	if _dead:
		return
	# Starve: lose ground if you haven't destroyed anything recently (down to the idle floor).
	_idle += delta
	if _idle >= idle_grace and value > idle_floor:
		value = maxf(idle_floor, value - idle_decay * delta)
		changed.emit(level(), value)

## Destroyed something worth `v`: gain power and reset the idle timer.
func add(v: float) -> void:
	if _dead:
		return
	value = minf(value + v * gain_per_value, max_value())
	_idle = 0.0
	changed.emit(level(), value)

## Took `amount` of enemy damage: drain power; unlike starvation this can kill.
func damage(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	value -= amount
	changed.emit(level(), value)
	if value <= death_value:
		value = death_value
		_dead = true
		died.emit()

## Current 0-based tier index (0 = F-1 .. thresholds.size()-1 = F5).
func level() -> int:
	var lvl := 0
	for i in thresholds.size():
		if value >= thresholds[i]:
			lvl = i
	return lvl

## The displayed F-number for the current tier (0 .. 5).
func f_label() -> int:
	return level() + BASE_LABEL

## Top of the scale — the full-bar value, used as the health bar's max.
func max_value() -> float:
	return thresholds[thresholds.size() - 1]

## Testing: jump to a tier by 0-based index (0 = F0). Sits mid-band so it doesn't instantly
## decay out, and clears any death state.
func set_level(idx: int) -> void:
	idx = clampi(idx, 0, thresholds.size() - 1)
	var lo := thresholds[idx]
	var hi := (lo + 10.0) if idx + 1 >= thresholds.size() else thresholds[idx + 1]
	value = (lo + hi) * 0.5
	_idle = 0.0
	_dead = false
	changed.emit(level(), value)

## HUD info: current tier, value/max, and how far into / left in the current band.
func progress() -> Dictionary:
	var lvl := level()
	var prev := thresholds[lvl]
	var at_max := lvl + 1 >= thresholds.size()
	var next := prev if at_max else thresholds[lvl + 1]
	return {
		"level": lvl,
		"f_label": lvl + BASE_LABEL,
		"value": value,
		"max": max_value(),
		"since_prev": value - prev,
		"to_next": (next - value) if not at_max else 0.0,
		"at_max": at_max,
	}
