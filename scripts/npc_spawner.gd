extends Node
## Threat-budget enemy director. Difficulty scales with the tornado's Fujita level (plus a gentle
## time ramp), and the director keeps the combined threat_cost of all living enemies near a target
## budget. It picks weighted-random among the types unlocked at the current level (with a small
## anti-repeat nudge), and places them off-screen — trucks on roads, flyers on an altitude ring,
## ground units on the ground ring. A hard cap bounds the concurrent count for web performance.

@export var enabled: bool = true
## Enemy scenes the director can spawn (their threat_cost / spawn_min_level / spawn_weight are
## read from each scene at startup).
@export var npc_scenes: Array[PackedScene] = []

@export_group("Budget")
## Threat budget at F0.
@export var base_budget: float = 2.0
## Extra budget per Fujita level above F0.
@export var budget_per_level: float = 2.0
## Extra budget per minute elapsed (slow background ramp).
@export var budget_per_minute: float = 1.0
## Never have more than this many enemies alive at once (perf ceiling).
@export var hard_cap: int = 10

@export_group("Pacing")
## Seconds between spawn checks.
@export var check_interval: float = 1.0
## Wait this long before the first spawn (lets roads / scene settle).
@export var start_delay: float = 2.0
## Intensity breathes: the live budget swings +/- this fraction around the target.
@export var breath_amount: float = 0.25
## Seconds for one full build-up -> lull cycle.
@export var breath_period: float = 20.0

@export_group("Placement")
## Ring distance from the tornado to spawn at (out past the camera frame).
@export var spawn_radius: float = 220.0
## Extra height for flyers, added to the tornado's height.
@export var spawn_altitude: float = 40.0

var _t: float = 0.0
var _elapsed: float = 0.0
var _defs: Array = []          # cached [{scene, cost, min_level, weight, flyer}]
var _active: Array = []        # [{node, cost}]
var _last_scene: PackedScene = null

func _ready() -> void:
	_t = start_delay
	_cache_defs()

## Instantiate each scene once (not added to the tree, so no _ready side effects) to read its
## spawn metadata, then free it. Avoids re-reading per spawn.
func _cache_defs() -> void:
	for scene in npc_scenes:
		if scene == null:
			continue
		var probe := scene.instantiate()
		_defs.append({
			"scene": scene,
			"cost": float(probe.get("threat_cost")) if "threat_cost" in probe else 1.0,
			"min_level": int(probe.get("spawn_min_level")) if "spawn_min_level" in probe else 0,
			"weight": float(probe.get("spawn_weight")) if "spawn_weight" in probe else 1.0,
			"flyer": "altitude" in probe,  # flyers expose an `altitude` export
		})
		probe.free()

func _process(delta: float) -> void:
	if not enabled or _defs.is_empty():
		return
	_elapsed += delta
	_active = _active.filter(func(e): return is_instance_valid(e["node"]))
	_t -= delta
	if _t > 0.0:
		return
	_t = check_interval
	_try_spawn()

func _try_spawn() -> void:
	if _active.size() >= hard_cap:
		return
	if _active_threat() >= _current_budget():
		return
	var torn := get_tree().get_first_node_in_group("tornado")
	if torn == null:
		return
	var def: Dictionary = _pick_def()
	if def.is_empty():
		return
	var inst := (def["scene"] as PackedScene).instantiate()
	get_tree().current_scene.add_child(inst)
	_place(inst, def, torn as Node3D)
	_active.append({"node": inst, "cost": def["cost"]})
	_last_scene = def["scene"]

## Target budget for right now: base + Fujita + time, breathing in and out for rhythm.
func _current_budget() -> float:
	var target := base_budget + _fujita_level() * budget_per_level + (_elapsed / 60.0) * budget_per_minute
	var breath := 1.0 + breath_amount * sin(_elapsed / maxf(breath_period, 0.001) * TAU)
	return target * breath

func _active_threat() -> float:
	var s := 0.0
	for e in _active:
		s += e["cost"]
	return s

## Weighted-random pick among types unlocked at the current level, lightly avoiding a repeat.
## Returns an empty Dictionary when nothing is eligible.
func _pick_def() -> Dictionary:
	var lvl := _fujita_level()
	var pool: Array = []
	var total := 0.0
	for d in _defs:
		if d["min_level"] > lvl:
			continue
		var w: float = d["weight"]
		if d["scene"] == _last_scene:
			w *= 0.4  # anti-repeat: don't spam the same type
		if w <= 0.0:
			continue
		pool.append({"def": d, "w": w})
		total += w
	if pool.is_empty() or total <= 0.0:
		return {}
	var r := randf() * total
	for p in pool:
		r -= p["w"]
		if r <= 0.0:
			return p["def"]
	return pool[pool.size() - 1]["def"]

## Trucks claim a road; flyers spawn on an off-screen altitude ring; everything else on the
## off-screen ground ring — so they fly/drive into frame rather than popping in on camera.
func _place(inst: Node, def: Dictionary, torn: Node3D) -> void:
	if inst.has_method("place_on_road") and inst.place_on_road():
		return
	if not (inst is Node3D):
		return
	(inst as Node3D).global_position = _offscreen_point(torn, def["flyer"])

## A point on the ring (at flyer altitude if needed) that is NOT in the camera's view. Samples
## random angles and keeps the first off-screen one; falls back to the camera's side of the
## tornado (reliably behind the frame) if every sample happened to be visible.
func _offscreen_point(torn: Node3D, flyer: bool) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	var y := torn.global_position.y + (spawn_altitude if flyer else 0.0)
	var ang := randf() * TAU
	for i in 12:
		ang = randf() * TAU
		var p := torn.global_position + Vector3(cos(ang), 0.0, sin(ang)) * spawn_radius
		p.y = y
		if cam == null or not cam.is_position_in_frustum(p):
			return p
	# Fallback: the tornado's camera-facing side sits beyond/behind the camera — out of frame.
	if cam:
		var to_cam := cam.global_position - torn.global_position
		if Vector2(to_cam.x, to_cam.z).length() > 0.001:
			ang = atan2(to_cam.z, to_cam.x)
	var out := torn.global_position + Vector3(cos(ang), 0.0, sin(ang)) * spawn_radius
	out.y = y
	return out

func _fujita_level() -> int:
	var t := get_tree().get_first_node_in_group("tornado")
	if t and t.has_method("get_level"):
		return t.get_level()
	return 0
