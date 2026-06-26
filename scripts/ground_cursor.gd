extends Sprite3D
## Ground marker with two modes:
##   Traveling  -> sits at the tornado's committed destination.
##   Arrived/idle -> follows the mouse cursor on the ground (hover).

@export var ground_height: float = 0.0
@export var hover_offset: float = 0.15
@export var spin_speed: float = 30.0

const _FLAT := Vector3(-PI / 2.0, 0.0, 0.0)

var _angle: float = 0.0
var _tornado: Node3D

func _ready() -> void:
	top_level = true
	_tornado = get_tree().get_first_node_in_group("tornado") as Node3D

func _process(delta: float) -> void:
	_angle = wrapf(_angle + deg_to_rad(spin_speed) * delta, 0.0, TAU)

	if _tornado == null or not is_instance_valid(_tornado):
		_tornado = get_tree().get_first_node_in_group("tornado") as Node3D

	if _tornado and _tornado.is_seeking():
		_place_at(_tornado.get_destination())  # show where it's headed
	else:
		_place_at_mouse()  # arrived: return to hover-follow

func _place_at(point: Vector3) -> void:
	visible = true
	global_transform.basis = Basis(Vector3.UP, _angle) * Basis.from_euler(_FLAT)
	global_position = Vector3(point.x, ground_height + hover_offset, point.z)

func _place_at_mouse() -> void:
	var cam := get_viewport().get_camera_3d()
	if not cam:
		visible = false
		return
	var mouse := get_viewport().get_mouse_position()
	var origin := cam.project_ray_origin(mouse)
	var dir := cam.project_ray_normal(mouse)
	if is_zero_approx(dir.y):
		visible = false
		return
	var t := (ground_height - origin.y) / dir.y
	if t < 0.0:
		visible = false
		return
	_place_at(origin + dir * t)
