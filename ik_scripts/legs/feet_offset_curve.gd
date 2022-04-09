extends Node
class_name FeetOffsetCurve


const MIN_VERT_SPEED := 0.1
const MIN_VERT_HEIGHT := 0.5

const HEIGHT_MULTIPLIER = 0.6
const HOR_MULTIPLIER = 0.8


# TODO: Place arbitrary dividers in consts and tweak values
static func get_horizontal_offset(progress: float, speed_ratio: float, height_ratio: float) -> float:
	var ratio = speed_ratio * (1.0 - height_ratio)
#	return (1 - progress) * pow(progress, 2.0) + progress * (1.0 - pow(1.0 - (ratio + 1.0) * progress, 2.0) + pow(ratio * progress, 2.0))
#	return (1 - progress) * (pow(ratio - (ratio + 1.0) * progress, 2.0) - pow(ratio * (1.0 - progress), 2.0)) + progress * (1.0 - pow(1.0 - (ratio + 1.0) * progress, 2.0) + pow(ratio * progress, 2.0))
	return -sin(2.0 * PI * progress) * 0.5 * pow(ratio, 2.0) * HOR_MULTIPLIER



static func get_vertical_offset(progress: float, speed_ratio: float, height_ratio: float) -> float:
	var ratio := max(speed_ratio, MIN_VERT_SPEED) * max(1.0 - height_ratio, 0.3)
#	return 0.5 * sqrt(1 - pow(2.0 * progress - 1, 2.0)) * pow(ratio, 2.0) * HEIGHT_MULTIPLIER
	return 0.5 * sin(progress * PI) * pow(ratio, 2.0) * HEIGHT_MULTIPLIER
