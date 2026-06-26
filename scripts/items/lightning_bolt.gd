extends Node3D
## A jagged lightning bolt stretched from one point to another.

## Radius of each bolt segment.
@export var thickness: float = 0.35
## Number of segments along the bolt (more = more jagged detail).
@export var segments: int = 7
## How far the bolt wanders sideways between endpoints (world units).
@export var jaggedness: float = 1.8
## Seconds the bolt stays visible before fading out.
@export var life: float = 0.18

@export_group("Glow")
## Color of the soft halo around the bolt.
@export var glow_color: Color = Color(0.5, 0.8, 1.0)
## Halo radius as a multiple of the core thickness (bigger = wider glow).
@export var glow_width: float = 3.0
## Halo opacity (it's additively blended, so this is a soft glow not a solid sleeve).
@export_range(0.0, 1.0) var glow_alpha: float = 0.35

var _t: float = 0.0
var _mat: StandardMaterial3D
var _glow_mat: StandardMaterial3D
var _meshes: Array[MeshInstance3D] = []

## Draw the bolt between two world points.
func setup(from: Vector3, to: Vector3) -> void:
	var dir := to - from
	var dist := dir.length()
	if dist < 0.01:
		queue_free()
		return
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.albedo_color = Color(0.6, 0.9, 1.0)
	_mat.emission_enabled = true
	_mat.emission = Color(0.4, 0.75, 1.0)
	_mat.emission_energy_multiplier = 6.0

	# Soft additive halo to fake a glow (real bloom isn't available on gl_compatibility).
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # visible from inside the halo too
	_glow_mat.albedo_color = Color(glow_color.r, glow_color.g, glow_color.b, glow_alpha)
	_glow_mat.emission_enabled = true
	_glow_mat.emission = glow_color
	_glow_mat.emission_energy_multiplier = 4.0

	# Two axes perpendicular to the bolt, to wander within.
	var fwd := dir / dist
	var px := Vector3.UP.cross(fwd)
	if px.length() < 0.001:
		px = Vector3.RIGHT
	px = px.normalized()
	var py := fwd.cross(px).normalized()

	# Build a zigzag path: straight endpoints, jittered interior points.
	var pts: Array[Vector3] = [from]
	for i in range(1, segments):
		var base := from.lerp(to, float(i) / float(segments))
		var off := px * randf_range(-jaggedness, jaggedness) + py * randf_range(-jaggedness, jaggedness)
		pts.append(base + off)
	pts.append(to)

	for i in range(pts.size() - 1):
		_add_segment(pts[i], pts[i + 1])

func _add_segment(a: Vector3, b: Vector3) -> void:
	var seg := b - a
	var seg_len := seg.length()
	if seg_len < 0.001:
		return
	# Cylinder height is local Y — orient Y along the segment.
	var y := seg / seg_len
	var x := Vector3.UP.cross(y)
	if x.length() < 0.001:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	var xform := Transform3D(Basis(x, y, z), (a + b) * 0.5)
	# Wider, additive halo first (drawn behind), then the bright core on top.
	_make_cylinder(thickness * 0.5 * glow_width, seg_len, _glow_mat, xform, 6)
	_make_cylinder(thickness * 0.5, seg_len, _mat, xform, 5)

func _make_cylinder(radius: float, seg_len: float, mat: Material, xform: Transform3D, sides: int) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = seg_len
	cm.radial_segments = sides
	cm.rings = 0
	cm.material = mat
	mi.mesh = cm
	add_child(mi)
	mi.global_transform = xform
	_meshes.append(mi)

func _process(delta: float) -> void:
	_t += delta
	# Shrink thickness toward zero over the lifetime for a quick fade-out.
	var k := clampf(1.0 - _t / life, 0.0, 1.0)
	for mi in _meshes:
		if is_instance_valid(mi):
			mi.scale = Vector3(k, 1.0, k)
	if _t >= life:
		queue_free()
