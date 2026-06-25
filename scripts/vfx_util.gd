extends RefCounted
class_name VFXUtil
## Helpers for spawning the explosion/debris VFX under the Compatibility renderer (our web
## target). These effects were authored for Forward+ and carry features that are either
## expensive or unsupported in Compatibility — this strips the worst offenders at spawn time.

## Walk a freshly-instanced VFX and remove the things that tank the framerate or simply don't
## work in Compatibility:
##   - shadow-casting lights  -> a shadow map re-render per explosion (huge when they stack)
##   - Decal nodes            -> unsupported in Compatibility; pure cost / error spam on web
static func tame_for_compatibility(node: Node) -> void:
	if node is Light3D:
		(node as Light3D).shadow_enabled = false  # keep the flash, drop the shadow map
	if node is Decal:
		node.queue_free()  # not rendered in Compatibility anyway
		return
	for c in node.get_children():
		tame_for_compatibility(c)
