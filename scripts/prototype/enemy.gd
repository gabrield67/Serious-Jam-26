extends CharacterBody2D
class_name Enemy2D  # renamed from Enemy to avoid clashing with the 3D game's Enemy
## Truck / ray-cannon archetype (Tornado Jockey style): slowly drives up into firing
## range, then plants and shoots. It does NOT flee — once your storm closes in it
## can't escape, so growing big and bearing down is the counterplay. Dies to thrown debris.

@export var speed: float = 150.0          # slow — these can't run away
@export var health: float = 2.0
## Distance the enemy drives up to, then holds.
@export var preferred_range: float = 420.0
## It will fire from anywhere inside this range while approaching.
@export var fire_range: float = 540.0

@export_group("Shooting")
@export var fire_cooldown: float = 2.6
@export var projectile_speed: float = 470.0
@export var muzzle_offset: float = 22.0
@export var projectile_scene: PackedScene = preload("res://scenes/prototype/enemy_projectile.tscn")

var _target: Node2D
var _cooldown: float = 0.0

func _ready() -> void:
	add_to_group("enemy")
	_cooldown = randf() * fire_cooldown  # desync volleys

func _physics_process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)

	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("tornado")
		if _target == null:
			return

	var to_target := _target.global_position - global_position
	var dist := to_target.length()
	var dir := to_target.normalized() if dist > 0.001 else Vector2.RIGHT

	# Drive up until in position, then hold. No retreat — that's the whole point.
	var move_dir := dir if dist > preferred_range else Vector2.ZERO
	velocity = move_dir * speed
	move_and_slide()
	rotation = dir.angle()  # aim at the tornado

	# Fire once anything's in range.
	if dist <= fire_range and _cooldown <= 0.0:
		_cooldown = fire_cooldown
		_fire(dir)

func _fire(dir: Vector2) -> void:
	if projectile_scene == null:
		return
	var proj := projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position + dir * muzzle_offset
	if proj.has_method("launch"):
		proj.launch(dir * projectile_speed)

func hit(damage: float) -> void:
	health -= damage
	var flash := create_tween()
	modulate = Color(2.0, 0.6, 0.6)
	flash.tween_property(self, "modulate", Color(1, 1, 1), 0.15)
	if health <= 0.0:
		queue_free()
