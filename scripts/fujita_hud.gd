extends Label
## HUD readout: tornado health, Fujita scale, and how far past the previous / to the next
## F-scale. Polls the tornado each frame.

var _tornado: Node

func _ready() -> void:
	_tornado = get_tree().get_first_node_in_group("tornado")

func _process(_delta: float) -> void:
	if _tornado == null or not is_instance_valid(_tornado):
		_tornado = get_tree().get_first_node_in_group("tornado")
		return
	if not _tornado.has_method("get_health"):
		return

	var p: Dictionary = _tornado.get_fujita_progress()
	if p.is_empty():
		return
	var debris: Vector2 = _tornado.get_debris() if _tornado.has_method("get_debris") else Vector2.ZERO
	var f: int = p.get("f_label", 0)  
	var value: float = p.get("value", 0.0)
	var maxv: float = p.get("max", 1.0)

	var line := "F-Scale F%d\nHealth %d/%d\nDebris %d/%d" % [
		f, int(round(value)), int(round(maxv)), int(debris.x), int(debris.y)]
	if p.get("at_max", false):
		line += "  (MAX)"
	else:
		line += "\n%.1f into F%d, %.1f to F%d" % [p.get("since_prev", 0.0), f, p.get("to_next", 0.0), f + 1]
	text = line
