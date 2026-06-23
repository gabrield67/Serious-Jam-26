extends Area2D
class_name EnemyProjectile
## Fired by ranged enemies. Travels straight; on hitting the tornado it shrinks its
## SIZE (Fujita rating) — debris/ammo is unaffected — then frees itself.

@export var lifetime: float = 4.0
@export var size_damage: float = 1.0

var _vel: Vector2 = Vector2.ZERO
var _life: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func launch(v: Vector2) -> void:
	_vel = v

func _physics_process(delta: float) -> void:
	position += _vel * delta
	_life += delta
	if _life >= lifetime:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_hit"):
		body.take_hit(size_damage)
		queue_free()
