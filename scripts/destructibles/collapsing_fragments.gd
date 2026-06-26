extends Node3D
class_name CollapsingFragments
## Drives a pre-baked VoronoiShatter shard collection through a PROGRESSIVE collapse:
##   - shards start frozen, forming the still-standing building
##   - the Destructible calls crumble_to(fraction) as the tornado chews; shards break off
##     top-down in proportion to that fraction (so it pauses when the tornado leaves)
##   - each broken-off shard is swept slowly toward the tornado, then disappears
##   - when the building is FULLY destroyed, one chunk is handed permanently to the
##     tornado's swirl (its debris queue) via collect_debris()
##
## Works on any RigidBody3D descendants, so it doesn't care how the shards were baked.

@export var shard_lifetime: float = 2.5  ## seconds a broken-off shard is swept before it vanishes
@export var density: float = 1.5         ## mass per unit shard volume
@export var min_mass: float = 0.4
@export var max_mass: float = 12.0

@export_group("Tornado pull")
@export var pull_strength: float = 4.0   ## initial impulse toward the funnel on break-off
@export var swirl_strength: float = 4.0  ## tangential (around the funnel)
@export var lift_strength: float = 2.0   ## upward kick
@export var scatter: float = 1.5         ## random jitter on release
@export var sweep_force: float = 12.0    ## continuous pull that slowly sweeps shards in

## Optional per-surface override materials (set by the Destructible before setup) so the
## shards wear the same palette tints as the building they came from. Index = surface.
var surface_materials: Array = []

var _shards: Array[RigidBody3D] = []
var _thresholds: PackedFloat32Array = PackedFloat32Array()  ## per shard: crumble fraction at which it breaks off
var _released: Array[bool] = []
var _release_time: PackedFloat32Array = PackedFloat32Array()  ## when each shard broke off (-1 = not yet)
var _initial_count: int = 0
var _keepsake_given: bool = false
var _pull_target: Node3D
var _time: float = 0.0
var _phys_mat: PhysicsMaterial

func _ready() -> void:
	set_physics_process(false)

## Gather + freeze the shards and assign each a top-down break-off threshold. Does NOT
## release anything — call crumble_to() to drive the collapse. pull_target = the tornado.
func setup(pull_target: Node3D) -> void:
	_pull_target = pull_target
	_gather(self)
	if _shards.is_empty():
		queue_free()
		return

	# Freeze (they form the standing building) and exempt them from the tornado so they
	# don't shove it away as they spawn inside it.
	var tornado_body := pull_target as PhysicsBody3D
	for s in _shards:
		s.freeze = true
		if tornado_body:
			s.add_collision_exception_with(tornado_body)
			tornado_body.add_collision_exception_with(s)
		_tint_shard(s)

	# Top-down: higher shards get lower thresholds, so they break off first.
	var order := range(_shards.size())
	var ys: PackedFloat32Array = PackedFloat32Array()
	for s in _shards:
		ys.append(s.global_position.y)
	order.sort_custom(func(a, b): return ys[a] > ys[b])

	_thresholds.resize(_shards.size())
	_released.resize(_shards.size())
	_release_time.resize(_shards.size())
	_initial_count = _shards.size()
	var n: int = max(_shards.size(), 1)
	for rank in order.size():
		var idx: int = order[rank]
		_thresholds[idx] = float(rank) / n
		_released[idx] = false
		_release_time[idx] = -1.0

	set_physics_process(true)

## Release every shard whose break-off threshold is <= fraction (0..1). Idempotent and
## monotonic: calling with a smaller fraction does nothing, so pausing just stops progress.
func crumble_to(fraction: float) -> void:
	for i in _shards.size():
		if not _released[i] and _thresholds[i] <= fraction:
			_release(i)

## The building is fully destroyed: drop whatever's still standing AND hand one permanent
## chunk to the tornado's swirl.
func release_all() -> void:
	crumble_to(1.0)
	_give_keepsake()

func _physics_process(delta: float) -> void:
	_time += delta
	var any_alive := false
	for i in _shards.size():
		var s := _shards[i]
		if s == null:
			continue
		if not is_instance_valid(s):
			_shards[i] = null
			continue
		if _released[i]:
			# Slowly sweep the broken-off piece toward the tornado, then vanish.
			if _pull_target and is_instance_valid(_pull_target):
				var to := _pull_target.global_position - s.global_position
				if to.length() > 0.5:
					s.apply_central_force(to.normalized() * sweep_force * s.mass)
			if _time - _release_time[i] >= shard_lifetime:
				s.queue_free()
				_shards[i] = null
				continue
		any_alive = true
	# Once every piece has broken off and swept away, the controller is done.
	if not any_alive and _keepsake_given:
		queue_free()

func _release(i: int) -> void:
	_released[i] = true
	_release_time[i] = _time
	var s := _shards[i]
	if not is_instance_valid(s):
		return
	s.mass = _mass_for(s)
	s.linear_damp = 0.5
	s.angular_damp = 1.5
	s.physics_material_override = _get_phys_mat()
	s.freeze = false
	s.apply_central_impulse(_impulse(s) * s.mass)
	s.apply_torque_impulse(_rand_vec() * scatter * s.mass)

## On full destruction, spawn one lightweight chunk and give it to the tornado's debris
## swirl so the kill is permanently represented in the orbit (subject to carry capacity).
func _give_keepsake() -> void:
	if _keepsake_given:
		return
	_keepsake_given = true
	if _pull_target == null or not _pull_target.has_method("collect_debris"):
		return
	var src := _any_shard_mesh()
	if src == null:
		return
	var chunk := MeshInstance3D.new()
	chunk.mesh = src.mesh
	chunk.scale = src.global_transform.basis.get_scale()
	for i in surface_materials.size():
		if surface_materials[i] != null:
			chunk.set_surface_override_material(i, surface_materials[i])
	get_tree().current_scene.add_child(chunk)
	chunk.global_position = global_position
	_pull_target.collect_debris(chunk)

func _any_shard_mesh() -> MeshInstance3D:
	for s in _shards:
		if is_instance_valid(s):
			var m := _find_mesh(s)
			if m and m.mesh:
				return m
	return null

func _impulse(s: RigidBody3D) -> Vector3:
	var dir := Vector3.UP * lift_strength + _rand_vec() * scatter
	if _pull_target and is_instance_valid(_pull_target):
		var to := _pull_target.global_position - s.global_position
		to.y = 0.0
		if to.length() > 0.01:
			var flat := to.normalized()
			dir += flat * pull_strength
			dir += Vector3.UP.cross(flat).normalized() * swirl_strength
	return dir

func _mass_for(s: RigidBody3D) -> float:
	var mesh := _find_mesh(s)
	if mesh and mesh.mesh:
		var sz := mesh.mesh.get_aabb().size * mesh.global_transform.basis.get_scale()
		var vol: float = max(sz.x * sz.y * sz.z, 0.001)
		return clampf(vol * density, min_mass, max_mass)
	return 1.0

func _gather(node: Node) -> void:
	for c in node.get_children():
		if c is RigidBody3D:
			_shards.append(c)
		else:
			_gather(c)

func _find_mesh(node: Node) -> MeshInstance3D:
	for c in node.get_children():
		if c is MeshInstance3D:
			return c
	return null

## Paint a shard's surfaces with the building's per-surface materials (same surface order),
## so a fractured house keeps its wall/roof colors. Nulls leave the shard's own material.
func _tint_shard(s: RigidBody3D) -> void:
	if surface_materials.is_empty():
		return
	var mi := _find_mesh(s)
	if mi == null:
		return
	# Shards can have fewer surfaces than the source building, so only paint the ones that exist.
	var count := mini(surface_materials.size(), mi.get_surface_override_material_count())
	for i in count:
		var mat: Material = surface_materials[i]
		if mat != null:
			mi.set_surface_override_material(i, mat)

func _rand_vec() -> Vector3:
	return Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))

func _get_phys_mat() -> PhysicsMaterial:
	if _phys_mat == null:
		_phys_mat = PhysicsMaterial.new()
		_phys_mat.friction = 0.9
		_phys_mat.bounce = 0.0
	return _phys_mat
