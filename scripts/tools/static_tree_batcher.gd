extends Node3D
## Bakes all descendant tree meshes into static MultiMeshInstance3D(s) at runtime — one draw
## call per distinct mesh, with no scripts, collision, or pickup behaviour. Attach to a purely
## decorative tree group (e.g. the perimeter "Tree Border") to make it cheap "plain plastic"
## foliage. The original interactive tree instances are removed on load.

## Plastic-look material applied to every baked tree. Set to null to keep the trees' own
## materials (still gets the MultiMesh batching, just not the uniform plastic look).
@export var plastic_material: Material = preload("res://resources/foliage/plastic_tree.tres")
## Baked trees don't cast shadows (cheap, and they're background dressing).
@export var cast_shadows: bool = false

func _ready() -> void:
	# Group every descendant mesh by its Mesh resource, recording each instance's transform
	# relative to this node (so the MultiMeshInstance can sit at our local origin).
	var groups: Dictionary = {}
	var inv := global_transform.affine_inverse()
	for mi in _find_meshes(self, []):
		if mi.mesh == null:
			continue
		if not groups.has(mi.mesh):
			groups[mi.mesh] = []
		groups[mi.mesh].append(inv * mi.global_transform)

	# Drop the originals — meshes, scripts, collision shapes and pickup groups all go.
	for c in get_children():
		c.queue_free()

	# One MultiMeshInstance per distinct mesh.
	for mesh in groups:
		var xforms: Array = groups[mesh]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if plastic_material != null:
			mmi.material_override = plastic_material
		mmi.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadows
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		add_child(mmi)

func _find_meshes(node: Node, acc: Array) -> Array:
	for c in node.get_children():
		if c is MeshInstance3D:
			acc.append(c)
		_find_meshes(c, acc)
	return acc
