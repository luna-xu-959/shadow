extends Control

## Full-screen UI root under CanvasLayer — tracks viewport size on every resize.


func _ready() -> void:
	_sync_to_viewport()
	get_viewport().size_changed.connect(_sync_to_viewport)
	get_tree().root.size_changed.connect(_sync_to_viewport)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED or what == NOTIFICATION_ENTER_TREE:
		call_deferred("_sync_to_viewport")


func _sync_to_viewport() -> void:
	var rect := get_viewport().get_visible_rect()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)
	set_size(rect.size)
	position = rect.position
