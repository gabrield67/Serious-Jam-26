extends StaticBody3D
class_name Destructible
## A destructible object with two orthogonal archetypes:
##   - data (DestructibleData): SIZE tier -> destroy time / value / debris
##   - kind (DestructibleKind):  TYPE     -> display name + per-surface color palettes
## The maw calls chew() until destroyed -> emits consumed(value) + debris.

@export var data: DestructibleData
## Optional type: display name + per-surface palettes. Null = keep model materials,
## display name falls back to the node name.
@export var kind: DestructibleKind
## Pre-baked VoronoiShatter shard scene. When set, the building collapses into these
## physics shards on death instead of just bursting particles. Null = particle burst.
@export var fragments_scene: PackedScene

@export_group("Per-instance overrides")
## Keep the model's authored scale instead of multiplying by data.scale_mult.
## Use for hand-placed structures that are already the size you want.
@export var keep_authored_scale: bool = false
## Pin a specific color instead of picking from the palette.
@export var force_color: bool = false
@export var color: Color = Color.WHITE

signal consumed(value: float)

## Shared across instances: one material per chosen color (keeps batching sane).
static var _mat_cache: Dictionary = {}

var _mesh: MeshInstance3D
var _progress: float = 0.0
var _destroy_time: float = 1.0
var _base_scale: Vector3
var _fragments: CollapsingFragments  # spawned on first chew, drives the progressive crumble

func _ready() -> void:
	add_to_group("consumable")
	add_to_group("targetable")
	_mesh = _find_mesh()

	_destroy_time = data.destroy_time if data else 1.0
	var vis := 1.0 if keep_authored_scale else (data.scale_mult if data else 1.0)
	_base_scale = scale * vis
	scale = _base_scale

	_apply_color()
	_ensure_collision()

## Maw contact. The building crumbles progressively: shards break off as the tornado
## chews, in proportion to how far along `destroy_time` we are. The maw stops calling
## this when the tornado moves away, so the crumble naturally pauses (and resumes on
## return). Once fully chewed, the remaining shards release and the building is gone.
func chew(amount: float) -> bool:
	_progress += amount
	if _fragments == null:
		_begin_crumble()
	if _fragments:
		_fragments.crumble_to(_progress / _destroy_time)
	if _progress >= _destroy_time:
		_finish()
		return true
	return false

## First chew: swap the intact mesh for the frozen shard collection (which the player
## then watches break apart). No-op if this kind has no baked fragments.
func _begin_crumble() -> void:
	if fragments_scene == null:
		return
	if _mesh:
		_mesh.visible = false
	var ctrl := CollapsingFragments.new()
	# Pass our per-surface materials (the instance's palette tints) so the shards match.
	ctrl.surface_materials = _surface_materials()
	get_tree().current_scene.add_child(ctrl)
	# Position + rotation only — the baked shards already encode the model's size,
	# so re-applying our scale would double it.
	ctrl.global_transform = Transform3D(global_transform.basis.orthonormalized(), global_position)
	var frags := fragments_scene.instantiate()
	ctrl.add_child(frags)
	if frags is Node3D:
		frags.transform = Transform3D.IDENTITY
	ctrl.setup(get_tree().get_first_node_in_group("tornado"))
	_fragments = ctrl

## The materials this instance is showing per surface (palette tints applied in _ready),
## so the shards can be painted identically. Nulls = keep the shard's own material.
func _surface_materials() -> Array:
	var mats: Array = []
	if _mesh:
		for i in _mesh.get_surface_override_material_count():
			mats.append(_mesh.get_surface_override_material(i))
	return mats

func _finish() -> void:
	if data:
		consumed.emit(data.value)
	_spawn_debris()
	if _fragments:
		_fragments.release_all()  # drop whatever's still standing; it lives on and cleans itself up
	else:
		_spawn_fragments_instant()  # no baked shards -> just a particle burst already spawned
	queue_free()

## Fallback for kinds without baked shards: nothing to collapse, the dust burst above
## carries the destruction. (Kept as a hook in case we want a different no-shard effect.)
func _spawn_fragments_instant() -> void:
	pass

func _spawn_debris() -> void:
	if data == null or data.debris == null or data.debris.vfx == null:
		return
	var burst := data.debris.vfx.instantiate()
	get_tree().current_scene.add_child(burst)
	if burst is Node3D:
		burst.global_position = global_position
	if burst.has_method("play"):
		burst.play()  # emit only after it's positioned

## Name shown in HUD/score; falls back to the node name when there's no kind.
func get_display_name() -> String:
	if kind and kind.display_name != "":
		return kind.display_name
	return name

# --- Targeting ---

## Health = how much destruction is left: Vector2(remaining, total). Drains as it's chewed.
func get_health() -> Vector2:
	return Vector2(maxf(_destroy_time - _progress, 0.0), _destroy_time)

func set_highlighted(on: bool) -> void:
	if _mesh:
		TargetHighlight.apply(_mesh, on)

# --- Color: per mesh surface ("face"), independent of size ---

func _apply_color() -> void:
	if _mesh == null or _mesh.mesh == null:
		return
	var count := _mesh.mesh.get_surface_count()
	for i in count:
		var c := _surface_color(i)
		if c.a == 0.0:
			continue  # no tint for this surface -> keep its own material
		_mesh.set_surface_override_material(i, _tinted_material(i, c))

func _surface_color(surface: int) -> Color:
	if force_color:
		return color
	if kind == null:
		return Color(0, 0, 0, 0)
	var pal := kind.palette_for_surface(surface)
	if pal == null:
		return Color(0, 0, 0, 0)
	return pal.pick(global_position, surface)

func _tinted_material(surface: int, c: Color) -> Material:
	var base := _mesh.get_active_material(surface)
	var key := "%d_%d" % [base.get_instance_id() if base else 0, hash(c)]
	if not _mat_cache.has(key):
		var m: StandardMaterial3D
		if base is StandardMaterial3D:
			m = base.duplicate()  # keep the colormap texture, just tint it
		else:
			m = StandardMaterial3D.new()
		m.albedo_color = c
		_mat_cache[key] = m
	return _mat_cache[key]

# --- Auto collision from the mesh AABB (so any model just works) ---

func _ensure_collision() -> void:
	if _has_collision_child() or _mesh == null or _mesh.mesh == null:
		return
	var aabb := _mesh.mesh.get_aabb()
	var shape := BoxShape3D.new()
	shape.size = aabb.size * _mesh.scale
	var col := CollisionShape3D.new()
	col.name = "AutoCollision"
	col.shape = shape
	col.position = _mesh.position + aabb.get_center() * _mesh.scale
	add_child(col)

func _has_collision_child() -> bool:
	for c in get_children():
		if c is CollisionShape3D:
			return true
	return false

func _find_mesh() -> MeshInstance3D:
	for c in get_children():
		if c is MeshInstance3D:
			return c
	return null
