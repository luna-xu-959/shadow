extends Node

## Persists local player choices and active lobby settings across scene changes.

signal loadout_changed
signal lobby_settings_changed

var display_name: String = "玩家"
var selected_character_id: String = ""
var selected_skin_id: String = "default"
var selected_accessory_id: String = "none"
var wardrobe_use_custom_tint := false
var wardrobe_custom_tint: Color = Color.WHITE
var wardrobe_part_colors: Dictionary = {}

var lobby_mode: GameMode.Id = GameMode.Id.FFA
var selected_map_id: String = "town_arena"
var is_ready: bool = false

var last_match_results: Dictionary = {}


func has_character() -> bool:
	return not selected_character_id.is_empty()


func ensure_default_loadout() -> void:
	if selected_character_id == "default":
		selected_character_id = "snail"
	if has_character():
		return
	var characters: Array = CharacterCatalog.get_characters()
	if characters.is_empty():
		return
	selected_character_id = characters[0].get("id", "")
	selected_skin_id = "default"
	selected_accessory_id = "none"
	wardrobe_use_custom_tint = false
	loadout_changed.emit()


func set_character(character_id: String) -> void:
	if selected_character_id == character_id:
		return
	selected_character_id = character_id
	selected_skin_id = "default"
	selected_accessory_id = "none"
	wardrobe_use_custom_tint = false
	reset_wardrobe_part_colors()
	loadout_changed.emit()


func ensure_wardrobe_part_colors() -> void:
	if wardrobe_part_colors.is_empty() and has_character():
		reset_wardrobe_part_colors()


func reset_wardrobe_part_colors() -> void:
	if not has_character():
		wardrobe_part_colors = {}
		return
	wardrobe_part_colors = {}
	var catalog_colors := CharacterCatalog.get_character_part_colors(selected_character_id)
	for part in CharacterCatalog.CUSTOMIZABLE_WARDROBE_PARTS:
		if catalog_colors.has(part):
			wardrobe_part_colors[part] = catalog_colors[part]


func get_wardrobe_part_colors() -> Dictionary:
	ensure_wardrobe_part_colors()
	return wardrobe_part_colors.duplicate(true)


func get_wardrobe_part_color(part: String) -> Color:
	ensure_wardrobe_part_colors()
	return wardrobe_part_colors.get(
		part,
		CharacterCatalog.DEFAULT_WARDROBE_PART_COLORS.get(part, Color.WHITE)
	)


func set_wardrobe_part_color(part: String, color: Color) -> void:
	ensure_wardrobe_part_colors()
	wardrobe_part_colors[part] = color
	wardrobe_use_custom_tint = true
	loadout_changed.emit()


func set_skin(skin_id: String) -> void:
	if selected_skin_id == skin_id and not wardrobe_use_custom_tint:
		return
	selected_skin_id = skin_id
	wardrobe_use_custom_tint = false
	reset_wardrobe_part_colors()
	loadout_changed.emit()


func uses_native_wardrobe_appearance() -> bool:
	return not wardrobe_use_custom_tint


func set_wardrobe_custom_tint(color: Color) -> void:
	wardrobe_custom_tint = color
	wardrobe_use_custom_tint = true
	loadout_changed.emit()


func clear_wardrobe_custom_tint() -> void:
	wardrobe_use_custom_tint = false
	loadout_changed.emit()


func set_accessory(accessory_id: String) -> void:
	if selected_accessory_id == accessory_id:
		return
	selected_accessory_id = accessory_id
	loadout_changed.emit()


func set_display_name(new_name: String) -> void:
	display_name = new_name.strip_edges()
	if display_name.is_empty():
		display_name = "玩家"
	loadout_changed.emit()


func set_lobby_mode(mode: GameMode.Id) -> void:
	if lobby_mode == mode:
		return
	lobby_mode = mode
	lobby_settings_changed.emit()


func set_map(map_id: String) -> void:
	if selected_map_id == map_id:
		return
	selected_map_id = map_id
	lobby_settings_changed.emit()


func set_ready(value: bool) -> void:
	is_ready = value


func get_loadout_summary() -> String:
	if not has_character():
		return "未选择角色"
	var character: Dictionary = CharacterCatalog.get_character(selected_character_id)
	var skin: Dictionary = CharacterCatalog.get_skin(selected_character_id, selected_skin_id)
	var char_name: String = character.get("name", selected_character_id)
	var skin_name: String = skin.get("name", selected_skin_id)
	return "%s / %s" % [char_name, skin_name]


func get_preview_tint() -> Color:
	if wardrobe_use_custom_tint:
		return wardrobe_custom_tint
	if not has_character():
		return Color.WHITE
	var skin: Dictionary = CharacterCatalog.get_skin(selected_character_id, selected_skin_id)
	if skin.is_empty():
		var character: Dictionary = CharacterCatalog.get_character(selected_character_id)
		return CharacterCatalog.color_from_value(character.get("accent", Color.WHITE))
	return CharacterCatalog.color_from_value(skin.get("tint", Color.WHITE))
