extends Enemy
## Tank turret NPC — while the tornado is in range it locks a continuous laser onto it,
## holding it slowed and slowly draining its strength for as long as the beam connects.

@export_group("Turret")
## The node that swivels to aim. Defaults to the tank's head.
@export var turret_path: NodePath = "Sketchfab_model/Root/body/head"
@export var turn_speed: float = 120.0
## Yaw correction so the cannon points AT the tornado (depends on the model's rest pose).
@export var facing_offset: float = 0.0

@export_group("Laser")
## Damage (Fujita/sec) and slow come from the shared EnemyDamage config (tank_dps / tank_slow).
## Where on the funnel the beam hits / aims.
@export var aim_height: float = 20.0
## Beam thickness.
@export var beam_thickness: float = 0.5

@export var muzzle_path: NodePath
@export var muzzle_height: float = 2.0
@export var laser_scene: PackedScene = preload("res://scenes/items/LaserBeam.tscn")

@onready var _turret: Node3D = get_node_or_null(turret_path)
@onready var _muzzle: Node3D = get_node_or_null(muzzle_path)

var _target: Node3D
var _turret_rest: Basis
var _turret_yaw: float = 0.0
var _beam: Node3D

func _ready() -> void:
	add_to_group("enemy")
	if _turret:
		_turret_rest = _turret.global_transform.basis

func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("tornado")
		if _target == null:
			return

	_aim(delta)

	if in_attack_range():
		_fire_beam(delta)
	else:
		_stop_beam()

func _aim(delta: float) -> void:
	if _turret == null:
		return
	var origin := _turret.global_position
	var to_t := _target.global_position - origin
	to_t.y = 0.0
	if to_t.length() < 0.01:
		return
	var want := atan2(to_t.x, to_t.z) + facing_offset
	_turret_yaw = rotate_toward(_turret_yaw, want, deg_to_rad(turn_speed) * delta)
	# Rotate the rest pose around WORLD up — independent of the model's local axes.
	_turret.global_transform = Transform3D(Basis(Vector3.UP, _turret_yaw) * _turret_rest, origin)

## Hold the beam on the tornado, draining and slowing it continuously.
func _fire_beam(delta: float) -> void:
	if _beam == null or not is_instance_valid(_beam):
		_beam = laser_scene.instantiate()
		_beam.set("continuous", true)
		_beam.set("thickness", beam_thickness)
		get_tree().current_scene.add_child(_beam)

	var from := _muzzle_position()
	var to := _target.global_position + Vector3(0, aim_height, 0)
	if _beam.has_method("aim"):
		_beam.aim(from, to)

	# Small per-frame amounts: weakens slowly over time and never trips the heavy-hit Fujita
	# knockdown — it's a steady drain. apply_slow is topped up each frame and lapses shortly
	# after the beam drops.
	if _target.has_method("take_hit"):
		_target.take_hit(EnemyDamage.config.tank_dps * delta)
	if _target.has_method("apply_slow"):
		_target.apply_slow(EnemyDamage.config.tank_slow, 0.2)

func _stop_beam() -> void:
	if _beam and is_instance_valid(_beam):
		_beam.queue_free()
	_beam = null

func _exit_tree() -> void:
	_stop_beam()

func _muzzle_position() -> Vector3:
	if _muzzle:
		return _muzzle.global_position
	var src: Node3D = _turret if _turret else self
	return src.global_position + Vector3(0, muzzle_height, 0)
