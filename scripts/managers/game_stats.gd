extends Node
## Run stats that persist across the scene change to the game-over screen (registered as the
## "GameStats" autoload singleton). The map starts a fresh run on load; the game-over screen
## reads the final values.

var time_played: float = 0.0
var score: int = 0
var _running: bool = false

## Begin a fresh run — reset the totals and start the clock. Called when the game map loads.
func start_run() -> void:
	time_played = 0.0
	score = 0
	_running = true

## Stop the clock (e.g. on death). The values are kept for the game-over screen to read.
func stop_run() -> void:
	_running = false

func _process(delta: float) -> void:
	if _running:
		time_played += delta

## Add to the damage score. Ignored once the run has stopped, so post-death actions don't count.
func add_score(points: int) -> void:
	if _running:
		score += points

## "M:SS" form of the elapsed time, for display.
func time_string() -> String:
	var secs := int(time_played)
	return "%d:%02d" % [secs / 60, secs % 60]
