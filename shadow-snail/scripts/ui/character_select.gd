extends Control

const GamePathsScript = preload("res://scripts/core/game_paths.gd")
const UiFactoryScript = preload("res://scripts/ui/ui_factory.gd")

@onready var _character_list: ItemList = %CharacterList
@onready var _summary: Label = %SummaryLabel
@onready var _preview_viewport: SubViewport = %PreviewViewport
@onready var _preview_root: Node3D = %PreviewRoot
@onready var _preview_camera: Camera3D = %PreviewCamera

var _spin := 0.0


func _ready() -> void:
	_populate_characters()
	_character_list.item_selected.connect(_on_character_selected)
	CharacterCatalog.catalog_changed.connect(_populate_characters)
	if SessionState.has_character():
		_select_current_character()
	else:
		_character_list.select(0)
		_on_character_selected(0)


func _process(delta: float) -> void:
	_spin += delta * 0.6
	if _preview_root:
		_preview_root.rotation.y = _spin


func _populate_characters() -> void:
	_character_list.clear()
	for entry in CharacterCatalog.get_characters():
		_character_list.add_item(entry.get("name", entry.get("id", "?")))


func _select_current_character() -> void:
	var characters: Array = CharacterCatalog.get_characters()
	for i in characters.size():
		if characters[i].get("id", "") == SessionState.selected_character_id:
			_character_list.select(i)
			_on_character_selected(i)
			return


func _on_character_selected(index: int) -> void:
	var characters: Array = CharacterCatalog.get_characters()
	if index < 0 or index >= characters.size():
		return
	var entry: Dictionary = characters[index]
	SessionState.set_character(str(entry.get("id", "")))
	_summary.text = "%s\n%s" % [entry.get("name", ""), entry.get("summary", "")]
	_refresh_preview(entry)


func _refresh_preview(entry: Dictionary) -> void:
	if _preview_root.get_child_count() > 0:
		for child in _preview_root.get_children():
			child.queue_free()
	var tint: Color = SessionState.get_preview_tint()
	if tint == Color.WHITE:
		tint = CharacterCatalog.color_from_value(entry.get("accent", Color(0.8, 0.8, 0.85)), Color(0.8, 0.8, 0.85))
	var preview := UiFactoryScript.make_character_preview(
		str(entry.get("id", "")),
		true,
		tint,
		{},
		true
	)
	_preview_root.add_child(preview)
	_preview_camera.look_at(_preview_root.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)


func _on_confirm_pressed() -> void:
	if not SessionState.has_character():
		return
	var return_path := GameFlow.get_character_select_return_path()
	if return_path == GamePathsScript.COSMETICS_SCENE:
		GameFlow.go_to_cosmetics(GamePathsScript.MAIN_MENU_SCENE)
	elif return_path == GamePathsScript.LOBBY_SCENE:
		LobbySync.update_local_loadout()
		GameFlow.go_to_lobby()
	else:
		GameFlow.go_to_main_menu()


func _on_cosmetics_pressed() -> void:
	if not SessionState.has_character():
		return
	GameFlow.go_to_cosmetics(GameFlow.get_character_select_return_path())


func _on_back_pressed() -> void:
	var return_path := GameFlow.get_character_select_return_path()
	get_tree().change_scene_to_file(return_path)
