extends Resource
class_name DestructibleData
## One archetype per SIZE tier (Small / Medium / Large / Giant).
## Holds how a thing of that size behaves when the tornado eats it.
## (Display name + color live on DestructibleKind, the TYPE axis.)

## Seconds for the tornado to fully destroy this.
@export var destroy_time: float = 2.0
## Reward when destroyed (Fujita/size growth, score, etc.).
@export var value: float = 1.0
## Debris emitted on destruction.
@export var debris: DebrisType
## Visual scale multiplier, applied only when an instance does NOT keep its authored scale.
@export var scale_mult: float = 1.0
