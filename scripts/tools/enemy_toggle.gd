extends Node3D
## Test helper: activates one enemy child at a time so you can isolate behavior.
## Press number keys 1..N to show only that enemy, 0 to show them all. Attach to the
## node whose Node3D children are the enemies (e.g. the "NPCs" node).

## Which enemy starts active (1-based, in child order). 0 = all enemies active.
@export var active: int = 1
## Optional Label to show the current selection on-screen.
@export var hint_label_path: NodePath

var _enemies: Array[Node3D] = []
var _hint: Label

func _ready() -> void:
	for c in get_children():
		if c is Node3D:
			_enemies.append(c as Node3D)
	if hint_label_path != NodePath():
		_hint = get_node_or_null(hint_label_path) as Label
	_apply(active)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = (event as InputEventKey).keycode
		if k == KEY_0:
			_apply(0)
		elif k >= KEY_1 and k <= KEY_9:
			_apply(k - KEY_0)

## which: 0 = all active, otherwise the 1-based index of the only active enemy.
func _apply(which: int) -> void:
	active = which
	for i in _enemies.size():
		_set_active(_enemies[i], which == 0 or which == i + 1)
	_update_hint()

func _set_active(e: Node3D, on: bool) -> void:
	e.visible = on
	e.set_process(on)
	e.set_physics_process(on)
	# Drop disabled enemies from the targeting groups so they can't be hovered/hit.
	if on:
		if not e.is_in_group("enemy"):
			e.add_to_group("enemy")
		if not e.is_in_group("targetable"):
			e.add_to_group("targetable")
	else:
		e.remove_from_group("enemy")
		e.remove_from_group("targetable")

func _update_hint() -> void:
	var who: String = "All"
	if active >= 1 and active <= _enemies.size():
		who = _enemies[active - 1].name
	var line := "Enemy [%s]   (1-%d isolate, 0 all)" % [who, _enemies.size()]
	print(line)
	if _hint:
		_hint.text = line
