extends Spatial

enum TARGET_SIDE {LEFT, RIGHT}

const MIN_ANGLE = 0.1
const MAX_ANGLE = 0.3
const MAX_SPEED = 5.0
const MIN_SPEED = 0.5
const MIN_POS = 0.2

const LEG_LENGTH = 1.0


var _previous_pos: Vector3
var _velocity: Vector3
var _stick_zone_cos: float
var _interpolation_time: float





func _physics_process(delta: float) -> void:
	_velocity = _get_velocity(delta)
	_update_stick_zone()
	_update_interpolation_time()
	$MeshInstance.global_transform.origin = get_next_stick_point()




func should_unstick(position: Vector3) -> bool:
	var dir := (position - global_transform.origin).normalized()
	return !_is_in_stick_zone(dir) and _velocity.normalized().dot(dir) > 0.0



func get_next_stick_point() -> Vector3:
	if _velocity.length_squared() == 0.0:
		return global_transform.origin + Vector3.DOWN
	return global_transform.origin + (Vector3.DOWN.rotated(Vector3.UP.cross(_velocity.normalized()), asin(_stick_zone_cos)) * LEG_LENGTH)



func get_interpolation_time(progress: float = 0.0) -> float:
	return _interpolation_time



func get_speed_ratio() -> float:
	return clamp(_velocity.length() / MAX_SPEED, 0.0, 1.0)



func _is_in_stick_zone(direction: Vector3) -> bool:
#	print(String(direction) + "    " + String(_stick_zone_cos) + "    " + String(Vector3.DOWN.dot(direction)) + "   " + String(Vector3.DOWN.dot(direction) > _stick_zone_cos) + "    " + String(_velocity.length()))
	return Vector3.DOWN.dot(direction) > _stick_zone_cos



func _update_stick_zone() -> void:
#	print(clamp(lerp(MAX_ANGLE, MIN_ANGLE, _velocity.length() / MAX_SPEED), MIN_ANGLE, MAX_ANGLE))
	_stick_zone_cos = 1.0 - clamp(lerp(MAX_ANGLE, MIN_ANGLE, _velocity.length() / MAX_SPEED), MIN_ANGLE, MAX_ANGLE)



func _update_interpolation_time() -> void:
	var velocity_length := _velocity.length()
	if velocity_length == 0.0:
		_interpolation_time = 0.0
		return
	
	var speed_ratio := clamp(velocity_length / MAX_SPEED, 0.0, 1.0)
	# At min speed -> always one foot on ground (ratio of 1), At max speed -> no foot on floor
	var on_ground_ratio: float = lerp(1.0, 0.0, speed_ratio)
	var supposed_covered_distance = lerp(MAX_ANGLE, MIN_ANGLE, speed_ratio) * 2.0 * LEG_LENGTH
	_interpolation_time = (2.0 * supposed_covered_distance / velocity_length) * (1.0 - on_ground_ratio)
	print(String(2.0 * supposed_covered_distance) + "   " + String(velocity_length) + "    " + String(1.0 - on_ground_ratio))



func _get_velocity(delta: float) -> Vector3:
	var velocity := (global_transform.origin - _previous_pos) / delta
	_previous_pos = global_transform.origin
	return -velocity
