extends Camera3D

## Third-person follow: mouse steers Ghost (P1); Human (P0) uses U/O to turn view.
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
var _pending_mouse_delta := Vector2.ZERO
var _look_captured := false
var _camera_enabled := true


func configure_for_player(enabled: bool, mouse_look: bool) -> void:
	_camera_enabled = enabled
	use_mouse_look = mouse_look
	if enabled and mouse_look:
		call_deferred("_capture_look")
	elif not enabled:
		_release_look()


func _ready() -> void:
	_pitch = -0.38
	_yaw = 0.0 if player_id == 0 else PI
	process_physics_priority = -100
	await get_tree().process_frame
	_player = get_node_or_null(player_path) as Node3D
	if use_mouse_look:
		call_deferred("_capture_look")


func _process(_delta: float) -> void:
	if use_mouse_look and _look_captured and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not _camera_enabled or not use_mouse_look:
		return

	if event.is_action_pressed("ui_cancel"):
		_release_look()
		return

	if event is InputEventMouseMotion:
		if _look_captured:
			var motion := event as InputEventMouseMotion
			_pending_mouse_delta += motion.relative
		elif _is_mouse_on_my_panel():
			_capture_look()
			var motion := event as InputEventMouseMotion
			_pending_mouse_delta += motion.relative

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and not _look_captured and _is_mouse_on_my_panel():
			_capture_look()


func _capture_look() -> void:
	_look_captured = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _release_look() -> void:
	_look_captured = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func is_look_captured() -> bool:
	return _look_captured


func _is_mouse_on_my_panel() -> bool:
	if not _camera_enabled:
		return false
	var mouse := get_viewport().get_mouse_position()
	var width := get_viewport().get_visible_rect().size.x
	if width < 64.0:
		return true
	if player_id == 1:
		return mouse.x >= width * 0.5
	return mouse.x < width * 0.5


func get_camera_forward_xz() -> Vector3:
	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.00001:
		return Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	return forward.normalized()


func get_view_yaw() -> float:
	return _yaw


func get_flat_yaw() -> float:
	return get_view_yaw()


func _physics_process(delta: float) -> void:
	if not _camera_enabled:
		return
	if _player == null:
		_player = get_node_or_null(player_path) as Node3D
		if _player == null:
			return

	var prefix := "p0" if player_id == 0 else "p1"
	var cam_left := "%s_cam_left" % prefix
	var cam_right := "%s_cam_right" % prefix
	var turn := Input.get_action_strength(cam_right) - Input.get_action_strength(cam_left)
	if turn != 0.0:
		_yaw -= turn * KEY_YAW_SPEED * delta

	if use_mouse_look and _look_captured and _pending_mouse_delta != Vector2.ZERO:
		_yaw -= _pending_mouse_delta.x * MOUSE_SENSITIVITY
		_pitch = clampf(
			_pitch - _pending_mouse_delta.y * MOUSE_SENSITIVITY, -0.95, -0.15
		)
		_pending_mouse_delta = Vector2.ZERO

	var anchor := _player.global_position
	if _player.has_method("get_camera_anchor"):
		anchor = _player.call("get_camera_anchor")

	var focus := anchor + Vector3(0.0, look_height, 0.0)
	var offset := Vector3(
		sin(_yaw) * cos(_pitch) * camera_distance,
		-sin(_pitch) * camera_distance,
		cos(_yaw) * cos(_pitch) * camera_distance
	)
	global_position = focus + offset
	look_at(focus, Vector3.UP)
