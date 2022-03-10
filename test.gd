extends Node2D


export(float) var circle_height := 100.0
export(float) var circle_length := 100.0
export(float, -1.0, 1.0) var height_offset := 0.0

var _circle_rotation := 0.0



func _physics_process(delta: float) -> void:
	_circle_rotation += delta * 5.0
	_circle_rotation = fmod(_circle_rotation, PI * 2.0)
	var normalized_vect := Vector2(cos(_circle_rotation), sin(_circle_rotation))
	var vect := Vector2(normalized_vect.x * circle_length, normalized_vect.y * circle_height)
	
	$Sprite.position = vect
	$Sprite2.position = -vect
	
	$Sprite.self_modulate = Color.red if normalized_vect.y > height_offset else Color.blue
	$Sprite2.self_modulate = Color.red if -normalized_vect.y > height_offset else Color.blue
	
	# Finding the offset
	
