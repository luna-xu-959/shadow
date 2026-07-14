extends Node

const OUTPUT_PATH := "res://Saved/DiagnoseWardrobePreview.txt"


func _ready() -> void:
	var lines: PackedStringArray = []
	lines.append("DiagnoseWardrobePreview")
	SessionState.selected_character_id = "snail"
	SessionState.reset_wardrobe_part_colors()

	var model_path := UiFactory._resolve_preview_model_path("snail")
	lines.append("model_path=%s" % model_path)
	lines.append("model_exists=%s" % str(FileAccess.file_exists(ProjectSettings.globalize_path(model_path))))

	var packed_root := UiFactory._load_preview_model(model_path)
	if packed_root == null:
		lines.append("load_result=null")
	else:
		lines.append("load_result=ok")
		lines.append("skeletons=%d" % packed_root.find_children("*", "Skeleton3D", true, false).size())
		lines.append("meshes_before_rig=%d" % UiFactory.count_mesh_instances(packed_root))
		var bounds := UiFactory.compute_combined_bounds(packed_root)
		lines.append("bounds_before=%s size=%s" % [str(bounds.position), str(bounds.size)])
		for mesh_node in packed_root.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := mesh_node as MeshInstance3D
			lines.append(
				"mesh name=%s has_mesh=%s skin=%s" % [
					mesh_instance.name,
					mesh_instance.mesh != null,
					mesh_instance.skin != null,
				]
			)
		packed_root.queue_free()

	var preview := UiFactory.make_character_preview("snail", true, Color.WHITE, {}, true)
	lines.append("preview_children=%d" % preview.get_child_count())
	var model_root := preview.get_child(0) as Node3D
	if model_root:
		lines.append("model_root_scale=%s" % str(model_root.scale))
	lines.append("preview_meshes=%d" % UiFactory.count_mesh_instances(preview))
	var preview_bounds := UiFactory.compute_combined_bounds(preview)
	lines.append("preview_bounds=%s size=%s" % [str(preview_bounds.position), str(preview_bounds.size)])
	lines.append("textured_parts=%d" % UiFactory._count_textured_parts(preview))

	_write(lines)
	get_tree().quit(0)


func _write(lines: PackedStringArray) -> void:
	var text := "\n".join(lines) + "\n"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Saved"))
	var file := FileAccess.open(ProjectSettings.globalize_path(OUTPUT_PATH), FileAccess.WRITE)
	if file:
		file.store_string(text)
	print(text)
