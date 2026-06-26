extends Label
## Shows the run's final time survived and damage score on the game-over screen, read from the
## GameStats autoload (which persisted across the scene change).

func _ready() -> void:
	text = "Time   %s\nScore   %d" % [GameStats.time_string(), GameStats.score]
