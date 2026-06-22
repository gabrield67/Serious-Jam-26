extends Sprite3D
## Projects the mouse onto the ground plane

@export var ground_height: float = 0.0
@export var hover_offset: float = 0.05
@export var spin_speed: float = 30.0

const _FLAT := Vector3(-PI / 2.0, 0.0, 0.0)

var _angle: float = 0.0

func _ready() -> void:
	top_level = true

func _process(delta: float) -> void:
	_angle = wrapf(_angle + deg_to_rad(spin_speed) * delta, 0.0, TAU)

	var cam := get_viewport().get_camera_3d()
	if not cam:
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
	visible = true
	global_transform.basis = Basis(Vector3.UP, _angle) * Basis.from_euler(_FLAT)
	global_position = origin + dir * t + Vector3(0.0, hover_offset, 0.0)
