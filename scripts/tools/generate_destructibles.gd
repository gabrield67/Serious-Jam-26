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
##
## With GENERATE_FRAGMENTS on, it ALSO Voronoi-fractures each mesh (via the enabled
## VoronoiShatter addon) and bakes a frozen shard scene per model, linked to the
## destructible's `fragments_scene` so it physically collapses on death.

const SOURCE_NODE := "Map Objects"
const OUT_DIR := "res://scenes/destructibles/generated"
const DESTRUCTIBLE := "res://scripts/destructibles/destructible.gd"
## Meshes under a "minor" group node aren't destructibles — they become PickupItems the
## tornado carries (not chewed, not fractured).
const PICKUP := "res://scripts/pickup_item.gd"
const MINOR_GROUP := "minor"
## Baked shard scenes, written to FRAGMENTS_DIR as "Fragments_<MeshName>.tscn".
const FRAGMENTS_DIR := "res://scenes/destructibles/fragments"
## Fracture each mesh automatically (uses the VoronoiShatter addon's generator). When
## false, only links a manually pre-baked Fragments_<name>.tscn if one already exists.
const GENERATE_FRAGMENTS := true
const FRAG_SAMPLES := 24       ## fracture pieces (fewer = bigger chunks, faster)
const FRAG_SEED := 0
const FRAG_CELL_SCALE := 0.9   ## <1 leaves gaps between shards (stops spawn-explosion)

# Index 0..3 = small, medium, large, giant.
const TIER_PATHS := [
	"res://resources/destructibles/size/small.tres",
	"res://resources/destructibles/size/medium.tres",
	"res://resources/destructibles/size/large.tres",
	"res://resources/destructibles/size/giant.tres",
]
const GROUP_TIERS := {"small": 0, "medium": 1, "large": 2, "giant": 3}
const DEFAULT_TIER := 1  # medium

## Type archetypes (display name + per-surface palettes). A mesh gets the first kind
## whose keyword matches its name. Add your kind .tres paths here.
const KIND_PATHS := [
	"res://resources/destructibles/kinds/apartments.tres",
	"res://resources/destructibles/kinds/bank.tres",
	"res://resources/destructibles/kinds/barn.tres",
	"res://resources/destructibles/kinds/church.tres",
	"res://resources/destructibles/kinds/foliage.tres",
	"res://resources/destructibles/kinds/gas.tres",
	"res://resources/destructibles/kinds/house.tres",
	"res://resources/destructibles/kinds/motel.tres",
	"res://resources/destructibles/kinds/sign.tres",
	"res://resources/destructibles/kinds/silo.tres",
	"res://resources/destructibles/kinds/skyscraper.tres",
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

	if GENERATE_FRAGMENTS and not DirAccess.dir_exists_absolute(FRAGMENTS_DIR):
		DirAccess.make_dir_recursive_absolute(FRAGMENTS_DIR)

	var script: Script = load(DESTRUCTIBLE)
	var tiers := TIER_PATHS.map(func(p): return load(p))
	var kinds := KIND_PATHS.map(func(p): return load(p))
	var vgen = VoronoiGenerator.new() if GENERATE_FRAGMENTS else null

	var jobs: Array = []
	_collect(src, DEFAULT_TIER, false, jobs)

	var made := 0
	var pickups := 0
	for j in jobs:
		var child: MeshInstance3D = j[0]
		var tier: int = j[1]
		var minor: bool = j[2]

		if minor:
			if _save_pickup(child, kinds):
				pickups += 1
			continue

		var body := StaticBody3D.new()
		body.set_script(script)
		body.name = child.name
		body.collision_layer = 2
		body.collision_mask = 0
		body.set("data", tiers[tier])
		body.set("kind", _kind_for(child.name, kinds))
		body.set("keep_authored_scale", true)
		var frag_path := "%s/Fragments_%s.tscn" % [FRAGMENTS_DIR, child.name]
		if GENERATE_FRAGMENTS:
			var fpacked := _bake_fragments(vgen, child)
			if fpacked and ResourceSaver.save(fpacked, frag_path) == OK:
				body.set("fragments_scene", load(frag_path))
				print("  fractured %s" % child.name)
			else:
				print("  (no fragments for %s — mesh not CSG-solid: flipped/inconsistent normals, open holes, or flat geometry. Recalc normals + check Non-Manifold in Blender)" % child.name)
		elif ResourceLoader.exists(frag_path):
			body.set("fragments_scene", load(frag_path))
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

	if vgen:
		vgen.free()
	print("Generator: wrote %d destructible + %d pickup scenes to %s" % [made, pickups, OUT_DIR])
	EditorInterface.get_resource_filesystem().scan()

## Bake a "minor" mesh into a reusable PickupItem scene (carried by the tornado, never
## destroyed). Mirrors the destructible wrapping minus size/fragments; keeps the kind
## (display name + per-surface palette colors).
func _save_pickup(child: MeshInstance3D, kinds: Array) -> bool:
	var body := StaticBody3D.new()
	body.set_script(load(PICKUP))
	body.name = child.name
	body.set("kind", _kind_for(child.name, kinds))
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
	body.free()
	if err != OK:
		push_error("Generator: failed to save pickup %s (err %d)" % [path, err])
		return false
	return true

## Fracture one mesh into a frozen RigidBody3D shard scene (CollapsingFragments drives it
## at runtime). Tries the real mesh, then a position-welded copy if CSG cracks on import
## seams. Returns null (with a warning) when the geometry still defeats CSG — fix in Blender.
func _bake_fragments(vgen, source: MeshInstance3D) -> PackedScene:
	if source.mesh == null:
		return null
	var config = VoronoiGeneratorConfig.new()
	config.num_samples = FRAG_SAMPLES
	config.random_seed = FRAG_SEED
	config.texture = null

	# Try the real mesh first — a clean solid fractures with its surface materials intact.
	var results: Array = vgen.create_from_mesh(source, config)
	if results == null or results.is_empty():
		# Failed: import splits verts (material seams / hard edges / UV seams), leaving CSG
		# hairline cracks. Weld by position and retry (shards come out single-surface).
		var temp := MeshInstance3D.new()
		temp.mesh = _weld_single_surface(source.mesh)
		results = vgen.create_from_mesh(temp, config)
		temp.free()
	if results == null or results.is_empty():
		# Still failing -> the model is multiple disconnected parts (CSG needs one solid).
		# Fracture each connected component separately and combine the shards.
		results = []
		var comps := _split_components(source.mesh)
		for ci in comps.size():
			var comp_mesh: ArrayMesh = comps[ci]
			var cproxy := MeshInstance3D.new()
			cproxy.mesh = comp_mesh
			var cr: Array = vgen.create_from_mesh(cproxy, config)
			cproxy.free()
			if cr == null or cr.is_empty():
				# This part is wound inside-out (CSG saw its "solid" as the exterior, so it
				# clipped to nothing). Flip the winding and retry.
				var fproxy := MeshInstance3D.new()
				fproxy.mesh = _flip_mesh(comp_mesh)
				cr = vgen.create_from_mesh(fproxy, config)
				fproxy.free()
			if cr != null and not cr.is_empty():
				results.append_array(cr)
			else:
				var sz := comp_mesh.get_aabb().size
				push_warning("Fragments: %s part %d still failed (size %.1fx%.1fx%.1f)" % [source.name, ci, sz.x, sz.y, sz.z])
		if not results.is_empty():
			print("    (split %s into %d parts to fracture)" % [source.name, comps.size()])
	if results == null or results.is_empty():
		var pts: Array = vgen.sample_points(source.mesh, config)
		var tet: Array = vgen.create_delauney_tetrahedra(pts)
		push_warning("Fragments: %s failed — %d sample points, %d tetrahedra (open/flat geometry?)" % [source.name, pts.size(), tet.size()])
		return null

	# Bake at the model's render scale so runtime placement needs position+rotation only.
	var s: Vector3 = source.transform.basis.get_scale()
	var gap: Vector3 = s * FRAG_CELL_SCALE
	# No material override — shards keep the model's surface materials so the Destructible
	# can re-apply its per-instance palette colors to them at runtime (matching the build).

	var root := Node3D.new()
	root.name = "Fragments_%s" % source.name
	var i := 0
	for vm in results:
		if vm == null or vm.mesh == null:
			continue
		var body := RigidBody3D.new()
		body.name = "Shard_%d" % i
		body.freeze = true  # CollapsingFragments releases them
		body.position = -vm.position * s
		var mi := MeshInstance3D.new()
		mi.mesh = vm.mesh
		mi.scale = gap
		body.add_child(mi)
		var col := CollisionShape3D.new()
		col.shape = vm.mesh.create_convex_shape(true, true)
		col.scale = gap
		body.add_child(col)
		root.add_child(body)
		i += 1

	if i == 0:
		root.free()
		return null
	_own_all(root, root)
	var packed := PackedScene.new()
	packed.pack(root)
	return packed

## Collapse all surfaces of a mesh into one position-welded surface, so CSG sees a single
## watertight solid (multi-material meshes otherwise split verts at the material seam).
## Welds by quantized position (so the seam closes) and recomputes smooth normals manually
## — SurfaceTool.generate_normals() after index() is unreliable.
func _weld_single_surface(mesh: Mesh) -> ArrayMesh:
	var pos_to_i := {}
	var out_v := PackedVector3Array()
	var out_idx := PackedInt32Array()
	for si in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var src: Array = []
		if ix != null and ix.size() > 0:
			src = Array(ix)
		else:
			for k in v.size():
				src.append(k)
		for k in src:
			var p: Vector3 = v[k]
			# Round to ~0.01 so seam verts that the import nudged apart still merge.
			var key := "%d_%d_%d" % [roundi(p.x * 100.0), roundi(p.y * 100.0), roundi(p.z * 100.0)]
			if not pos_to_i.has(key):
				pos_to_i[key] = out_v.size()
				out_v.append(p)
			out_idx.append(pos_to_i[key])

	var normals := PackedVector3Array()
	normals.resize(out_v.size())
	for t in range(0, out_idx.size(), 3):
		var a := out_idx[t]
		var b := out_idx[t + 1]
		var c := out_idx[t + 2]
		var fn := (out_v[b] - out_v[a]).cross(out_v[c] - out_v[a])
		normals[a] += fn
		normals[b] += fn
		normals[c] += fn
	for n in normals.size():
		normals[n] = normals[n].normalized() if normals[n].length() > 0.0 else Vector3.UP

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out_v
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = out_idx
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out

## Split a mesh into one welded ArrayMesh per connected component (positions kept, so the
## parts stay where they belong). Each part is its own watertight solid, which CSG can
## fracture even when the whole model is several disconnected pieces.
func _split_components(mesh: Mesh) -> Array:
	# Weld by position and collect triangles as welded-index triples.
	var pos_to_i := {}
	var verts := PackedVector3Array()
	var tris: Array = []
	for si in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var src: Array = []
		if ix != null and ix.size() > 0:
			src = Array(ix)
		else:
			for k in v.size():
				src.append(k)
		var widx: Array = []
		for k in src:
			var p: Vector3 = v[k]
			var key := "%d_%d_%d" % [roundi(p.x * 100.0), roundi(p.y * 100.0), roundi(p.z * 100.0)]
			if not pos_to_i.has(key):
				pos_to_i[key] = verts.size()
				verts.append(p)
			widx.append(pos_to_i[key])
		for t in range(0, widx.size(), 3):
			tris.append([widx[t], widx[t + 1], widx[t + 2]])

	# Union-find: triangles sharing a welded vertex are the same component.
	# Plain Array (by-reference) so the helpers' mutations propagate reliably.
	var parent: Array = []
	parent.resize(verts.size())
	for i in verts.size():
		parent[i] = i
	for t in tris:
		_uf_union(parent, t[0], t[1])
		_uf_union(parent, t[0], t[2])

	# Group triangles by component root.
	var comp_tris := {}
	for t in tris:
		var root := _uf_find(parent, t[0])
		if not comp_tris.has(root):
			comp_tris[root] = []
		comp_tris[root].append(t)

	# Build a welded ArrayMesh per component (re-indexed, normals recomputed).
	var meshes: Array = []
	for root in comp_tris:
		var local := {}
		var lv := PackedVector3Array()
		var li := PackedInt32Array()
		for t in comp_tris[root]:
			for vi in t:
				if not local.has(vi):
					local[vi] = lv.size()
					lv.append(verts[vi])
				li.append(local[vi])
		var normals := PackedVector3Array()
		normals.resize(lv.size())
		for k in range(0, li.size(), 3):
			var a := li[k]
			var b := li[k + 1]
			var c := li[k + 2]
			var fn := (lv[b] - lv[a]).cross(lv[c] - lv[a])
			normals[a] += fn
			normals[b] += fn
			normals[c] += fn
		for n in normals.size():
			normals[n] = normals[n].normalized() if normals[n].length() > 0.0 else Vector3.UP
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = lv
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_INDEX] = li
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		meshes.append(am)
	return meshes

## Reverse a single-surface mesh's winding (and normals) — flips an inside-out component so
## CSG treats its interior as the solid.
func _flip_mesh(mesh: ArrayMesh) -> ArrayMesh:
	var arr := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ix: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var out_i := PackedInt32Array()
	for k in range(0, ix.size(), 3):
		out_i.append(ix[k])
		out_i.append(ix[k + 2])
		out_i.append(ix[k + 1])
	var normals: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	for n in normals.size():
		normals[n] = -normals[n]
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = out_i
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return out

func _uf_find(parent: Array, x: int) -> int:
	while parent[x] != x:
		parent[x] = parent[parent[x]]  # path halving
		x = parent[x]
	return x

func _uf_union(parent: Array, a: int, b: int) -> void:
	var ra := _uf_find(parent, a)
	var rb := _uf_find(parent, b)
	if ra != rb:
		parent[rb] = ra

func _own_all(node: Node, owner_node: Node) -> void:
	for c in node.get_children():
		c.owner = owner_node
		_own_all(c, owner_node)

func _collect(node: Node, tier: int, minor: bool, jobs: Array) -> void:
	for c in node.get_children():
		if c is MeshInstance3D:
			jobs.append([c, tier, minor])
		else:
			var key := String(c.name).to_lower()
			if key == MINOR_GROUP:
				_collect(c, tier, true, jobs)
			else:
				_collect(c, GROUP_TIERS.get(key, tier), minor, jobs)

func _kind_for(node_name: String, kinds: Array) -> Resource:
	var lower := node_name.to_lower()
	for k in kinds:
		if k == null:
			continue
		for kw in k.match_keywords:
			if String(kw) != "" and lower.contains(String(kw).to_lower()):
				return k
	return null
