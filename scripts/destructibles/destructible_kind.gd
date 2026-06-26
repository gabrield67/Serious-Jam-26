extends Resource
class_name DestructibleKind
## A "type" of destructible (House, Barn, Skyscraper...). Carries identity + color,
## and is orthogonal to size: a House can be any size tier.
##   - display_name: shown in HUD/score ("House" for every house model)
##   - surface_palettes: one color set per mesh surface ("face")

@export var display_name: String = ""

## The generator assigns this kind to any mesh whose name contains one of these
## (case-insensitive) keywords, e.g. ["House"].
@export var match_keywords: PackedStringArray = PackedStringArray()

## Color set per mesh surface (a house mesh with 2 surfaces wants 2 entries:
## e.g. wall colors, roof colors). Rules:
##   - 1 entry   -> applied to every surface (each surface still varies via salt)
##   - N entries -> surface i uses entry i; surfaces past the end keep their material
##   - empty     -> no tint, keep the model's own materials
@export var surface_palettes: Array[DestructiblePalette] = []

func palette_for_surface(i: int) -> DestructiblePalette:
	if surface_palettes.is_empty():
		return null
	if surface_palettes.size() == 1:
		return surface_palettes[0]
	return surface_palettes[i] if i < surface_palettes.size() else null

## Shared across instances: one tinted material per (base material, color) pair.
static var _mat_cache: Dictionary = {}

## Tint each surface of a mesh from this kind's per-surface palettes, seeded by world
## position so each instance varies but stays stable. Used by Destructible and PickupItem.
func apply_to(mesh: MeshInstance3D, world_pos: Vector3) -> void:
	if mesh == null or mesh.mesh == null:
		return
	for i in mesh.mesh.get_surface_count():
		var pal := palette_for_surface(i)
		if pal == null:
			continue
		var c := pal.pick(world_pos, i)
		if c.a == 0.0:
			continue  # empty palette -> keep this surface's own material
		mesh.set_surface_override_material(i, _tinted(mesh, i, c))

func _tinted(mesh: MeshInstance3D, surface: int, c: Color) -> Material:
	var base := mesh.get_active_material(surface)
	var key := "%d_%d" % [base.get_instance_id() if base else 0, hash(c)]
	if not _mat_cache.has(key):
		var m: StandardMaterial3D
		if base is StandardMaterial3D:
			m = base.duplicate()  # keep the texture, just tint it
		else:
			m = StandardMaterial3D.new()
		m.albedo_color = c
		_mat_cache[key] = m
	return _mat_cache[key]
