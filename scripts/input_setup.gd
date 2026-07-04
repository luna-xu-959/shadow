extends Node

const DEADZONE := 0.15


func _ready() -> void:
	_reset_action("p0_forward", [KEY_W])
	_reset_action("p0_back", [KEY_S])
	_reset_action("p0_left", [KEY_A])
	_reset_action("p0_right", [KEY_D])
	_reset_action("p0_jump", [KEY_SPACE])
	_reset_action("p0_cam_left", [KEY_Q])
	_reset_action("p0_cam_right", [KEY_E])

	_reset_action("p1_forward", [KEY_UP, KEY_I])
	_reset_action("p1_back", [KEY_DOWN, KEY_K])
	_reset_action("p1_left", [KEY_LEFT, KEY_J])
	_reset_action("p1_right", [KEY_RIGHT, KEY_L])
	_reset_action("p1_jump", [KEY_KP_ENTER, KEY_ENTER])
	_reset_action("p1_cam_left", [KEY_U])
	_reset_action("p1_cam_right", [KEY_O])


func _reset_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action, DEADZONE)

	for key in keys:
		var event := InputEventKey.new()
		event.keycode = KEY_NONE
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
