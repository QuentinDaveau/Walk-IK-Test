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

onready var _wheeler: Spatial = get_node(_wheeler_path)

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



func _ready() -> void:
	_ik_target_right.start()
	_ik_target_left.start()
	
	$RightTarget.set_as_toplevel(true)
	$LeftTarget.set_as_toplevel(true)



func _physics_process(delta: float) -> void:
	var skeleton := _ik_target_right.get_parent_skeleton()
#	_right_world_target = _find_ik_position(_right_world_target, _right_target.global_transform, skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.get_bone_parent(skeleton.find_bone(_ik_target_right.tip_bone))))
#	_left_world_target = _find_ik_position(_left_world_target, _left_target.global_transform, skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.get_bone_parent(skeleton.find_bone(_ik_target_left.tip_bone))))
	
	_right_progress += delta
	_left_progress += delta
	
	if _right_progress >= _right_time:
		_right_moving = false
	
	if _left_progress >= _left_time:
		_left_moving = false
	
	if not _right_moving and $FeetTracker.should_unstick(_right_target_position):
		_right_starting_point = _ik_target_right.target.origin
		_right_progress = 0.0
		_right_target_position = $FeetTracker.get_next_stick_point()
		_right_time = $FeetTracker.get_interpolation_time(0.0)
		_right_target_position = _find_ik_position(_right_target_position)
		$RightTarget.global_transform.origin = _right_target_position
		_right_moving = true
#
#	if not _left_moving and $FeetTracker.should_unstick(_left_target_position):
#		_left_starting_point = _ik_target_left.target.origin
#		_left_progress = 0.0
#		_left_target_position = $FeetTracker.get_next_stick_point()
#		_left_time = $FeetTracker.get_interpolation_time(0.0)
#		_left_target_position = _find_ik_position(_right_target_position)
#		$LeftTarget.global_transform.origin = _left_target_position
#		_left_moving = true
	
	
	if _right_moving:
		print(_right_progress / _right_time)
		var right_progress := _feet_offset_curve.get_horizontal_progress(_right_progress / _right_time, $FeetTracker.get_speed_ratio(), 0.0)
		
		var right_flat := _right_starting_point
		right_flat.y = 0.0
		var right_progress_flat := _right_target_position
		right_progress_flat.y = 0.0
		var right_flat_position = right_flat.linear_interpolate(right_progress_flat, right_progress)
		right_flat_position.y = lerp(_right_starting_point.y, _right_target_position.y, _feet_offset_curve.get_vertical_progress(_right_progress / _right_time, $FeetTracker.get_speed_ratio(), 0.0))
		_ik_target_right.target.origin = _ik_target_right.target.origin.linear_interpolate(right_flat_position, 30.0 * delta)
		$LeftTarget2.global_transform.origin = right_flat_position
	
#	if _left_moving:
#		var left_progress := _feet_offset_curve.get_horizontal_progress(_left_progress / _left_time, $FeetTracker.get_speed_ratio(), 0.0)
#
#		_ik_target_left.target.origin = _ik_target_left.target.origin.linear_interpolate(_left_world_target.origin, 30.0 * delta)
#
	_previous_position = global_transform.origin



func _find_ik_position(world_target: Vector3) -> Vector3:
	var dir := global_transform.origin - world_target
	var flat_dir := Vector3(dir.x, 0.0, dir.z)
	_caster.global_transform.origin = global_transform.origin
	_caster.cast_to = flat_dir
	_caster.force_update_transform()
	_caster.force_raycast_update()
	if _caster.is_colliding():
		_caster.global_transform.origin = _caster.get_collision_point() - flat_dir.normalized() * 0.05
	else:
		_caster.global_transform.origin = global_transform.origin + flat_dir
	
	_caster.cast_to = Vector3.DOWN * dir.y * 2.0
	_caster.force_update_transform()
	_caster.force_raycast_update()
	if _caster.is_colliding():
		return _caster.get_collision_point()
	else:
		return world_target



