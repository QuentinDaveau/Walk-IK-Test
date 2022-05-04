extends Resource
class_name MovementParameter


# Curve with only four points
export(Curve) var _stick_zone_angle_from_speed: Curve

export(float) var _stick_zone_safe_margin: float = 0.1

# Curve corresponding to the air ratio: 0 = always 2 feet on ground, 1 = 1 feet on ground, 2 = no feet on ground
export(Curve) var _air_ratio_from_speed: Curve

export(float) var _max_speed: float



func get_angle(speed: float) -> float:
	return _stick_zone_angle_from_speed.interpolate_baked(get_speed_ratio(speed))



func get_air_ratio(speed: float) -> float:
	return _air_ratio_from_speed.interpolate_baked(get_speed_ratio(speed))



func get_speed_ratio(speed: float) -> float:
	return clamp(inverse_lerp(0, _max_speed, speed), 0.0, 1.0)

