extends Node3D
class_name Enemy
## Base for NPC enemies. Adds health + the targeting contract (name / health / highlight)
## so the targeting system can hover them, show their info, and damage them with thrown
## debris. NPC behavior scripts (helicopter, tank, ...) extend this instead of Node3D.

@export var enemy_name: String = "Enemy"
@export var max_health: float = 30.0
## Only attacks when the tornado is within this many world units (0 = always).
@export var attack_range: float = 80.0

@export_group("Death")
## Effect spawned where the enemy dies (auto-plays, then frees itself). Override per-scene
## for a different blast — e.g. the tank uses Explosion B.
@export var death_vfx: PackedScene = preload("res://Explosion VFX/Scenes/VFX_Explosion_A.tscn")
## Uniform scale applied to the spawned effect.
@export var death_vfx_scale: float = 10
## How long the effect lives before despawning (seconds).
@export var death_vfx_lifetime: float = 4.0

@export_group("Obstacle avoidance")
## Steer around buildings/pickups instead of moving through them.
@export var avoid_enabled: bool = true
## How far beyond an obstacle's own footprint it starts steering away.
@export var avoid_range: float = 18.0
## How hard it steers away (higher = wider berth).
@export var avoid_strength: float = 2.5
## Max steer rate while dodging (deg/sec) — used by enemies that turn to avoid.
@export var avoid_turn_speed: float = 240.0
## Flyers only: ignore obstacles whose top is more than this far below them, so they fly over
## short buildings and only weave around ones that reach near their altitude.
@export var avoid_clearance: float = 8.0

var health: float

## True when the tornado is close enough to attack. Enemies gate their attacks on this.
func in_attack_range() -> bool:
	if attack_range <= 0.0:
		return true
	var t := get_tree().get_first_node_in_group("tornado")
	if t == null or not (t is Node3D):
		return false
	return global_position.distance_to((t as Node3D).global_position) <= attack_range

## Horizontal repulsion (away from nearby destructibles + pickups) around `from`, for steering
## avoidance. Each obstacle pushes harder the closer we are within its footprint + avoid_range.
## When `flying` is true, obstacles whose top sits well below us are ignored — we clear them.
func obstacle_push(from: Vector3, flying: bool = false) -> Vector3:
	if not avoid_enabled:
		return Vector3.ZERO
	var ceiling := from.y - avoid_clearance
	var push := Vector3.ZERO
	for grp in ["consumable", "pickup"]:
		for n in get_tree().get_nodes_in_group(grp):
			var o := n as Node3D
			if o == null or not is_instance_valid(o) or o == self:
				continue
			if flying:
				if not o.has_method("get_avoid_top_y"):
					continue  # no height info (ground pickups, etc.) — flyers don't dodge these
				if o.get_avoid_top_y() < ceiling:
					continue  # its top is below us — we clear it
			var away := Vector3(from.x - o.global_position.x, 0.0, from.z - o.global_position.z)
			var d := away.length()
			var radius: float = o.get_avoid_radius() if o.has_method("get_avoid_radius") else 2.0
			if d < 0.001 or d > radius + avoid_range:
				continue
			var t := 1.0 - clampf((d - radius) / maxf(avoid_range, 0.001), 0.0, 1.0)
			push += (away / d) * t
	return push

func _enter_tree() -> void:
	add_to_group("enemy")
	add_to_group("targetable")
	health = max_health

## Chips health, dies at 0.
func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
	health -= amount
	if health <= 0.0:
		kill()

## Instantly destroy this enemy — a thrown debris is a one-hit kill.
func kill() -> void:
	if health > 0.0:
		health = 0.0
	_on_death()
	queue_free()

## Spawns the death explosion at the enemy's position. Override for extra death behavior
## (call super() to keep the explosion).
func _on_death() -> void:
	if death_vfx == null:
		return
	var fx := death_vfx.instantiate()
	# GPUParticles only scale cleanly in local-coords mode; in global coords a big node scale
	# makes them spray out fast and just flash. Flip them to local before scaling.
	_make_particles_local(fx)
	# The effects' "Init" animation loops, so over the lifetime it replays (the minis blast
	# 3x). Make it play once.
	_stop_vfx_loop(fx)
	# Strip Compatibility-killers (shadow-casting lights, Decals) so stacked deaths don't sputter.
	VFXUtil.tame_for_compatibility(fx)
	get_tree().current_scene.add_child(fx)
	if fx is Node3D:
		var n3 := fx as Node3D
		n3.global_position = global_position
		n3.scale = Vector3.ONE * death_vfx_scale
	# It's parented to the scene (not us), so it survives our queue_free; free it after it plays.
	get_tree().create_timer(death_vfx_lifetime).timeout.connect(fx.queue_free)

func _make_particles_local(node: Node) -> void:
	if node is GPUParticles3D:
		(node as GPUParticles3D).local_coords = true
	for child in node.get_children():
		_make_particles_local(child)

## Turn off looping on the effect's animations so the blast fires once, not on repeat.
func _stop_vfx_loop(node: Node) -> void:
	if node is AnimationPlayer:
		var ap := node as AnimationPlayer
		for anim_name in ap.get_animation_list():
			var anim := ap.get_animation(anim_name)
			if anim:
				anim.loop_mode = Animation.LOOP_NONE
	for child in node.get_children():
		_stop_vfx_loop(child)

# --- Targeting contract ---

func get_display_name() -> String:
	return enemy_name

func get_health() -> Vector2:
	return Vector2(maxf(health, 0.0), max_health)

func set_highlighted(on: bool) -> void:
	TargetHighlight.apply(self, on)
