extends Node
class_name HealthManager
## The tornado's health. Damaged by enemy attacks; its cap is set by the FujitaManager
## (bigger F-scale = bigger health pool).

signal changed(current: float, max_health: float)
signal died

var current: float = 10.0
var max_health: float = 10.0

## Set the cap (from the Fujita scale). Tops up if currently full, otherwise clamps down.
func set_max(m: float) -> void:
	var was_full := current >= max_health
	max_health = maxf(1.0, m)
	current = max_health if was_full else minf(current, max_health)
	changed.emit(current, max_health)

func take_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	current = maxf(0.0, current - amount)
	changed.emit(current, max_health)
	if current <= 0.0:
		died.emit()

func heal(amount: float) -> void:
	current = minf(max_health, current + amount)
	changed.emit(current, max_health)
