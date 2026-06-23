extends Node3D
## A short-lived laser beam stretched between two points. Call setup(from, to) after
## spawning; it orients/scales a cylinder along the line and fades out.

@export var lifetime: float = 0.18
@export var thickness: float = 0.15

@onready var _mesh: MeshInstance3D = get_node_or_null("Mesh")

var _t: float = 0.0
var _len: float = 1.0

func setup(from: Vector3, to: Vector3) -> void:
	var dir := to - from
	_len = maxf(dir.length(), 0.001)
	var y := dir / _len
	var x := Vector3.UP.cross(y)
	if x.length() < 0.001:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	global_transform = Transform3D(Basis(x, y, z), (from + to) * 0.5)
	if _mesh:
		_mesh.scale = Vector3(thickness, _len, thickness)

func _process(delta: float) -> void:
	_t += delta
	var k := clampf(1.0 - _t / lifetime, 0.0, 1.0)
	if _mesh:
		_mesh.scale = Vector3(thickness * k, _len, thickness * k)
	if _t >= lifetime:
		queue_free()
