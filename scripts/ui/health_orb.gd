extends Control
## Tornado health / F-scale orb. The translucent gradient circle is the container; a solid
## colored circle (one per F-tier) fills/empties with health, and an "F#" label sits on top.
## Polls the tornado each frame.

const GRADIENT := preload("res://Screens/HUD/Circle with translucent gradient.png")
const F_CIRCLES: Array[Texture2D] = [
	preload("res://Screens/HUD/F0 circle.png"),
	preload("res://Screens/HUD/F1 circle.png"),
	preload("res://Screens/HUD/F2 circle.png"),
	preload("res://Screens/HUD/F3 circle.png"),
	preload("res://Screens/HUD/F4 circle.png"),
	preload("res://Screens/HUD/F5 circle.png"),
]
## The circle sits in the left square of each (2500x648) source image — crop to it.
const REGION := Rect2(0, 0, 648, 648)

@onready var _bar: TextureProgressBar = $Bar
@onready var _container: TextureRect = $Container
@onready var _label: Label = $FLabel

var _tornado: Node
var _fills: Array[AtlasTexture] = []

func _ready() -> void:
	# Fill (clipped by health) sits in the bar; the translucent gradient container is drawn
	# on top of it by the separate TextureRect (later in the tree = in front).
	for tex in F_CIRCLES:
		_fills.append(_crop(tex))
	_bar.texture_progress = _fills[0]
	_container.texture = _crop(GRADIENT)
	_tornado = get_tree().get_first_node_in_group("tornado")

## An AtlasTexture cropping the circle out of a source image.
func _crop(tex: Texture2D) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = tex
	a.region = REGION
	return a

func _process(_delta: float) -> void:
	if _tornado == null or not is_instance_valid(_tornado):
		_tornado = get_tree().get_first_node_in_group("tornado")
		return
	if not _tornado.has_method("get_fujita_progress"):
		return
	var p: Dictionary = _tornado.get_fujita_progress()
	if p.is_empty():
		return
	var f: int = p.get("f_label", 1)

	# Fill = how far through the current tier the player is (0% just reached this F,
	# 100% about to hit the next). At the top tier it stays full.
	var pct := 100.0
	if not p.get("at_max", false):
		var since_prev: float = p.get("since_prev", 0.0)
		var to_next: float = p.get("to_next", 0.0)
		var span: float = since_prev + to_next
		pct = (since_prev / span * 100.0) if span > 0.001 else 0.0
	_bar.value = clampf(pct, 0.0, 100.0)
	# Color the fill by the current tier (F0..F5 -> index 0..5).
	_bar.texture_progress = _fills[clampi(f, 0, _fills.size() - 1)]
	_label.text = "F%d" % f
