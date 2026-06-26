extends Area3D
class_name HeliProjectile
## Fired by the helicopter. Flies straight and detonates when it reaches the tornado's
## column (proximity check — robust to the tornado body letting things pass through),
## shrinking it on hit. Fizzles on hitting the ground or after its lifetime.

@export var lifetime: float = 4.0
@export var damage: float = 1.0
## Detonates when this close (horizontally) to the tornado's column.
@export var hit_radius: float = 6.0

var _vel: Vector3 = Vector3.ZERO
var _life: float = 0.0
var _tornado: Node3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_tornado = get_tree().get_first_node_in_group("tornado") as Node3D

func launch(v: Vector3) -> void:
	_vel = v

func _physics_process(delta: float) -> void:
	global_position += _vel * delta

	# Proximity hit on the tornado column — its body may not physically block the shot, and
	# the reach grows with the funnel so it still connects when the storm is larger.
	if _tornado and is_instance_valid(_tornado):
		var flat := global_position - _tornado.global_position
		flat.y = 0.0
		var reach := hit_radius
		if _tornado.has_method("get_size_factor"):
			reach *= _tornado.get_size_factor()
		if flat.length() <= reach:
			_hit_tornado()
			return

	_life += delta
	if _life >= lifetime:
		queue_free()

func _on_body_entered(body: Node) -> void:
	# Ignore the tornado's body — its collider is far wider than the visible funnel, so the
	# proximity check above decides when the shot actually reaches the column.
	if body.is_in_group("tornado"):
		return
	queue_free()  # ground or anything else — fizzle

func _hit_tornado() -> void:
	if _tornado and _tornado.has_method("take_hit"):
		_tornado.take_hit(damage)
	queue_free()
