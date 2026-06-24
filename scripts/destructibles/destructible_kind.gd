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
