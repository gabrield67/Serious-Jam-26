extends CanvasLayer

## In-game pause overlay. Registered as an autoload so it's always present during
## play; it pauses the SceneTree in place (resume keeps game state) rather than
## reloading the world. Gated to the gameplay scene so it can't pause menus.

const GAMEPLAY_SCENE := "res://scenes/map.tscn"
const MAIN_MENU_SCENE := "res://Screens/HomeScreen.tscn"

@onready var _video: VideoStreamPlayer = $VideoStreamPlayer
@onready var _continue: Button = $VBoxContainer/Continue

func _ready() -> void:
	# Must keep running while the tree is paused so it can hear "pause" again and
	# so its buttons stay interactive. Children inherit this mode.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if _video:
		_video.stop()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _is_gameplay():
		if visible:
			resume()
		else:
			open()
		get_viewport().set_input_as_handled()

## Only allow pausing while the actual game world is the current scene — never on
## the home / loading / game-over screens.
func _is_gameplay() -> bool:
	var cs := get_tree().current_scene
	return cs != null and cs.scene_file_path == GAMEPLAY_SCENE

func open() -> void:
	get_tree().paused = true
	visible = true
	if _video:
		_video.play()
	if _continue:
		_continue.grab_focus()

func resume() -> void:
	if _video:
		_video.stop()
	visible = false
	get_tree().paused = false

func _on_continue_pressed() -> void:
	resume()

func _on_main_menu_pressed() -> void:
	if _video:
		_video.stop()
	visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
