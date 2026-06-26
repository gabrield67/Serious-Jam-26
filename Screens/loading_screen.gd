class_name LoadingScreen
extends Control

## Lightweight scene that streams a heavy scene (the world) in on a background
## thread and shows progress, instead of instantiating it in one blocked frame.
##
## Usage: set LoadingScreen.target_path (defaults to the world), then
## get_tree().change_scene_to_file("res://Screens/LoadingScreen.tscn").

## Scene to load in the background. Static so the caller can set it before the
## scene switch; survives the change because it lives on the script, not an instance.
static var target_path: String = "res://scenes/map.tscn"

@onready var _bar: ProgressBar = $Center/VBox/Bar
@onready var _label: Label = $Center/VBox/Label

var _path: String
var _progress: Array = []

func _ready() -> void:
	_path = target_path
	# use_sub_threads=true lets dependencies (textures/meshes) load across the
	# worker pool on threaded web builds; it's a harmless no-op single-threaded.
	var err := ResourceLoader.load_threaded_request(
		_path, "PackedScene", true, ResourceLoader.CACHE_MODE_REUSE)
	if err != OK:
		push_error("LoadingScreen: could not start threaded load of %s (err %d); blocking load." % [_path, err])
		get_tree().change_scene_to_file(_path)

func _process(_delta: float) -> void:
	var status := ResourceLoader.load_threaded_get_status(_path, _progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			var pct := 0.0
			if _progress.size() > 0:
				pct = float(_progress[0]) * 100.0
			_bar.value = pct
			_label.text = "Loading... %d%%" % int(pct)
		ResourceLoader.THREAD_LOAD_LOADED:
			set_process(false)
			_bar.value = 100.0
			_label.text = "Loading... 100%"
			var packed: PackedScene = ResourceLoader.load_threaded_get(_path)
			get_tree().change_scene_to_packed(packed)
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			set_process(false)
			push_error("LoadingScreen: failed to load %s (status %d); blocking load." % [_path, status])
			get_tree().change_scene_to_file(_path)
