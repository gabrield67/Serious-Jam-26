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

## Spawn a one-shot explosion/VFX scene into the world: flips its particles to local coords (so
## scaling doesn't make them spray), stops any looping "Init" animation (so it fires once), strips
## the Compatibility-killers, positions + scales it, and frees it after `lifetime`.
static func spawn_one_shot(scene: PackedScene, at: Vector3, scl: float, lifetime: float = 4.0) -> void:
	if scene == null:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.current_scene == null:
		return
	var fx := scene.instantiate()
	_make_particles_local(fx)
	_stop_vfx_loop(fx)
	tame_for_compatibility(fx)
	tree.current_scene.add_child(fx)
	if fx is Node3D:
		(fx as Node3D).global_position = at
		(fx as Node3D).scale = Vector3.ONE * scl
	tree.create_timer(lifetime).timeout.connect(fx.queue_free)

static func _make_particles_local(node: Node) -> void:
	if node is GPUParticles3D:
		(node as GPUParticles3D).local_coords = true
	for c in node.get_children():
		_make_particles_local(c)

static func _stop_vfx_loop(node: Node) -> void:
	if node is AnimationPlayer:
		var ap := node as AnimationPlayer
		for anim_name in ap.get_animation_list():
			var anim := ap.get_animation(anim_name)
			if anim:
				anim.loop_mode = Animation.LOOP_NONE
	for c in node.get_children():
		_stop_vfx_loop(c)
