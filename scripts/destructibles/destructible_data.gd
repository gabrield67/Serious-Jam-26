extends Resource
class_name DestructibleData
## One archetype per SIZE tier (Small / Medium / Large / Giant).
## Holds how a thing of that size behaves when the tornado eats it.
## (Display name + color live on DestructibleKind, the TYPE axis.)

## Seconds for the tornado to fully destroy this.
@export var destroy_time: float = 2.0
## Reward when destroyed (Fujita/size growth).
@export var value: float = 1.0
## Damage-score points awarded for destroying one of these (separate from the Fujita value above).
@export var score: int = 25
## Debris emitted on destruction.
@export var debris: DebrisType
## Visual scale multiplier, applied only when an instance does NOT keep its authored scale.
@export var scale_mult: float = 1.0
## Camera-shake trauma (0..1) added when the tornado first hits an item of this size.
@export var hit_shake: float = 0.3
