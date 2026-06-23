extends Area2D
class_name VortexMaw
## mm yummy building

## Chew work applied per second to every object the tornado is currently on top of.
@export var chew_rate: float = 1.0

@export_group("Contact size")
## Contact radius at F0 — roughly the tornado's footprint.
@export var base_radius: float = 55.0
## Extra contact radius per Fujita level (a bigger storm covers more ground).
@export var radius_per_level: float = 8.0
@export var max_radius: float = 160.0

@export_group("Overrun")
## Debris gained when the storm runs over an enemy. 0 = kill-only (growth comes from
## chewing objects, not from plowing through enemies in transit).
@export var enemy_debris_reward: float = 0.0

signal consumed(value: float)

var _shape: CollisionShape2D
var _inside: Array[Node] = []

func _ready() -> void:
	_shape = get_node_or_null("CollisionShape2D")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_intensity(0)

func _physics_process(delta: float) -> void:
	# Chew everything the tornado is currently overlapping.
	for body in _inside.duplicate():
		if not is_instance_valid(body):
			_inside.erase(body)
			continue
		if body.has_method("chew"):
			if body.chew(chew_rate * delta):
				_inside.erase(body)

func _on_body_entered(body: Node) -> void:
	# Overrun: drive the storm into an enemy and it's destroyed, dropping debris.
	if body.is_in_group("enemy"):
		if body.has_method("hit"):
			body.hit(9999.0)
		consumed.emit(enemy_debris_reward)
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

## Called by the tornado when its Fujita level changes — grows the contact footprint.
func set_intensity(level: int) -> void:
	var r := minf(base_radius + level * radius_per_level, max_radius)
	if _shape and _shape.shape is CircleShape2D:
		_shape.shape.radius = r
