extends Resource
class_name DestructibleData
## Archetype for a kind of destructible object (house, tree, ...). One .tres per kind.
## Centralizes the size->time and size->scale tables so every "medium" stays consistent.

enum Size { SMALL, MEDIUM, LARGE, HUGE }

## Seconds to destroy, by size category.
const SIZE_TIME := { Size.SMALL: 0.5, Size.MEDIUM: 2.0, Size.LARGE: 6.0, Size.HUGE: 14.0 }
## Visual scale multiplier, by size category.
const SIZE_SCALE := { Size.SMALL: 0.7, Size.MEDIUM: 1.0, Size.LARGE: 1.4, Size.HUGE: 2.0 }

@export var display_name: String = ""
@export var size: Size = Size.MEDIUM
@export var debris: DebrisType
## Reward when destroyed (Fujita/size growth, score, etc.).
@export var value: float = 1.0
## Colors this kind may randomly take per instance. Empty = keep the model's own texture.
@export var palette: PackedColorArray = PackedColorArray()
## -1 = derive destroy time from size; otherwise a fixed number of seconds.
@export var destroy_time_override: float = -1.0

func time_for(s: int) -> float:
	if destroy_time_override >= 0.0:
		return destroy_time_override
	return SIZE_TIME.get(s, 2.0)

func scale_for(s: int) -> float:
	return SIZE_SCALE.get(s, 1.0)
