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

	var hp: Vector2 = _tornado.get_health()
	var debris: Vector2 = _tornado.get_debris() if _tornado.has_method("get_debris") else Vector2.ZERO
	var p: Dictionary = _tornado.get_fujita_progress()
	var lvl: int = p.get("level", 0)

	var line := "Health %d/%d\nDebris %d/%d\nF-Scale F%d" % [
		int(round(hp.x)), int(round(hp.y)), int(debris.x), int(debris.y), lvl]
	if p.get("at_max", false):
		line += "  (MAX)"
	else:
		line += "  (%.1f into F%d, %.1f to F%d)" % [p.get("since_prev", 0.0), lvl, p.get("to_next", 0.0), lvl + 1]
	text = line
