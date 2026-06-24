extends StaticBody3D
class_name Destructible
## A destructible object driven by a DestructibleData (size archetype).
##   - destroy time / value / debris come from `data` (its size tier)
##   - color is an independent axis: an optional DestructiblePalette
##   - the tornado's maw calls chew() until destroyed -> emits consumed(value) + debris
##
## Size and color are orthogonal: pick a size `data` (Small/Medium/Large/Giant)

@export var data: DestructibleData
## Optional cosmetic colors. Null / empty = keep the model's own material.
@export var palette: DestructiblePalette

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

func _ready() -> void:
	add_to_group("consumable")
	_mesh = _find_mesh()

	_destroy_time = data.destroy_time if data else 1.0
	var vis := 1.0 if keep_authored_scale else (data.scale_mult if data else 1.0)
	_base_scale = scale * vis
	scale = _base_scale

	_apply_color()
	_ensure_collision()

## Maw contact. Returns true once destroyed.
func chew(amount: float) -> bool:
	_progress += amount
	scale = _base_scale * lerpf(1.0, 0.08, clampf(_progress / _destroy_time, 0.0, 1.0))
	if _progress >= _destroy_time:
		_destroy()
		return true
	return false

func _destroy() -> void:
	if data:
		consumed.emit(data.value)
		_spawn_debris()
	queue_free()

func _spawn_debris() -> void:
	if data == null or data.debris == null or data.debris.vfx == null:
		return
	var burst := data.debris.vfx.instantiate()
	get_tree().current_scene.add_child(burst)
	if burst is Node3D:
		burst.global_position = global_position
	if burst.has_method("play"):
		burst.play()  # emit only after it's positioned

# --- Color (independent of size) ---

func _apply_color() -> void:
	if _mesh == null:
		return
	var chosen: Color
	if force_color:
		chosen = color
	elif palette != null:
		chosen = palette.pick(global_position)
		if chosen.a == 0.0:
			return  # empty palette -> keep the model's own material
	else:
		return  # no palette -> keep the model's own material
	_mesh.material_override = _tinted_material(chosen)

func _tinted_material(c: Color) -> Material:
	if not _mat_cache.has(c):
		var base := _mesh.get_active_material(0)
		var m: StandardMaterial3D
		if base is StandardMaterial3D:
			m = base.duplicate()  # keep the colormap texture, just tint it
		else:
			m = StandardMaterial3D.new()
		m.albedo_color = c
		_mat_cache[c] = m
	return _mat_cache[c]

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
