extends Spatial
class_name ProceduralWalkAnimator


"""
Quick and dirty class to test the IK with the legs without the use of animations
"""

export(NodePath) var _ik_system_right_path
export(NodePath) var _ik_system_left_path
export(float) var _legs_spacing := 0.1
export(Resource) var _movement_parameters: Resource

onready var _ik_target_right: SkeletonIK = get_node(_ik_system_right_path)
onready var _ik_target_left: SkeletonIK = get_node(_ik_system_left_path)

var _stick_zone_updater: StickZoneUpdater
var _right_leg: LegIkAnimator
var _left_leg: LegIkAnimator





func _ready() -> void:
	_stick_zone_updater = StickZoneUpdater.new(_movement_parameters, global_transform, get_world())
	_right_leg = LegIkAnimator.new(_ik_target_right, _stick_zone_updater, Vector3.RIGHT * _legs_spacing, get_world())
	_left_leg = LegIkAnimator.new(_ik_target_left, _stick_zone_updater, Vector3.LEFT * _legs_spacing, get_world())
	
	_right_leg.set_other_leg(_left_leg)
	_left_leg.set_other_leg(_right_leg)



func _physics_process(delta: float) -> void:
	_stick_zone_updater.update(global_transform, delta)
	
	# 0 = right, 1 = left
	var force_update := [LegIkAnimator.ForceState.None, LegIkAnimator.ForceState.None]
	
	# If we just started to move, we need to force-update one of the two legs (the one most behind the direction
	if _stick_zone_updater.just_started_moving():
		var forward := _stick_zone_updater.get_direction()
		if forward.dot(_right_leg.get_feet_offset()) < forward.dot(_left_leg.get_feet_offset()):
			force_update[0] = LegIkAnimator.ForceState.Full
		else:
			force_update[1] = LegIkAnimator.ForceState.Full
#
#	# If we just stopped moving, we reset the legs position starting from the furthest one
#	if _stick_zone_updater.just_stopped_moving():
#		force_update[0] = LegIkAnimator.ForceState.Full
#		force_update[1] = LegIkAnimator.ForceState.Full
#	else:
#		# Force update if velocity changed too much (either in length or direction)
#		if _right_leg.should_refresh_from_velocity():
#			force_update[0] = LegIkAnimator.ForceState.Short
#		if _left_leg.should_refresh_from_velocity():
#			force_update[1] = LegIkAnimator.ForceState.Short
#
#		# If we force update both legs, one needs to be a long update (the least progressed one)
#		if force_update[0] and force_update[1]:
#			if _right_leg.get_progress_ratio() < _left_leg.get_progress_ratio():
#				force_update[0] = LegIkAnimator.ForceState.Full
#			else:
#				force_update[1] = LegIkAnimator.ForceState.Full
	
	# Unstick if necessary
#	if force_update[0] or _right_leg.should_unstick():
#		_right_leg.unstick(force_update[0])
#
#	if force_update[1] or _left_leg.should_unstick():
#		_left_leg.unstick(force_update[1])
	
	if _right_leg._state == LegIkAnimator.LegState.Moving:
		_right_leg.update(delta, global_transform.basis)
		_left_leg.update(delta, global_transform.basis)
	else:
		_left_leg.update(delta, global_transform.basis)
		_right_leg.update(delta, global_transform.basis)





class LegIkAnimator:
	
	enum LegState {Stick, Moving}
	enum ForceState {None, Full, Short}
	
	var _caster: Raycaster
	var _ik_target: SkeletonIK
	var _stick_zone: StickZoneUpdater
	var _other: LegIkAnimator
	var _position_offset: Vector3
	
	var _state: int = LegState.Moving
	var _starting_point: Vector3
	var _end_point: Vector3
	var _height_diff_ratio: float
	
	var _progress_ratio: float
	var _movement_time: float
	var _initial_movement_time: float
	var _full_movement_ratio: float = 1.0
	var _movement_corresponding_velocity: Vector3
	
	
	func _init(ik_target: SkeletonIK, stick_zone: StickZoneUpdater, position_offset: Vector3, world: World) -> void:
		_ik_target = ik_target
		_ik_target.start()
		_stick_zone = stick_zone
		_position_offset = position_offset
		_caster = Raycaster.new(world)
	
	
	
	func set_other_leg(other: LegIkAnimator) -> void:
		_other = other
	
	
	
	func update(delta: float, body_forward: Basis) -> void:
		DebugOverlay.draw_sphere(_end_point, 0.1, Color.blue if _state == LegState.Moving else Color.gray)
		
		match _state:
			LegState.Stick:
				DebugOverlay.draw_sphere(_stick_zone.get_ground() + _stick_zone.get_forward() * -_position_offset, _stick_zone.get_dist(), Color.orange)
				if should_unstick():
					unstick()
			LegState.Moving:
				# Very messy
#				_progress_ratio = min(_progress_ratio + (delta * 1.1 * max(1.0 / max(_initial_movement_time, 0.1), max(_initial_movement_time / max(_movement_time * _progress_ratio, 1.0), 1.0))), 1.0)
#				_progress_ratio = min(_progress_ratio + (delta * 1.0 * max(1.0 / max(_initial_movement_time, 0.1), max(_initial_movement_time / max(_movement_time * _progress_ratio, 1.0), 1.0))), 1.0)
#				_progress_ratio = _progress_ratio + (delta * max(1.0 / max(_initial_movement_time, 0.05), _movement_time * (1.0 - _progress_ratio)))
				
				_compute_movement()
				
				
				
				
#				if _initial_movement_time * (1.0 - _progress_ratio) < _movement_time:
#					# IMPORTANT: The glitch comes from here:
#					# the target point has an offset to anticipate the movement velocity,
#					# offset calculated using the _movement_time, and not the _initial_movement_time.
#					# So if we use the _initial_movement_time, we reach the point too fast, and since it has
#					# an offset, we are out of the stick zone
#					_progress_ratio += delta / max(_initial_movement_time, 0.01)
#				else:
				_progress_ratio += delta * (1.0 - _progress_ratio) / max(_movement_time, 0.01)
				
				_update_movement(body_forward)
				
				if _progress_ratio >= 0.99:
					_state = LegState.Stick
					_progress_ratio = 0.0
					_movement_time = 0.0
					_initial_movement_time = 0.0
#				print(_progress_ratio, "     ", _movement_time, "    ", _initial_movement_time)
				
#				print(_progress_ratio, "    ", 1.0 / max(_initial_movement_time, 0.1), "    ", _movement_time * (1.0 - _progress_ratio), "     ", 1.0 / max(_initial_movement_time, 0.1) > _movement_time * (1.0 - _progress_ratio))
				
	
	
	
	func unstick(forced: int = ForceState.None) -> void:
		_compute_movement(true)
		_progress_ratio = 0.0
		_state = LegState.Moving
	
	
	
	func should_refresh_from_velocity() -> bool:
		return _state == LegState.Moving and (_movement_corresponding_velocity - _stick_zone.get_velocity()).length_squared() > 0.5
	
	
	
	func get_feet_offset() -> Vector3:
		return _stick_zone.get_ground().direction_to(_ik_target.target.origin)
	
	
	
	func get_corresponding_velocity() -> Vector3:
		return _movement_corresponding_velocity
	
	
	
	func get_progress_ratio() -> float:
		return _progress_ratio
	
	
	
	func get_movement_time() -> float:
		return _movement_time
	
	
	
	func should_unstick() -> bool:
		# Unstick if we are moving and both legs will have to unstick almost at the same time
		if _stick_zone.get_speed() > 0.2 and _other._state == LegState.Stick:
			if abs(_stick_zone.get_time_to_reach_edge(_other._ik_target.target.origin, _other._position_offset) - _stick_zone.get_time_to_reach_edge(_ik_target.target.origin, _position_offset)) < 0.1:
				return true
		
		return _state == LegState.Stick and _stick_zone.should_unstick(_ik_target.target.origin, _position_offset)
	
	
	
	func _update_movement(body_forward: Basis) -> void:
		
		# X with offset: TODO: Reduce offset if we have a very quick movement to do (mix of offset + multiplier ?)
		var new_position := _starting_point.linear_interpolate(_end_point, _progress_ratio)
		new_position += _starting_point.direction_to(_end_point) * FeetOffsetCurve.get_horizontal_offset(_progress_ratio, _stick_zone.get_speed_ratio() * _full_movement_ratio, _height_diff_ratio)
		
		# Y progress -> offset
		new_position.y = lerp(_starting_point.y, _end_point.y, _progress_ratio)
		# TODO: Set the offfset divider in a const somewhere
		new_position.y += FeetOffsetCurve.get_vertical_offset(_progress_ratio, _stick_zone.get_speed_ratio() * _full_movement_ratio, _height_diff_ratio)
		
		# TEMP ? No lerp for smoothing for now, may not be required
		_ik_target.target.origin = new_position
		_ik_target.target.basis = body_forward
	
	
	
	func _compute_movement(first: bool = false) -> void:
		var target_time: float
		var air_ratio_to_ground := (1.0 / (1.0 - (_stick_zone.get_air_ratio() / 2.0))) - 1.0
		var desired_air_time := _stick_zone.get_traversal_time() * air_ratio_to_ground
		
		match _other._state:
			LegState.Stick:
				target_time = _stick_zone.get_time_to_reach_edge(_other._ik_target.target.origin, _other._position_offset)
				
				
				# If we will take too much time to reach the target_time, we cap it
				if target_time == INF:
					target_time = 0.4 * (1.0 - _progress_ratio)
				
#				var relative_progression := -((_stick_zone.get_traversal_time() / 2.0) - target_time) / (_stick_zone.get_traversal_time() / 2.0)
				var relative_progression := -(target_time - _stick_zone.get_traversal_time()) / _stick_zone.get_traversal_time()
				var relative_progress_from_half = 0.5 - relative_progression
				target_time = desired_air_time - (0.5 * desired_air_time - relative_progress_from_half * _stick_zone.get_traversal_time())
#				target_time = desired_air_time * (1.0 - relative_progression)
				print(target_time, "     ", _movement_time, "    ", relative_progression, "     ", relative_progress_from_half)
				
				
				# air ratio offset
#				target_time += _stick_zone.get_traversal_time() * (_stick_zone.get_air_ratio() - 1.0)
#				target_time *= _stick_zone.get_air_ratio()
				
				if first or target_time < _movement_time:
					_movement_time = target_time
			LegState.Moving:
				# If the other leg is still in the air, smallest time possible
				_movement_time = max(_other._movement_time * (1.0 - _other._progress_ratio) - _stick_zone.get_traversal_time(), 0.2) * (1.0 - _progress_ratio)
				
				# Test run
				
				if _other._progress_ratio < 0.5:
					_movement_time = max(((0.5 - _other._progress_ratio) * desired_air_time) - (0.5 * _stick_zone.get_traversal_time()), 0.0)
				else:
					_movement_time = min(((1.5 - _other._progress_ratio) * desired_air_time) + (0.5 * _stick_zone.get_traversal_time()), desired_air_time)
				
#				_movement_time = max(((0.5 - _other._progress_ratio) * desired_air_time) - (0.5 * _stick_zone.get_traversal_time()), 0.0)
				
				
#				_movement_time = _stick_zone.apply_air_ratio_offset(_movement_time)
				
#				var target_ratio: float = lerp(0.5, 1.0, inverse_lerp(2.0, 1.0, _stick_zone.get_air_ratio()))
#				_movement_time = min(_stick_zone.get_traversal_time() + (_other._movement_time * target_ratio), 1.0)
#				print(_movement_time)
		
#		print(target_time < _movement_time * _progress_ratio)
#
#		if first or target_time < _movement_time * _progress_ratio:
		
		if first:
			_initial_movement_time = _movement_time
			_starting_point = _ik_target.target.origin
		
		
		var target_lerp := 1.0
#		match forced:
#			ForceState.None:
#				var target_ratio: float = lerp(0.5, 1.0, inverse_lerp(2.0, 1.0, _stick_zone.get_air_ratio()))
#				_movement_time = _stick_zone.get_interpolation_time(_progress_ratio)
#				_movement_time += other_time * (target_ratio - other_ratio)
#				_full_movement_ratio = 1.0
#			ForceState.Full:
#				_movement_time = _stick_zone.get_interpolation_time(_progress_ratio)
#				_full_movement_ratio = 1.0
#			ForceState.Short:
#				_full_movement_ratio = clamp(1.0 - _progress_ratio, 0.1, 0.5)
#				target_lerp = _full_movement_ratio
#				_movement_time = _stick_zone.get_interpolation_time(_progress_ratio, _full_movement_ratio)
		
		_end_point = _find_true_position(_stick_zone.get_next_stick_point(_movement_time, _starting_point, target_lerp))
		_end_point += _stick_zone.get_forward() * -_position_offset
		
		# TODO: Get the max length from somewhere
		_height_diff_ratio = inverse_lerp(0.0, 1.0, abs(_starting_point.y - _end_point.y))
		_movement_corresponding_velocity = _stick_zone.get_velocity()
	
	
	
	func _find_true_position(world_target: Vector3) -> Vector3:
		var first_origin := _stick_zone.get_origin()
		var flat_target := Vector3(world_target.x, first_origin.y, world_target.z)
		
		var collision := _caster.get_collision_data(first_origin, flat_target)
		var second_origin: Vector3
		if collision.collides():
			second_origin = collision.collision_position() - flat_target.direction_to(first_origin) * 0.1
		else:
			second_origin = flat_target
		
		# TODO: Get the max down length from somewhere
		var second_collision := _caster.get_collision_data(second_origin, second_origin + Vector3.DOWN * 1.5)
		return second_collision.collision_position() if second_collision.collides() else world_target
	


