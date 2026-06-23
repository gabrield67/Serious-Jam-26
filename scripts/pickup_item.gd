extends StaticBody3D
class_name PickupItem
## A thing the tornado picks up and carries (orbits) instead of destroying.
## Auto-generates a collision box from its mesh so the maw can detect it.

func _ready() -> void:
	add_to_group("pickup")
	_ensure_collision()

## Called when grabbed — go inert so it isn't detected again.
func grab() -> void:
	collision_layer = 0
	remove_from_group("pickup")

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
