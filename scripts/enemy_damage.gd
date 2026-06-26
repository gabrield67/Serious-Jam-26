extends Node
## Autoload accessor for the enemy damage config. Tweak the numbers on
## res://resources/enemy_damage.tres in the inspector; read them at runtime via
## EnemyDamage.config.<field> (e.g. EnemyDamage.config.tank_dps).

var config: EnemyDamageConfig = preload("res://resources/enemy_damage.tres")
