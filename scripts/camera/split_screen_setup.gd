extends CanvasLayer

## Split-screen display: cameras live on Main; RenderingServer routes each to its panel.

@onready var _vp_left: SubViewport = $LayoutRoot/ViewportLeft/SubViewport
@onready var _vp_right: SubViewport = $LayoutRoot/ViewportRight/SubViewport


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

	cam0.current = false
	cam1.current = false
	RenderingServer.viewport_attach_camera(_vp_left.get_viewport_rid(), cam0.get_camera_rid())
	RenderingServer.viewport_attach_camera(_vp_right.get_viewport_rid(), cam1.get_camera_rid())


func enable_split_view() -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	get_parent().get_viewport().disable_3d = true


func disable_split_view() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	get_parent().get_viewport().disable_3d = false
