extends StaticBody3D
class_name Destructible
## A destructible object driven by a DestructibleData archetype.
##   - destroy time + visual scale come from the archetype's size category
##   - color is auto-picked from the archetype palette (per instance)
##   - the tornado's maw calls chew() until destroyed -> emits consumed(value) + debris
##
## Variation model:
##   cosmetic color  -> automatic, from data.palette (no extra resources)
##   size            -> data.size, or a per-instance override
##   genuinely different stats -> point `data` at a different .tres

@export var data: DestructibleData

@export_group("Per-instance overrides")
## Use size_override instead of data.size (affects destroy time + scale).
@export var use_size_override: bool = false
@export var size_override: DestructibleData.Size = DestructibleData.Size.MEDIUM
## Pin a specific color instead of a random palette pick.
@export var force_color: bool = false
@export var color: Color = Color.WHITE
## Stable color per placement (seeded by position) vs re-rolled each run.
@export var stable_color: bool = true

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

	var s := int(size_override) if use_size_override else (int(data.size) if data else 0)
	_destroy_time = data.time_for(s) if data else 1.0
	_base_scale = scale * (data.scale_for(s) if data else 1.0)
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

# --- Color ---

func _apply_color() -> void:
	if _mesh == null or data == null:
		return
	var chosen: Color
	if force_color:
		chosen = color
	elif not data.palette.is_empty():
		chosen = _pick_palette_color()
	else:
		return  # keep the model's own texture untouched
	_mesh.material_override = _tinted_material(chosen)

func _pick_palette_color() -> Color:
	var idx: int
	if stable_color:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(global_position)
		idx = rng.randi() % data.palette.size()
	else:
		idx = randi() % data.palette.size()
	return data.palette[idx]

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
