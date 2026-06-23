extends Area3D
class_name PowerUpPickup
## A glowing item. When the tornado drives over it, it grants a brief power-up
## (fire tornado) and disappears.

@export var duration: float = 5.0
@export var spin_speed: float = 90.0   # deg/sec
@export var bob_height: float = 0.4
@export var bob_speed: float = 2.0

@onready var _visual: Node3D = get_node_or_null("Visual")

var _t: float = 0.0
var _base_y: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_base_y = position.y

func _process(delta: float) -> void:
	_t += delta
	if _visual:
		_visual.rotation.y += deg_to_rad(spin_speed) * delta
	position.y = _base_y + sin(_t * bob_speed) * bob_height

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("tornado") and body.has_method("power_up"):
		body.power_up(duration)
		queue_free()
