extends CPUParticles3D
## One-shot debris burst. Call play() AFTER positioning it, then it frees itself.

func _ready() -> void:
	one_shot = true
	emitting = false
	finished.connect(queue_free)

## Emit from the current position (call once placed in the world).
func play() -> void:
	restart()
	emitting = true
