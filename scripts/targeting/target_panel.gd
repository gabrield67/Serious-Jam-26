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
	# Readable over the bright/busy 3D scene: white text with a thick dark outline + shadow.
	_name.add_theme_color_override("font_color", Color(1, 1, 1))
	_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_name.add_theme_constant_override("outline_size", 6)
	_name.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_name.add_theme_constant_override("shadow_offset_x", 1)
	_name.add_theme_constant_override("shadow_offset_y", 1)
	_box.add_child(_name)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(120, 10)
	_bar.show_percentage = false
	# Dark backing + bright fill so the health bar stands out against any backdrop.
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bg.set_corner_radius_all(3)
	bg.set_border_width_all(1)
	bg.border_color = Color(0, 0, 0, 0.85)
	_bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.35, 0.85, 0.45)  # bright green
	fill.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("fill", fill)
	_box.add_child(_bar)

	visible = false

## health = Vector2(current, max); a max of 0 means "no health" (hide the bar, name only).
func show_for(display_name: String, health: Vector2, screen_pos: Vector2) -> void:
	_name.text = display_name
	_bar.visible = health.y > 0.0
	if _bar.visible:
		_bar.max_value = maxf(health.y, 0.001)
		_bar.value = clampf(health.x, 0.0, health.y)
	visible = true
	# Center the box horizontally on the target and float it just above.
	var s := _box.size
	_box.position = screen_pos - Vector2(s.x * 0.5, s.y + 18.0)

func hide_panel() -> void:
	visible = false
