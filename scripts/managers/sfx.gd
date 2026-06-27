extends Node
## Central one-shot sound-effects player (autoload "Sfx"). Plays SFX from the scene tree,
## decoupled from the objects that trigger them.

## Explosion clips; one is picked at random per enemy hit.
const EXPLOSIONS: Array[AudioStream] = [
	preload("res://sounds/explosions/explosion01.wav"),
	preload("res://sounds/explosions/explosion02.wav"),
	preload("res://sounds/explosions/explosion03.wav"),
	preload("res://sounds/explosions/explosion04.wav"),
	preload("res://sounds/explosions/explosion05.wav"),
	preload("res://sounds/explosions/explosion06.wav"),
	preload("res://sounds/explosions/explosion07.wav"),
	preload("res://sounds/explosions/explosion08.wav"),
	preload("res://sounds/explosions/explosion09.wav"),
]
## Loudness of the enemy-hit explosion.
var explosion_volume_db: float = 0.0

## Play a random explosion when an enemy is hit (non-positional — same volume wherever the
## enemy is). Self-frees when it finishes.
func play_explosion() -> void:
	if EXPLOSIONS.is_empty():
		return
	var p := AudioStreamPlayer.new()
	p.stream = EXPLOSIONS[randi() % EXPLOSIONS.size()]
	p.volume_db = explosion_volume_db
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
