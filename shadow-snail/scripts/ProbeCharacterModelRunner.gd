extends Node

const OUTPUT_PATH := "res://Saved/ProbeCharacterModel.txt"


func _ready() -> void:
	var lines: PackedStringArray = []
	lines.append("ProbeCharacterModel")
	for label_path in [
		["body", GamePaths.DEFAULT_CHARACTER_MODEL],
		["idle", GamePaths.DEFAULT_CHARACTER_IDLE_ANIMATION],
		["assembled", ""],
	]:
		var label: String = label_path[0]
		var path: String = label_path[1]
		var root: Node3D = null
		if label == "assembled":
			root = UiFactory.make_character_preview("default", true, Color.WHITE, {}, true)
			lines.append("[%s] children=%d meshes=%d" % [
				label,
				root.get_child_count(),
				root.find_children("*", "MeshInstance3D", true, false).size(),
			])
		else:
			lines.append("[%s] path=%s" % [label, path])
			var packed: PackedScene = load(path)
			if packed == null:
				lines.append("  load_failed=true")
				continue
			root = packed.instantiate()
		_dump_materials(root, lines, "  ")
		root.queue_free()
	_write(lines)


func _dump_materials(root: Node, lines: PackedStringArray, indent: String) -> void:
	for mesh_node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var part := UiFactory.resolve_wardrobe_mesh_part(mesh_instance.name)
		lines.append("%smesh=%s part=%s override=%s" % [
			indent,
			mesh_instance.name,
			part,
			mesh_instance.material_override != null,
		])
		for surface_idx in range(mesh_instance.mesh.get_surface_count()):
			var mesh_mat := mesh_instance.mesh.surface_get_material(surface_idx)
			var active_mat := mesh_instance.get_active_material(surface_idx)
			var override_mat := mesh_instance.get_surface_override_material(surface_idx)
			lines.append("%s  surface_%d mesh_mat=%s" % [indent, surface_idx, _mat_info(mesh_mat)])
			lines.append("%s  surface_%d active=%s" % [indent, surface_idx, _mat_info(active_mat)])
			lines.append("%s  surface_%d override=%s" % [indent, surface_idx, _mat_info(override_mat)])


func _mat_info(material: Material) -> String:
	if material == null:
		return "null"
	if material is StandardMaterial3D:
		var std := material as StandardMaterial3D
		var tex := "null"
		if std.albedo_texture != null:
			tex = std.albedo_texture.resource_path
		return "albedo=%s tex=%s" % [str(std.albedo_color), tex]
	return material.get_class()


func _write(lines: PackedStringArray) -> void:
	var text := "\n".join(lines) + "\n"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Saved"))
	var file := FileAccess.open(ProjectSettings.globalize_path(OUTPUT_PATH), FileAccess.WRITE)
	if file:
		file.store_string(text)
	print(text)
	get_tree().quit(0)
