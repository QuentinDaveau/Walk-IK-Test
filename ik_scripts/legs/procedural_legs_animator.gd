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
	
	if _right_leg._state == LegIkAnimator.LegState.Moving:
		_right_leg.update(delta, global_transform.basis)
		_left_leg.update(delta, global_transform.basis)
	else:
		_left_leg.update(delta, global_transform.basis)
		_right_leg.update(delta, global_transform.basis)





class LegIkAnimator:
	
	enum LegState {Stick, Moving}
	
	var _caster: Raycaster
	var _ik_target: SkeletonIK
	var _stick_zone: StickZoneUpdater
	var _other: LegIkAnimator
	var _position_offset: Vector3
	
	var _state: int = LegState.Moving
	var _starting_point: Vector3
	var _end_point: Vector3
	var _height_diff_ratio: float
	var _true_position_offset: Vector3
	
	var _progress_ratio: float
	var _movement_time: float
	
	
	func _init(ik_target: SkeletonIK, stick_zone: StickZoneUpdater, position_offset: Vector3, world: World) -> void:
		_ik_target = ik_target
		_ik_target.start()
		_stick_zone = stick_zone
		_position_offset = position_offset
		_true_position_offset = _position_offset
		_caster = Raycaster.new(world)
	
	
	
	func set_other_leg(other: LegIkAnimator) -> void:
		_other = other
	
	
	
	func update(delta: float, body_forward: Basis) -> void:
		DebugOverlay.draw_sphere(_end_point, 0.1, Color.blue if _state == LegState.Moving else Color.gray)
		
		match _state:
			LegState.Stick:
				if _should_unstick():
					_update_true_offset(body_forward)
					_unstick()
			LegState.Moving:
				_update_true_offset(body_forward)
				_compute_movement()
				_progress_ratio = min(_progress_ratio + (delta * (1.0 - _progress_ratio) / max(_movement_time, 0.01)), 1.0)
				_update_movement(body_forward)
				
				if _progress_ratio >= 0.99:
					_state = LegState.Stick
					_progress_ratio = 0.0
					_movement_time = 0.0
	
	
	
	func get_time_to_edge() -> float:
		return _stick_zone.get_time_to_reach_edge(_ik_target.target.origin, _true_position_offset)
	
	
	
	func is_sticking() -> bool:
		return _state == LegState.Stick
	
	
	
	func _update_true_offset(body_forward: Basis) -> void:
		_true_position_offset = body_forward * -_position_offset
		if _stick_zone.get_speed() < 0.2:
			return
		var mouvement := _stick_zone.get_direction()
		var angle_diff := body_forward.z.signed_angle_to(mouvement, Vector3.UP)
		var dot := body_forward.z.dot(mouvement)
		_true_position_offset += _position_offset.rotated(Vector3.UP, angle_diff) * ((1.0 - abs(dot)) * sign(dot))
	
	
	
	func _unstick() -> void:
		_compute_movement(true)
		_progress_ratio = 0.0
		_state = LegState.Moving
	
	
	
	func _should_unstick() -> bool:
		# Unstick if we are moving and both legs will have to unstick almost at the same time
		if (_stick_zone.get_speed() > 0.2 and _other.is_sticking()) and abs(_other.get_time_to_edge() - get_time_to_edge()) < 0.1:
			return true                                                                             
		return _state == LegState.Stick and _stick_zone.should_unstick(_ik_target.target.origin, -_true_position_offset)
	
	
	
	func _update_movement(body_forward: Basis) -> void:
		var new_position := _starting_point.linear_interpolate(_end_point, _progress_ratio)
		new_position += _starting_point.direction_to(_end_point) * FeetOffsetCurve.get_horizontal_offset(_progress_ratio, _stick_zone.get_speed_ratio(), _height_diff_ratio)
		
		# Y progress -> offset
		new_position.y = lerp(_starting_point.y, _end_point.y, _progress_ratio)
		# TODO: Set the offfset divider in a const somewhere
		new_position.y += FeetOffsetCurve.get_vertical_offset(_progress_ratio, _stick_zone.get_speed_ratio(), _height_diff_ratio)
		
		# TEMP ? No lerp for smoothing for now, may not be required
		_ik_target.target.origin = new_position
		_ik_target.target.basis = body_forward
	
	
	
	func _compute_movement(first: bool = false) -> void:
		var air_ratio_to_ground := (1.0 / (1.0 - (_stick_zone.get_air_ratio() / 2.0))) - 1.0
		var desired_air_time := _stick_zone.get_traversal_time() * air_ratio_to_ground
		
		match _other._state:
			LegState.Stick:
				var target_time := _other.get_time_to_edge()
				
				# If we will take too much time to reach the target_time, we cap it
				if target_time == INF:
					target_time = 0.4 * (1.0 - _progress_ratio)
				
				var relative_progression := 0.5 + ((target_time - _stick_zone.get_traversal_time()) / _stick_zone.get_traversal_time())
				target_time = desired_air_time - (0.5 * desired_air_time - relative_progression * _stick_zone.get_traversal_time())
			
				if first or target_time < _movement_time:
					_movement_time = target_time
			
			LegState.Moving:
				if _other._progress_ratio < 0.5:
					_movement_time = max(((0.5 - _other._progress_ratio) * desired_air_time) - (0.5 * _stick_zone.get_traversal_time()), 0.0)
				else:
					_movement_time = min((min(1.5 - _other._progress_ratio, 1.0) * desired_air_time) + (0.5 * _stick_zone.get_traversal_time()), desired_air_time)
		
		if first:
			_starting_point = _ik_target.target.origin
		
		_end_point = _find_true_position(_stick_zone.get_next_stick_point(_movement_time) + _true_position_offset)
		
		# TODO: Get the max length from somewhere
		_height_diff_ratio = inverse_lerp(0.0, 1.0, abs(_starting_point.y - _end_point.y))
	
	
	
	func _find_true_position(world_target: Vector3) -> Vector3:
		DebugOverlay.draw_line(world_target, _stick_zone.get_origin(), 1.0, Color.blue)
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
	


