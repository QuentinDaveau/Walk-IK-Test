extends Spatial

enum TARGET_SIDE {LEFT, RIGHT}

const MIN_ANGLE = 0.4 # in rads
const MAX_ANGLE = 0.45 # in rads

const MAX_SPEED = 4.0 # Speed at which we will reach the min angle
const MIN_SPEED = 2.0



var _previous_pos: Vector3
var _velocity: Vector3
var _stick_zone_angle: float
var _interpolation_time: float
var _dist_to_ground: float
var _stick_zone_dist: float
var _dist_covered_by_step : float
var _air_ratio: float = 1.0





func _physics_process(delta: float) -> void:
	_velocity = _get_velocity(delta)
	_update_stick_zone_angle()
	_update_interpolation_time()
	$MeshInstance.global_transform.origin = get_next_stick_point()
	$MeshInstance2.global_transform.origin = $RayCast.get_collision_point()
	$MeshInstance2.mesh.mid_height = _dist_covered_by_step * 2.0 - 0.2



func should_unstick(position: Vector3) -> bool:
	var dir := (position - global_transform.origin).normalized()
	return !_is_in_stick_zone(dir) and _velocity.normalized().dot(dir) < 0.1



func get_next_stick_point(extra_multiplier: float = 0.0) -> Vector3:
	if _velocity.length_squared() == 0.0:
		return global_transform.origin + Vector3.DOWN
	var dist_to_reach := _interpolation_time * _velocity
	return global_transform.origin + _velocity.normalized() * (_dist_covered_by_step / _air_ratio) + dist_to_reach * (1.0 + extra_multiplier)



func get_interpolation_time(progress: float = 0.0) -> float:
	return _interpolation_time * (1.0 - progress)



func get_speed_ratio() -> float:
	return clamp(_velocity.length() / MAX_SPEED, 0.0, 1.0)



func get_velocity() -> Vector3:
	return _velocity



func _is_in_stick_zone(direction: Vector3) -> bool:
	return Vector3.DOWN.dot(direction) > cos(_stick_zone_angle / _air_ratio)



func _update_stick_zone_angle() -> void:
	var velocity_length := _velocity.length()
	var speed_ratio := clamp((velocity_length - MIN_SPEED) / MAX_SPEED, 0.0, 1.0)
	_dist_to_ground = (global_transform.origin - $RayCast.get_collision_point()).length() if $RayCast.is_colliding() else 1.0
	_stick_zone_angle = lerp(MIN_ANGLE, MAX_ANGLE, speed_ratio)
	# At min speed -> always one foot on ground (ratio of 1), At max speed -> no foot on floor (ratio of 2.0, we take twice as much time)
	_air_ratio = lerp(1.0, 2.0, speed_ratio)
	
	# Distance covered by feet on ground
	_stick_zone_dist = _dist_to_ground * tan(_stick_zone_angle) / _air_ratio
	
	# Distance covered for each step (on ground + in air)
	_dist_covered_by_step = _dist_to_ground * tan(_stick_zone_angle)



func _update_interpolation_time() -> void:
	var velocity_length := _velocity.length()
	if velocity_length == 0.0:
		_interpolation_time = 0.0
		return
	
	_interpolation_time = pow(_air_ratio, 2.0) * 2.0 * (_dist_covered_by_step / velocity_length)



func _get_velocity(delta: float) -> Vector3:
	var velocity := (global_transform.origin - _previous_pos) / delta
	_previous_pos = global_transform.origin
	return velocity
