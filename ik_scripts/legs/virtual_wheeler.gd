extends Spatial

enum TARGET_SIDE {LEFT, RIGHT}

const MIN_SIZE = 0.0
const MAX_SIZE = 0.2
const MIN_STRETCH = 0.3
const MAX_STRETCH = 0.5
const MAX_SPEED = 2.5
const MIN_SPEED = 0.5
const MIN_POS = 0.2

var _previous_pos: Vector3
var _wheel_rotation: float
var _wheel_axis: Vector3 = Vector3.RIGHT
var _wheel_size: float = 1.0
var _wheel_stretch: float = 1.0
var _wheel_position: float = 0.0
var _wheel_main_target: Vector3
var _velocity: Vector3




func _physics_process(delta: float) -> void:
	_velocity = get_velocity(delta)
	_update_wheel_size(_velocity, delta)
	_update_wheel_rotation(_velocity, delta)



func get_target(side: int) -> Vector3:
	return (global_transform.origin + Vector3.DOWN * _wheel_position + _wheel_main_target.rotated(Vector3.UP, _velocity.angle_to(Vector3.FORWARD))) * (1.0 if side == TARGET_SIDE.RIGHT else -1.0)



func 



func _update_wheel_size(velocity: Vector3, delta: float) -> void:
	var speed_ratio := (velocity.length() / MAX_SPEED) - MIN_SPEED
	
	_wheel_size = lerp(MIN_SIZE, MAX_SIZE, speed_ratio)
	_wheel_stretch = lerp(MIN_STRETCH, MAX_STRETCH, speed_ratio)
	_wheel_position = 1.0 - lerp(0.0, MIN_POS, speed_ratio)



func _update_wheel_rotation(velocity: Vector3, delta: float) -> void:
	if velocity.length_squared() == 0.0:
		return
	
	_wheel_axis = velocity.normalized().cross(Vector3.UP)
	
	var angular_velocity := delta * velocity / (PI * _wheel_stretch * 0.25)
	_wheel_rotation += angular_velocity.length()
	
	_wheel_main_target = Vector3(cos(_wheel_rotation), sin(_wheel_rotation), 0.0)


func get_velocity(delta: float) -> Vector3:
	var velocity := (global_transform.origin - _previous_pos) / delta
	_previous_pos = global_transform.origin
	return -velocity
