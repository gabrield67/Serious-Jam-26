extends Area3D
class_name VortexMaw3D
## Contact-destroy core for the 3D tornado. Attach as a child of the Tornado.
## Any "consumable"-group body (a Destructible) overlapping this area is chewed down over
## time and destroyed; "pickup"-group bodies are grabbed instead.
## Movement stays in tornado.gd — this only handles destruction.

@export var chew_rate: float = 1.0

## Direct-contact chew radius (tornado LOCAL space, so real reach = this × the tornado's
## node scale). Fixed — it does NOT widen with the Fujita scale — so only the funnel core
## actually touching a building triggers its fragmenting. Lower it for an even tighter hit.
@export var base_radius: float = 2.0

signal consumed(value: float)
signal grabbed(body: Node)

var _inside: Array[Node] = []
var _shape: CollisionShape3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_shape = _find_shape()
	_apply_radius()

func _apply_radius() -> void:
	if _shape == null:
		_shape = _find_shape()
	if _shape and _shape.shape is CylinderShape3D:
		_shape.shape.radius = base_radius

func _find_shape() -> CollisionShape3D:
	for c in get_children():
		if c is CollisionShape3D:
			return c
	return null

## The destructible currently being chewed (most recent), or null — for the target panel.
func get_chew_target() -> Node:
	for i in range(_inside.size() - 1, -1, -1):
		if is_instance_valid(_inside[i]):
			return _inside[i]
	return null

func _physics_process(delta: float) -> void:
	for body in _inside.duplicate():
		if not is_instance_valid(body):
			_inside.erase(body)
			continue
		if body.has_method("chew"):
			if body.chew(chew_rate * delta):
				_inside.erase(body)

func _on_body_entered(body: Node) -> void:
	# Pickups are carried by the tornado, not chewed.
	if body.is_in_group("pickup"):
		grabbed.emit(body)
		return
	if body.is_in_group("consumable"):
		if body.has_signal("consumed") and not body.consumed.is_connected(_on_consumed):
			body.consumed.connect(_on_consumed)
		if not _inside.has(body):
			_inside.append(body)

func _on_body_exited(body: Node) -> void:
	_inside.erase(body)

func _on_consumed(value: float) -> void:
	consumed.emit(value)
