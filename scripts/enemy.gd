extends Node3D
class_name Enemy
## Base for NPC enemies. Adds health + the targeting contract (name / health / highlight)
## so the targeting system can hover them, show their info, and damage them with thrown
## debris. NPC behavior scripts (helicopter, tank, ...) extend this instead of Node3D.

@export var enemy_name: String = "Enemy"
@export var max_health: float = 30.0

var health: float

func _enter_tree() -> void:
	add_to_group("enemy")
	add_to_group("targetable")
	health = max_health

## Called by auto-aimed thrown debris — chips health, dies at 0.
func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
	health -= amount
	if health <= 0.0:
		_on_death()
		queue_free()

## Override for death VFX / score.
func _on_death() -> void:
	pass

# --- Targeting contract ---

func get_display_name() -> String:
	return enemy_name

func get_health() -> Vector2:
	return Vector2(maxf(health, 0.0), max_health)

func set_highlighted(on: bool) -> void:
	TargetHighlight.apply(self, on)
