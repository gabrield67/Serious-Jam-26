extends Resource
class_name DestructiblePalette
## Cosmetic color set for destructibles, kept separate from size/behavior data so the
## two axes can be mixed freely (any size can take any palette, or none).

## Colors an instance may take. Empty = keep the model's own texture/material.
@export var colors: PackedColorArray = PackedColorArray()
## Stable color per placement (seeded by position) vs re-rolled each run.
@export var stable: bool = true

## Pick a color for an instance at a given world position. Returns false if no tint.
func pick(world_pos: Vector3) -> Color:
	if colors.is_empty():
		return Color(0, 0, 0, 0)  # caller treats alpha 0 as "no tint"
	var idx: int
	if stable:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(world_pos)
		idx = rng.randi() % colors.size()
	else:
		idx = randi() % colors.size()
	return colors[idx]
