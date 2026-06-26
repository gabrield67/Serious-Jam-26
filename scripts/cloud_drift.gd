extends MeshInstance3D
## Low overcast layer with faked vertical thickness

@export var follow: bool = true
## Texture scroll speed (UV units per second) for the gentle drift.
@export var drift: Vector2 = Vector2(0.008, 0.004)

@export_group("Thickness")
## How many stacked sheets make up the bank (more = thicker/denser, but more overdraw).
@export var sheet_count: int = 5
## Vertical span of the bank (world units), built upward from this node.
@export var thickness: float = 45.0
## UV shift between sheets so each shows different clouds
@export var layer_uv_step: float = 0.11
## How much darker the underside sheets are than the top
@export var underside_darken: float = 0.3

var _t: float = 0.0
var _tornado: Node3D
var _sheets: Array[MeshInstance3D] = []
var _base_color: Color = Color.WHITE

func _ready() -> void:
	_tornado = get_tree().get_first_node_in_group("tornado") as Node3D
	var base_mat := material_override as StandardMaterial3D
	if base_mat == null:
		return
	_base_color = base_mat.albedo_color
	sheet_count = maxi(sheet_count, 1)
	var span := maxi(sheet_count - 1, 1)
	for i in sheet_count:
		var frac := float(i) / float(span)   # 0 = bottom (this node), 1 = top
		var sheet: MeshInstance3D
		var mat: StandardMaterial3D
		if i == 0:
			sheet = self
			mat = base_mat
		else:
			sheet = MeshInstance3D.new()
			sheet.mesh = mesh
			mat = base_mat.duplicate()
			sheet.material_override = mat
			add_child(sheet)
			sheet.position.y = frac * thickness  # stack upward
		mat.albedo_color = _base_color.darkened(underside_darken * (1.0 - frac))
		sheet.set_meta("uv_bias", Vector2(i * layer_uv_step, i * layer_uv_step * 0.6))
		_sheets.append(sheet)

func _process(delta: float) -> void:
	_t += delta

	var anchor := Vector2.ZERO
	if follow:
		if _tornado == null or not is_instance_valid(_tornado):
			_tornado = get_tree().get_first_node_in_group("tornado") as Node3D
		if _tornado:
			var tp := _tornado.global_position
			global_position.x = tp.x
			global_position.z = tp.z
			anchor = Vector2(tp.x, tp.z)

	var size := Vector2(100.0, 100.0)
	if mesh is PlaneMesh:
		size = (mesh as PlaneMesh).size

	for sheet in _sheets:
		var mat := sheet.material_override as StandardMaterial3D
		if mat == null:
			continue
		var sc := mat.uv1_scale
		var bias: Vector2 = sheet.get_meta("uv_bias", Vector2.ZERO)
		mat.uv1_offset = Vector3(
			anchor.x * sc.x / size.x + drift.x * _t + bias.x,
			anchor.y * sc.y / size.y + drift.y * _t + bias.y,
			0.0)
