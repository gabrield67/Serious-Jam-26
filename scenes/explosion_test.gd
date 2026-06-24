extends Node3D

@onready var debris = $Debris
@onready var smoke = $Smoke
@onready var fire = $Fire
@onready var explosion_sound = $ExplosionTestSound

func explose():
	debris.emitting = true
	smoke.emitting = true
	fire.emitting = true
	explosion_sound.play()
	await get_tree().create_timer(2.0).timeout
	queue_free()
	
