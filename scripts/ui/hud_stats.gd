extends CanvasLayer
## Autoload HUD overlay showing the run's elapsed time and score (polled from GameStats).
## Only visible during gameplay — gated on a tornado existing — so it stays hidden on menus.
## Lives outside hud.tscn so it survives that scene being re-saved in the editor.
##
## The time is split into minutes/seconds labels with a drawn colon (two dots) between them,
## so the display doesn't depend on the grunge font having a ':' glyph.

@onready var _min: Label = $TimeBox/MinLabel
@onready var _sec: Label = $TimeBox/SecLabel
@onready var _score: Label = $ScoreLabel

func _process(_delta: float) -> void:
	var playing := get_tree().get_first_node_in_group("tornado") != null
	visible = playing
	if not playing:
		return
	var secs := int(GameStats.time_played)
	_min.text = "%d" % (secs / 60)
	_sec.text = "%02d" % (secs % 60)
	_score.text = "SCORE %d" % GameStats.score
