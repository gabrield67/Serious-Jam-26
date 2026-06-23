extends Resource
class_name DebrisType
## Reusable debris definition — shared across object kinds (a house and a wall can
## both drop "concrete"). The `element` tag is the hook for fire/water/electric later.

@export var vfx: PackedScene          # burst spawned on destruction
@export var element: StringName = &"neutral"
@export var amount: int = 1           # how much debris this represents (for future scoring/ammo)
