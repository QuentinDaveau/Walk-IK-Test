extends Camera


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		transform = transform.rotated(Vector3.UP, -event.relative.x * 0.01)
		transform = transform.rotated(Vector3.UP.cross(transform.basis.z).normalized(), -event.relative.y * 0.01)
	
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == BUTTON_WHEEL_UP:
			transform.origin -= transform.basis.z.normalized()
		if event.button_index == BUTTON_WHEEL_DOWN:
			transform.origin += transform.basis.z.normalized()
	
	if Input.is_action_pressed("speed_reset"):
		Engine.time_scale = 1.0
	if Input.is_action_pressed("speed_up"):
		Engine.time_scale *= 2.0
	if Input.is_action_pressed("speed_down"):
		Engine.time_scale /= 2.0
