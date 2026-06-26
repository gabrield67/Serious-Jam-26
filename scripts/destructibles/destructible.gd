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

@export_group("Dust")
## A single dust burst kicked up when the tornado first bites into this object — shaped to
## its bounding box, with particle lifetime scaled by the object's size. Not on the whole time.
@export var dust_vfx: PackedScene = preload("res://Explosion VFX/Scenes/VFX_Smokey_Dust.tscn")
## Particle count per unit of the object's volume (more = denser fill of its shape).
@export var dust_density: float = 0.3
## Inflate the cloud past the object's bounds (1 = exact, 1.25 = 25% bigger).
@export var dust_oversize: float = 1
## Multiplier on each puff's size — bigger merges them into a thicker cloud.
@export var dust_particle_scale: float = 1.5
## Per-puff opacity (0..1). Lower = more translucent puffs that blend into one continuous
## cloud instead of reading as separate opaque clumps. Pair with higher density to keep it full.
@export var dust_softness: float = 0.35
## How much of the burst spawns up front (0 = puffs trickle in, thin → full → fade; 1 = the
## whole cloud pops in at once). Mid values start with body, swell to full, then dissipate.
@export var dust_burst: float = 0.6
## Particle lifetime per world-unit of object size — bigger objects make longer-lived dust.
@export var dust_lifetime_per_size: float = 0.1
## Extra time the dust node lingers after the burst before despawning (seconds).
@export var dust_fade: float = 1.2

signal consumed(value: float)

## Shared across instances: one material per chosen color (keeps batching sane).
static var _mat_cache: Dictionary = {}

var _mesh: MeshInstance3D
var _progress: float = 0.0
var _destroy_time: float = 1.0
var _base_scale: Vector3
var _fragments: CollapsingFragments  # spawned on first chew, drives the progressive crumble
var _highlighted: bool = false       # currently hovered
var _dust_spawned: bool = false      # the one-shot dust burst already fired

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
	if not _dust_spawned:
		_dust_spawned = true
		_spawn_dust()  # one burst on first contact
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
	if _highlighted:
		TargetHighlight.apply(ctrl, true)  # keep the hover glow on the shards

## The materials this instance is showing per surface (palette tints applied in _ready),
## so the shards can be painted identically. Nulls = keep the shard's own material.
func _surface_materials() -> Array:
	var mats: Array = []
	if _mesh:
		for i in _mesh.get_surface_override_material_count():
			mats.append(_mesh.get_surface_override_material(i))
	return mats

## Spawn the dust, shaped to the object so it fills the object's volume.
func _spawn_dust() -> void:
	if dust_vfx == null:
		return
	var d := dust_vfx.instantiate()
	get_tree().current_scene.add_child(d)
	if d is Node3D:
		_shape_dust(d as Node3D)

## Fire a single dust burst over the object's (oriented) bounding box so the cloud takes the
## object's shape instead of puffing from a single point. Particle count scales with volume;
## particle lifetime scales with the object's size; the emitter is one-shot so it isn't on the
## whole time the tornado chews, and the node despawns itself once the burst plays out.
func _shape_dust(d3: Node3D) -> void:
	var half := Vector3(2.0, 2.0, 2.0)
	var center := global_position
	var box_basis := global_transform.basis.orthonormalized()
	if _mesh and _mesh.mesh:
		var gt := _mesh.global_transform
		var aabb := _mesh.mesh.get_aabb()
		half = (aabb.size * 0.5) * gt.basis.get_scale()
		center = gt * aabb.get_center()
		box_basis = gt.basis.orthonormalized()
	var obj_size := maxf(half.x, maxf(half.y, half.z)) * 2.0   # largest full extent
	var life := clampf(obj_size * dust_lifetime_per_size, 0.3, 4.0)
	half *= dust_oversize  # let the cloud spill a bit past the object
	d3.global_transform = Transform3D(box_basis, center)
	var volume := maxf(half.x * half.y * half.z * 8.0, 0.001)
	for p in _all_particles(d3, []):
		p.position = Vector3.ZERO
		# Many overlapping translucent puffs read as one cloud, so fill the volume densely.
		p.amount = clampi(int(volume * dust_density), 80, 2000)
		p.lifetime = life      # particle length scales with the object's size
		p.one_shot = true       # a single burst, not on for the whole chew
		p.explosiveness = dust_burst  # front-load the puffs: start with body, then dissipate
		p.emitting = true
		if p.process_material is ParticleProcessMaterial:
			var ppm: ParticleProcessMaterial = p.process_material.duplicate()
			ppm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			ppm.emission_box_extents = half
			ppm.scale_min *= dust_particle_scale  # bigger puffs -> thicker, more merged cloud
			ppm.scale_max *= dust_particle_scale
			ppm.color.a *= dust_softness  # translucent puffs blend instead of clumping
			p.process_material = ppm
	# Self-despawn once the burst has fully played out (emission window + last puff's life).
	get_tree().create_timer(life * 2.0 + dust_fade).timeout.connect(d3.queue_free)

func _all_particles(node: Node, acc: Array) -> Array:
	if node is GPUParticles3D:
		acc.append(node)
	for c in node.get_children():
		_all_particles(c, acc)
	return acc

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
	VFXUtil.tame_for_compatibility(burst)  # drop shadow lights / Decals so bursts don't sputter
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

## Camera-shake level (0..1) while being chewed: size strength on an exponential falloff with
## remaining life — strong on the first bite, dropping off fast so a half-eaten building
## barely rumbles. Raise SHAKE_FALLOFF for an even sharper drop.
const SHAKE_FALLOFF := 3.0
func get_shake_level() -> float:
	if _destroy_time <= 0.0:
		return 0.0
	var remaining := clampf((_destroy_time - _progress) / _destroy_time, 0.0, 1.0)
	var base: float = data.hit_shake if data else 0.3
	return base * pow(remaining, SHAKE_FALLOFF)

func set_highlighted(on: bool) -> void:
	_highlighted = on
	# Highlight the whole node (catches any mesh nesting) and the shards once it's crumbling
	# (they live in the scene, not under us, and the intact mesh is hidden by then).
	TargetHighlight.apply(self, on)
	if _fragments and is_instance_valid(_fragments):
		TargetHighlight.apply(_fragments, on)

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
