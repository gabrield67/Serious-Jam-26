extends Enemy
## Tank turret NPC

@export_group("Turret")
## The node that swivels to aim. Defaults to the tank's head.
@export var turret_path: NodePath = "Sketchfab_model/Root/body/head"
@export var turn_speed: float = 120.0
## Yaw correction so the cannon points AT the tornado (depends on the model's rest pose).
@export var facing_offset: float = 0.0

@export_group("Laser")
@export var fire_cooldown: float = 2.0
## Strength (Fujita size) removed per hit.
@export var damage: float = 1.0
## Move-speed multiplier applied to the tornado while slowed (0.5 = half speed).
@export var slow_factor: float = 0.5
@export var slow_duration: float = 1.5
## Where on the funnel the beam hits / aims.
@export var aim_height: float = 5.0

@export var muzzle_path: NodePath
@export var muzzle_height: float = 2.0
@export var laser_scene: PackedScene = preload("res://scenes/items/LaserBeam.tscn")

@onready var _turret: Node3D = get_node_or_null(turret_path)
@onready var _muzzle: Node3D = get_node_or_null(muzzle_path)

var _target: Node3D
var _cooldown: float = 0.0
var _turret_rest: Basis
var _turret_yaw: float = 0.0 

func _ready() -> void:
	add_to_group("enemy")
	_cooldown = randf() * fire_cooldown
	if _turret:
		_turret_rest = _turret.global_transform.basis

func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("tornado")
		if _target == null:
			return

	_aim(delta)

	_cooldown -= delta
	if _cooldown <= 0.0:
		_cooldown = fire_cooldown
		_fire()

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

func _fire() -> void:
	if _target == null:
		return
	if _target.has_method("take_hit"):
		_target.take_hit(damage)
	if _target.has_method("apply_slow"):
		_target.apply_slow(slow_factor, slow_duration)

	if laser_scene:
		var muzzle := _muzzle_position()
		var aim := _target.global_position + Vector3(0, aim_height, 0)
		var beam := laser_scene.instantiate()
		get_tree().current_scene.add_child(beam)
		if beam.has_method("setup"):
			beam.setup(muzzle, aim)

func _muzzle_position() -> Vector3:
	if _muzzle:
		return _muzzle.global_position
	var src: Node3D = _turret if _turret else self
	return src.global_position + Vector3(0, muzzle_height, 0)
