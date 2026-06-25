extends Node
## Drives the tornado's PhantomCamera. It orbits the camera to chase behind the tornado's
## heading (so you see where you're going), backs up/lowers as the Fujita size grows, swings
## to face inward near map edges, and leans toward the mouse to scout ahead. It drives the
## camera's follow_offset / look_at_offset; the camera's own damping smooths the rest.

@export var phantom_camera_path: NodePath

@export_group("Grow with Fujita")
## Extra horizontal distance (back up) per unit of size factor above 1.
@export var backup_per_size: float = 32.0
## Height dropped (lower the camera) per unit of size factor above 1.
@export var lower_per_size: float = 8.0
## Optional cap on the extra back-up distance (0 = uncapped).
@export var max_backup: float = 120.0

@export_group("Edge facing")
## Half-size of the playable area (centre to edge), world units.
@export var map_radius: float = 2000.0
## Centre of the playable area on the ground plane.
@export var map_center: Vector2 = Vector2.ZERO
## Start swinging the camera to face inward past this fraction of the way to the edge.
@export var edge_start: float = 0.6
## Fully faced inward by this fraction of the way to the edge.
@export var edge_full: float = 0.95

@export_group("Mouse look")
## Lean the camera toward the mouse so the player can scout ahead of the funnel.
@export var mouse_look: bool = true
## How far the aim leans toward the cursor at full deflection (ground units).
@export var look_ahead: float = 45.0
## Fraction of the screen around the centre where the mouse doesn't pan (0..1).
@export var look_dead_zone: float = 0.12
## How quickly the look-ahead eases in and out.
@export var look_smooth: float = 4.0

@export_group("Lead with movement")
## Orbit the camera to the side opposite the tornado's heading, and slide it off-centre.
@export var move_lead: bool = true
## How slowly the camera orbits around to the new side (deg/sec).
@export var pan_speed: float = 40.0
## Minimum travel speed before the camera updates which side to swing behind.
@export var move_threshold: float = 2.0
## How far the aim leads in the travel direction — slides the tornado off-centre (ground units).
@export var look_lead: float = 30.0
## Speed at which the look-ahead reaches full strength.
@export var ref_speed: float = 25.0
## How quickly the look-ahead eases in and out.
@export var lead_smooth: float = 3.0

var _pcam: Node
var _tornado: Node
var _base_offset: Vector3
var _base_look_at: Vector3
var _look_pan: Vector2 = Vector2.ZERO   # current eased ground-plane mouse look-ahead
var _look_lead: Vector2 = Vector2.ZERO  # current eased movement look-ahead
var _dir: Vector2 = Vector2(1.0, 0.0)         # current camera horizontal direction (orbits)
var _desired_dir: Vector2 = Vector2(1.0, 0.0)  # side it's swinging toward

func _ready() -> void:
	if phantom_camera_path != NodePath():
		_pcam = get_node_or_null(phantom_camera_path)
	if _pcam == null:
		_pcam = _find_pcam(get_tree().current_scene)  # path exports get stripped on reimport
	_tornado = get_tree().get_first_node_in_group("tornado")
	if _pcam:
		_base_offset = _pcam.follow_offset
		_base_look_at = _pcam.look_at_offset
		var bh := Vector2(_base_offset.x, _base_offset.z)
		_dir = bh.normalized() if bh.length() > 0.001 else Vector2(1.0, 0.0)
		_desired_dir = _dir

## Find the first PhantomCamera3D in the tree (fallback when the node path isn't set).
func _find_pcam(node: Node) -> Node:
	if node == null:
		return null
	if node is PhantomCamera3D:
		return node
	for child in node.get_children():
		var found := _find_pcam(child)
		if found != null:
			return found
	return null

func _process(delta: float) -> void:
	if _pcam == null:
		return
	if _tornado == null or not is_instance_valid(_tornado):
		_tornado = get_tree().get_first_node_in_group("tornado")
		if _tornado == null:
			return

	var sf := 1.0
	if _tornado.has_method("get_size_factor"):
		sf = _tornado.get_size_factor()
	var grow := maxf(sf - 1.0, 0.0)

	# Grow with Fujita: back up and lower.
	var backup := backup_per_size * grow
	if max_backup > 0.0:
		backup = minf(backup, max_backup)

	# Tornado's horizontal velocity.
	var vel2 := Vector2.ZERO
	var tv = _tornado.get("velocity")
	if tv is Vector3:
		vel2 = Vector2(tv.x, tv.z)
	var spd := vel2.length()

	# Chase: aim the camera to the side OPPOSITE the tornado's heading (behind the motion).
	# Only update the target side while actually moving, so it holds its angle when stopped.
	if move_lead and spd > move_threshold:
		_desired_dir = -vel2 / spd

	# Edge facing: near a map edge, override toward the outward side so it looks back inward.
	var p := Vector2(_tornado.global_position.x, _tornado.global_position.z) - map_center
	var cheb := maxf(absf(p.x), absf(p.y))      # distance to the nearest edge (square map)
	var start := edge_start * map_radius
	var ef := clampf((cheb - start) / maxf(edge_full * map_radius - start, 0.001), 0.0, 1.0)
	var goal := _desired_dir
	if ef > 0.0 and p.length() > 1.0:
		goal = _desired_dir.rotated(_desired_dir.angle_to(p.normalized()) * ef)

	# Slowly pan the current direction toward the goal side (capped degrees per second).
	var step := deg_to_rad(pan_speed) * delta
	_dir = _dir.rotated(clampf(_dir.angle_to(goal), -step, step))
	if _dir.length() > 0.001:
		_dir = _dir.normalized()

	# Movement look-ahead: slide the tornado off-centre toward the trailing edge (eases back
	# to centre when stopped).
	var look_lead_t := Vector2.ZERO
	if move_lead and spd > 0.5:
		var f := clampf(spd / maxf(ref_speed, 0.001), 0.0, 1.0)
		look_lead_t = (vel2 / spd) * look_lead * f
	_look_lead = _look_lead.lerp(look_lead_t, clampf(lead_smooth * delta, 0.0, 1.0))

	var base_mag := Vector2(_base_offset.x, _base_offset.z).length()
	var hdist := base_mag + backup
	var off := Vector3(_dir.x * hdist, _base_offset.y - lower_per_size * grow, _dir.y * hdist)
	_pcam.follow_offset = off

	# Mouse look-ahead: lean the aim toward the cursor so the player can scout ahead. Pans the
	# look_at target across the ground (capped + eased). Screen axes come from the camera's
	# current direction so right/forward stay correct as it orbits.
	var target_pan := Vector2.ZERO
	if mouse_look:
		var vp := get_viewport()
		if vp:
			var rect := vp.get_visible_rect().size
			var mp := vp.get_mouse_position()
			var screen := Vector2(mp.x / maxf(rect.x, 1.0), mp.y / maxf(rect.y, 1.0)) * 2.0 - Vector2.ONE
			screen.y = -screen.y   # top of screen = look further ahead
			var mag := minf(screen.length(), 1.0)
			if mag > look_dead_zone:
				var amt := (mag - look_dead_zone) / maxf(1.0 - look_dead_zone, 0.001) * look_ahead
				var s := screen.normalized()
				var fwd := -_dir                         # ground forward (camera -> tornado)
				var right := Vector2(-fwd.y, fwd.x)      # screen-right on the ground
				target_pan = (right * s.x + fwd * s.y) * amt
	_look_pan = _look_pan.lerp(target_pan, clampf(look_smooth * delta, 0.0, 1.0))
	_pcam.look_at_offset = _base_look_at + Vector3(_look_pan.x + _look_lead.x, 0.0, _look_pan.y + _look_lead.y)
