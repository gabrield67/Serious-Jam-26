extends Node3D
## A laser beam stretched between two points. For a one-shot, call setup(from, to) and it
## fades out on its own. For a sustained beam, set `continuous = true` and call aim(from, to)
## every frame to keep it locked on — free it yourself when the source stops firing.

@export var thickness: float = 0.5
@export var continuous: bool = false
## Fade-out time for one-shot beams.
@export var fade_time: float = 0.18
## Thickness wobble for a lively, energized look.
@export var pulse_amount: float = 0.18
@export var pulse_speed: float = 22.0

@onready var _mesh: MeshInstance3D = get_node_or_null("Mesh")

var _t: float = 0.0
var _len: float = 1.0
var _pulse: float = 0.0

func setup(from: Vector3, to: Vector3) -> void:
	_orient(from, to)

## Re-aim a continuous beam each frame.
func aim(from: Vector3, to: Vector3) -> void:
	_orient(from, to)

func _orient(from: Vector3, to: Vector3) -> void:
	var dir := to - from
	_len = maxf(dir.length(), 0.001)
	var y := dir / _len
	var x := Vector3.UP.cross(y)
	if x.length() < 0.001:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	global_transform = Transform3D(Basis(x, y, z), (from + to) * 0.5)
	_scale_mesh(1.0)

func _scale_mesh(k: float) -> void:
	if _mesh == null:
		return
	var w := thickness * k * (1.0 + pulse_amount * sin(_pulse))
	_mesh.scale = Vector3(w, _len, w)

func _process(delta: float) -> void:
	_pulse += delta * pulse_speed
	if continuous:
		_scale_mesh(1.0)   # stay lit and pulsing; the firer frees us when done
		return
	_t += delta
	var k := clampf(1.0 - _t / fade_time, 0.0, 1.0)
	_scale_mesh(k)
	if _t >= fade_time:
		queue_free()
