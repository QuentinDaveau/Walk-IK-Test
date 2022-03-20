extends Spatial


func _process(delta: float) -> void:
	var move_vector := Vector2.ZERO
	if Input.is_action_pressed("ui_up"):
		move_vector.y += 1.0
	if Input.is_action_pressed("ui_down"):
		move_vector.y -= 1.0
	if Input.is_action_pressed("ui_left"):
		move_vector.x += 1.0
	if Input.is_action_pressed("ui_right"):
		move_vector.x -= 1.0
	
	if Input.is_action_pressed("ui_shift"):
		move_vector *= 2.0
	
	if Input.is_action_pressed("ui_ctrl"):
		move_vector /= 2.0
	
	var rotate := 0.0
	if Input.is_action_pressed("ui_rotate_left"):
		rotate += 1.0
	if Input.is_action_pressed("ui_rotate_right"):
		rotate -= 1.0
	
	global_translate(global_transform.basis.xform(Vector3(move_vector.x, 0.0, move_vector.y)) * 2.0 * delta)
	global_rotate(Vector3.UP, rotate * (PI / 2.0) * delta)
