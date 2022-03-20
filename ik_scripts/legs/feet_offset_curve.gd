extends Node
class_name FeetOffsetCurve


const MIN_VERT_SPEED := 0.2
const MIN_VERT_HEIGHT := 0.5



func get_horizontal_progress(progress: float, speed_ratio: float, height_ratio: float) -> float:
	var ratio = speed_ratio * (1.0 - height_ratio) / 3.0
#	return (1 - progress) * pow(progress, 2.0) + progress * (1.0 - pow(1.0 - (ratio + 1.0) * progress, 2.0) + pow(ratio * progress, 2.0))
	return (1 - progress) * (pow(ratio - (ratio + 1.0) * progress, 2.0) - pow(ratio * (1.0 - progress), 2.0)) + progress * (1.0 - pow(1.0 - (ratio + 1.0) * progress, 2.0) + pow(ratio * progress, 2.0))



func get_vertical_offset(progress: float, speed_ratio: float, height_ratio: float) -> float:
	var ratio := max(speed_ratio, MIN_VERT_SPEED) * max(1.0 - height_ratio, 0.3)
	return sqrt(1 - pow(2.0 * progress - 1, 2.0)) * ratio
