extends Node3D

## Interactive dev scene for previewing character FBX prototypes in isolation.
## Run this scene directly (F6) and change Model Path in the Inspector.

@export_file("*.fbx,*.glb,*.gltf,*.scn,*.tscn") var model_path: String = GamePaths.DEFAULT_CHARACTER_MODEL
@export var character_id: String = "default"
@export var use_native_materials: bool = true
@export var inject_idle_rig: bool = true
@export var play_idle: bool = true
@export var auto_spin: bool = false
@export var spin_speed: float = 0.45
@export var target_height: float = 2.0

@onready var _pivot: Node3D = $Pivot
@onready var _camera: Camera3D = $Camera3D
@onready var _info_label: Label = $Ui/InfoLabel

var _preview: Node3D
var _yaw := 0.0
var _dragging := false
var _last_mouse_x := 0.0


func _ready() -> void:
	_reload_preview()
	_update_info_label()


func _reload_preview() -> void:
	if _preview:
		_preview.queue_free()
		_preview = null

	_preview = UiFactory.make_prototype_preview(
		model_path,
		character_id,
		use_native_materials,
		inject_idle_rig,
		play_idle
	)
	_pivot.add_child(_preview)
	_yaw = 0.0
	_pivot.rotation = Vector3.ZERO
	call_deferred("_fit_preview")


func _fit_preview() -> void:
	if _preview == null or _camera == null or _pivot == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	UiFactory.fit_character_preview(
		_pivot,
		_preview,
		_camera,
		Vector2i(maxi(1, int(viewport_size.x)), maxi(1, int(viewport_size.y))),
		{
			"center_width_ratio": 0.55,
			"target_world_height": target_height,
			"max_scale": 2.0,
			"yaw": _yaw,
		}
	)
	_camera.look_at(Vector3(0.0, target_height * 0.5, 0.0), Vector3.UP)


func _update_info_label() -> void:
	if _info_label == null:
		return
	_info_label.text = "原型预览\n%s\ncharacter=%s  native=%s  rig=%s  idle=%s\n左键拖拽旋转 | R 重载" % [
		model_path,
		character_id,
		use_native_materials,
		inject_idle_rig,
		play_idle,
	]


func _process(delta: float) -> void:
	if auto_spin and not _dragging:
		_yaw += delta * spin_speed
		_pivot.rotation.y = _yaw


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		if button_event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = button_event.pressed
			_last_mouse_x = button_event.position.x
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		_yaw += (motion.position.x - _last_mouse_x) * 0.012
		_last_mouse_x = motion.position.x
		_pivot.rotation.y = _yaw
	elif event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_R:
			_reload_preview()
			_update_info_label()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		call_deferred("_fit_preview")
