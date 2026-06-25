@tool
extends Node
## All dev/debug controls in one place. Drop this node into any scene with a tornado and
## delete it for release. It finds the tornado by group, so no wiring needed.

## Master switch — turn all the debug controls on or off.
@export var enabled: bool = true

## Controls reference (read-only — shown in the inspector for quick reference).
@export_multiline var controls: String = """[  or  ]             Fujita size  -  down / up
F1 .. F6        jump to F0 .. F5
Tab               cycle the tornado's visual style
Hold Shift    fly the tornado around fast"""

## Speed multiplier applied to the tornado while Shift is held.
@export var fast_mult: float = 5.0

var _tornado: Node

## Show the controls field as read-only help text rather than an editable value.
func _validate_property(property: Dictionary) -> void:
	if property.name == "controls":
		property.usage |= PROPERTY_USAGE_READ_ONLY

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_tornado = get_tree().get_first_node_in_group("tornado")

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _tornado == null or not is_instance_valid(_tornado):
		_tornado = get_tree().get_first_node_in_group("tornado")
		if _tornado == null:
			return
	if not enabled:
		_tornado.set("debug_speed_mult", 1.0)  # clear any lingering boost
		return
	# Hold Shift to zip around.
	_tornado.set("debug_speed_mult", fast_mult if Input.is_key_pressed(KEY_SHIFT) else 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not enabled:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if _tornado == null or not is_instance_valid(_tornado):
		_tornado = get_tree().get_first_node_in_group("tornado")
		if _tornado == null:
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
	elif k == KEY_TAB and _tornado.has_method("cycle_style"):
		_tornado.cycle_style()

func _report() -> void:
	if _tornado.has_method("get_level"):
		print("Fujita -> F%d" % _tornado.get_level())
