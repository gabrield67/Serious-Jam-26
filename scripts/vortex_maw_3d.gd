extends Area3D
class_name VortexMaw3D
## Contact-destroy core for the 3D tornado. Attach as a child of the Tornado.
## Any Consumable3D overlapping this area is chewed down over time and destroyed.
## Movement stays in tornado.gd — this only handles destruction.

@export var chew_rate: float = 1.0

signal consumed(value: float)

var _inside: Array[Node] = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _physics_process(delta: float) -> void:
	for body in _inside.duplicate():
		if not is_instance_valid(body):
			_inside.erase(body)
			continue
		if body.has_method("chew"):
			if body.chew(chew_rate * delta):
				_inside.erase(body)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("consumable"):
		if body.has_signal("consumed") and not body.consumed.is_connected(_on_consumed):
			body.consumed.connect(_on_consumed)
		if not _inside.has(body):
			_inside.append(body)

func _on_body_exited(body: Node) -> void:
	_inside.erase(body)

func _on_consumed(value: float) -> void:
	consumed.emit(value)
