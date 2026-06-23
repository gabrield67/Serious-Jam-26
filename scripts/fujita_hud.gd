extends Label
## 3D-game HUD readout of the tornado's Fujita rating (F0-F5).

var _tornado: Node

func _ready() -> void:
	_tornado = get_tree().get_first_node_in_group("tornado")

func _process(_delta: float) -> void:
	if _tornado == null or not is_instance_valid(_tornado):
		_tornado = get_tree().get_first_node_in_group("tornado")
		return
	if _tornado.has_method("get_level"):
		text = "F%d" % _tornado.get_level()
