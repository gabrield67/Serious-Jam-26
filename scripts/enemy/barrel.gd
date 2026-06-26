extends StaticBody3D
class_name Barrel
## A bomb barrel dropped by the truck.

## Blast damage comes from the shared EnemyDamage config (barrel_blast).
## Seconds from being dropped to detonation.
@export var fuse: float = 3.0
## The tornado takes the hit only if its centre is within this distance of the blast.
@export var blast_radius: float = 14.0
## How far it's flung when the player expels it in time.
@export var eject_speed: float = 22.0

@export_group("Explosion")
@export var explosion_vfx: PackedScene = preload("res://Explosion VFX/Scenes/VFX_Explosion_A.tscn")
@export var explosion_scale: float = 6.0

var _exploded: bool = false
var _grabbed: bool = false
var _ejected: bool = false
var _t: float = 0.0
var _base_scale: Vector3        # original (scene-space) scale, the ground/pulse baseline
var _carry_base: Vector3        # local scale once swirling under the (scaled) funnel
var _carry_captured: bool = false
var _eject_vel: Vector3 = Vector3.ZERO
var _mat: StandardMaterial3D    # per-instance material we flash for the fuse telegraph

func _ready() -> void:
	add_to_group("pickup")
	_base_scale = scale
	_arm_telegraph()

## Give this barrel its own emissive material so flashing it doesn't affect other barrels.
func _arm_telegraph() -> void:
	var mi := get_node_or_null("Mesh") as MeshInstance3D
	if mi == null:
		return
	var src := mi.get_active_material(0)
	if src is StandardMaterial3D:
		_mat = (src as StandardMaterial3D).duplicate()
		_mat.emission_enabled = true
		_mat.emission = Color(1.0, 0.2, 0.08)
		_mat.emission_energy_multiplier = 0.0
		mi.set_surface_override_material(0, _mat)

## The tornado sucked it up — drop out of the pickup group; the fuse keeps burning.
func grab() -> void:
	collision_layer = 0
	remove_from_group("pickup")
	_grabbed = true
	_carry_captured = false  # re-capture the carried (funnel-scaled) size next frame

## Player expelled it — fling it clear. It stays live and goes off wherever it lands/flies.
func eject() -> void:
	if _ejected or _exploded:
		return
	_ejected = true
	_grabbed = false
	scale = _base_scale
	var dir := Vector3(randf() - 0.5, 0.6, randf() - 0.5).normalized()
	_eject_vel = dir * eject_speed

func _process(delta: float) -> void:
	if _exploded:
		return
	_t += delta

	if _ejected:
		# Tumble away under gravity.
		_eject_vel.y -= 30.0 * delta
		global_position += _eject_vel * delta
		rotation.x += delta * 6.0
		if global_position.y <= 0.0:
			global_position.y = 0.0
			_eject_vel = Vector3.ZERO

	# Fuse telegraph: flash brighter + blink faster as it counts down, pulsing the barrel too.
	var frac := clampf(_t / fuse, 0.0, 1.0)
	var freq := lerpf(5.0, 28.0, frac)
	var blink := absf(sin(_t * freq))
	if _mat:
		_mat.emission_energy_multiplier = blink * lerpf(1.5, 6.0, frac)
	if not _ejected:
		var base := _base_scale
		if _grabbed:
			if not _carry_captured:
				_carry_base = scale
				_carry_captured = true
			base = _carry_base
		scale = base * (1.0 + sin(_t * freq) * 0.1 * frac)

	if _t >= fuse:
		_explode()

func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	VFXUtil.spawn_one_shot(explosion_vfx, global_position, explosion_scale)
	var t := get_tree().get_first_node_in_group("tornado")
	if t and (t is Node3D) and t.has_method("take_hit"):
		# Bigger storms are bigger targets — grow the catch radius with the funnel's size.
		var reach := blast_radius
		if t.has_method("get_size_factor"):
			reach *= float(t.call("get_size_factor"))
		if global_position.distance_to((t as Node3D).global_position) <= reach:
			t.take_hit(EnemyDamage.config.barrel_blast)
	queue_free()
