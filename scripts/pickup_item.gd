extends StaticBody3D
class_name PickupItem
## A thing the tornado picks up and carries (orbits) instead of destroying.
## Auto-generates a collision box from its mesh so the maw can detect it.

## Optional type: display name + per-surface palettes (same system as Destructible).
## Null = keep the model's own materials; display name falls back to the node name.
@export var kind: DestructibleKind

func _ready() -> void:
	add_to_group("pickup")
	add_to_group("targetable")  # so the hover system highlights + labels it
	# Layer 2 so the maw (mask 3) still detects it, but the tornado's body (mask 1) passes
	# through instead of being blocked. mask 0 — it's just a target, it scans nothing.
	collision_layer = 2
	collision_mask = 0
	_ensure_collision()
	if kind:
		kind.apply_to(_find_mesh(), global_position)

## Highlight on hover (pickups have no health bar — just a name label).
func set_highlighted(on: bool) -> void:
	var mesh := _find_mesh()
	if mesh:
		TargetHighlight.apply(mesh, on)

## Name shown in HUD/score; falls back to the node name when there's no kind.
func get_display_name() -> String:
	if kind and kind.display_name != "":
		return kind.display_name
	return name

## Called when grabbed — go inert so it isn't detected again.
func grab() -> void:
	collision_layer = 0
	remove_from_group("pickup")
	remove_from_group("targetable")
	set_highlighted(false)

func _ensure_collision() -> void:
	var mesh := _find_mesh()
	if _has_collision_child() or mesh == null or mesh.mesh == null:
		return
	var aabb := mesh.mesh.get_aabb()
	var shape := BoxShape3D.new()
	shape.size = aabb.size * mesh.scale
	var col := CollisionShape3D.new()
	col.name = "AutoCollision"
	col.shape = shape
	col.position = mesh.position + aabb.get_center() * mesh.scale
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
