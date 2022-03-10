extends Spatial


"""
Quick and dirty class to test the IK with the legs without the use of animations
"""

export(float) var _max_step_angle = 0.4 # in rads
export(float) var _max_leg_length = 2.0
export(float) var _speed_step_dist_multiplier

export(NodePath) var _ik_system_right_path
export(NodePath) var _ik_system_left_path

export(NodePath) var _right_target_path
export(NodePath) var _left_target_path

onready var _ik_target_right: SkeletonIK = get_node(_ik_system_right_path)
onready var _ik_target_left: SkeletonIK = get_node(_ik_system_left_path)

onready var _right_target: Spatial = get_node(_right_target_path)
onready var _left_target: Spatial = get_node(_left_target_path)

onready var _caster := $RayCast

var _step_cycle: int = 0
var _previous_position: Vector3

var _left_world_target: Transform
var _right_world_target: Transform



func _ready() -> void:
	_ik_target_right.start()
	_ik_target_left.start()



func _physics_process(delta: float) -> void:
	var skeleton := _ik_target_right.get_parent_skeleton()
#	_right_world_target = _update_ik_position(_right_world_target, _right_target.global_transform, skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.get_bone_parent(skeleton.find_bone(_ik_target_right.tip_bone))))
#	_left_world_target = _update_ik_position(_left_world_target, _left_target.global_transform, skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.get_bone_parent(skeleton.find_bone(_ik_target_left.tip_bone))))
#	
	_right_world_target = _update_ik_position(_right_world_target, _right_target.global_transform, _right_target.get_parent().global_transform)
	_left_world_target = _update_ik_position(_left_world_target, _left_target.global_transform, _left_target.get_parent().global_transform)
	
	
	_ik_target_right.target.origin = _ik_target_right.target.origin.linear_interpolate(_right_world_target.origin, 30.0 * delta)
	_ik_target_left.target.origin = _ik_target_left.target.origin.linear_interpolate(_left_world_target.origin, 30.0 * delta)
	
	_previous_position = global_transform.origin



func _update_ik_position(world_target: Transform, feet_target: Transform, feet_parent: Transform) -> Transform:
	var move_dir := (global_transform.origin - _previous_position).normalized()
	var cast_end: Vector3 = feet_target.origin
	
#	_caster.global_transform.origin = feet_parent.origin
	_caster.global_transform.origin = (cast_end) + Vector3.UP
	_caster.cast_to = cast_end - _caster.global_transform.origin
	_caster.force_raycast_update()
	
	var end_transform: Transform
	if not _caster.is_colliding():
#		end_transform = Transform(global_transform.basis, global_transform.origin + Vector3.DOWN * _max_leg_length)
		end_transform = feet_target
		end_transform.basis = world_target.basis
	elif move_dir:
#		end_transform = world_target
		var rotation_axis := -move_dir.cross(_caster.get_collision_normal()).normalized()
		var rotated_normal := Basis(rotation_axis, _caster.get_collision_normal(), rotation_axis.cross(_caster.get_collision_normal())).orthonormalized()
		end_transform.basis = rotated_normal
		end_transform.origin = _caster.get_collision_point()
	return end_transform
	



