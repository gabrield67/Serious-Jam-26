extends Control
## Debris slots — 12 cells (Slots/SlotRow/Slot0..Slot11 in the scene), driven by the tornado's
## debris (get_debris() = Vector2(carried, capacity)):
##   - holding debris (i < carried)        -> filled (full bright)
##   - usable but empty (carried..capacity) -> greyed
##   - beyond capacity                      -> faint ghost (locked)

## Tint for a slot that's currently holding debris — full bright (white = the slot's own colour).
@export var filled_modulate: Color = Color(1, 1, 1, 1)
## Tint for a usable but empty slot — greyed out.
@export var available_modulate: Color = Color(0.4, 0.45, 0.45, 0.55)
## Tint for a locked slot beyond the current capacity — a faint ghost.
@export var locked_modulate: Color = Color(1, 1, 1, 0.15)

@onready var _slots: Array[Node] = $Slots/SlotRow.get_children()
var _tornado: Node

func _ready() -> void:
	_tornado = get_tree().get_first_node_in_group("tornado")

func _process(_delta: float) -> void:
	if _tornado == null or not is_instance_valid(_tornado):
		_tornado = get_tree().get_first_node_in_group("tornado")
		return
	if not _tornado.has_method("get_debris"):
		return
	var d: Vector2 = _tornado.get_debris()
	var carried: int = int(d.x)  # slots currently holding debris
	var cap: int = int(d.y)      # how many slots are usable
	for i in _slots.size():
		var slot := _slots[i] as CanvasItem
		if slot == null:
			continue
		if i < carried:
			slot.modulate = filled_modulate
		elif i < cap:
			slot.modulate = available_modulate
		else:
			slot.modulate = locked_modulate
