extends Node

signal match_finished(results: Dictionary)

const MATCH_DURATION_SEC := 90.0

var _arena: Node3D
var _players_root: Node3D
var _timer := MATCH_DURATION_SEC
var _active := false


func setup(arena: Node3D, players_root: Node3D) -> void:
	_arena = arena
	_players_root = players_root
	_spawn_players()
	_active = true


func _process(delta: float) -> void:
	if not _active:
		return
	_timer -= delta
	if _timer <= 0.0:
		_finish_match()


func get_time_left() -> float:
	return maxf(_timer, 0.0)


func get_mode_label() -> String:
	var mode: int = SessionState.get_meta("active_match_mode", SessionState.lobby_mode)
	return GameMode.label(mode as GameMode.Id)


func _spawn_players() -> void:
	var player_scene: PackedScene = load("res://scenes/match/match_player.tscn")
	var spawn_points := _arena.get_node_or_null("SpawnPoints")
	var points: Array[Node3D] = []
	if spawn_points:
		for child in spawn_points.get_children():
			if child is Node3D:
				points.append(child)

	var payloads: Array[Dictionary] = []
	if NetworkManager.is_online and not LobbySync.players.is_empty():
		var peer_ids: Array = LobbySync.players.keys()
		peer_ids.sort()
		for peer_id in peer_ids:
			var data: Dictionary = LobbySync.players[peer_id]
			payloads.append({
				"peer_id": peer_id,
				"payload": data,
			})
	else:
		payloads.append({"peer_id": 1, "payload": LobbySync.build_local_payload()})

	for i in payloads.size():
		var entry: Dictionary = payloads[i]
		var player: CharacterBody3D = player_scene.instantiate()
		var peer_id: int = entry.get("peer_id", 1)
		player.configure_from_lobby(peer_id, entry.get("payload", {}))
		if points.size() > 0:
			var point: Node3D = points[i % points.size()]
			player.global_position = point.global_position
		else:
			player.global_position = Vector3(i * 2.0 - 2.0, 0.0, 0.0)
		_players_root.add_child(player, true)


func _finish_match() -> void:
	if not _active:
		return
	_active = false
	var ranking: Array[Dictionary] = []
	var peer_ids: Array = LobbySync.players.keys()
	peer_ids.sort()
	for peer_id in peer_ids:
		var data: Dictionary = LobbySync.players[peer_id]
		ranking.append({
			"name": data.get("name", "玩家"),
			"loadout": data.get("loadout", ""),
		})
	if ranking.is_empty():
		ranking.append({
			"name": SessionState.display_name,
			"loadout": SessionState.get_loadout_summary(),
		})
	var results := {
		"mode": SessionState.get_meta("active_match_mode", SessionState.lobby_mode),
		"ranking": ranking,
	}
	match_finished.emit(results)
	GameFlow.go_to_results(results)
