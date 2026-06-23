extends Label
## HUD readout: Fujita rating + debris count, plus wave/enemy-cap from the spawner.
## Polls each frame so it can't desync from signal timing.

@export var tornado_path: NodePath

var _tornado: Node
var _spawner: Node

func _ready() -> void:
	_tornado = get_node_or_null(tornado_path)
	if _tornado == null:
		_tornado = get_tree().get_first_node_in_group("tornado")

func _process(_delta: float) -> void:
	if _spawner == null:
		_spawner = get_tree().get_first_node_in_group("spawner")

	if _tornado == null or not _tornado.has_method("get_debris_count"):
		text = "F0  (no tornado)"
		return

	var line := "F%d   debris %d/%d" % [_tornado.get_level(), _tornado.get_debris_count(), _tornado.get_capacity()]
	if _spawner and _spawner.has_method("get_wave"):
		var enemies := get_tree().get_nodes_in_group("enemy").size()
		line += "\nWave %d   enemies %d/%d" % [_spawner.get_wave(), enemies, _spawner.current_cap()]
	text = line
