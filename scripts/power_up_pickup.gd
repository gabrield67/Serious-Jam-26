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
@export var bob_height: float = 0.4
@export var bob_speed: float = 2.0
## Gentle size pulse of the glowing symbol (fraction; 0 = no pulse).
@export var pulse_amount: float = 0.12

@onready var _visual: Node3D = get_node_or_null("Visual")

var _t: float = 0.0
var _base_y: float = 0.0
var _base_scale: Vector3 = Vector3.ONE

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_base_y = position.y
	if _visual:
		_base_scale = _visual.scale

func _process(delta: float) -> void:
	_t += delta
	if _visual:
		# Pulse the symbol's size so it reads as a lively glow (billboards can't show a spin).
		_visual.scale = _base_scale * (1.0 + sin(_t * bob_speed) * pulse_amount)
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
