extends Area3D
class_name HeliProjectile
## Fired by the helicopter. Flies straight; shrinks the tornado on hit, frees on
## hitting anything (tornado or ground) or after its lifetime.

@export var lifetime: float = 4.0
@export var damage: float = 1.0

var _vel: Vector3 = Vector3.ZERO
var _life: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func launch(v: Vector3) -> void:
	_vel = v

func _physics_process(delta: float) -> void:
	global_position += _vel * delta
	_life += delta
	if _life >= lifetime:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("tornado") and body.has_method("take_hit"):
		body.take_hit(damage)
	queue_free()
