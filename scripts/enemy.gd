extends Node3D
class_name Enemy
## Base for NPC enemies. Adds health + the targeting contract (name / health / highlight)
## so the targeting system can hover them, show their info, and damage them with thrown
## debris. NPC behavior scripts (helicopter, tank, ...) extend this instead of Node3D.

@export var enemy_name: String = "Enemy"
@export var max_health: float = 30.0
## Only attacks when the tornado is within this many world units (0 = always).
@export var attack_range: float = 80.0

var health: float

## True when the tornado is close enough to attack. Enemies gate their attacks on this.
func in_attack_range() -> bool:
	if attack_range <= 0.0:
		return true
	var t := get_tree().get_first_node_in_group("tornado")
	if t == null or not (t is Node3D):
		return false
	return global_position.distance_to((t as Node3D).global_position) <= attack_range

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
