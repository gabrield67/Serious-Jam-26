@tool
extends EditorScript
## One-shot generator: turns every MeshInstance3D under SOURCE_NODE into a reusable
## Destructible scene under OUT_DIR. Size tier is assigned EXPLICITLY by organization:
## put meshes under a child node named Small / Medium / Large / Giant. Meshes not in a
## size group use DEFAULT_TIER (index into [small, medium, large, giant]).
##
## How to run:
##   1. Open the scene that contains the source meshes (e.g. zoo.tscn).
##   2. Organize meshes under Small/Medium/Large/Giant group nodes (leave those at the
##      default transform — they're just organizers).
##   3. Open this file in the script editor, then File > Run (Ctrl+Shift+X).
##   4. Drag the generated scenes from OUT_DIR onto your map; duplicate freely.
##
## Re-running overwrites the generated scenes (it won't touch your map placements).

const SOURCE_NODE := "structure copy"
const OUT_DIR := "res://scenes/destructibles/generated"
const DESTRUCTIBLE := "res://scripts/destructibles/destructible.gd"

# Index 0..3 = small, medium, large, giant.
const TIER_PATHS := [
	"res://resources/destructibles/small.tres",
	"res://resources/destructibles/medium.tres",
	"res://resources/destructibles/large.tres",
	"res://resources/destructibles/giant.tres",
]
const GROUP_TIERS := {"small": 0, "medium": 1, "large": 2, "giant": 3}
const DEFAULT_TIER := 1  # medium

## Type archetypes (display name + per-surface palettes). A mesh gets the first kind
## whose keyword matches its name. Add your kind .tres paths here.
const KIND_PATHS := [
	"res://resources/destructibles/kinds/house.tres",
]

func _run() -> void:
	var root := get_scene()
	if root == null:
		push_error("Generator: open a scene first.")
		return
	var src := root.get_node_or_null(SOURCE_NODE)
	if src == null:
		push_error("Generator: no node named '%s' in the open scene." % SOURCE_NODE)
		return

	if not DirAccess.dir_exists_absolute(OUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var script: Script = load(DESTRUCTIBLE)
	var tiers := TIER_PATHS.map(func(p): return load(p))
	var kinds := KIND_PATHS.map(func(p): return load(p))

	var jobs: Array = []
	_collect(src, DEFAULT_TIER, jobs)

	var made := 0
	for j in jobs:
		var child: MeshInstance3D = j[0]
		var tier: int = j[1]

		var body := StaticBody3D.new()
		body.set_script(script)
		body.name = child.name
		body.collision_layer = 2
		body.collision_mask = 0
		body.set("data", tiers[tier])
		body.set("kind", _kind_for(child.name, kinds))
		body.set("keep_authored_scale", true)
		# Keep the model's intrinsic scale/rotation, drop placement offset.
		var t := child.transform
		t.origin = Vector3.ZERO
		body.transform = t

		var mesh: MeshInstance3D = child.duplicate()
		mesh.transform = Transform3D.IDENTITY
		body.add_child(mesh)
		mesh.owner = body

		var packed := PackedScene.new()
		packed.pack(body)
		var path := "%s/%s.tscn" % [OUT_DIR, child.name]
		var err := ResourceSaver.save(packed, path)
		if err != OK:
			push_error("Generator: failed to save %s (err %d)" % [path, err])
		else:
			made += 1
		body.free()

	print("Generator: wrote %d destructible scenes to %s" % [made, OUT_DIR])
	EditorInterface.get_resource_filesystem().scan()

func _collect(node: Node, tier: int, jobs: Array) -> void:
	for c in node.get_children():
		if c is MeshInstance3D:
			jobs.append([c, tier])
		else:
			var key := String(c.name).to_lower()
			_collect(c, GROUP_TIERS.get(key, tier), jobs)

func _kind_for(node_name: String, kinds: Array) -> Resource:
	var lower := node_name.to_lower()
	for k in kinds:
		if k == null:
			continue
		for kw in k.match_keywords:
			if String(kw) != "" and lower.contains(String(kw).to_lower()):
				return k
	return null
