extends Control

enum WardrobeTab { TOP, BOTTOM, WAIST, NECKLACE, HEAD }

const TAB_KEYS: Array[String] = ["top", "bottom", "waist", "necklace", "head"]
const CLOTHING_TABS: Array[WardrobeTab] = [WardrobeTab.TOP, WardrobeTab.BOTTOM]
const ACCESSORY_SLOTS: Dictionary = {
	"none": ["waist", "necklace", "head"],
	"shell_spikes": ["waist"],
	"scarf": ["necklace"],
	"goggles": ["head"],
	"party_hat": ["head"],
}
const GRID_COLUMNS := 4
const GRID_ROWS := 2
const PALETTE_SWATCH_COLUMNS := 6
const PALETTE_SWATCH_ROWS := 3
const PALETTE_INSET_LEFT := 0.06
const PALETTE_INSET_RIGHT := 0.94
const PALETTE_INSET_TOP := 0.20
const PALETTE_INSET_BOTTOM := 0.76
const PALETTE_WHEEL_WIDTH_RATIO := 0.96
const PALETTE_GRID_MAX_HEIGHT_RATIO := 0.24
const PANEL_Y_ROT := 2.0
const PANEL_X_ROT := 0.0
const PANEL_HEIGHT := 2.22
const PANEL_WIDTH_RATIO := 0.33
const PANEL_HEIGHT_RATIO := 1.0
const PANEL_H_SPACING := 2.08
const PANEL_Z_OFFSET := -0.06
const PANEL_Y_LIFT := 0.32
const PANEL_VERTICAL_MARGIN := 0.12
const SCENE_LOOK_Y_RATIO := 0.46
const CHARACTER_Z := 0.18
const CHARACTER_PIVOT_DROP := 0.48
const CHARACTER_LOOK_Y_OFFSET := 0.50
const CHARACTER_ROTATE_SENSITIVITY := 0.012
const CAMERA_HEIGHT := 1.42
const CAMERA_DISTANCE := 4.2
const CAMERA_FOV := 38.0
const SCENE_FALLBACK_SIZE := Vector2(1280.0, 544.0)

const PRESET_COLORS: Array[Color] = [
	Color("#00CED1"), Color("#32CD32"), Color("#228B22"), Color("#8A2BE2"), Color("#FFFFFF"), Color("#1A1A1A"),
	Color("#87CEEB"), Color("#FF69B4"), Color("#FFD700"), Color("#FF8C00"), Color("#000080"), Color("#4169E1"),
	Color("#FFB6C1"), Color("#FFDAB9"), Color("#FFF8DC"), Color("#D2B48C"), Color("#C0C0C0"), Color("#36454F"),
]

@onready var _background: TextureRect = %Background
@onready var _clothing_panel_unified: TextureRect = %ClothingPanelUnified
@onready var _clothing_ui_viewport: SubViewport = %ClothingUiViewport
@onready var _palette_ui_viewport: SubViewport = %PaletteUiViewport
@onready var _palette_panel_blank: TextureRect = %PalettePanelBlank
@onready var _palette_insets: Control = %PaletteInsets
@onready var _palette_vbox: VBoxContainer = %PaletteVBox
@onready var _wardrobe_scene_container: SubViewportContainer = %WardrobeSceneContainer
@onready var _wardrobe_scene_viewport: SubViewport = %WardrobeSceneViewport
@onready var _wardrobe_camera: Camera3D = %WardrobeCamera
@onready var _left_panel_pivot: Node3D = %LeftPanelPivot
@onready var _left_panel_mesh: MeshInstance3D = %LeftPanelMesh
@onready var _character_pivot: Node3D = %CharacterPivot
@onready var _right_panel_pivot: Node3D = %RightPanelPivot
@onready var _right_panel_mesh: MeshInstance3D = %RightPanelMesh
@onready var _tab_row: HBoxContainer = %TabRow
@onready var _item_grid: GridContainer = %ItemGrid
@onready var _color_picker: ColorPicker = %ColorPicker
@onready var _color_grid: GridContainer = %ColorGrid
@onready var _name_label: Label = %NameLabel

var _active_tab: WardrobeTab = WardrobeTab.TOP
var _tab_buttons: Array[Button] = []
var _item_slots: Array[Control] = []
var _preview_character: Node3D
var _picker_syncing := false
var _character_yaw := 0.0
var _character_dragging := false
var _panel_height := PANEL_HEIGHT
var _left_panel_material: StandardMaterial3D
var _right_panel_material: StandardMaterial3D
var _scene_look_y := 0.0
var _needs_initial_preview := true


func _ready() -> void:
	_apply_background()
	_setup_unified_panels()
	_setup_header()
	_build_tabs()
	_style_palette_embed()
	_build_color_palette()
	call_deferred("_setup_wardrobe_scene")
	if not SessionState.has_character():
		GameFlow.go_to_character_select()
		return
	SessionState.ensure_wardrobe_part_colors()
	_refresh_item_grid()
	_sync_color_picker()


func _apply_background() -> void:
	var bg_path := GamePaths.WARDROBE_BACKGROUND
	if not FileAccess.file_exists(bg_path):
		push_warning("换装背景未找到：%s" % bg_path)
		return
	var texture: Texture2D = load(bg_path)
	if texture == null:
		var image := Image.new()
		var absolute_path := ProjectSettings.globalize_path(bg_path)
		if image.load(absolute_path) != OK:
			push_warning("换装背景加载失败：%s" % bg_path)
			return
		texture = ImageTexture.create_from_image(image)
	_background.texture = texture


func _setup_unified_panels() -> void:
	_apply_unified_panel_texture(_clothing_panel_unified, ResourceUi.get_texture("clothing_panel"))
	_apply_unified_panel_texture(_palette_panel_blank, ResourceUi.get_texture("palette_panel_blank"))


func _style_palette_embed() -> void:
	if _color_picker == null or _color_grid == null:
		push_warning("调色板节点未就绪，跳过样式初始化")
		return
	_color_picker.edit_alpha = false
	_color_picker.edit_intensity = false
	_color_picker.hex_visible = false
	_color_picker.presets_visible = false
	_color_picker.sampler_visible = false
	_color_picker.can_add_swatches = false
	_color_picker.color_modes_visible = false
	_color_picker.sliders_visible = false
	_color_picker.picker_shape = ColorPicker.SHAPE_HSV_WHEEL
	_color_picker.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_color_picker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_color_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_color_grid.columns = PALETTE_SWATCH_COLUMNS
	if _palette_vbox:
		_palette_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_palette_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_palette_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	call_deferred("_strip_color_picker_chrome")
	var empty_style := StyleBoxEmpty.new()
	_color_picker.add_theme_stylebox_override("background", empty_style)
	_color_picker.add_theme_stylebox_override("panel", empty_style)
	for margin_name in ["content_margin_left", "content_margin_top", "content_margin_right", "content_margin_bottom"]:
		_color_picker.add_theme_constant_override(margin_name, 0)


func _strip_color_picker_chrome() -> void:
	if _color_picker == null:
		return
	var empty_style := StyleBoxEmpty.new()
	for child in _color_picker.get_children():
		if child is Button:
			child.visible = false
		elif child is Control:
			_clear_control_panel_backgrounds(child as Control, empty_style)


func _clear_control_panel_backgrounds(control: Control, empty_style: StyleBoxEmpty) -> void:
	control.add_theme_stylebox_override("panel", empty_style)
	control.add_theme_stylebox_override("background", empty_style)
	control.add_theme_stylebox_override("normal", empty_style)
	for child in control.get_children():
		if child is Button:
			child.visible = false
		elif child is Control:
			_clear_control_panel_backgrounds(child as Control, empty_style)


func _setup_wardrobe_scene() -> void:
	if _wardrobe_scene_container == null or _clothing_ui_viewport == null or _palette_ui_viewport == null:
		push_warning("换装 3D 场景节点未就绪")
		return

	_clothing_ui_viewport.transparent_bg = true
	_clothing_ui_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_palette_ui_viewport.transparent_bg = true
	_palette_ui_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_wardrobe_scene_viewport.transparent_bg = true
	_wardrobe_scene_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_strip_color_picker_chrome()

	_left_panel_material = _make_panel_material(_clothing_ui_viewport.get_texture())
	_right_panel_material = _make_panel_material(_palette_ui_viewport.get_texture())
	_left_panel_mesh.material_override = _left_panel_material
	_right_panel_mesh.material_override = _right_panel_material

	if not _wardrobe_scene_container.resized.is_connected(_update_wardrobe_scene_layout):
		_wardrobe_scene_container.resized.connect(_update_wardrobe_scene_layout)
	if not _wardrobe_scene_container.gui_input.is_connected(_on_wardrobe_scene_gui_input):
		_wardrobe_scene_container.gui_input.connect(_on_wardrobe_scene_gui_input)
	call_deferred("_update_wardrobe_scene_layout")


func _make_panel_material(texture: Texture2D) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	return material


func _update_wardrobe_scene_layout() -> void:
	if _wardrobe_scene_container == null or _left_panel_mesh == null or _right_panel_mesh == null:
		return

	var scene_size := _wardrobe_scene_container.size
	if scene_size.x <= 1.0 or scene_size.y <= 1.0:
		scene_size = SCENE_FALLBACK_SIZE

	var panel_ui_width := scene_size.x * PANEL_WIDTH_RATIO
	var panel_ui_height := scene_size.y * PANEL_HEIGHT_RATIO
	var panel_pixel_size := Vector2i(maxi(1, int(panel_ui_width)), maxi(1, int(panel_ui_height)))
	_clothing_ui_viewport.size = panel_pixel_size
	_palette_ui_viewport.size = panel_pixel_size
	_apply_clothing_layout(panel_pixel_size)
	_apply_palette_layout(panel_pixel_size)
	_wardrobe_scene_viewport.size = Vector2i(int(scene_size.x), int(scene_size.y))
	_wardrobe_camera.fov = CAMERA_FOV

	var layout := _compute_wardrobe_vertical_layout()
	var panel_height: float = layout["panel_height"]
	var panel_base_y: float = layout["panel_base_y"]
	_panel_height = panel_height
	_scene_look_y = layout["look_y"]

	var panel_aspect := panel_ui_width / panel_ui_height
	var quad_size := Vector2(panel_aspect * panel_height, panel_height)
	var left_quad := QuadMesh.new()
	left_quad.size = quad_size
	_left_panel_mesh.mesh = left_quad
	var right_quad := QuadMesh.new()
	right_quad.size = quad_size
	_right_panel_mesh.mesh = right_quad

	var mesh_lift := Vector3(0.0, panel_height * 0.5, 0.0)
	_left_panel_mesh.position = mesh_lift
	_right_panel_mesh.position = mesh_lift

	if _left_panel_material:
		_left_panel_material.albedo_texture = _clothing_ui_viewport.get_texture()
	if _right_panel_material:
		_right_panel_material.albedo_texture = _palette_ui_viewport.get_texture()

	var spacing := PANEL_H_SPACING * (scene_size.x / SCENE_FALLBACK_SIZE.x)
	var panel_z := PANEL_Z_OFFSET
	var panel_y := panel_base_y + PANEL_Y_LIFT
	var character_y := panel_base_y - CHARACTER_PIVOT_DROP

	_left_panel_pivot.position = Vector3(-spacing, panel_y, panel_z)
	_left_panel_pivot.rotation_degrees = Vector3(PANEL_X_ROT, PANEL_Y_ROT, 0.0)
	_character_pivot.position = Vector3(0.0, character_y, CHARACTER_Z)
	_character_pivot.rotation.y = _character_yaw
	_right_panel_pivot.position = Vector3(spacing, panel_y, panel_z)
	_right_panel_pivot.rotation_degrees = Vector3(PANEL_X_ROT, -PANEL_Y_ROT, 0.0)

	_wardrobe_camera.position = Vector3(0.0, CAMERA_HEIGHT, CAMERA_DISTANCE)
	var look_target := Vector3(0.0, _scene_look_y + CHARACTER_LOOK_Y_OFFSET, CHARACTER_Z)
	_wardrobe_camera.look_at(look_target, Vector3.UP)
	call_deferred("_fit_character_preview")
	call_deferred("_fit_character_preview_late")
	_activate_wardrobe_camera()
	if _needs_initial_preview:
		_needs_initial_preview = false
		_refresh_preview()


func _compute_wardrobe_vertical_layout() -> Dictionary:
	var panel_z := PANEL_Z_OFFSET
	var camera_pos := Vector3(0.0, CAMERA_HEIGHT, CAMERA_DISTANCE)
	var panel_world := Vector3(0.0, 0.0, panel_z)
	var panel_dist := camera_pos.distance_to(panel_world)
	var fov_y := deg_to_rad(CAMERA_FOV)
	var frustum_h := 2.0 * tan(fov_y * 0.5) * panel_dist
	var usable_h := frustum_h * (1.0 - PANEL_VERTICAL_MARGIN * 2.0)
	var panel_height := minf(PANEL_HEIGHT, usable_h)
	var look_y := CAMERA_HEIGHT * SCENE_LOOK_Y_RATIO
	var panel_base_y := look_y - panel_height * 0.5
	return {
		"look_y": look_y,
		"panel_height": panel_height,
		"panel_base_y": panel_base_y,
		"frustum_h": frustum_h,
	}


func _apply_palette_layout(panel_size: Vector2i) -> void:
	if _color_picker == null or _color_grid == null:
		return

	if _palette_insets:
		_palette_insets.anchor_left = PALETTE_INSET_LEFT
		_palette_insets.anchor_right = PALETTE_INSET_RIGHT
		_palette_insets.anchor_top = PALETTE_INSET_TOP
		_palette_insets.anchor_bottom = PALETTE_INSET_BOTTOM

	var content_width := panel_size.x * (PALETTE_INSET_RIGHT - PALETTE_INSET_LEFT)
	var content_height := panel_size.y * (PALETTE_INSET_BOTTOM - PALETTE_INSET_TOP)
	var grid_sep := clampi(int(panel_size.x * 0.012), 6, 12)
	var vbox_sep := clampi(int(panel_size.y * 0.016), 8, 14)
	if _palette_vbox:
		_palette_vbox.add_theme_constant_override("separation", vbox_sep)
		_palette_vbox.custom_minimum_size = Vector2(content_width, 0)
		_palette_vbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var swatch_size := (content_width - grid_sep * (PALETTE_SWATCH_COLUMNS - 1)) / float(PALETTE_SWATCH_COLUMNS)
	var max_grid_height := content_height * PALETTE_GRID_MAX_HEIGHT_RATIO
	var row_limit := (max_grid_height - grid_sep * (PALETTE_SWATCH_ROWS - 1)) / float(PALETTE_SWATCH_ROWS)
	swatch_size = minf(swatch_size, row_limit)
	swatch_size = clampf(swatch_size, 22.0, 40.0)

	var grid_height := swatch_size * PALETTE_SWATCH_ROWS + grid_sep * (PALETTE_SWATCH_ROWS - 1)
	var wheel_budget_h := maxf(content_height - grid_height - vbox_sep, content_width * 0.55)
	var wheel_size := minf(content_width * PALETTE_WHEEL_WIDTH_RATIO, wheel_budget_h)
	wheel_size = maxf(wheel_size, content_width * 0.72)

	_color_picker.custom_minimum_size = Vector2(wheel_size, wheel_size)
	_color_picker.size = Vector2(wheel_size, wheel_size)
	_color_picker.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_color_picker.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_color_grid.custom_minimum_size = Vector2(content_width, grid_height)
	_color_grid.add_theme_constant_override("h_separation", grid_sep)
	_color_grid.add_theme_constant_override("v_separation", grid_sep)
	for child in _color_grid.get_children():
		if child is Button:
			(child as Button).custom_minimum_size = Vector2(swatch_size, swatch_size)
			(child as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	call_deferred("_strip_color_picker_chrome")


func _apply_clothing_layout(panel_size: Vector2i) -> void:
	var slot_width := clampf(panel_size.x * 0.19, 72.0, 108.0)
	var slot_height := clampf(panel_size.y * 0.24, 112.0, 156.0)
	for slot in _item_slots:
		slot.custom_minimum_size = Vector2(slot_width, slot_height)

	var tab_font := clampi(int(panel_size.y * 0.028), 11, 16)
	for button in _tab_buttons:
		button.add_theme_font_size_override("font_size", tab_font)

	var item_font := clampi(int(panel_size.y * 0.024), 10, 14)
	for slot in _item_slots:
		var label: Label = slot.get_node_or_null("Label")
		if label:
			label.add_theme_font_size_override("font_size", item_font)


func _activate_wardrobe_camera() -> void:
	if _wardrobe_camera:
		_wardrobe_camera.current = true


func _on_wardrobe_scene_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouse):
		return

	var left_hit := _project_panel_ui_position(_left_panel_mesh, _clothing_ui_viewport)
	if left_hit.x >= 0.0:
		var forwarded := event.duplicate()
		forwarded.position = left_hit
		_clothing_ui_viewport.push_input(forwarded)
		return

	var right_hit := _project_panel_ui_position(_right_panel_mesh, _palette_ui_viewport)
	if right_hit.x >= 0.0:
		var forwarded := event.duplicate()
		forwarded.position = right_hit
		_palette_ui_viewport.push_input(forwarded)
		return

	if event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		if button_event.button_index == MOUSE_BUTTON_LEFT:
			_character_dragging = button_event.pressed
	elif event is InputEventMouseMotion and _character_dragging:
		var motion := event as InputEventMouseMotion
		_character_yaw += motion.relative.x * CHARACTER_ROTATE_SENSITIVITY
		_character_pivot.rotation.y = _character_yaw


func _project_panel_ui_position(mesh: MeshInstance3D, ui_viewport: SubViewport) -> Vector2:
	if mesh == null or ui_viewport == null or mesh.mesh == null:
		return Vector2(-1.0, -1.0)

	var local_pos := _wardrobe_scene_container.get_local_mouse_position()
	var container_size := _wardrobe_scene_container.size
	if local_pos.x < 0.0 or local_pos.y < 0.0 or local_pos.x > container_size.x or local_pos.y > container_size.y:
		return Vector2(-1.0, -1.0)

	var ray_origin := _wardrobe_camera.project_ray_origin(local_pos)
	var ray_dir := _wardrobe_camera.project_ray_normal(local_pos)
	var mesh_transform := mesh.global_transform
	var plane := Plane(-mesh_transform.basis.z, mesh_transform.origin)
	var hit: Variant = plane.intersects_ray(ray_origin, ray_dir)
	if hit == null:
		return Vector2(-1.0, -1.0)

	var local_hit: Vector3 = mesh_transform.affine_inverse() * hit
	var quad_size := (mesh.mesh as QuadMesh).size
	var u := (local_hit.x / quad_size.x) + 0.5
	var v := (-local_hit.y / quad_size.y) + 0.5
	if u < 0.0 or u > 1.0 or v < 0.0 or v > 1.0:
		return Vector2(-1.0, -1.0)

	return Vector2(u * ui_viewport.size.x, v * ui_viewport.size.y)


func _apply_unified_panel_texture(target: TextureRect, texture: Texture2D) -> void:
	if target == null:
		push_warning("贴图目标节点不存在，跳过赋值")
		return
	if texture == null:
		return
	target.texture = texture
	target.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	target.stretch_mode = TextureRect.STRETCH_SCALE


func _setup_header() -> void:
	_name_label.text = SessionState.display_name
	_apply_texture_button(%BackButton, ResourceUi.get_texture("btn_back"))
	_apply_texture_button(%SettingsButton, ResourceUi.get_texture("btn_settings"))
	_apply_texture_button(%ReadyButton, ResourceUi.get_texture("btn_ready"))
	var banner := ResourceUi.get_texture("banner_title")
	if banner and has_node("%TitleBanner"):
		%TitleBanner.texture = banner


func _apply_texture_button(button: TextureButton, texture: Texture2D) -> void:
	if texture == null:
		return
	button.texture_normal = texture
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED


func _build_tabs() -> void:
	for child in _tab_row.get_children():
		child.queue_free()
	_tab_buttons.clear()

	var transparent_style := StyleBoxEmpty.new()
	var frame_texture := ResourceUi.get_texture("frame_teal")
	for i in TAB_KEYS.size():
		var button := Button.new()
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.add_theme_stylebox_override("normal", transparent_style)
		button.add_theme_stylebox_override("hover", transparent_style)
		button.add_theme_stylebox_override("pressed", transparent_style)
		button.pressed.connect(_on_tab_pressed.bind(i))

		var indicator := TextureRect.new()
		indicator.name = "Indicator"
		indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		indicator.visible = false
		indicator.set_anchors_preset(Control.PRESET_FULL_RECT)
		if frame_texture:
			indicator.texture = frame_texture
			indicator.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			indicator.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		button.add_child(indicator)

		_tab_row.add_child(button)
		_tab_buttons.append(button)
	_update_tab_visuals()


func _build_color_palette() -> void:
	for child in _color_grid.get_children():
		child.queue_free()

	for color in PRESET_COLORS:
		var swatch := _make_color_swatch(color)
		swatch.pressed.connect(_on_preset_color_pressed.bind(color))
		_color_grid.add_child(swatch)

	_color_picker.color_changed.connect(_on_color_picker_changed)


func _make_color_swatch(color: Color, size: float = 44.0) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(size, size)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(5)
	style.set_border_width_all(1)
	style.border_color = Color(0.22, 0.24, 0.28, 0.9)
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.border_color = Color(0.92, 0.78, 0.28, 0.95)
	hover.set_border_width_all(2)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button


func _refresh_item_grid() -> void:
	for slot in _item_slots:
		slot.queue_free()
	_item_slots.clear()

	var items := _get_items_for_tab(_active_tab)
	var max_slots := GRID_COLUMNS * GRID_ROWS
	for i in max_slots:
		var slot := _make_item_slot()
		_item_grid.add_child(slot)
		_item_slots.append(slot)
		if i < items.size():
			_bind_item_slot(slot, items[i])
		else:
			_bind_empty_slot(slot)

	if _clothing_ui_viewport and _clothing_ui_viewport.size.x > 1:
		_apply_clothing_layout(_clothing_ui_viewport.size)


func _get_items_for_tab(tab: WardrobeTab) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var character_id := SessionState.selected_character_id
	if tab in CLOTHING_TABS:
		for skin in CharacterCatalog.get_skins(character_id):
			results.append({
				"type": "skin",
				"id": str(skin.get("id", "")),
				"name": str(skin.get("name", "")),
				"tint": CharacterCatalog.color_from_value(skin.get("tint", Color.WHITE)),
			})
		return results

	var slot_key := TAB_KEYS[tab]
	for accessory in CharacterCatalog.get_accessories(character_id):
		var accessory_id := str(accessory.get("id", ""))
		if _accessory_matches_slot(accessory_id, slot_key):
			results.append({
				"type": "accessory",
				"id": accessory_id,
				"name": str(accessory.get("name", "")),
			})
	return results


func _accessory_matches_slot(accessory_id: String, slot_key: String) -> bool:
	var slots: Array = ACCESSORY_SLOTS.get(accessory_id, [])
	return slot_key in slots


func _make_item_slot() -> Control:
	var slot := Control.new()
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot.custom_minimum_size = Vector2(80, 128)

	var preview := ColorRect.new()
	preview.name = "Preview"
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.set_anchors_preset(Control.PRESET_CENTER)
	preview.offset_left = -22.0
	preview.offset_top = -40.0
	preview.offset_right = 22.0
	preview.offset_bottom = 40.0
	slot.add_child(preview)

	var label := Label.new()
	label.name = "Label"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 4.0
	label.offset_top = 8.0
	label.offset_right = -4.0
	label.offset_bottom = -8.0
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	slot.add_child(label)

	var frame := TextureRect.new()
	frame.name = "Frame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.visible = false
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	var frame_texture := ResourceUi.get_texture("frame_gold")
	if frame_texture:
		frame.texture = frame_texture
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	slot.add_child(frame)

	var button := Button.new()
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	var hitbox_style := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", hitbox_style)
	button.add_theme_stylebox_override("hover", hitbox_style)
	button.add_theme_stylebox_override("pressed", hitbox_style)
	slot.add_child(button)
	return slot


func _bind_empty_slot(slot: Control) -> void:
	var preview: ColorRect = slot.get_node("Preview")
	var label: Label = slot.get_node("Label")
	var frame: TextureRect = slot.get_node("Frame")
	var button: Button = slot.get_child(slot.get_child_count() - 1) as Button
	preview.visible = false
	label.text = ""
	frame.visible = false
	button.disabled = true


func _bind_item_slot(slot: Control, item: Dictionary) -> void:
	var preview: ColorRect = slot.get_node("Preview")
	var label: Label = slot.get_node("Label")
	var frame: TextureRect = slot.get_node("Frame")
	var button: Button = slot.get_child(slot.get_child_count() - 1) as Button
	button.disabled = false

	if item.get("type", "") == "skin":
		preview.visible = true
		preview.color = item.get("tint", Color.WHITE)
		label.text = ""
	else:
		preview.visible = false
		label.text = item.get("name", "")

	var selected := false
	if item.get("type", "") == "skin":
		selected = SessionState.selected_skin_id == item.get("id", "") and not SessionState.wardrobe_use_custom_tint
	else:
		selected = SessionState.selected_accessory_id == item.get("id", "")
	frame.visible = selected
	button.pressed.connect(_on_item_slot_pressed.bind(item))


func _on_tab_pressed(tab_index: int) -> void:
	_active_tab = tab_index as WardrobeTab
	_update_tab_visuals()
	_refresh_item_grid()
	_sync_color_picker()


func _update_tab_visuals() -> void:
	for i in _tab_buttons.size():
		var button := _tab_buttons[i]
		var indicator: TextureRect = button.get_node("Indicator")
		indicator.visible = i == int(_active_tab)


func _on_item_slot_pressed(item: Dictionary) -> void:
	if item.get("type", "") == "skin":
		SessionState.set_skin(str(item.get("id", "")))
		_sync_color_picker()
	elif item.get("type", "") == "accessory":
		SessionState.set_accessory(str(item.get("id", "")))
	_refresh_item_grid()
	_apply_wardrobe_slots()


func _on_preset_color_pressed(color: Color) -> void:
	var part := _active_part_key()
	if part.is_empty():
		return
	SessionState.set_wardrobe_part_color(part, color)
	_sync_color_picker()
	_refresh_item_grid()
	_apply_wardrobe_slots()


func _on_color_picker_changed(color: Color) -> void:
	if _picker_syncing:
		return
	var part := _active_part_key()
	if part.is_empty():
		return
	SessionState.set_wardrobe_part_color(part, color)
	_refresh_item_grid()
	_apply_wardrobe_slots()


func _active_part_key() -> String:
	match _active_tab:
		WardrobeTab.TOP:
			return "top"
		WardrobeTab.BOTTOM:
			return "bottom"
		WardrobeTab.HEAD:
			return "hat"
		_:
			return ""


func _sync_color_picker() -> void:
	_picker_syncing = true
	var part := _active_part_key()
	if part.is_empty():
		part = "top"
	if SessionState.uses_native_wardrobe_appearance():
		var catalog_colors := CharacterCatalog.get_character_part_colors(SessionState.selected_character_id)
		_color_picker.color = catalog_colors.get(part, Color.WHITE)
	else:
		_color_picker.color = SessionState.get_wardrobe_part_color(part)
	_picker_syncing = false


func _uses_native_preview() -> bool:
	return SessionState.uses_native_wardrobe_appearance()


func _apply_wardrobe_slots() -> void:
	if _preview_character == null:
		_refresh_preview()
		return
	UiFactory.update_wardrobe_slots(
		_preview_character,
		SessionState.selected_character_id,
		SessionState.get_wardrobe_part_colors(),
		SessionState.uses_native_wardrobe_appearance()
	)
	call_deferred("_fit_character_preview")


func _refresh_preview() -> void:
	if _preview_character:
		_preview_character.queue_free()
	var use_native := _uses_native_preview()
	_preview_character = UiFactory.make_character_preview(
		SessionState.selected_character_id,
		true,
		Color.WHITE,
		SessionState.get_wardrobe_part_colors() if not use_native else {},
		use_native
	)
	_character_pivot.add_child(_preview_character)
	var mesh_count := 0
	for mesh_node in _preview_character.find_children("*", "MeshInstance3D", true, false):
		if (mesh_node as MeshInstance3D).visible:
			mesh_count += 1
	if mesh_count == 0:
		push_warning("换装预览未找到网格，请检查 character_body.fbx 导入")
	call_deferred("_fit_character_preview")
	call_deferred("_fit_character_preview_late")
	_activate_wardrobe_camera()
	if _wardrobe_scene_viewport:
		_wardrobe_scene_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _fit_character_preview() -> void:
	if _preview_character == null or _character_pivot == null or _wardrobe_camera == null:
		return
	if _scene_look_y <= 0.001:
		_scene_look_y = _compute_wardrobe_vertical_layout()["look_y"]
	_character_pivot.rotation.y = _character_yaw
	_character_pivot.scale = Vector3.ONE
	var look_target := Vector3(0.0, _scene_look_y + CHARACTER_LOOK_Y_OFFSET, CHARACTER_Z)
	_wardrobe_camera.look_at(look_target, Vector3.UP)
	_activate_wardrobe_camera()


func _fit_character_preview_late() -> void:
	await get_tree().process_frame
	_fit_character_preview()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(GameFlow.get_cosmetics_return_path())


func _on_settings_pressed() -> void:
	pass


func _on_ready_pressed() -> void:
	LobbySync.update_local_loadout()
	get_tree().change_scene_to_file(GameFlow.get_cosmetics_return_path())


func _on_change_character_pressed() -> void:
	GameFlow.go_to_character_select(GameFlow.get_cosmetics_return_path())
