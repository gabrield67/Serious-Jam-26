extends VBoxContainer

# Note: the world is no longer preloaded here. Preloading pulled the entire
# 447-node map (and all its dependencies) into memory at menu startup. Instead we
# hand off to the loading screen, which streams it in on a background thread.
const LOADING_SCREEN := "res://Screens/LoadingScreen.tscn"


func _on_play_pressed() -> void:
	LoadingScreen.target_path = "res://scenes/map.tscn"
	get_tree().change_scene_to_file(LOADING_SCREEN)


func _on_button_2_pressed() -> void:
	get_tree().quit()
