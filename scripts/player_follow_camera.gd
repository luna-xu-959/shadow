extends Camera3D

## Third-person follow: mouse steers Ghost (P1); Human (P0) uses Q/E to turn view.
@export var player_path: NodePath
@export var player_id: int = 0
@export var use_mouse_look: bool = false
@export var camera_distance: float = 5.8
@export var look_height: float = 1.35

const MOUSE_SENSITIVITY := 0.0028
const KEY_YAW_SPEED := 1.9

var _yaw: float = 0.0
var _pitch: float = -0.38
var _player: Node3D


func _ready() -> void:
	_pitch = -0.38
	_yaw = 0.0 if player_id == 0 else PI
	await get_tree().process_frame
	_player = get_node_or_null(player_path) as Node3D
	if use_mouse_look:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _input(event: InputEvent) -> void:
	if use_mouse_look and event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch - motion.relative.y * MOUSE_SENSITIVITY, -0.95, -0.15)

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if use_mouse_look:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_node_or_null(player_path) as Node3D
		if _player == null:
			return

	if not use_mouse_look:
		var cam_left := "%s_cam_left" % ("p0" if player_id == 0 else "p1")
		var cam_right := "%s_cam_right" % ("p0" if player_id == 0 else "p1")
		var turn := Input.get_action_strength(cam_right) - Input.get_action_strength(cam_left)
		_yaw -= turn * KEY_YAW_SPEED * delta

	var anchor := _player.global_position
	if _player.has_method("get_camera_anchor"):
		anchor = _player.get_camera_anchor()

	var focus := anchor + Vector3(0.0, look_height, 0.0)
	var offset := Vector3(
		sin(_yaw) * cos(_pitch) * camera_distance,
		-sin(_pitch) * camera_distance,
		cos(_yaw) * cos(_pitch) * camera_distance
	)
	global_position = focus + offset
	look_at(focus, Vector3.UP)

	if _player.has_method("set_move_yaw"):
		_player.set_move_yaw(_yaw)
