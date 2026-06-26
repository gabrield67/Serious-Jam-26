extends Node3D
## Spawns every generated destructible/pickup in a grid — `copies` of each type in a row —
## so you can run the scene and eyeball that the per-instance palette colors apply and vary.
## Each item gets its own random colors at runtime (in its _ready), so duplicates differ.

const DIR := "res://scenes/destructibles/generated/"
@export var copies: int = 3      ## instances per type, side by side (to see color variation)
@export var spacing: float = 24.0
@export var row_gap: float = 24.0

func _ready() -> void:
	var names: Array = []
	var d := DirAccess.open(DIR)
	if d:
		for f in d.get_files():
			if f.ends_with(".tscn"):
				names.append(f)
	names.sort()

	var rows := names.size()
	for r in rows:
		var packed: PackedScene = load(DIR + names[r])
		if packed == null:
			continue
		for c in copies:
			var inst := packed.instantiate()
			if inst is Node3D:
				var x := (float(c) - (copies - 1) * 0.5) * spacing
				var z := (float(r) - (rows - 1) * 0.5) * row_gap
				inst.position = Vector3(x, _ground_offset(inst), z)
			add_child(inst)

## Lift the item so its base sits on y=0 (the generated meshes are origin-centered).
func _ground_offset(inst: Node3D) -> float:
	var mi := _find_mesh(inst)
	if mi and mi.mesh:
		return -mi.mesh.get_aabb().position.y * inst.scale.y
	return 0.0

func _find_mesh(node: Node) -> MeshInstance3D:
	for c in node.get_children():
		if c is MeshInstance3D:
			return c
	return null
