extends CanvasLayer

## Split-screen display: cameras live on Main; RenderingServer routes each to its panel.

@onready var _vp_left: SubViewport = $ViewportLeft/SubViewport
@onready var _vp_right: SubViewport = $ViewportRight/SubViewport


func _ready() -> void:
	var main := get_parent() as Node3D
	if main == null:
		return

	var world: World3D = main.get_world_3d()
	if world == null:
		return

	_vp_left.world_3d = world
	_vp_right.world_3d = world

	var cam0 := main.get_node_or_null("CameraP0") as Camera3D
	var cam1 := main.get_node_or_null("CameraP1") as Camera3D
	if cam0 == null or cam1 == null:
		push_error("SplitScreen: missing CameraP0/CameraP1 on Main.")
		return

	# Cameras stay in the main tree but render into the split panels.
	cam0.current = false
	cam1.current = false
	RenderingServer.viewport_attach_camera(_vp_left.get_viewport_rid(), cam0.get_camera_rid())
	RenderingServer.viewport_attach_camera(_vp_right.get_viewport_rid(), cam1.get_camera_rid())

	# Hide the root 3D pass (no root camera); only the sub-viewports draw the world.
	main.get_viewport().disable_3d = true

	get_tree().root.size_changed.connect(_sync_panel_layout)
	call_deferred("_sync_panel_layout")


func _sync_panel_layout() -> void:
	var size := get_viewport().get_visible_rect().size
	if size.x < 64.0:
		var window_size: Vector2i = get_viewport().get_window().size
		size = Vector2(window_size)
	if size.x < 64.0:
		size = Vector2(1280, 720)

	var half_w := size.x * 0.5
	var h := size.y

	var left := $ViewportLeft as Control
	var right := $ViewportRight as Control
	left.set_position(Vector2.ZERO)
	left.set_size(Vector2(half_w, h))
	right.set_position(Vector2(half_w, 0.0))
	right.set_size(Vector2(half_w, h))
