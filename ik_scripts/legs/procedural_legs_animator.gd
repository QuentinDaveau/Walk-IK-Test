extends Spatial


"""
Quick and dirty class to test the IK with the legs without the use of animations
"""

export(NodePath) var _ik_system_right_path
export(NodePath) var _ik_system_left_path

onready var _ik_target_right: SkeletonIK = get_node(_ik_system_right_path)
onready var _ik_target_left: SkeletonIK = get_node(_ik_system_left_path)

var _stick_zone_updater: StickZoneUpdater
var _right_leg: LegIkAnimator
var _left_leg: LegIkAnimator





func _ready() -> void:
	_stick_zone_updater = StickZoneUpdater.new(global_transform, get_world())
	_right_leg = LegIkAnimator.new(_ik_target_right, _stick_zone_updater, get_world())
	_left_leg = LegIkAnimator.new(_ik_target_left, _stick_zone_updater, get_world())



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
	
	# Force update if velocity changed too much (either in length or direction)
	if _right_leg.should_refresh_from_velocity():
		force_update[0] = LegIkAnimator.ForceState.Short
	if _left_leg.should_refresh_from_velocity():
		force_update[1] = LegIkAnimator.ForceState.Short
	
	# If we force update both legs, one needs to be a long update (the least progressed one)
	if force_update[0] and force_update[1]:
		if _right_leg.get_progress_ratio() < _left_leg.get_progress_ratio():
			force_update[0] = LegIkAnimator.ForceState.Full
		else:
			force_update[1] = LegIkAnimator.ForceState.Full
	
	# Unstick if necessary
	if force_update[0] or _right_leg.should_unstick():
		_right_leg.unstick(_left_leg.get_progress_ratio(), _left_leg.get_movement_time(), force_update[0])
	
	if force_update[1] or _left_leg.should_unstick():
		_left_leg.unstick(_right_leg.get_progress_ratio(), _right_leg.get_movement_time(), force_update[1])
	
	_right_leg.update(delta)
	_left_leg.update(delta)





class LegIkAnimator:
	
	enum LegState {Stick, Moving}
	enum ForceState {None, Full, Short}
	
	var _caster: Raycaster
	var _ik_target: SkeletonIK
	var _stick_zone: StickZoneUpdater
	
	var _state: int = LegState.Stick
	var _starting_point: Vector3
	var _end_point: Vector3
	var _height_diff_ratio: float
	
	var _progress_ratio: float
	var _movement_time: float
	var _full_movement_ratio: float
	var _movement_corresponding_velocity: Vector3
	
	
	func _init(ik_target: SkeletonIK, stick_zone: StickZoneUpdater, world: World) -> void:
		_ik_target = ik_target
		_ik_target.start()
		_stick_zone = stick_zone
		_caster = Raycaster.new(world)
	
	
	func update(delta: float) -> void:
		if not _state == LegState.Moving:
			return
		_progress_ratio = min(_progress_ratio + (delta / _movement_time), 1.0)
		_update_movement(delta)
		if _progress_ratio >= 1.0:
			_state = LegState.Stick
			_progress_ratio = 0.0
			_movement_time = 0.0
	
	
	
	func unstick(other_ratio: float, other_time: float, forced: int = ForceState.None) -> void:
		_compute_movement(other_ratio, other_time, forced)
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
		return _state == LegState.Stick and _stick_zone.should_unstick(_ik_target.target.origin)
	
	
	
	func _update_movement(delta: float) -> void:
		# X with offset: TODO: Reduce offset if we have a very quick movement to do (mix of offset + multiplier ?)
		var new_position := _starting_point.linear_interpolate(_end_point, _progress_ratio)
		new_position += _starting_point.direction_to(_end_point) * FeetOffsetCurve.get_horizontal_offset(_progress_ratio, _stick_zone.get_speed_ratio() * _full_movement_ratio, _height_diff_ratio)
		
		# Y progress -> offset
		new_position.y = lerp(_starting_point.y, _end_point.y, _progress_ratio)
		# TODO: Set the offfset divider in a const somewhere
		new_position.y += FeetOffsetCurve.get_vertical_offset(_progress_ratio, _stick_zone.get_speed_ratio() * _full_movement_ratio, _height_diff_ratio)
		
		# TEMP ? No lerp for smoothing for now, may not be required
		_ik_target.target.origin = new_position
	
	
	
	func _compute_movement(other_ratio: float, other_time: float, forced: int = ForceState.None) -> void:
		match forced:
			ForceState.None:
				var target_ratio: float = lerp(0.5, 1.0, inverse_lerp(2.0, 1.0, _stick_zone.get_air_ratio()))
				_movement_time = _stick_zone.get_interpolation_time(_progress_ratio)
				_movement_time += other_time * (target_ratio - other_ratio)
				_full_movement_ratio = 1.0
			ForceState.Full:
				_movement_time = _stick_zone.get_interpolation_time(_progress_ratio)
#				_movement_time = _stick_zone.get_interpolation_time()
				_full_movement_ratio = 1.0 - _progress_ratio
			ForceState.Short:
				_full_movement_ratio = min(1.0 - _progress_ratio, 0.5)
				_movement_time = _stick_zone.get_interpolation_time(_progress_ratio, _full_movement_ratio)
#				_movement_time = _stick_zone.get_interpolation_time(0.0, _full_movement_ratio)
		
		_progress_ratio = 0.0
		_starting_point = _ik_target.target.origin
		_end_point = _find_true_position(_stick_zone.get_next_stick_point(_movement_time, _starting_point, _full_movement_ratio))
		
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
	


