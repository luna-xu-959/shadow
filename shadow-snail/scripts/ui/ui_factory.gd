class_name UiFactory
extends RefCounted

const PREVIEW_FOOT_Y := 0.0
const PREVIEW_CAPSULE_Y := 1.0


static func make_panel_style(bg: Color = Color(0.08, 0.1, 0.14, 0.92)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 16
	style.content_margin_top = 16
	style.content_margin_right = 16
	style.content_margin_bottom = 16
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.28, 0.34, 0.42)
	return style


static func make_button(text: String, min_width: float = 220.0) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(min_width, 44)
	return button


static func make_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 28)
	return label


static func make_subtitle(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92))
	return label


static func make_preview_mesh_instance(tint: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.45
	capsule.height = 1.2
	mesh_instance.mesh = capsule
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.85
	mesh_instance.material_override = material
	mesh_instance.position = Vector3(0.0, PREVIEW_CAPSULE_Y, 0.0)
	return mesh_instance


const CUSTOMIZABLE_WARDROBE_PARTS: Array[String] = ["top", "bottom", "hat"]

const BASE_APPEARANCE_TEXTURE_FILES: Dictionary = {
	"body": "body_basecolor.jpg",
}

const NATIVE_PART_TEXTURE_FILES: Dictionary = {
	"bottom": "bottom_basecolor.jpg",
	"hat": "hat_basecolor.jpg",
	"top": "top_basecolor.jpg",
}


const PREVIEW_NORMAL_HEIGHT := 2.0
const PREVIEW_HEIGHT_MIN := 0.2
const PREVIEW_HEIGHT_MAX := 6.0


static func make_character_preview(
	character_id: String,
	preserve_materials: bool = false,
	tint: Color = Color.WHITE,
	part_colors: Dictionary = {},
	use_native_materials: bool = false
) -> Node3D:
	var wrapper := Node3D.new()
	wrapper.name = "CharacterPreview"

	var model_path := _resolve_preview_model_path(character_id)
	var model_root := _load_preview_model(model_path)
	if model_root == null:
		if not model_path.is_empty():
			push_warning("角色预览加载失败，使用占位体：%s" % model_path)
		wrapper.add_child(make_preview_mesh_instance(tint))
		return wrapper

	_ensure_skinned_rig(model_root, character_id)

	if _count_mesh_instances(model_root) == 0:
		push_warning("角色模型无可见网格，使用占位体：%s" % model_path)
		model_root.queue_free()
		wrapper.add_child(make_preview_mesh_instance(tint))
		return wrapper

	wrapper.add_child(model_root)
	_bind_native_base_appearance(model_root, character_id)
	if use_native_materials:
		_bind_native_wardrobe_textures(model_root, character_id)
		if _count_textured_parts(model_root) < CUSTOMIZABLE_WARDROBE_PARTS.size():
			var fallback_colors := CharacterCatalog.get_character_part_colors(character_id)
			apply_wardrobe_part_colors(wrapper, _filter_customizable_part_colors(fallback_colors))
	elif not preserve_materials:
		apply_preview_tint(wrapper, tint)
	elif not part_colors.is_empty():
		apply_wardrobe_part_colors(wrapper, _filter_customizable_part_colors(part_colors))
	_prepare_wardrobe_preview_meshes(model_root)
	_play_idle_animation(wrapper, character_id, model_root)
	model_root.scale = Vector3.ONE
	model_root.position = Vector3.ZERO
	_align_preview_to_floor(model_root)
	_normalize_preview_height(model_root)
	return wrapper


## Load a specific FBX/scene path for isolated prototype preview (editor/dev).
static func make_prototype_preview(
	model_path: String,
	character_id: String = "default",
	use_native_materials: bool = true,
	inject_idle_rig: bool = true,
	play_idle: bool = true
) -> Node3D:
	var wrapper := Node3D.new()
	wrapper.name = "PrototypePreview"

	var resolved_path := model_path
	if resolved_path.is_empty():
		resolved_path = _resolve_preview_model_path(character_id)

	var model_root := _load_preview_model(resolved_path)
	if model_root == null:
		push_warning("角色原型加载失败：%s" % resolved_path)
		wrapper.add_child(make_preview_mesh_instance(Color(0.75, 0.75, 0.8)))
		return wrapper

	if inject_idle_rig:
		_ensure_skinned_rig(model_root, character_id)

	wrapper.add_child(model_root)
	if use_native_materials:
		_apply_native_part_appearance(model_root, character_id)
	if play_idle:
		_play_idle_animation(wrapper, character_id, model_root)
	_align_preview_to_floor(model_root)
	_normalize_preview_height(model_root)
	return wrapper


static func _load_preview_model(path: String) -> Node3D:
	if path.is_empty():
		return null

	var absolute_path := _to_absolute_path(path)
	if absolute_path.is_empty() or not FileAccess.file_exists(absolute_path):
		return null

	var model: Node3D = null
	if ResourceLoader.exists(path):
		var packed := _try_load_packed_scene(path)
		if packed != null:
			model = _prepare_loaded_scene(packed.instantiate())

	if model != null and _count_mesh_instances(model) > 0:
		return model
	if model != null:
		model.queue_free()

	if absolute_path.to_lower().ends_with(".fbx"):
		return _load_fbx_runtime(absolute_path)

	return null


static func _try_load_packed_scene(path: String) -> PackedScene:
	var resource: Resource = ResourceLoader.load(path)
	if resource is PackedScene:
		return resource as PackedScene
	return null


static func _load_fbx_runtime(absolute_path: String) -> Node3D:
	var doc := FBXDocument.new()
	var state := FBXState.new()
	var err := doc.append_from_file(absolute_path, state)
	if err != OK:
		push_warning("FBX 运行时导入失败 [%s]: %s" % [error_string(err), absolute_path])
		return null
	var scene := doc.generate_scene(state)
	if scene == null:
		push_warning("FBX 场景生成失败：%s" % absolute_path)
		return null
	return _prepare_loaded_scene(scene)


static func _prepare_loaded_scene(scene: Node) -> Node3D:
	_convert_importer_meshes(scene)
	return _ensure_node3d_root(scene)


static func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null


static func _apply_native_part_appearance(root: Node, character_id: String) -> void:
	_bind_native_base_appearance(root, character_id)
	_bind_native_wardrobe_textures(root, character_id)
	if _count_textured_parts(root) < CUSTOMIZABLE_WARDROBE_PARTS.size():
		var fallback_colors := CharacterCatalog.get_character_part_colors(character_id)
		apply_wardrobe_part_colors(root, _filter_customizable_part_colors(fallback_colors))


static func update_wardrobe_slots(
	preview_root: Node3D,
	character_id: String,
	part_colors: Dictionary,
	use_native_materials: bool
) -> void:
	if preview_root == null:
		return
	var model_root := _find_preview_model_root(preview_root)
	if model_root == null:
		return
	if use_native_materials:
		_bind_native_wardrobe_textures(model_root, character_id)
	elif not part_colors.is_empty():
		apply_wardrobe_part_colors(preview_root, _filter_customizable_part_colors(part_colors))


static func _find_preview_model_root(preview_root: Node3D) -> Node3D:
	for child in preview_root.get_children():
		if child is Node3D:
			return child as Node3D
	return preview_root


static func _filter_customizable_part_colors(part_colors: Dictionary) -> Dictionary:
	var filtered: Dictionary = {}
	for part in CUSTOMIZABLE_WARDROBE_PARTS:
		if part_colors.has(part):
			filtered[part] = part_colors[part]
	return filtered


static func _native_texture_search_dirs(character_id: String) -> Array[String]:
	var dirs: Array[String] = []
	for candidate in [
		"res://assets/characters/default/model",
		"res://assets/characters/default/animations",
		"%s/characters/default/model" % GamePaths.RESOURCE_ROOT,
		"%s/characters/default/animations" % GamePaths.RESOURCE_ROOT,
	]:
		if _resource_exists(candidate) and candidate not in dirs:
			dirs.append(candidate)
	var model_path := CharacterCatalog.get_model_resource_path(character_id)
	if not model_path.is_empty():
		var model_dir := model_path.get_base_dir()
		if model_dir not in dirs:
			dirs.append(model_dir)
	return dirs


static func _load_native_texture(filename: String, search_dirs: Array[String]) -> Texture2D:
	if filename.is_empty():
		return null
	for dir_path in search_dirs:
		var resource_path := "%s/%s" % [dir_path, filename]
		if ResourceLoader.exists(resource_path):
			var loaded: Resource = load(resource_path)
			if loaded is Texture2D:
				return loaded as Texture2D
		var absolute_path := _to_absolute_path(resource_path)
		if absolute_path.is_empty() or not FileAccess.file_exists(absolute_path):
			continue
		var image := Image.new()
		if image.load(absolute_path) == OK:
			return ImageTexture.create_from_image(image)
	return null


static func _resolve_part_texture(
	part: String,
	manifest_textures: Dictionary,
	search_dirs: Array[String]
) -> Texture2D:
	if manifest_textures.has(part):
		var manifest_texture := _load_texture_resource(str(manifest_textures[part]))
		if manifest_texture != null:
			return manifest_texture
	var filename := ""
	if BASE_APPEARANCE_TEXTURE_FILES.has(part):
		filename = str(BASE_APPEARANCE_TEXTURE_FILES[part])
	elif NATIVE_PART_TEXTURE_FILES.has(part):
		filename = str(NATIVE_PART_TEXTURE_FILES[part])
	if filename.is_empty():
		return null
	return _load_native_texture(filename, search_dirs)


static func _apply_native_texture_to_mesh(mesh_instance: MeshInstance3D, texture: Texture2D) -> void:
	if mesh_instance.mesh == null or texture == null:
		return
	for surface_idx in range(mesh_instance.mesh.get_surface_count()):
		var material := StandardMaterial3D.new()
		var base := mesh_instance.get_active_material(surface_idx)
		if base is StandardMaterial3D:
			material = (base as StandardMaterial3D).duplicate()
		material.albedo_texture = texture
		material.albedo_color = Color.WHITE
		mesh_instance.set_surface_override_material(surface_idx, material)


static func _mesh_has_albedo_texture(mesh_instance: MeshInstance3D) -> bool:
	if mesh_instance.mesh == null:
		return false
	for surface_idx in range(mesh_instance.mesh.get_surface_count()):
		var material := mesh_instance.get_surface_override_material(surface_idx)
		if material == null:
			material = mesh_instance.get_active_material(surface_idx)
		if material is StandardMaterial3D:
			if (material as StandardMaterial3D).albedo_texture != null:
				return true
	return false


static func _bind_native_base_appearance(root: Node, character_id: String) -> void:
	var manifest_textures := CharacterCatalog.get_character_part_textures(character_id)
	var search_dirs := _native_texture_search_dirs(character_id)
	var body_color: Color = CharacterCatalog.get_character_part_colors(character_id).get(
		"body",
		CharacterCatalog.DEFAULT_WARDROBE_PART_COLORS.get("body", Color.WHITE)
	)
	for mesh_node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var lower := mesh_instance.name.to_lower().strip_edges()
		if lower == "body":
			var texture := _resolve_part_texture("body", manifest_textures, search_dirs)
			if texture != null:
				_apply_native_texture_to_mesh(mesh_instance, texture)
			else:
				_apply_mesh_part_color(mesh_instance, body_color)
		elif lower.contains("eye") and not _mesh_has_albedo_texture(mesh_instance):
			# 眼睛优先保留 FBX 导入材质；仅在无贴图时用 body 色兜底
			_apply_mesh_part_color(mesh_instance, body_color)


static func _bind_native_wardrobe_textures(root: Node, character_id: String) -> void:
	var manifest_textures := CharacterCatalog.get_character_part_textures(character_id)
	var search_dirs := _native_texture_search_dirs(character_id)
	for mesh_node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var part := resolve_wardrobe_mesh_part(mesh_instance.name)
		if part.is_empty():
			continue
		var texture := _resolve_part_texture(part, manifest_textures, search_dirs)
		if texture == null:
			continue
		_apply_native_texture_to_mesh(mesh_instance, texture)


static func _bind_native_part_textures(root: Node, character_id: String) -> void:
	_bind_native_base_appearance(root, character_id)
	_bind_native_wardrobe_textures(root, character_id)


static func _load_texture_resource(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		var loaded: Resource = load(path)
		if loaded is Texture2D:
			return loaded as Texture2D
	var absolute_path := _to_absolute_path(path)
	if absolute_path.is_empty() or not FileAccess.file_exists(absolute_path):
		return null
	var image := Image.new()
	if image.load(absolute_path) != OK:
		return null
	return ImageTexture.create_from_image(image)


static func _count_textured_parts(root: Node) -> int:
	var count := 0
	for mesh_node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var part := resolve_wardrobe_mesh_part(mesh_instance.name)
		if part.is_empty():
			continue
		for surface_idx in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.get_surface_override_material(surface_idx)
			if material == null:
				material = mesh_instance.get_active_material(surface_idx)
			if material is StandardMaterial3D:
				var std := material as StandardMaterial3D
				if std.albedo_texture != null:
					count += 1
					break
	return count


static func _ensure_skinned_rig(model_root: Node3D, character_id: String) -> void:
	if _find_skeleton(model_root) != null:
		return
	if _count_mesh_instances(model_root) == 0:
		return
	var idle_root := _load_idle_rig_scene(character_id)
	if idle_root == null:
		return
	var idle_skeleton := _find_skeleton(idle_root)
	if idle_skeleton == null:
		idle_root.queue_free()
		return
	var armature_root: Node = idle_skeleton
	while armature_root.get_parent() != null and armature_root.get_parent() != idle_root:
		armature_root = armature_root.get_parent()
	model_root.add_child(armature_root.duplicate())
	idle_root.queue_free()


static func _load_idle_rig_scene(character_id: String) -> Node3D:
	for candidate in _idle_animation_candidates(character_id):
		if not _resource_exists(candidate):
			continue
		var idle_root := _load_preview_model(candidate)
		if idle_root != null and _find_skeleton(idle_root) != null:
			return idle_root
		if idle_root != null:
			idle_root.queue_free()
	return null


static func _convert_importer_meshes(root: Node) -> void:
	for node in root.find_children("*", "ImporterMeshInstance3D", true, false):
		if node.get_class() != "ImporterMeshInstance3D":
			continue
		var parent := node.get_parent()
		if parent == null:
			continue
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = node.name
		mesh_instance.transform = node.transform
		if node.get("skin") != null:
			mesh_instance.skin = node.skin
		var importer_mesh = node.get("mesh")
		if importer_mesh != null and importer_mesh.has_method("get_mesh"):
			var mesh: Mesh = importer_mesh.get_mesh()
			mesh_instance.mesh = mesh
			if mesh != null:
				for surface_idx in range(mesh.get_surface_count()):
					var surface_mat := mesh.surface_get_material(surface_idx)
					if surface_mat != null:
						mesh_instance.set_surface_override_material(surface_idx, surface_mat)
		if node.get("material_override") != null:
			mesh_instance.material_override = node.material_override
		parent.remove_child(node)
		parent.add_child(mesh_instance)
		node.queue_free()


static func _ensure_node3d_root(node: Node) -> Node3D:
	if node is Node3D:
		return node as Node3D
	var root := Node3D.new()
	root.name = "ModelRoot"
	root.add_child(node)
	return root


static func _to_absolute_path(path: String) -> String:
	if path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	if path.begins_with("uid://"):
		return ""
	return path


static func _resolve_preview_model_path(character_id: String) -> String:
	for candidate in _preview_model_candidates(character_id):
		if _resource_exists(candidate):
			return candidate
	return ""


static func _idle_animation_candidates(character_id: String) -> Array[String]:
	var candidates: Array[String] = []
	var idle_path := CharacterCatalog.get_idle_animation_resource_path(character_id)
	if idle_path.is_empty():
		return candidates
	candidates.append(idle_path)
	if GamePaths.DEFAULT_CHARACTER_IDLE_ANIMATION not in candidates:
		candidates.append(GamePaths.DEFAULT_CHARACTER_IDLE_ANIMATION)
	if GamePaths.DEFAULT_CHARACTER_IDLE_ANIMATION_EXTERNAL not in candidates:
		candidates.append(GamePaths.DEFAULT_CHARACTER_IDLE_ANIMATION_EXTERNAL)
	return candidates


static func _preview_model_candidates(character_id: String) -> Array[String]:
	var candidates: Array[String] = []
	var model_path := CharacterCatalog.get_model_resource_path(character_id)
	if model_path.is_empty():
		return candidates
	candidates.append(model_path)
	if GamePaths.DEFAULT_CHARACTER_MODEL not in candidates:
		candidates.append(GamePaths.DEFAULT_CHARACTER_MODEL)
	if GamePaths.DEFAULT_CHARACTER_MODEL_EXTERNAL not in candidates:
		candidates.append(GamePaths.DEFAULT_CHARACTER_MODEL_EXTERNAL)
	return candidates


static func _resource_exists(path: String) -> bool:
	if path.is_empty():
		return false
	if ResourceLoader.exists(path):
		return true
	if FileAccess.file_exists(path):
		return true
	var absolute := _to_absolute_path(path)
	return not absolute.is_empty() and FileAccess.file_exists(absolute)


static func resolve_wardrobe_mesh_part(mesh_name: String) -> String:
	var lower := mesh_name.to_lower().strip_edges()
	for part in CUSTOMIZABLE_WARDROBE_PARTS:
		if lower == part:
			return part
	for part in CUSTOMIZABLE_WARDROBE_PARTS:
		if lower.ends_with("_%s" % part) or lower.begins_with("%s_" % part):
			return part
	return ""


static func is_base_appearance_mesh(mesh_name: String) -> bool:
	var lower := mesh_name.to_lower().strip_edges()
	if lower == "body" or lower.ends_with("_body") or lower.begins_with("body_"):
		return true
	if lower.contains("eye"):
		return true
	return false


static func should_show_preview_mesh(mesh_name: String) -> bool:
	if is_base_appearance_mesh(mesh_name):
		return true
	return not resolve_wardrobe_mesh_part(mesh_name).is_empty()


static func apply_wardrobe_part_colors(root: Node, part_colors: Dictionary) -> void:
	if root == null or part_colors.is_empty():
		return
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var part := resolve_wardrobe_mesh_part(mesh_instance.name)
		if part.is_empty() or not part_colors.has(part):
			continue
		_apply_mesh_part_color(mesh_instance, part_colors[part])


static func _apply_mesh_part_color(mesh_instance: MeshInstance3D, color: Color) -> void:
	mesh_instance.material_override = null
	for surface_idx in range(mesh_instance.mesh.get_surface_count()):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.albedo_texture = null
		material.roughness = 0.75
		mesh_instance.set_surface_override_material(surface_idx, material)


static func apply_preview_tint(node: Node, tint: Color) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			return
		var material := StandardMaterial3D.new()
		var base := mesh_instance.get_active_material(0)
		if base is StandardMaterial3D:
			var src := base as StandardMaterial3D
			material.albedo_texture = src.albedo_texture
			material.normal_texture = src.normal_texture
			material.roughness = src.roughness
			material.metallic = src.metallic
		material.albedo_color = tint
		if material.albedo_texture == null:
			material.roughness = 0.75
		mesh_instance.material_override = material
	for child in node.get_children():
		apply_preview_tint(child, tint)


static func _apply_tint_recursive(node: Node, tint: Color) -> void:
	apply_preview_tint(node, tint)


static func _play_idle_animation(wrapper: Node3D, character_id: String, model_root: Node3D) -> void:
	var player := _find_animation_player(model_root)
	if player == null:
		player = _find_animation_player(wrapper)
	if player == null:
		player = AnimationPlayer.new()
		player.name = "PreviewAnimationPlayer"
		model_root.add_child(player)

	for anim_name in ["idle", "Idle", "IDLE", "mixamo_com"]:
		if player.has_animation(anim_name):
			player.play(anim_name)
			return

	var existing := player.get_animation_list()
	if not existing.is_empty():
		player.play(existing[0])
		return

	var idle_path := ""
	for candidate in _idle_animation_candidates(character_id):
		if _resource_exists(candidate):
			idle_path = candidate
			break
	if idle_path.is_empty():
		return

	var idle_resource: Resource = null
	if ResourceLoader.exists(idle_path):
		idle_resource = load(idle_path)
	if idle_resource == null and idle_path.to_lower().ends_with(".fbx"):
		var absolute_path := _to_absolute_path(idle_path)
		if not absolute_path.is_empty():
			var idle_scene := _load_fbx_runtime(absolute_path)
			if idle_scene != null:
				var idle_player := _find_animation_player(idle_scene)
				if idle_player != null:
					_copy_animations(idle_player, player)
				idle_scene.queue_free()
				for anim_name in ["idle", "Idle", "IDLE", "mixamo_com"]:
					if player.has_animation(anim_name):
						player.play(anim_name)
						return
				if not player.get_animation_list().is_empty():
					player.play(player.get_animation_list()[0])
				return

	if idle_resource == null:
		return

	if idle_resource is PackedScene:
		var temp := (idle_resource as PackedScene).instantiate()
		var idle_player := _find_animation_player(temp)
		if idle_player != null:
			_copy_animations(idle_player, player)
		temp.queue_free()
		for anim_name in ["idle", "Idle", "IDLE", "mixamo_com"]:
			if player.has_animation(anim_name):
				player.play(anim_name)
				return
		if not player.get_animation_list().is_empty():
			player.play(player.get_animation_list()[0])


static func _copy_animations(from_player: AnimationPlayer, to_player: AnimationPlayer) -> void:
	var lib_name := StringName("")
	var lib := to_player.get_animation_library(lib_name)
	if lib == null:
		lib = AnimationLibrary.new()
		to_player.add_animation_library(lib_name, lib)
	for anim_name in from_player.get_animation_list():
		var animation := from_player.get_animation(anim_name)
		if animation != null:
			var key := StringName(anim_name)
			if lib.has_animation(key):
				lib.remove_animation(key)
			lib.add_animation(key, animation.duplicate())


static func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null


static func count_mesh_instances(root: Node) -> int:
	return _count_mesh_instances(root)


static func compute_combined_bounds(root: Node) -> AABB:
	return _compute_combined_bounds(root)


static func _count_mesh_instances(root: Node) -> int:
	return root.find_children("*", "MeshInstance3D", true, false).size()


static func _ensure_preview_meshes_visible(root: Node) -> void:
	for mesh_node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		mesh_instance.visible = true
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _prepare_wardrobe_preview_meshes(root: Node) -> void:
	for mesh_node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		mesh_instance.visible = should_show_preview_mesh(mesh_instance.name)
		if mesh_instance.visible:
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _transform_to_ancestor(node: Node3D, ancestor: Node) -> Transform3D:
	var chain: Array[Node3D] = []
	var current: Node = node
	while current != null and current != ancestor:
		if current is Node3D:
			chain.append(current as Node3D)
		current = current.get_parent()
	var xf := Transform3D.IDENTITY
	for i in range(chain.size() - 1, -1, -1):
		xf = xf * chain[i].transform
	return xf


static func _compute_visual_bounds(root: Node, wardrobe_only: bool = false) -> AABB:
	var bounds := AABB()
	var started := false
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		if wardrobe_only:
			if not mesh_instance.visible:
				continue
			if not should_show_preview_mesh(mesh_instance.name):
				continue
		var local_aabb := mesh_instance.mesh.get_aabb()
		if local_aabb.size.length_squared() <= 0.0001:
			continue
		var mesh_xf: Transform3D
		if mesh_instance.is_inside_tree():
			mesh_xf = mesh_instance.global_transform
		else:
			mesh_xf = _transform_to_ancestor(mesh_instance, root)
		var world_aabb := local_aabb * mesh_xf
		if world_aabb.size.length_squared() <= 0.0001:
			continue
		if not started:
			bounds = world_aabb
			started = true
		else:
			bounds = bounds.merge(world_aabb)
	return bounds


static func _compute_skeleton_bounds(root: Node) -> AABB:
	var bounds := AABB()
	var started := false
	for node in root.find_children("*", "Skeleton3D", true, false):
		var skeleton := node as Skeleton3D
		var skel_xf: Transform3D
		if skeleton.is_inside_tree():
			skel_xf = skeleton.global_transform
		else:
			skel_xf = _transform_to_ancestor(skeleton, root)
		for bone_idx in skeleton.get_bone_count():
			var bone_xf := skel_xf * skeleton.get_bone_rest(bone_idx)
			var pos := bone_xf.origin
			if not started:
				bounds = AABB(pos, Vector3.ZERO)
				started = true
			else:
				bounds = bounds.expand(pos)
	return bounds


static func _compute_combined_bounds(root: Node, wardrobe_only: bool = false) -> AABB:
	var mesh_bounds := _compute_visual_bounds(root, wardrobe_only)
	var skeleton_bounds := AABB()
	if not wardrobe_only:
		skeleton_bounds = _compute_skeleton_bounds(root)
	if mesh_bounds.size.length_squared() <= 0.0001:
		return skeleton_bounds
	if skeleton_bounds.size.length_squared() <= 0.0001:
		return mesh_bounds
	if skeleton_bounds.size.y > mesh_bounds.size.y * 4.0:
		return mesh_bounds
	return mesh_bounds.merge(skeleton_bounds)


static func _normalize_preview_height(model_root: Node3D, target_height: float = PREVIEW_NORMAL_HEIGHT) -> void:
	var bounds := _compute_combined_bounds(model_root, true)
	if bounds.size.y <= 0.001:
		push_warning("角色预览无法计算边界，跳过高度归一化")
		return
	var factor := target_height / bounds.size.y
	factor = clampf(factor, 0.00000001, 100.0)
	model_root.scale = Vector3.ONE * factor
	_align_preview_to_floor(model_root)


static func _align_preview_to_floor(model_root: Node3D) -> void:
	var bounds := _compute_combined_bounds(model_root, true)
	if bounds.size.length_squared() <= 0.0001:
		model_root.position = Vector3(0.0, PREVIEW_CAPSULE_Y, 0.0)
		return
	var center_x := bounds.position.x + bounds.size.x * 0.5
	var center_z := bounds.position.z + bounds.size.z * 0.5
	model_root.position += Vector3(-center_x, PREVIEW_FOOT_Y - bounds.position.y, -center_z)


static func fit_character_preview(
	pivot: Node3D,
	preview: Node3D,
	camera: Camera3D,
	viewport_size: Vector2i,
	opts: Dictionary = {}
) -> void:
	if pivot == null or preview == null or camera == null:
		return

	var center_width_ratio: float = float(opts.get("center_width_ratio", 0.22))
	var target_world_height: float = float(opts.get("target_world_height", -1.0))
	var max_scale: float = float(opts.get("max_scale", 0.095))
	var yaw: float = float(opts.get("yaw", 0.0))
	var face_y_deg: float = float(opts.get("face_y_deg", 0.0))
	var fixed_look: Variant = opts.get("look_target", null)

	pivot.rotation = Vector3(0.0, yaw + deg_to_rad(face_y_deg), 0.0)
	pivot.scale = Vector3.ONE

	var bounds := _compute_combined_bounds(preview, true)
	var model_h := bounds.size.y
	var model_w := maxf(bounds.size.x, bounds.size.z)

	if model_h <= 0.001 or model_w <= 0.001:
		pivot.scale = Vector3.ONE * max_scale
		return

	var look_target: Vector3
	if fixed_look is Vector3:
		look_target = fixed_look as Vector3
	else:
		look_target = bounds.get_center()
	camera.look_at(look_target, Vector3.UP)

	var dist := camera.global_position.distance_to(look_target)
	if dist <= 0.001:
		return

	var fov_y := deg_to_rad(camera.fov)
	var aspect := viewport_size.x / float(maxi(viewport_size.y, 1))
	var frustum_h := 2.0 * tan(fov_y * 0.5) * dist
	var frustum_w := frustum_h * aspect
	var target_w := frustum_w * center_width_ratio

	var scale_factor := 1.0
	if target_world_height > 0.0:
		scale_factor = minf(target_world_height / model_h, target_w / model_w)
	else:
		scale_factor = minf(frustum_h * 0.32 / model_h, target_w / model_w)
	scale_factor = minf(scale_factor, max_scale)
	scale_factor = maxf(scale_factor, 0.0001)
	pivot.scale = Vector3.ONE * scale_factor
	pivot.rotation.y = yaw + deg_to_rad(face_y_deg)
