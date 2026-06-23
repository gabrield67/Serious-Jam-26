extends Area2D
class_name DebrisProjectile
## A flung debris chunk. Travels straight, frees on lifetime or on hitting an enemy.

@export var lifetime: float = 2.0
@export var damage: float = 1.0

var _vel: Vector2 = Vector2.ZERO
var _life: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func launch(v: Vector2) -> void:
	_vel = v

func _physics_process(delta: float) -> void:
	position += _vel * delta
	rotation += 12.0 * delta
	_life += delta
	if _life >= lifetime:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemy"):
		if body.has_method("hit"):
			body.hit(damage)
		queue_free()
