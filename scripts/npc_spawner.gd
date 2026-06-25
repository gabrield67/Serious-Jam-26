extends Node
## Spawns NPC enemies over time. A truck (anything with place_on_road) is dropped onto a road
## lane; everything else spawns on a ring around the tornado and flies/drives in on its own.

@export var enabled: bool = true
## NPC scenes to spawn from (picked at random).
@export var npc_scenes: Array[PackedScene] = []
## Seconds between spawns.
@export var interval: float = 5.0
## Don't spawn while this many NPCs are already alive.
@export var max_active: int = 6
## Ring distance from the tornado for non-road NPCs.
@export var spawn_radius: float = 220.0
## Wait this long before the first spawn (lets the roads finish building).
@export var start_delay: float = 2.0

var _t: float = 0.0
var _active: Array = []

func _ready() -> void:
	_t = start_delay

func _process(delta: float) -> void:
	if not enabled or npc_scenes.is_empty():
		return
	_active = _active.filter(func(n): return is_instance_valid(n))
	if _active.size() >= max_active:
		return
	_t -= delta
	if _t <= 0.0:
		_t = interval
		_spawn()

func _spawn() -> void:
	var scene: PackedScene = npc_scenes.pick_random()
	if scene == null:
		return
	var inst := scene.instantiate()
	get_tree().current_scene.add_child(inst)
	_active.append(inst)
	# Trucks place themselves on a road; others spawn on a ring around the tornado.
	if inst.has_method("place_on_road") and inst.place_on_road():
		return
	if inst is Node3D:
		(inst as Node3D).global_position = _ring_point()

func _ring_point() -> Vector3:
	var torn := get_tree().get_first_node_in_group("tornado")
	var c: Vector3 = torn.global_position if torn else Vector3.ZERO
	var a := randf() * TAU
	return c + Vector3(cos(a), 0.0, sin(a)) * spawn_radius
