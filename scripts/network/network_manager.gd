class_name ShadowNetworkManager
extends Node

## Friend multiplayer over ENet. Pair with Tailscale so friends can join via 100.x.x.x.

const DEFAULT_PORT := 8910
const CONNECT_TIMEOUT_SEC := 20.0

signal session_started(is_host: bool)
signal session_failed(message: String)
signal peer_joined(peer_id: int)
signal connect_timeout

var is_online := false
var is_host := false
var _connect_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var mp := _mp()
	mp.peer_connected.connect(_on_peer_connected)
	mp.connected_to_server.connect(_on_connected_to_server)
	mp.connection_failed.connect(_on_connection_failed)
	mp.server_disconnected.connect(_on_server_disconnected)


func _mp() -> MultiplayerAPI:
	return get_tree().get_multiplayer()


func host_game() -> Error:
	close_session()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(DEFAULT_PORT, SessionConfig.MAX_CLIENTS)
	if err != OK:
		session_failed.emit("Could not host on port %d (error %d)." % [DEFAULT_PORT, err])
		return err
	_mp().multiplayer_peer = peer
	is_online = true
	is_host = true
	session_started.emit(true)
	return OK


func join_game(address: String) -> Error:
	close_session()
	var trimmed := address.strip_edges()
	if trimmed.is_empty():
		session_failed.emit("Enter the host Tailscale IP before joining.")
		return ERR_INVALID_PARAMETER

	var host := trimmed
	var port := DEFAULT_PORT
	if host.contains(":"):
		var parts := host.split(":", false, 1)
		host = parts[0]
		port = int(parts[1])

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(host, port)
	if err != OK:
		session_failed.emit("Could not connect to %s:%d (error %d)." % [host, port, err])
		return err
	_mp().multiplayer_peer = peer
	_start_connect_timer()
	return OK


func close_session() -> void:
	_stop_connect_timer()
	if _mp().multiplayer_peer:
		_mp().multiplayer_peer.close()
		_mp().multiplayer_peer = null
	is_online = false
	is_host = false


func get_role_label() -> String:
	if not is_online:
		return "Offline"
	if is_host:
		return "Host (Human)"
	return "Client (Ghost)"


func _start_connect_timer() -> void:
	_stop_connect_timer()
	_connect_timer = Timer.new()
	_connect_timer.one_shot = true
	_connect_timer.wait_time = CONNECT_TIMEOUT_SEC
	_connect_timer.timeout.connect(_on_connect_timer_timeout)
	add_child(_connect_timer)
	_connect_timer.start()


func _stop_connect_timer() -> void:
	if _connect_timer and is_instance_valid(_connect_timer):
		_connect_timer.queue_free()
	_connect_timer = null


func _on_connect_timer_timeout() -> void:
	if is_online:
		return
	close_session()
	connect_timeout.emit()
	session_failed.emit(
		"Connection timed out after %d seconds.\n"
		% int(CONNECT_TIMEOUT_SEC)
		+ "- Host must click Host Game first and stay in the game\n"
		+ "- Friend IP must be host Tailscale IP (100.x.x.x)\n"
		+ "- Host firewall must allow UDP %d" % DEFAULT_PORT
	)


func _on_connected_to_server() -> void:
	_stop_connect_timer()
	is_online = true
	is_host = false
	session_started.emit(false)


func _on_peer_connected(peer_id: int) -> void:
	peer_joined.emit(peer_id)


func _on_connection_failed() -> void:
	_stop_connect_timer()
	close_session()
	session_failed.emit(
		"Connection failed. Check:\n"
		+ "- Host already clicked Host Game and is still in-game\n"
		+ "- IP is correct (Tailscale 100.x.x.x)\n"
		+ "- Host firewall allows UDP %d" % DEFAULT_PORT
	)


func _on_server_disconnected() -> void:
	close_session()
	session_failed.emit("Disconnected from host.")
