extends Node3D
## Test helper: each number key 1..N spawns a fresh copy of that enemy type — press the same
## key repeatedly to stack up several (e.g. press "plane" twice for two planes). Press 0 to
## clear everything spawned. The Node3D children are used as hidden prototypes (one per type,
## in child order) so spawns match exactly how they're set up in this scene.

## Which enemy to spawn once on start (1-based, in child order). 0 = start empty.
@export var active: int = 1
## Optional Label to show the controls / spawn count on-screen.
@export var hint_label_path: NodePath
## Random horizontal spread so repeated spawns don't stack exactly on top of each other.
@export var spawn_spread: float = 8.0

var _templates: Array[Node3D] = []
var _spawned: Array[Node3D] = []
var _hint: Label

func _ready() -> void:
	for c in get_children():
		if c is Node3D:
			_templates.append(c as Node3D)
			_disable_template(c as Node3D)
	if hint_label_path != NodePath():
		_hint = get_node_or_null(hint_label_path) as Label
	if active >= 1 and active <= _templates.size():
		_spawn(active - 1)
	_update_hint()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = (event as InputEventKey).keycode
		if k == KEY_0:
			_clear()
		elif k >= KEY_1 and k <= KEY_9:
			var idx := k - KEY_1
			if idx < _templates.size():
				_spawn(idx)

## Hide a prototype and stop it running so it only serves as a template to copy.
func _disable_template(e: Node3D) -> void:
	e.visible = false
	e.set_process(false)
	e.set_physics_process(false)
	e.remove_from_group("enemy")
	e.remove_from_group("targetable")

## Spawn a fresh, active copy of the prototype at `index`.
func _spawn(index: int) -> void:
	var t := _templates[index]
	var inst := t.duplicate() as Node3D
	# Same parent as the prototype, so its local transform places it identically (plus a jitter).
	var off := Vector3(randf_range(-spawn_spread, spawn_spread), 0.0, randf_range(-spawn_spread, spawn_spread))
	inst.position = t.position + off
	inst.visible = true
	add_child(inst)
	inst.set_process(true)
	inst.set_physics_process(true)
	if not inst.is_in_group("enemy"):
		inst.add_to_group("enemy")
	if not inst.is_in_group("targetable"):
		inst.add_to_group("targetable")
	_spawned.append(inst)
	_update_hint()

## Remove every spawned enemy (the prototypes stay).
func _clear() -> void:
	for e in _spawned:
		if is_instance_valid(e):
			e.queue_free()
	_spawned.clear()
	_update_hint()

func _update_hint() -> void:
	_spawned = _spawned.filter(func(e): return is_instance_valid(e))
	var keys := ""
	for i in _templates.size():
		keys += "%d:%s  " % [i + 1, _templates[i].name]
	var line := "Spawn  %s  (0 clear)   on screen: %d" % [keys, _spawned.size()]
	print(line)
	if _hint:
		_hint.text = line
