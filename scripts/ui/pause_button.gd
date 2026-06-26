extends Button

## On-screen pause button for the HUD. Needed because on web the first Esc press
## just exits browser fullscreen, so players need a visible way to pause (P also works).

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	PauseMenu.open()
