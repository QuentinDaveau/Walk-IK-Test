extends Spatial


"""
Quick and dirty class to test the IK with the legs without the use of animations
"""

export(float) var _max_leg_length = 2.0
export(float) var _speed_step_dist_multiplier

export(NodePath) var _ik_system_right_path
export(NodePath) var _ik_system_left_path

export(NodePath) var _wheeler_path

onready var _ik_target_right: SkeletonIK = get_node(_ik_system_right_path)
onready var _ik_target_left: SkeletonIK = get_node(_ik_system_left_path)

#onready var _wheeler: Spatial = get_node(_wheeler_path)

onready var _caster := $RayCast
onready var _feet_track = $FeetTracker

var _step_cycle: int = 0
var _previous_position: Vector3

var _left_world_target: Transform
var _right_world_target: Transform

var _right_target_position: Vector3
var _left_target_position: Vector3

var _right_time: float = 0.0
var _left_time: float = 0.0

var _right_progress: float = 0.0
var _left_progress: float = 0.0


var _right_moving: bool = false
var _left_moving: bool = false

var _right_starting_point: Vector3
var _left_starting_point: Vector3

var _feet_offset_curve := FeetOffsetCurve.new()

var _right_velocity: Vector3
var _left_velocity: Vector3



func _ready() -> void:
	_ik_target_right.start()
	_ik_target_left.start()
	
	$RightTarget.set_as_toplevel(true)
	$LeftTarget.set_as_toplevel(true)



func _physics_process(delta: float) -> void:
	var skeleton := _ik_target_right.get_parent_skeleton()
#	_right_world_target = _find_ik_position(_right_world_target, _right_target.global_transform, skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.get_bone_parent(skeleton.find_bone(_ik_target_right.tip_bone))))
#	_left_world_target = _find_ik_position(_left_world_target, _left_target.global_transform, skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.get_bone_parent(skeleton.find_bone(_ik_target_left.tip_bone))))
	
	var should_refresh_right: bool = _right_moving and (_right_velocity - $FeetTracker.get_velocity()).length_squared() > 0.1
	var should_refresh_left: bool = _left_moving and (_left_velocity - $FeetTracker.get_velocity()).length_squared() > 0.1
	
	
	_right_progress += delta
	_left_progress += delta
	
	if _right_progress >= _right_time:
		_right_moving = false
	
	if _left_progress >= _left_time:
		_left_moving = false
	
	var left_ratio := 0.0 if not _left_moving else 1.0 - clamp(inverse_lerp(0.0, _left_time, _left_progress * 1.2), 0.0, 1.0)
	var right_ratio := 0.0 if not _right_moving else 1.0 - clamp(inverse_lerp(0.0, _right_time, _right_progress * 1.2), 0.0, 1.0)
	
	
	if should_refresh_right or (not _right_moving and $FeetTracker.should_unstick(_right_target_position)):
		_right_starting_point = _ik_target_right.target.origin
		_right_target_position = $FeetTracker.get_next_stick_point(left_ratio if not should_refresh_right else - 1 + right_ratio)
		_right_time = $FeetTracker.get_interpolation_time(0.0) + (left_ratio * _left_time if not should_refresh_right else 0.0)
		_right_progress = 0.0 if not should_refresh_right else (1.0 - right_ratio) * _right_time
		if should_refresh_right:
			print(right_ratio, "    ", _right_time, "   ", _right_progress)
		_right_target_position = _find_ik_position(_right_target_position)
		$RightTarget.global_transform.origin = _right_target_position
		_right_velocity = $FeetTracker.get_velocity()
		_right_moving = true
	
	right_ratio = 0.0 if not _right_moving or not _right_time else 1.0 - clamp(inverse_lerp(0.0, _right_time, _right_progress * 1.2), 0.0, 1.0)
	
	if should_refresh_left or (not _left_moving and $FeetTracker.should_unstick(_left_target_position)):
		# Applying speed slowdown if the other leg is still moving, with a slight understimation of the left motion to ensure that it will always arrive a bit sooner
		_left_starting_point = _ik_target_left.target.origin
		_left_target_position = $FeetTracker.get_next_stick_point(right_ratio if not should_refresh_left else - 1 + left_ratio)
		_left_time = $FeetTracker.get_interpolation_time(0.0) + (right_ratio * _right_time if not should_refresh_left else 0.0)
		_left_progress = 0.0 if not should_refresh_left else (1.0 - left_ratio) * _left_time
		_left_target_position = _find_ik_position(_left_target_position)
		$LeftTarget.global_transform.origin = _left_target_position
		_left_velocity = $FeetTracker.get_velocity()
		_left_moving = true
	
	
	if _right_moving and _right_time:
		var right_progress := _feet_offset_curve.get_horizontal_progress(_right_progress / _right_time, $FeetTracker.get_speed_ratio(), 0.0)
		
#		print(_feet_offset_curve.get_vertical_offset(_right_progress / _right_time, $FeetTracker.get_speed_ratio(), 0.0))
		
		var right_flat := _right_starting_point
		right_flat.y = 0.0
		var right_progress_flat := _right_target_position
		right_progress_flat.y = 0.0
		var right_flat_position = right_flat.linear_interpolate(right_progress_flat, right_progress)
		right_flat_position.y = lerp(_right_starting_point.y, _right_target_position.y, _right_progress / _right_time)
		right_flat_position.y += _feet_offset_curve.get_vertical_offset(_right_progress / _right_time, $FeetTracker.get_speed_ratio(), 0.0) / 3.0
		_ik_target_right.target.origin = _ik_target_right.target.origin.linear_interpolate(right_flat_position, 50.0 * delta)
		$RightTarget2.global_transform.origin = right_flat_position
	
	if _left_moving and _left_time:
		var left_progress := _feet_offset_curve.get_horizontal_progress(_left_progress / _left_time, $FeetTracker.get_speed_ratio(), 0.0)
		
		var left_flat := _left_starting_point
		left_flat.y = 0.0
		var left_progress_flat := _left_target_position
		left_progress_flat.y = 0.0
		var left_flat_position = left_flat.linear_interpolate(left_progress_flat, left_progress)
		left_flat_position.y = lerp(_left_starting_point.y, _left_target_position.y, _left_progress / _left_time)
		left_flat_position.y += _feet_offset_curve.get_vertical_offset(_left_progress / _left_time, $FeetTracker.get_speed_ratio(), 0.0) / 3.0
		_ik_target_left.target.origin = _ik_target_left.target.origin.linear_interpolate(left_flat_position, 50.0 * delta)
		$LeftTarget2.global_transform.origin = left_flat_position
	
	_previous_position = global_transform.origin



func _find_ik_position(world_target: Vector3) -> Vector3:
	var dir := world_target - global_transform.origin
	var flat_dir := Vector3(dir.x, 0.0, dir.z)
	_caster.global_transform.origin = global_transform.origin
	_caster.cast_to = flat_dir
	_caster.force_update_transform()
	_caster.force_raycast_update()
	if _caster.is_colliding():
		_caster.global_transform.origin = _caster.get_collision_point() - flat_dir.normalized() * 0.05
	else:
		_caster.global_transform.origin = global_transform.origin + flat_dir
	
#	_caster.cast_to = Vector3.DOWN * dir.y * 2.0
	_caster.cast_to = Vector3.DOWN * 2.0
	_caster.force_update_transform()
	_caster.force_raycast_update()
	if _caster.is_colliding():
		return _caster.get_collision_point()
	else:
		return world_target



