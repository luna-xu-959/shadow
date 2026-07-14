class_name ResourceUi
extends RefCounted

## Loads wardrobe/common textures from shadow-resource.

const PATHS: Dictionary = {
	"clothing_panel": "ui/wardrobe/panels/clothing_panel_unified.png",
	"palette_panel_blank": "ui/wardrobe/panels/panel_frame_empty.png",
	"item_card_vertical": "ui/wardrobe/panels/item_card_vertical.png",
	"panel_frame_empty": "ui/wardrobe/panels/panel_frame_empty.png",
	"frame_gold": "ui/wardrobe/frames/frame_selected_gold_check.png",
	"frame_teal": "ui/wardrobe/frames/frame_selected_teal_check.png",
	"tab_top": "ui/wardrobe/tabs/tab_category_top.png",
	"tab_bottom": "ui/wardrobe/tabs/tab_category_bottom.png",
	"tab_waist": "ui/wardrobe/tabs/tab_category_waist.png",
	"tab_necklace": "ui/wardrobe/tabs/tab_category_necklace.png",
	"tab_head": "ui/wardrobe/tabs/tab_category_head.png",
	"btn_back": "ui/common/buttons/btn_back_yellow.png",
	"btn_settings": "ui/common/buttons/btn_settings_purple.png",
	"btn_ready": "ui/common/buttons/btn_ready_yellow_skull.png",
	"banner_title": "ui/common/banners/banner_title_graffiti.png",
}

static var _cache: Dictionary = {}


static func get_texture(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var relative: String = PATHS.get(key, "")
	if relative.is_empty():
		return null
	var texture := _load_texture("%s/%s" % [GamePaths.RESOURCE_ROOT, relative])
	if texture:
		_cache[key] = texture
	return texture


static func _load_texture(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		push_warning("ResourceUi: missing texture %s" % path)
		return null
	var texture: Texture2D = load(path)
	if texture != null:
		return texture
	var image := Image.new()
	var absolute_path := ProjectSettings.globalize_path(path)
	if image.load(absolute_path) != OK:
		return null
	return ImageTexture.create_from_image(image)
