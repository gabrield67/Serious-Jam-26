extends Label
## Live HUD readout of the current run's damage score and time, polled from the GameStats autoload.

func _process(_delta: float) -> void:
	text = "Score  %d\nTime  %s" % [GameStats.score, GameStats.time_string()]
