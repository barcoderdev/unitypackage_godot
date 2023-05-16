#----------------------------------------

extends Node3D

#----------------------------------------

@onready var camera = $Camera3D

#----------------------------------------

var rotation_speed = 0.1
var mouse_sensitivity = 0.05

var camera_rotate: bool = false
var camera_pan: bool = false
var camera_auto_rotate: bool = true

#----------------------------------------

func _process(delta: float):
	if camera_auto_rotate:
		rotate_y(0.5 * delta)

#----------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var scroll_amount: float = 0.0
		match event.button_index:
			MOUSE_BUTTON_RIGHT:				camera_rotate = event.pressed
			MOUSE_BUTTON_LEFT:				camera_pan = event.pressed
			MOUSE_BUTTON_WHEEL_UP:			scroll_amount -= event.factor
			MOUSE_BUTTON_WHEEL_DOWN:		scroll_amount += event.factor
			MOUSE_BUTTON_MIDDLE:
				position = Vector3.ZERO
				rotation = Vector3.ZERO

		if scroll_amount != 0:
			var target = max(camera.position.z + scroll_amount, 0.0)
			camera.position.z = lerpf(camera.position.z, target, 0.05)

	if event is InputEventMouseMotion:
		if camera_rotate:
			# The right mouse button is held, so rotate the camera
			var mouse_motion = event.relative
			rotation += Vector3(-mouse_motion.y, -mouse_motion.x, 0) * rotation_speed
		if camera_pan:
			var mouse_motion = event.relative
			translate(Vector3(-mouse_motion.x * mouse_sensitivity, mouse_motion.y * mouse_sensitivity, 0))

	if event is InputEventKey && event.pressed && event.keycode == KEY_SPACE:
		camera_auto_rotate = !camera_auto_rotate

#----------------------------------------
