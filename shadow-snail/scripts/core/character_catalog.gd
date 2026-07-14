extends Node

## Character and cosmetic catalog. Loads from shadow-resource when present, else uses placeholders.

signal catalog_changed

const PLACEHOLDER_CHARACTERS: Array[Dictionary] = [
	{
		"id": "snail",
		"name": "影噬蜗牛",
		"summary": "慢速硬壳，锋利影子。",
		"accent": Color(0.95, 0.72, 0.28),
	},
	{
		"id": "plush",
		"name": "毛绒跑者",
		"summary": "弹跳跃动的吉祥物战士。",
		"accent": Color(0.62, 0.78, 0.98),
	},
]

const PLACEHOLDER_SKINS: Dictionary = {
	"snail": [
		{"id": "default", "name": "经典", "tint": Color(0.98, 0.97, 0.94)},
		{"id": "moss", "name": "苔藓", "tint": Color(0.55, 0.78, 0.42)},
		{"id": "ember", "name": "余烬", "tint": Color(0.92, 0.45, 0.32)},
	],
	"plush": [
		{"id": "default", "name": "经典", "tint": Color(0.97, 0.96, 0.94)},
		{"id": "sky", "name": "晴空", "tint": Color(0.62, 0.78, 0.98)},
		{"id": "berry", "name": "浆果", "tint": Color(0.82, 0.42, 0.72)},
	],
}

const DEFAULT_WARDROBE_PART_COLORS: Dictionary = {
	"body": Color(0.94, 0.76, 0.62, 1.0),
	"top": Color(0.45, 0.32, 0.72, 1.0),
	"bottom": Color(0.22, 0.24, 0.30, 1.0),
	"hat": Color(0.55, 0.28, 0.75, 1.0),
}

const CUSTOMIZABLE_WARDROBE_PARTS: Array[String] = ["top", "bottom", "hat"]

const PLACEHOLDER_ACCESSORIES: Dictionary = {
	"snail": [
		{"id": "none", "name": "无"},
		{"id": "shell_spikes", "name": "尖刺壳"},
		{"id": "party_hat", "name": "派对帽"},
	],
	"plush": [
		{"id": "none", "name": "无"},
		{"id": "scarf", "name": "围巾"},
		{"id": "goggles", "name": "护目镜"},
	],
}

var _characters: Array[Dictionary] = []
var _skins: Dictionary = {}
var _accessories: Dictionary = {}


func _ready() -> void:
	_reload_catalog()


func _reload_catalog() -> void:
	_characters = PLACEHOLDER_CHARACTERS.duplicate(true)
	_skins = PLACEHOLDER_SKINS.duplicate(true)
	_accessories = PLACEHOLDER_ACCESSORIES.duplicate(true)
	_try_load_resource_manifest()
	catalog_changed.emit()


func _try_load_resource_manifest() -> void:
	var manifest_path := "%s/manifest.json" % GamePaths.RESOURCE_ROOT
	if not FileAccess.file_exists(manifest_path):
		return
	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	if data.has("characters"):
		_characters.clear()
		for entry in data["characters"]:
			if entry is Dictionary:
				_characters.append(_normalize_character(entry))
	if data.has("skins"):
		_skins = _normalize_skins(data["skins"])
	if data.has("accessories"):
		_accessories = data["accessories"]


static func color_from_value(value: Variant, fallback: Color = Color.WHITE) -> Color:
	if value is Color:
		return value
	if value is Array:
		var parts: Array = value
		if parts.size() >= 3:
			var alpha := 1.0
			if parts.size() >= 4:
				alpha = float(parts[3])
			return Color(float(parts[0]), float(parts[1]), float(parts[2]), alpha)
	return fallback


func _normalize_skins(raw: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for character_id in raw.keys():
		var skins: Variant = raw[character_id]
		if skins is Array:
			var normalized_skins: Array = []
			for skin in skins:
				if skin is Dictionary:
					normalized_skins.append(_normalize_skin(skin))
			normalized[character_id] = normalized_skins
	return normalized


func _normalize_skin(entry: Dictionary) -> Dictionary:
	var normalized := entry.duplicate(true)
	if normalized.has("tint"):
		normalized["tint"] = color_from_value(normalized["tint"])
	return normalized


func _normalize_character(entry: Dictionary) -> Dictionary:
	var normalized := entry.duplicate(true)
	if normalized.has("accent"):
		normalized["accent"] = color_from_value(normalized["accent"])
	if normalized.has("parts") and normalized["parts"] is Dictionary:
		var parts: Dictionary = {}
		for part_key in normalized["parts"].keys():
			var fallback: Color = DEFAULT_WARDROBE_PART_COLORS.get(str(part_key), Color.WHITE)
			parts[str(part_key)] = color_from_value(normalized["parts"][part_key], fallback)
		normalized["parts"] = parts
	return normalized


func get_characters() -> Array[Dictionary]:
	return _characters


func _resolve_character_id(character_id: String) -> String:
	if character_id == "default":
		return "snail"
	return character_id


func get_character(character_id: String) -> Dictionary:
	character_id = _resolve_character_id(character_id)
	for entry in _characters:
		if entry.get("id", "") == character_id:
			return entry
	return {}


func get_skins(character_id: String) -> Array:
	return _skins.get(_resolve_character_id(character_id), [])


func get_accessories(character_id: String) -> Array:
	return _accessories.get(_resolve_character_id(character_id), [])


func get_skin(character_id: String, skin_id: String) -> Dictionary:
	for skin in get_skins(character_id):
		if skin.get("id", "") == skin_id:
			return skin
	return {}


func get_accessory(character_id: String, accessory_id: String) -> Dictionary:
	for item in get_accessories(character_id):
		if item.get("id", "") == accessory_id:
			return item
	return {}


func get_model_resource_path(character_id: String) -> String:
	var entry := get_character(character_id)
	var model_rel := str(entry.get("model", ""))
	if model_rel.is_empty():
		return ""
	return "%s/%s" % [GamePaths.RESOURCE_ROOT, model_rel]


func get_character_part_colors(character_id: String) -> Dictionary:
	var colors := DEFAULT_WARDROBE_PART_COLORS.duplicate(true)
	var entry := get_character(character_id)
	var parts: Variant = entry.get("parts", {})
	if parts is Dictionary:
		for part_key in colors.keys():
			if parts.has(part_key):
				colors[part_key] = color_from_value(parts[part_key], colors[part_key])
	return colors


func get_idle_animation_resource_path(character_id: String) -> String:
	var entry := get_character(character_id)
	var animations: Variant = entry.get("animations", {})
	if animations is Dictionary:
		var idle_rel := str(animations.get("idle", ""))
		if not idle_rel.is_empty():
			return "%s/%s" % [GamePaths.RESOURCE_ROOT, idle_rel]
	return ""


func get_character_part_textures(character_id: String) -> Dictionary:
	var textures: Dictionary = {}
	var entry := get_character(character_id)
	var raw: Variant = entry.get("part_textures", {})
	if raw is Dictionary:
		for part_key in raw.keys():
			var rel_path := str(raw[part_key])
			if rel_path.is_empty():
				continue
			if rel_path.begins_with("res://"):
				textures[str(part_key)] = rel_path
			else:
				textures[str(part_key)] = "%s/%s" % [GamePaths.RESOURCE_ROOT, rel_path]
	return textures
