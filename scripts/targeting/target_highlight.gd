extends RefCounted
class_name TargetHighlight
## Toggles a highlight on a node's mesh instances using material_overlay — which renders
## ON TOP of the model's own materials, so it works regardless of textures/palette tints
## and is trivially reversible (set back to null).

static var _overlay: StandardMaterial3D

static func _mat() -> StandardMaterial3D:
	if _overlay == null:
		_overlay = StandardMaterial3D.new()
		_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_overlay.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_overlay.albedo_color = Color(0.35, 0.7, 1.0, 0.35)  # additive bluish glow
		_overlay.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _overlay

static func apply(node: Node, on: bool) -> void:
	if node == null:
		return
	for mi in _meshes(node, []):
		mi.material_overlay = _mat() if on else null

static func _meshes(node: Node, acc: Array) -> Array:
	if node is MeshInstance3D:
		acc.append(node)
	for c in node.get_children():
		_meshes(c, acc)
	return acc
