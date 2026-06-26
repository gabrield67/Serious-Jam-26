extends Area3D
class_name PowerUpPickup
## A glowing item. When the tornado drives over it, it transforms the tornado for a
## limited time and disappears. The mode decides which tornado you become:
##   "Fire" -> more damage to buildings
##   "Blue" -> electric zaps to enemies

## Which transformation this pickup grants ("Fire" or "Blue"). Must match a style name
## under the tornado's "Styles" node.
@export var transform_mode: String = "Fire"
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
	if not body.is_in_group("tornado"):
		return
	if body.has_method("transform_into"):
		body.transform_into(transform_mode, duration)
		queue_free()
	elif body.has_method("power_up"):  # fallback for older tornado API
		body.power_up(duration)
		queue_free()
