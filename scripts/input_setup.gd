extends Node

const DEADZONE := 0.15


func _ready() -> void:
	# P0 Human: arrow keys / IJKL (swapped from former Ghost layout)
	_reset_action("p0_forward", [KEY_UP, KEY_I])
	_reset_action("p0_back", [KEY_DOWN, KEY_K])
	_reset_action("p0_left", [KEY_LEFT, KEY_J])
	_reset_action("p0_right", [KEY_RIGHT, KEY_L])
	_reset_action("p0_jump", [KEY_KP_ENTER, KEY_ENTER])
	_reset_action("p0_cam_left", [KEY_U])
	_reset_action("p0_cam_right", [KEY_O])

	# P1 Ghost: WASD (swapped from former Human layout)
	_reset_action("p1_forward", [KEY_W])
	_reset_action("p1_back", [KEY_S])
	_reset_action("p1_left", [KEY_A])
	_reset_action("p1_right", [KEY_D])
	_reset_action("p1_jump", [KEY_SPACE])
	_reset_action("p1_attack", [KEY_F])
	_reset_action("p1_cam_left", [KEY_Q])
	_reset_action("p1_cam_right", [KEY_E])


func _reset_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action, DEADZONE)

	for key in keys:
		if key is int and key >= MOUSE_BUTTON_LEFT and key <= MOUSE_BUTTON_XBUTTON2:
			var mouse := InputEventMouseButton.new()
			mouse.device = -1
			mouse.button_index = key
			InputMap.action_add_event(action, mouse)
			continue
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
