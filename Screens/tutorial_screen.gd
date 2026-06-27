extends CanvasLayer
## Full-screen tutorial viewer. Instanced on demand by the home menu and the pause
## menu; pages through the images in Screens/Tutorial/ and frees itself on close.
## Runs with PROCESS_MODE_ALWAYS so it still works while the game tree is paused.

const PAGES := [
	preload("res://Screens/Tutorial/Page 1 intro and goal.png"),
	preload("res://Screens/Tutorial/Page 2 Movement and Shoot.png"),
	preload("res://Screens/Tutorial/Page 3 Enemies.png"),
	preload("res://Screens/Tutorial/Page 4 Power Ups.png"),
]

@onready var _image: TextureRect = $Page
@onready var _prev: Button = $Prev
@onready var _next: Button = $Next
@onready var _counter: Label = $Counter

var _index: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("tutorial_overlay")
	_show_page()
	_next.grab_focus()

func _show_page() -> void:
	_index = clampi(_index, 0, PAGES.size() - 1)
	_image.texture = PAGES[_index]
	_prev.disabled = _index == 0
	_next.disabled = _index == PAGES.size() - 1
	if _counter:
		_counter.text = "%d / %d" % [_index + 1, PAGES.size()]

func _on_prev_pressed() -> void:
	_index -= 1
	_show_page()

func _on_next_pressed() -> void:
	_index += 1
	_show_page()

func _on_close_pressed() -> void:
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_on_next_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		_on_prev_pressed()
		get_viewport().set_input_as_handled()
