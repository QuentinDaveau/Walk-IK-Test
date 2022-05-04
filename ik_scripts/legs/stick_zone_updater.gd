extends Resource
class_name StickZoneUpdater


var _transform: TransformData
var _stick_zone: StickZone



func _init(movement_parameters: MovementParameter, start_transform: Transform, world: World) -> void:
	_transform = TransformData.new()
	_transform.update_data(start_transform, 0.1)
	_stick_zone = StickZone.new(movement_parameters, world)
	_stick_zone.update(_transform)



func update(new_transform: Transform, delta: float) -> void:
	_transform.update_data(new_transform, delta)
	
	if _transform.has_changed():
		_stick_zone.update(_transform)



func should_unstick(target_position: Vector3, origin_offset: Vector3) -> bool:
#	var dir := _transform.current.origin.direction_to(target_position + get_forward() * origin_offset)
	var point := _transform.current.origin + Vector3.DOWN * Vector3.DOWN.dot(target_position - _transform.current.origin)
#	return !is_inside(dir)
	return point.distance_to(target_position + _transform.current.basis * origin_offset) > _stick_zone.stick_zone_dist



func get_next_stick_point(step_duration: float, current_point: Vector3, target_amplitude: float = 1.0) -> Vector3:
	var target_stick_point: Vector3
	var dist_to_reach := step_duration * _transform.velocity.value
	
#	if not _transform.is_moving():
#		target_stick_point = _transform.current.origin + Vector3.DOWN
#	else:
#		target_stick_point = _transform.current.origin + _transform.velocity.normalized * (_stick_zone.dist_covered_by_step / _stick_zone.air_ratio) + dist_to_reach
	target_stick_point = _transform.current.origin + _transform.velocity.normalized * _stick_zone.dist_covered_by_step + dist_to_reach
	# Add safe margin
	target_stick_point -= _transform.velocity.normalized * min(_stick_zone._movement_parameters._stick_zone_safe_margin, _stick_zone.stick_zone_dist * 0.5)
	

	return target_stick_point



func get_interpolation_time(progress: float = 0.0, multiplier: float = 1.0) -> float:
	return max(_stick_zone.interpolation_time * lerp(1.0, 0.0, progress), _stick_zone.MIN_INTERPOLATION_TIME) * multiplier



func is_inside(direction: Vector3) -> bool:
#	print(Vector2(5, 0).normalized().dot(Vector2(3, 7)))
#	return Vector3.DOWN.dot(direction) > cos(_stick_zone.stick_zone_angle / _stick_zone.air_ratio)
	return Vector3.DOWN.dot(direction) > cos(_stick_zone.stick_zone_angle)



func get_speed_ratio() -> float:
	return _stick_zone.speed_ratio



#func get_air_ratio() -> float:
#	return _stick_zone.air_ratio



func get_velocity() -> Vector3:
	return _transform.velocity.value



func get_speed() -> float:
	return _transform.velocity.length



func get_direction() -> Vector3:
	return _transform.velocity.normalized



func get_origin() -> Vector3:
	return _transform.current.origin



func get_forward() -> Basis:
	return _transform.current.basis



func get_ground() -> Vector3:
	return _stick_zone.ground_position



func just_started_moving() -> bool:
	return _transform.started_moving()



func just_stopped_moving() -> bool:
	return _transform.stopped_moving()



func get_dist() -> float:
	return _stick_zone.stick_zone_dist



func get_traversal_time() -> float:
	if not _transform.velocity.length:
		return 1.0
	return min(_stick_zone.stick_zone_dist * 2.0 / _transform.velocity.length, 1.0)



# N'est pas correct si le pied n'est pas au centre du cercle (le dot product simule un carré, pas un cercle)
func get_time_to_reach_edge(position: Vector3, local_offset: Vector3) -> float:
	# Capping the theorically infinite value
	if not _transform.velocity.length:
		return INF
	
	var corrected_self_pos := _stick_zone.ground_position + get_forward() * -local_offset
	DebugOverlay.draw_sphere(corrected_self_pos, 0.1, Color.red)
	var diff := position - corrected_self_pos
	
	# ratio to the edge -> 1 to 0 (1 = full duration left, 0 = no duration left)
	# dot goes from -1.0 to 1.0, we normalize it to 0.0 -> 1.0
	var forward := _transform.velocity.normalized * _stick_zone.stick_zone_dist
	var dist_ratio := ((forward.normalized().dot(diff / forward.length())) + 1.0) / 2.0
	
	
	
	DebugOverlay.draw_line(_stick_zone.ground_position, _stick_zone.ground_position + _transform.velocity.normalized * _stick_zone.stick_zone_dist, 1.0, Color.violet)
	DebugOverlay.draw_line(_stick_zone.ground_position, _stick_zone.ground_position + diff, 2.0, Color.greenyellow)
	
	if dist_ratio < 0.0:
		return 0.0
	
	# Traversing the whole stick zone takes stick_zone_dist * 2.0
	var dist_to_traverse := _stick_zone.stick_zone_dist * 2.0 * dist_ratio
	
#	print(_stick_zone.stick_zone_dist, "    ", dist_ratio, "   ", dist_to_traverse, "   ", _transform.velocity.length, "    ", dist_to_traverse / _transform.velocity.length)
	
	# maxing the value to prevent infinite or super high values
	var traversal_time := dist_to_traverse / _transform.velocity.length
	return traversal_time if traversal_time < 1.0 else INF



func get_air_ratio() -> float:
	return _stick_zone._movement_parameters.get_air_ratio(get_speed())



#func apply_air_ratio_offset(time: float) -> float:
#	var air_ratio := 
#	return time + get_traversal_time() * (_stick_zone._movement_parameters.get_air_ratio(get_speed()) - 1.0)



# Simple class to hold stick zone data
class StickZone:
	
	const MIN_ANGLE = 0.2 # in rads
	const MAX_ANGLE = 0.5 # in rads
	const MAX_SPEED = 3.0 # Speed at which we will reach the max angle
	const MIN_SPEED = 0.1
	const MIN_INTERPOLATION_TIME = 0.2
	
	var stick_zone_angle: float
	var stick_zone_dist: float
	var dist_covered_by_step: float
	var speed_ratio: float
	var air_ratio: float = 1.0
	var interpolation_time: float
	var ground_position: Vector3
	
	var _raycaster: Raycaster
	var _movement_parameters: MovementParameter
	
	
	func _init(movement_parameters: MovementParameter, world: World) -> void:
		_movement_parameters = movement_parameters
		_raycaster = Raycaster.new(world)
	
	
	# TODO: Expose raycast max length somewhere
	func update(transform_data: TransformData) -> void:
		var cast_data := _raycaster.get_collision_data(transform_data.current.origin, transform_data.current.origin + Vector3.DOWN)
		var dist_to_ground = cast_data.collision_length() if cast_data.collides() else 1.0
		
		ground_position = cast_data.collision_position() if cast_data.collides() else transform_data.current.origin + Vector3.DOWN
#		speed_ratio = clamp(inverse_lerp(0.0, MAX_SPEED, transform_data.velocity.length), 0.0, 1.0)
		
		speed_ratio = _movement_parameters.get_speed_ratio(transform_data.velocity.length)
		
		# We only want to change the stick_zone_angle and air_ratio once we are above a min speed
#		var limited_speed_ratio := clamp(inverse_lerp(MIN_SPEED, MAX_SPEED, transform_data.velocity.length), 0.0, 1.0)
		
#		stick_zone_angle = lerp(MIN_ANGLE, MAX_ANGLE, limited_speed_ratio)
		stick_zone_angle = _movement_parameters.get_angle(transform_data.velocity.length)
		
#		print(stick_zone_angle)
		
		
		# At MIN_SPEED: always one feet on ground (1.0), at max speed -> running: a feet is on ground only a small part of the time of the whole run cycle
#		air_ratio = lerp(1.0, 1.7, limited_speed_ratio)
		air_ratio = _movement_parameters.get_air_ratio(transform_data.velocity.length)
		
		
		stick_zone_dist = dist_to_ground * tan(stick_zone_angle)
		dist_covered_by_step = dist_to_ground * tan(stick_zone_angle)
		
		if transform_data.velocity.length == 0.0:
			interpolation_time = 0.0
		else:
			interpolation_time = pow(air_ratio, 2.0) * 2.0 * (dist_covered_by_step / transform_data.velocity.length)
		
		# Debug
		DebugOverlay.draw_line(transform_data.current.origin, ground_position, 1.0, Color.green if cast_data.collides() else Color.red)
#		DebugOverlay.draw_sphere(ground_position, stick_zone_dist, Color.orange)



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
	
	
	func stopped_moving() -> bool:
		return velocity.length == 0.0 and previous_velocity.length != 0.0




# Simple velocity struct to not have to recompute its length every time
class VelocityData:
	
	var value: Vector3
	var length: float
	var normalized: Vector3
	
	
	func set_value(new_velocity: Vector3) -> void:
		value = new_velocity
		length = value.length()
		normalized = value.normalized()

