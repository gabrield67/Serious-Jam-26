extends Node3D
class_name DestructibleField
## Turns plain MeshInstance3D children into Destructibles at load. 

enum Tier { SMALL, MEDIUM, LARGE, GIANT }

const GROUP_TIERS := {
	"small": Tier.SMALL, "medium": Tier.MEDIUM, "large": Tier.LARGE, "giant": Tier.GIANT,
}

## Size archetypes, one per tier.
@export var small: DestructibleData
@export var medium: DestructibleData
@export var large: DestructibleData
@export var giant: DestructibleData

## Optional shared cosmetic color (independent of size). Null = keep model materials.
@export var palette: DestructiblePalette

## Tier for meshes that aren't inside any size group.
@export var default_tier: Tier = Tier.MEDIUM

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# Collect (mesh, tier) first — wrapping reparents nodes and mutates the tree.
	var jobs: Array = []
	_collect(self, default_tier, jobs)
	for j in jobs:
		_wrap(j[0], j[1])

func _collect(node: Node, tier: Tier, jobs: Array) -> void:
	for c in node.get_children():
		if c is MeshInstance3D:
			jobs.append([c, tier])
		elif c is Destructible:
			continue  # already built — leave it alone
		else:
			var key := String(c.name).to_lower()
			var child_tier: Tier = GROUP_TIERS.get(key, tier)
			_collect(c, child_tier, jobs)

func _wrap(m: MeshInstance3D, tier: Tier) -> void:
	var parent := m.get_parent()
	var local := m.transform
	parent.remove_child(m)

	var body := Destructible.new()
	body.name = m.name
	body.collision_layer = 2
	body.collision_mask = 0
	body.data = _archetype(tier)
	body.palette = palette
	body.keep_authored_scale = true
	body.transform = local

	m.transform = Transform3D.IDENTITY
	body.add_child(m)
	parent.add_child(body)  # same parent -> transform stays correct under group nodes

func _archetype(tier: Tier) -> DestructibleData:
	match tier:
		Tier.SMALL: return small
		Tier.MEDIUM: return medium
		Tier.LARGE: return large
		Tier.GIANT: return giant
	return medium
