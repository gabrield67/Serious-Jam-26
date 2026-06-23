extends VBoxContainer

const WORLD = preload("res://scenes/game.tscn")


func _on_play_pressed() -> void:
	get_tree().change_scene_to_packed(WORLD)


func _on_button_2_pressed() -> void:
	get_tree().quit()
