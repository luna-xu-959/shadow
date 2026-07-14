extends Node

## Authoritative lobby state for online rooms.

signal lobby_updated
signal countdown_tick(seconds_left: int)
signal match_starting

const COUNTDOWN_SECONDS := 3

var players: Dictionary = {}
var _countdown := -1
var _countdown_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var network := get_node("/root/NetworkManager")
	network.session_started.connect(_on_session_started)
	network.peer_joined.connect(_on_peer_joined)
	network.peer_left.connect(_on_peer_left)
	network.session_failed.connect(func(_msg: String) -> void: reset_lobby())


func reset_lobby() -> void:
	players.clear()
	_countdown = -1
	_stop_countdown()
	SessionState.set_ready(false)
	lobby_updated.emit()


func register_local_player() -> void:
	var peer_id := _local_peer_id()
	var payload := build_local_payload()
	players[peer_id] = payload
	if _is_server():
		_broadcast_lobby.rpc(players, SessionState.lobby_mode, SessionState.selected_map_id, _countdown)
	else:
		_submit_loadout.rpc_id(1, payload)


func update_local_loadout() -> void:
	register_local_player()


func set_mode_from_ui(mode: GameMode.Id) -> void:
	if not _is_server():
		_request_mode.rpc_id(1, mode)
		return
	SessionState.set_lobby_mode(mode)
	_trim_players_for_mode()
	_broadcast_lobby.rpc(players, SessionState.lobby_mode, SessionState.selected_map_id, _countdown)


func set_ready_from_ui(ready: bool) -> void:
	SessionState.set_ready(ready)
	if not _is_server():
		_submit_ready.rpc_id(1, ready)
		return
	var peer_id := _local_peer_id()
	if players.has(peer_id):
		players[peer_id]["ready"] = ready
	_try_start_countdown()
	_broadcast_lobby.rpc(players, SessionState.lobby_mode, SessionState.selected_map_id, _countdown)


func host_start_match_now() -> void:
	if not _is_server():
		return
	begin_match_transition()


func begin_match_transition() -> void:
	if not _is_server():
		return
	match_starting.emit()
	GameFlow._load_match_scene.rpc(SessionState.lobby_mode, SessionState.selected_map_id)


func get_slot_entries() -> Array[Dictionary]:
	var max_players := GameMode.max_players(SessionState.lobby_mode)
	var entries: Array[Dictionary] = []
	var peer_ids: Array = players.keys()
	peer_ids.sort()
	for i in max_players:
		if i < peer_ids.size():
			var peer_id: int = peer_ids[i]
			var data: Dictionary = players[peer_id]
			entries.append({
				"peer_id": peer_id,
				"occupied": true,
				"name": data.get("name", "玩家"),
				"loadout": data.get("loadout", ""),
				"ready": data.get("ready", false),
				"is_local": peer_id == _local_peer_id(),
			})
		else:
			entries.append({
				"peer_id": -1,
				"occupied": false,
				"name": "空位",
				"loadout": "",
				"ready": false,
				"is_local": false,
			})
	return entries


func get_countdown() -> int:
	return _countdown


func can_start_match() -> bool:
	if not NetworkManager.is_online:
		return SessionState.has_character()
	if not _is_server() and NetworkManager.is_online:
		return false
	var ready_count := 0
	for data in players.values():
		if data.get("ready", false):
			ready_count += 1
	return ready_count >= GameMode.min_players(SessionState.lobby_mode)


func build_local_payload() -> Dictionary:
	return {
		"name": SessionState.display_name,
		"character_id": SessionState.selected_character_id,
		"skin_id": SessionState.selected_skin_id,
		"accessory_id": SessionState.selected_accessory_id,
		"loadout": SessionState.get_loadout_summary(),
		"ready": SessionState.is_ready,
	}


func _on_session_started(_is_host: bool) -> void:
	reset_lobby()
	call_deferred("register_local_player")


func _on_peer_joined(peer_id: int) -> void:
	if not _is_server():
		return
	players[peer_id] = {
		"name": "玩家 %d" % peer_id,
		"loadout": "连接中...",
		"ready": false,
	}
	_broadcast_lobby.rpc(players, SessionState.lobby_mode, SessionState.selected_map_id, _countdown)


func _on_peer_left(peer_id: int) -> void:
	players.erase(peer_id)
	if _is_server():
		_trim_players_for_mode()
		_broadcast_lobby.rpc(players, SessionState.lobby_mode, SessionState.selected_map_id, _countdown)
	lobby_updated.emit()


func _try_start_countdown() -> void:
	if not _is_server():
		return
	if not can_start_match():
		_countdown = -1
		_stop_countdown()
		_broadcast_lobby.rpc(players, SessionState.lobby_mode, SessionState.selected_map_id, _countdown)
		return
	if _countdown > 0:
		return
	_countdown = COUNTDOWN_SECONDS
	_start_countdown()
	_broadcast_lobby.rpc(players, SessionState.lobby_mode, SessionState.selected_map_id, _countdown)


func _start_countdown() -> void:
	_stop_countdown()
	_countdown_timer = Timer.new()
	_countdown_timer.wait_time = 1.0
	_countdown_timer.timeout.connect(_on_countdown_tick)
	add_child(_countdown_timer)
	_countdown_timer.start()
	countdown_tick.emit(_countdown)


func _stop_countdown() -> void:
	if _countdown_timer and is_instance_valid(_countdown_timer):
		_countdown_timer.queue_free()
	_countdown_timer = null


func _on_countdown_tick() -> void:
	if not _is_server():
		return
	_countdown -= 1
	if _countdown <= 0:
		_stop_countdown()
		begin_match_transition()
		return
	countdown_tick.emit(_countdown)
	_broadcast_lobby.rpc(players, SessionState.lobby_mode, SessionState.selected_map_id, _countdown)


func _trim_players_for_mode() -> void:
	var max_players := GameMode.max_players(SessionState.lobby_mode)
	var peer_ids: Array = players.keys()
	peer_ids.sort()
	while peer_ids.size() > max_players:
		var removed: int = peer_ids.pop_back()
		players.erase(removed)


func _is_server() -> bool:
	if not NetworkManager.is_online:
		return true
	return multiplayer.is_server()


func _local_peer_id() -> int:
	if not NetworkManager.is_online:
		return 1
	return multiplayer.get_unique_id()


@rpc("any_peer", "call_remote", "reliable")
func _submit_loadout(payload: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	players[peer_id] = payload
	_broadcast_lobby.rpc(players, SessionState.lobby_mode, SessionState.selected_map_id, _countdown)


@rpc("any_peer", "call_remote", "reliable")
func _submit_ready(ready: bool) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if players.has(peer_id):
		players[peer_id]["ready"] = ready
	_try_start_countdown()
	_broadcast_lobby.rpc(players, SessionState.lobby_mode, SessionState.selected_map_id, _countdown)


@rpc("any_peer", "call_remote", "reliable")
func _request_mode(mode: int) -> void:
	if not multiplayer.is_server():
		return
	SessionState.set_lobby_mode(mode as GameMode.Id)
	_trim_players_for_mode()
	_broadcast_lobby.rpc(players, SessionState.lobby_mode, SessionState.selected_map_id, _countdown)


@rpc("authority", "call_local", "reliable")
func _broadcast_lobby(
	lobby_players: Dictionary,
	mode: int,
	map_id: String,
	countdown: int
) -> void:
	players = lobby_players.duplicate(true)
	SessionState.set_lobby_mode(mode as GameMode.Id)
	SessionState.set_map(map_id)
	_countdown = countdown
	lobby_updated.emit()
	if countdown >= 0:
		countdown_tick.emit(countdown)
