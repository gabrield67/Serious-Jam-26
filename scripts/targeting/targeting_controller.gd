extends Node
class_name TargetingController
## Hover-to-target system. Each frame it finds what's under the mouse — enemies (by
## screen proximity) or destructibles (layer-2 raycast) — highlights it and shows its
## name + health in a panel. Left-click is left entirely to the tornado (always moves);
## RIGHT-click throws an auto-aimed debris at the hovered enemy.


## Physics layers the hover ray checks. Destructibles = layer 2.
@export_flags_3d_physics var target_mask: int = 2

## Pixel radius for picking an enemy under the cursor (enemies have no collision shapes,
## so they're picked by screen-space proximity rather than the ray).
@export var enemy_pick_radius: float = 70.0

@export var tornado_path: NodePath
@export var panel_path: NodePath

var _tornado: Node
var _panel: TargetPanel
var _hovered: Node

func _ready() -> void:
	_tornado = get_node_or_null(tornado_path)
	_panel = get_node_or_null(panel_path)

func _physics_process(_delta: float) -> void:
	# Picking raycasts the physics space, which must be touched in _physics_process.
	_set_hovered(_pick_target())
	_update_panel()

## Right-click throws a debris at the hovered enemy (auto-aimed). Uses _input so it can
## consume the event before the tornado's own right-click manual throw fires. Left-click
## is left entirely to the tornado (always moves).
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if _hovered != null and is_instance_valid(_hovered) and _hovered.is_in_group("enemy"):
			if _tornado and _tornado.has_method("throw_at"):
				_tornado.throw_at(_hovered)
			get_viewport().set_input_as_handled()  # consume so no manual throw also fires

## What's under the cursor right now (or null).
func _pick_target() -> Node:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var mp := get_viewport().get_mouse_position()
	# 1) Enemies have no collision shapes — pick the one nearest the cursor on screen.
	var enemy := _nearest_enemy(cam, mp)
	if enemy:
		return enemy
	# 2) Destructibles: raycast the physics space (layer 2).
	var from := cam.project_ray_origin(mp)
	var to := from + cam.project_ray_normal(mp) * 4000.0
	var space := cam.get_world_3d().direct_space_state
	if space == null:
		return null
	var q := PhysicsRayQueryParameters3D.create(from, to, target_mask)
	var hit := space.intersect_ray(q)
	if hit and hit.has("collider"):
		var col = hit["collider"]
		if col and col.is_in_group("targetable"):
			return col
	return null

## The node currently under the cursor (used by debug tools), or null.
func get_hovered() -> Node:
	return _hovered

func _nearest_enemy(cam: Camera3D, mp: Vector2) -> Node:
	var best: Node = null
	var best_d := enemy_pick_radius
	for e in get_tree().get_nodes_in_group("enemy"):
		if not (e is Node3D) or not is_instance_valid(e):
			continue
		if cam.is_position_behind(e.global_position):
			continue
		var d := cam.unproject_position(e.global_position).distance_to(mp)
		if d < best_d:
			best_d = d
			best = e
	return best

func _set_hovered(t: Node) -> void:
	if t == _hovered:
		return
	if _hovered and is_instance_valid(_hovered) and _hovered.has_method("set_highlighted"):
		_hovered.set_highlighted(false)
	_hovered = t
	if _hovered and _hovered.has_method("set_highlighted"):
		_hovered.set_highlighted(true)

## Show the hovered target, or — when nothing is hovered — whatever's being destroyed.
func _update_panel() -> void:
	if _panel == null:
		return
	var target: Node = _hovered
	if target == null and _tornado and _tornado.has_method("get_chew_target"):
		target = _tornado.get_chew_target()
	if target and is_instance_valid(target) and target is Node3D:
		var cam := get_viewport().get_camera_3d()
		if cam and not cam.is_position_behind(target.global_position):
			var disp: String = target.get_display_name() if target.has_method("get_display_name") else String(target.name)
			# Pickups have no health — pass Vector2.ZERO so the panel shows just the name.
			var hp: Vector2 = target.get_health() if target.has_method("get_health") else Vector2.ZERO
			_panel.show_for(disp, hp, cam.unproject_position(target.global_position))
			return
	_panel.hide_panel()
