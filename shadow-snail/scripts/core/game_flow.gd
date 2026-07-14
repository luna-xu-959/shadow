extends Node

## Scene router for menu → lobby → match flow.

signal scene_changed(scene_path: String)

var _changing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func go_to_main_menu() -> void:
	_change_scene(GamePaths.MAIN_MENU_SCENE)


func go_to_character_select(return_to: String = GamePaths.MAIN_MENU_SCENE) -> void:
	SessionState.set_meta("character_select_return", return_to)
	_change_scene(GamePaths.CHARACTER_SELECT_SCENE)


func go_to_cosmetics(return_to: String = GamePaths.MAIN_MENU_SCENE) -> void:
	if not SessionState.has_character():
		go_to_character_select(return_to)
		return
	SessionState.set_meta("cosmetics_return", return_to)
	_change_scene(GamePaths.COSMETICS_SCENE)


func go_to_lobby() -> void:
	_change_scene(GamePaths.LOBBY_SCENE)


func go_to_results(results: Dictionary) -> void:
	SessionState.last_match_results = results
	_change_scene(GamePaths.RESULTS_SCENE)


func start_match() -> void:
	if NetworkManager.is_online and not NetworkManager.is_host:
		return
	LobbySync.begin_match_transition()


func start_match_offline() -> void:
	_load_match_scene_local(SessionState.lobby_mode, SessionState.selected_map_id)


@rpc("authority", "call_local", "reliable")
func _load_match_scene(mode: int, map_id: String) -> void:
	_load_match_scene_local(mode, map_id)


func _load_match_scene_local(mode: int, map_id: String) -> void:
	SessionState.set_meta("active_match_mode", mode)
	SessionState.set_meta("active_map_id", map_id)
	_change_scene(GamePaths.ARENA_DEFAULT_SCENE)


func get_character_select_return_path() -> String:
	return str(SessionState.get_meta("character_select_return", GamePaths.MAIN_MENU_SCENE))


func get_cosmetics_return_path() -> String:
	return str(SessionState.get_meta("cosmetics_return", GamePaths.MAIN_MENU_SCENE))


func leave_match_to_lobby() -> void:
	go_to_lobby()


func leave_to_main_menu() -> void:
	var network := get_node("/root/NetworkManager")
	if network.is_online:
		network.close_session()
	var lobby := get_node_or_null("/root/LobbySync")
	if lobby and lobby.has_method("reset_lobby"):
		lobby.call("reset_lobby")
	go_to_main_menu()


func _change_scene(path: String) -> void:
	if _changing:
		return
	_changing = true
	var err := get_tree().change_scene_to_file(path)
	_changing = false
	if err != OK:
		push_error("GameFlow: failed to load %s (err=%s)" % [path, str(err)])
		return
	scene_changed.emit(path)
