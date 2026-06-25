extends Enemy
## Plane NPC — circles the tornado at altitude, banking into the turn. It carries a
## world-space dust trail (a child DustTrail particle node) that lingers behind it.

@export_group("Flight")
@export var orbit_radius: float = 15.0
@export var altitude: float = 16.0
## How fast it circles the tornado (deg/sec).
@export var orbit_speed: float = 55.0
@export var move_lerp: float = 3.0
## Degrees of roll into the turn (flip the sign if it banks the wrong way).
@export var bank_angle: float = 22.0
## Yaw correction if the model's nose faces the wrong way.
@export var facing_offset: float = PI

var _target: Node3D
var _angle: float = 0.0

func _ready() -> void:
	_angle = randf() * TAU

func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("tornado")
		if _target == null:
			return

	_angle += deg_to_rad(orbit_speed) * delta
	var c := _target.global_position
	var desired := c + Vector3(cos(_angle) * orbit_radius, altitude, sin(_angle) * orbit_radius)
	global_position = global_position.lerp(desired, clampf(move_lerp * delta, 0.0, 1.0))

	# Face the direction of travel (tangent of the circle) and bank into the turn.
	var tangent := Vector3(-sin(_angle), 0.0, cos(_angle))
	var r := rotation
	r.y = atan2(tangent.x, tangent.z) + facing_offset
	r.z = deg_to_rad(-bank_angle)
	rotation = r
