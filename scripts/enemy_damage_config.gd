extends Resource
class_name EnemyDamageConfig
## Central tuning for how much each enemy hurts the tornado. Edit the linked resource —
## res://resources/enemy_damage.tres — in the inspector to balance all enemy damage in one place.
## Read at runtime via the EnemyDamage autoload (e.g. EnemyDamage.config.tank_dps).

## Tank laser: Fujita drained per second the beam holds onto the tornado.
@export var tank_dps: float = 1.5
## Tank laser: movement-speed multiplier while the beam holds (0.5 = half speed).
@export var tank_slow: float = 0.5
## Helicopter projectile: Fujita removed per hit.
@export var helicopter_shot: float = 1.0
## Plane dust trail: Fujita drained per second the tornado sits in it.
@export var plane_trail_dps: float = 4.0
## Barrel explosion: Fujita removed when the blast catches the tornado.
@export var barrel_blast: float = 3.0
