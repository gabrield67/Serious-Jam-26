extends Node
## Test helper: keyboard control of the tornado's Fujita scale.
##   [  step down a level    ]  step up a level
##   F1..F6                  jump straight to F0..F5
## Drop this node into any scene with a tornado (it finds it by group).

@export var tornado_path: NodePath

var _tornado: Node

func _ready() -> void:
	if tornado_path != NodePath():
		_tornado = get_node_or_null(tornado_path)
	if _tornado == null:
		_tornado = get_tree().get_first_node_in_group("tornado")

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _tornado == null or not is_instance_valid(_tornado):
		return
	var k: int = (event as InputEventKey).keycode
	if k == KEY_BRACKETLEFT and _tornado.has_method("step_fujita"):
		_tornado.step_fujita(-1)
		_report()
	elif k == KEY_BRACKETRIGHT and _tornado.has_method("step_fujita"):
		_tornado.step_fujita(1)
		_report()
	elif k >= KEY_F1 and k <= KEY_F6 and _tornado.has_method("set_fujita_level"):
		_tornado.set_fujita_level(k - KEY_F1)
		_report()

func _report() -> void:
	if _tornado.has_method("get_level"):
		print("Fujita -> F%d" % _tornado.get_level())
