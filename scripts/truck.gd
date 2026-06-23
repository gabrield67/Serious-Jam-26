extends Node3D
## Truck NPC

@export_group("Drive")
## Forward speed on the ground.
@export var speed: float = 9.0
## Distance it drives up to, then holds.
@export var preferred_range: float = 30.0
## How quickly it turns to face the tornado (deg/sec).
@export var turn_speed: float = 180.0
## Yaw correction if the model's nose faces the wrong way.
@export var facing_offset: float = 0.0

@export_group("Shooting")
@export var fire_cooldown: float = 2.5
@export var projectile_speed: float = 45.0
@export var muzzle_offset: float = 3.0
## Aims this far up the funnel so shots hit the body, not the wheels' level.
@export var aim_height: float = 5.0
@export var projectile_scene: PackedScene = preload("res://scenes/heli_projectile.tscn")

var _target: Node3D
var _cooldown: float = 0.0
var _ground_y: float = 0.0

func _ready() -> void:
	add_to_group("enemy")
	_ground_y = global_position.y  # stay at the height it was placed at
	_cooldown = randf() * fire_cooldown

func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("tornado")
		if _target == null:
			return

	var to_t := _target.global_position - global_position
	to_t.y = 0.0
	var dist := to_t.length()
	var dir := to_t.normalized() if dist > 0.01 else Vector3.FORWARD

	# Drive up until in range, then hold (no retreat — it's slow on purpose).
	var pos := global_position
	if dist > preferred_range:
		pos += dir * speed * delta
	pos.y = _ground_y
	global_position = pos

	_turn_toward(dir, delta)

	_cooldown -= delta
	if dist <= preferred_range * 1.3 and _cooldown <= 0.0:
		_cooldown = fire_cooldown
		_fire()

func _turn_toward(dir: Vector3, delta: float) -> void:
	var want := atan2(dir.x, dir.z) + facing_offset
	var r := rotation
	r.y = rotate_toward(r.y, want, deg_to_rad(turn_speed) * delta)
	rotation = r

func _fire() -> void:
	if projectile_scene == null or _target == null:
		return
	var aim := _target.global_position + Vector3(0, aim_height, 0)
	var muzzle := global_position + Vector3(0, aim_height * 0.5, 0)
	var d := aim - muzzle
	if d.length() < 0.01:
		return
	d = d.normalized()
	var p := projectile_scene.instantiate()
	get_tree().current_scene.add_child(p)
	p.global_position = muzzle + d * muzzle_offset
	if p.has_method("launch"):
		p.launch(d * projectile_speed)
