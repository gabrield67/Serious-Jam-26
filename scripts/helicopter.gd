extends Node3D
## Helicopter NPC

@export_group("Rotors")
@export var main_rotor_path: NodePath = "Rotor_002"
@export var tail_rotor_path: NodePath = "Rotor_Back_004"
@export var main_speed: float = 1600.0
@export var tail_speed: float = 2200.0

@export_group("Flight")
## Horizontal distance it keeps from the tornado.
@export var orbit_radius: float = 24.0
## Height above the ground it flies at.
@export var altitude: float = 11.0
## How fast it circles the tornado (deg/sec).
@export var orbit_speed: float = 32.0
## How quickly it eases toward its orbit position.
@export var move_lerp: float = 2.0
## Yaw correction if the model's nose faces the wrong way.
@export var facing_offset: float = 0.0

@export_group("Shooting")
@export var fire_cooldown: float = 2.0
@export var projectile_speed: float = 50.0
@export var muzzle_offset: float = 3.0
## Aims this far up the funnel (so shots hit the body, not the base).
@export var aim_height: float = 5.0
@export var projectile_scene: PackedScene = preload("res://scenes/heli_projectile.tscn")

@onready var _main: Node3D = get_node_or_null(main_rotor_path)
@onready var _tail: Node3D = get_node_or_null(tail_rotor_path)

var _target: Node3D
var _angle: float = 0.0
var _cooldown: float = 0.0

func _ready() -> void:
	_angle = randf() * TAU
	_cooldown = randf() * fire_cooldown

func _physics_process(delta: float) -> void:
	if _main:
		_main.rotate_y(deg_to_rad(main_speed) * delta)
	if _tail:
		_tail.rotate_x(deg_to_rad(tail_speed) * delta)

	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("tornado")
		if _target == null:
			return

	_fly(delta)

	_cooldown -= delta
	if _cooldown <= 0.0:
		_cooldown = fire_cooldown
		_fire()

func _fly(delta: float) -> void:
	_angle += deg_to_rad(orbit_speed) * delta
	var c := _target.global_position
	var desired := c + Vector3(cos(_angle) * orbit_radius, altitude, sin(_angle) * orbit_radius)
	global_position = global_position.lerp(desired, clampf(move_lerp * delta, 0.0, 1.0))

	# Face the tornado — yaw only, so the model's scale is preserved.
	var to_t := c - global_position
	var r := rotation
	r.y = atan2(to_t.x, to_t.z) + facing_offset
	rotation = r

func _fire() -> void:
	if projectile_scene == null:
		return
	var aim := _target.global_position + Vector3(0, aim_height, 0)
	var dir := aim - global_position
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	var p := projectile_scene.instantiate()
	get_tree().current_scene.add_child(p)
	p.global_position = global_position + dir * muzzle_offset
	if p.has_method("launch"):
		p.launch(dir * projectile_speed)
