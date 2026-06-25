extends Control
class_name TargetPanel
## A small floating label + health bar shown above whatever the player is hovering (or the
## thing currently being destroyed). Driven by TargetingController; builds its own children
## in code so it needs no scene setup — just add this script to a Control under a CanvasLayer.

var _box: VBoxContainer
var _name: Label
var _bar: ProgressBar

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", 2)
	add_child(_box)

	_name = Label.new()
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.add_theme_font_size_override("font_size", 20)
	_box.add_child(_name)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(120, 10)
	_bar.show_percentage = false
	_box.add_child(_bar)

	visible = false

## health = Vector2(current, max). screen_pos = where the target is on screen.
func show_for(display_name: String, health: Vector2, screen_pos: Vector2) -> void:
	_name.text = display_name
	_bar.max_value = maxf(health.y, 0.001)
	_bar.value = clampf(health.x, 0.0, health.y)
	visible = true
	# Center the box horizontally on the target and float it just above.
	var s := _box.size
	_box.position = screen_pos - Vector2(s.x * 0.5, s.y + 18.0)

func hide_panel() -> void:
	visible = false
