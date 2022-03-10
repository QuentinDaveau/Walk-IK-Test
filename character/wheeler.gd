extends Spatial

const MIN_SIZE = 0.1
const MAX_SIZE = 0.2
const MIN_STRETCH = 0.3
const MAX_STRETCH = 0.5
const MAX_SPEED = 2.5
const MIN_SPEED = 0.5
const MIN_POS = 0.1

onready var right_target := $Debug/RightTarget
onready var left_target := $Debug/LeftTarget


var _previous_pos: Vector3
var _wheel_rotation: float
var _wheel_axis: Vector3 = Vector3.RIGHT
var _wheel_size: float = 1.0
var _wheel_stretch: float = 1.0
var _wheel_position: float = 0.0

var _hit_dist: float

var _wheel_transform: Transform = Transform()


func _physics_process(delta: float) -> void:
	_hit_dist = ($RayCast.get_collision_point() - $RayCast.global_transform.origin).length()
	
	var velocity := get_velocity(delta)
	_update_wheel_size(velocity, delta)
	_update_wheel_rotation(velocity, delta)
	$Debug.transform = _wheel_transform



func _update_wheel_size(velocity: Vector3, delta: float) -> void:
	var speed_ratio := (velocity.length() / MAX_SPEED) - MIN_SPEED
	
	_wheel_size = lerp(MIN_SIZE, MAX_SIZE, speed_ratio)
	_wheel_stretch = lerp(MIN_STRETCH, MAX_STRETCH, speed_ratio)
	_wheel_position = _hit_dist - lerp(0.0, MIN_POS, speed_ratio)
	
	_wheel_transform.origin = Vector3.DOWN * _wheel_position




func _update_wheel_rotation(velocity: Vector3, delta: float) -> void:
	if velocity.length_squared() == 0.0:
		return
	
	_wheel_axis = velocity.normalized().cross(Vector3.UP)
	
	var angular_velocity := delta * velocity / (PI * _wheel_stretch * 0.25)
	_wheel_rotation += angular_velocity.length()
	var new_basis := Basis(Vector3.UP, Vector3.FORWARD.signed_angle_to(velocity.normalized(), Vector3.UP))
	new_basis = new_basis.rotated(_wheel_axis.normalized(), _wheel_rotation)
	new_basis = new_basis.scaled(Vector3(_wheel_stretch, _wheel_size, _wheel_stretch))
	_wheel_transform.basis = new_basis



func get_velocity(delta: float) -> Vector3:
	var velocity := (global_transform.origin - _previous_pos) / delta
	_previous_pos = global_transform.origin
	return -velocity
