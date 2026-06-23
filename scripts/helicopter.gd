extends Node3D
## Spins the helicopter rotors.

@export var main_rotor_path: NodePath = "Rotor_002"
@export var tail_rotor_path: NodePath = "Rotor_Back_004"
## Degrees per second.
@export var main_speed: float = 1600.0
@export var tail_speed: float = 2200.0

@onready var _main: Node3D = get_node_or_null(main_rotor_path)
@onready var _tail: Node3D = get_node_or_null(tail_rotor_path)

func _process(delta: float) -> void:
	if _main:
		_main.rotate_y(deg_to_rad(main_speed) * delta)
	if _tail:
		_tail.rotate_x(deg_to_rad(tail_speed) * delta)
