extends Node3D
class_name VFXPrewarmer
## Compiles the heavy explosion/dust shaders at load so the FIRST one in-game doesn't freeze.
## The Compatibility renderer compiles each shader the first time it's DRAWN, on the main
## thread — a multi-frame hitch. We spawn one of every effect, scaled to nearly nothing where
## the camera can see it, for a moment at startup (so each shader draws once and compiles),
## then free them. Place this near the action (e.g. world origin) so the spawns are on-screen.

const EFFECTS := [
	preload("res://Explosion VFX/Scenes/VFX_Explosion_A.tscn"),
	preload("res://Explosion VFX/Scenes/VFX_Explosion_B.tscn"),
	preload("res://Explosion VFX/Scenes/VFX_mini_explosion_1.tscn"),
	preload("res://Explosion VFX/Scenes/VFX_mini_explosion_2.tscn"),
	preload("res://Explosion VFX/Scenes/VFX_Smokey_Dust.tscn"),
]

## How long the warm-up spawns live before being freed (long enough to draw at least once).
@export var warm_time: float = 0.6

func _ready() -> void:
	for scene in EFFECTS:
		if scene == null:
			continue
		var inst: Node = scene.instantiate()
		add_child(inst)
		if inst is Node3D:
			# Tiny so it's effectively invisible, but still drawn -> shader compiles.
			(inst as Node3D).scale = Vector3.ONE * 0.01
		# Don't let any of them cast shadows / lights during warm-up either.
		VFXUtil.tame_for_compatibility(inst)
	get_tree().create_timer(warm_time).timeout.connect(queue_free)
