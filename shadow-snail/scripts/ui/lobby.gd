extends Control

@onready var _mode_option: OptionButton = %ModeOption
@onready var _map_option: OptionButton = %MapOption
@onready var _name_field: LineEdit = %NameField
@onready var _slots_container: VBoxContainer = %SlotsContainer
@onready var _status_label: Label = %StatusLabel
@onready var _countdown_label: Label = %CountdownLabel
@onready var _ready_button: Button = %ReadyButton
@onready var _start_button: Button = %StartButton

var _slot_labels: Array[Label] = []


func _ready() -> void:
	SessionState.ensure_default_loadout()
	_name_field.text = SessionState.display_name
	_name_field.text_changed.connect(_on_name_changed)
	_build_mode_options()
	_build_map_options()
	_rebuild_slot_labels()
	_refresh_ui()

	LobbySync.lobby_updated.connect(_refresh_ui)
	LobbySync.countdown_tick.connect(_on_countdown_tick)
	NetworkManager.session_failed.connect(_on_network_failed)

	if NetworkManager.is_online:
		LobbySync.register_local_player()
	else:
		LobbySync.players[1] = LobbySync.build_local_payload()
		LobbySync.lobby_updated.emit()


func _build_mode_options() -> void:
	_mode_option.clear()
	for mode in GameMode.all_modes():
		_mode_option.add_item(GameMode.label(mode), mode)
	_mode_option.select(SessionState.lobby_mode)


func _build_map_options() -> void:
	_map_option.clear()
	_map_option.add_item("城镇竞技场", 0)
	_map_option.add_item("训练场", 1)
	_map_option.select(0 if SessionState.selected_map_id == "town_arena" else 1)


func _rebuild_slot_labels() -> void:
	for child in _slots_container.get_children():
		child.queue_free()
	_slot_labels.clear()
	var max_players := GameMode.max_players(SessionState.lobby_mode)
	for i in max_players:
		var label := Label.new()
		label.add_theme_font_size_override("font_size", 16)
		_slots_container.add_child(label)
		_slot_labels.append(label)


func _refresh_ui() -> void:
	_mode_option.disabled = NetworkManager.is_online and not NetworkManager.is_host
	_start_button.visible = NetworkManager.is_host or not NetworkManager.is_online
	_start_button.disabled = not LobbySync.can_start_match()

	var role := NetworkManager.get_role_label()
	var mode_label := GameMode.label(SessionState.lobby_mode)
	_status_label.text = "%s | %s | 端口 %d" % [role, mode_label, NetworkManager.DEFAULT_PORT]

	if _mode_option.selected >= 0:
		var selected_mode: int = _mode_option.get_item_id(_mode_option.selected)
		if selected_mode != SessionState.lobby_mode and (NetworkManager.is_host or not NetworkManager.is_online):
			pass
		elif _mode_option.get_item_id(_mode_option.selected) != SessionState.lobby_mode:
			for i in _mode_option.item_count:
				if _mode_option.get_item_id(i) == SessionState.lobby_mode:
					_mode_option.select(i)
					break

	_rebuild_slot_labels()
	var entries := LobbySync.get_slot_entries()
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var prefix := "[我] " if entry.get("is_local", false) else ""
		var ready_mark := " ✓" if entry.get("ready", false) else ""
		if entry.get("occupied", false):
			_slot_labels[i].text = "%s玩家%d %s%s — %s" % [
				prefix,
				i + 1,
				entry.get("name", "玩家"),
				ready_mark,
				entry.get("loadout", ""),
			]
		else:
			_slot_labels[i].text = "玩家%d 空位" % (i + 1)

	_ready_button.text = "取消准备" if SessionState.is_ready else "准备"
	_countdown_label.text = "" if LobbySync.get_countdown() < 0 else "%d 秒后开始..." % LobbySync.get_countdown()


func _on_countdown_tick(seconds_left: int) -> void:
	_countdown_label.text = "%d 秒后开始..." % seconds_left


func _on_network_failed(message: String) -> void:
	_status_label.text = message.replace("\n", " ")


func _on_name_changed(new_text: String) -> void:
	SessionState.set_display_name(new_text)
	LobbySync.update_local_loadout()


func _on_name_submitted(new_text: String) -> void:
	SessionState.set_display_name(new_text)
	LobbySync.update_local_loadout()
	_refresh_ui()


func _on_mode_selected(index: int) -> void:
	var mode: int = _mode_option.get_item_id(index)
	LobbySync.set_mode_from_ui(mode as GameMode.Id)
	_refresh_ui()


func _on_map_selected(index: int) -> void:
	var map_id := "town_arena" if index == 0 else "training_yard"
	SessionState.set_map(map_id)
	if NetworkManager.is_host or not NetworkManager.is_online:
		LobbySync.register_local_player()


func _on_ready_pressed() -> void:
	LobbySync.set_ready_from_ui(not SessionState.is_ready)
	_refresh_ui()


func _on_start_pressed() -> void:
	if NetworkManager.is_online:
		if NetworkManager.is_host:
			LobbySync.host_start_match_now()
	else:
		GameFlow.start_match_offline()


func _on_character_select_pressed() -> void:
	GameFlow.go_to_character_select(GamePaths.LOBBY_SCENE)


func _on_cosmetics_pressed() -> void:
	GameFlow.go_to_cosmetics(GamePaths.LOBBY_SCENE)


func _on_leave_pressed() -> void:
	GameFlow.leave_to_main_menu()
