extends Node

const OUTPUT_PATH := "res://Saved/VerifyCharacterPreview.txt"


func _ready() -> void:
	var lines: PackedStringArray = []
	lines.append("VerifyCharacterPreview")
	SessionState.selected_character_id = "snail"
	var preview := UiFactory.make_character_preview("snail", true, Color.WHITE, {}, true)
	var model_path := UiFactory._resolve_preview_model_path("snail")
	var bounds := UiFactory.compute_combined_bounds(preview)
	var capsule := 0
	var meshes := 0
	var wardrobe_parts := 0
	var textured_parts := 0
	var colored_parts := 0
	var skeletons := 0
	var animation_players := 0
	var playing_anim := ""
	for node in preview.find_children("*", "Skeleton3D", true, false):
		skeletons += 1
	for node in preview.find_children("*", "AnimationPlayer", true, false):
		animation_players += 1
		var player := node as AnimationPlayer
		if not player.current_animation.is_empty():
			playing_anim = player.current_animation
	for node in preview.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		meshes += 1
		if mesh_instance.mesh is CapsuleMesh:
			capsule += 1
		var part := UiFactory.resolve_wardrobe_mesh_part(mesh_instance.name)
		if part.is_empty():
			continue
		wardrobe_parts += 1
		if mesh_instance.mesh != null:
			for surface_idx in range(mesh_instance.mesh.get_surface_count()):
				var material := mesh_instance.get_surface_override_material(surface_idx)
				if material == null:
					material = mesh_instance.get_active_material(surface_idx)
				if material is StandardMaterial3D:
					var std := material as StandardMaterial3D
					if std.albedo_texture != null:
						textured_parts += 1
						break
					if std.albedo_color != Color.WHITE:
						colored_parts += 1
						break
	lines.append("model_path=%s" % model_path)
	lines.append("bounds_height=%.4f" % bounds.size.y)
	lines.append("mesh_instances=%d" % meshes)
	lines.append("capsule_meshes=%d" % capsule)
	lines.append("skeletons=%d" % skeletons)
	lines.append("animation_players=%d" % animation_players)
	lines.append("playing_animation=%s" % playing_anim)
	lines.append("wardrobe_parts=%d" % wardrobe_parts)
	lines.append("colored_parts=%d" % colored_parts)
	lines.append("textured_parts=%d" % textured_parts)
	var ok := (
		capsule == 0
		and wardrobe_parts >= 3
		and skeletons >= 1
		and animation_players >= 1
		and not playing_anim.is_empty()
		and textured_parts >= 3
	)
	lines.append("ok=%s" % str(ok))
	var text := "\n".join(lines) + "\n"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Saved"))
	var file := FileAccess.open(ProjectSettings.globalize_path(OUTPUT_PATH), FileAccess.WRITE)
	if file:
		file.store_string(text)
	print(text)
	get_tree().quit(0 if ok else 1)
