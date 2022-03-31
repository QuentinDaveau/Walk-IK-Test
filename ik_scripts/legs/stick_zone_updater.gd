extends Resource
class_name StickZoneUpdater


var _transform: TransformData
var _stick_zone: StickZone



func _init(world: World) -> void:
	_transform = TransformData.new()
	_stick_zone = StickZone.new(world)



func update(new_transform: Transform, delta: float) -> void:
	_transform.update_data(new_transform, delta)
	
	if _transform.has_changed():
		_stick_zone.update(_transform)



func should_unstick(target_position: Vector3) -> bool:
	var dir := _transform.current.origin.direction_to(target_position)
	return !is_inside(dir) and _transform.velocity.normalized.dot(dir) < 0.0



func get_next_stick_point(extra_multiplier: float = 0.0) -> Vector3:
	if not _transform.is_moving():
		return _transform.current.origin + Vector3.DOWN
	var dist_to_reach := _stick_zone.interpolation_time * _transform.velocity.value * (1.0 + extra_multiplier)
	return _transform.current.origin + _transform.velocity.normalized * (_stick_zone.dist_covered_by_step / _stick_zone.air_ratio) + dist_to_reach



func get_interpolation_time(progress: float = 0.0) -> float:
	return _stick_zone.interpolation_time * lerp(1.0, 0.0, progress)



func is_inside(direction: Vector3) -> bool:
	return Vector3.DOWN.dot(direction) > cos(_stick_zone.stick_zone_angle / _stick_zone.air_ratio)



func get_speed_ratio() -> float:
	return _stick_zone.speed_ratio



func get_velocity() -> Vector3:
	return _transform.velocity.value



func just_started_moving() -> bool:
	return _transform.started_moving()




# Simple class to hold stick zone data
class StickZone:
	
	const MIN_ANGLE = 0.4 # in rads
	const MAX_ANGLE = 0.45 # in rads
	const MAX_SPEED = 4.0 # Speed at which we will reach the min angle
	const MIN_SPEED = 2.0
	
	var stick_zone_angle: float
	var stick_zone_dist: float
	var dist_covered_by_step: float
	var speed_ratio: float
	var air_ratio: float
	var interpolation_time: float
	
	var _raycaster: Raycaster
	
	
	func _init(world: World) -> void:
		_raycaster = Raycaster.new(world)
	
	
	# TODO: Expose raycast max length somewhere
	func update(transform_data: TransformData) -> void:
		var cast_data := _raycaster.get_collision_data(transform_data.current.origin, transform_data.current.origin + Vector3.DOWN)
		var dist_to_ground = cast_data.collision_length() if cast_data.collides() else 1.0
		
		speed_ratio = inverse_lerp(0.0, MAX_SPEED, transform_data.velocity.length - MIN_SPEED)
		stick_zone_angle = lerp(MIN_ANGLE, MAX_ANGLE, speed_ratio)
		air_ratio = lerp(1.0, 2.0, speed_ratio)
		stick_zone_dist = dist_to_ground * tan(stick_zone_angle) / air_ratio
		dist_covered_by_step = dist_to_ground * tan(stick_zone_angle)
		
		if transform_data.velocity.length == 0.0:
			interpolation_time = 0.0
		else:
			interpolation_time = pow(air_ratio, 2.0) * 2.0 * (dist_covered_by_step / transform_data.velocity.length)




# Simple container to hold current transform, previous one, velocity...
class TransformData:
	
	var current: Transform
	var previous: Transform
	var velocity: VelocityData
	var previous_velocity: VelocityData
	
	
	func _init() -> void:
		velocity = VelocityData.new()
		previous_velocity = VelocityData.new()
	
	
	func update_data(current_position: Transform, delta: float) -> void:
		previous = current
		current = current_position
		previous_velocity.set_value(velocity.value)
		velocity.set_value((current.origin - previous.origin) / delta)
	
	
	func is_moving() -> bool:
		return velocity.length != 0.0
	
	
	func has_changed() -> bool:
		return current.origin != previous.origin
	
	
	func started_moving() -> bool:
		return velocity.length != 0.0 and previous_velocity.length == 0.0




# Simple velocity struct to not have to recompute its length every time
class VelocityData:
	
	var value: Vector3
	var length: float
	var normalized: Vector3
	
	
	func set_value(new_velocity: Vector3) -> void:
		value = new_velocity
		length = value.length()
		normalized = value.normalized()

