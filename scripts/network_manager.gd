class_name ShadowNetworkManager
extends Node

## Friend multiplayer over ENet. Pair with Tailscale so friends can join via 100.x.x.x.

const DEFAULT_PORT := 8910

signal session_started(is_host: bool)
signal session_failed(message: String)
signal peer_joined(peer_id: int)

var is_online := false
var is_host := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host_game() -> Error:
	close_session()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(DEFAULT_PORT, 1)
	if err != OK:
		session_failed.emit("Could not host on port %d (error %d)." % [DEFAULT_PORT, err])
		return err
	multiplayer.multiplayer_peer = peer
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
	multiplayer.multiplayer_peer = peer
	return OK


func close_session() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	is_online = false
	is_host = false


func get_role_label() -> String:
	if not is_online:
		return "Offline"
	if is_host:
		return "Host (Human)"
	return "Client (Ghost)"


func _on_connected_to_server() -> void:
	is_online = true
	is_host = false
	session_started.emit(false)


func _on_peer_connected(peer_id: int) -> void:
	peer_joined.emit(peer_id)


func _on_connection_failed() -> void:
	close_session()
	session_failed.emit(
		"Connection failed. Check:\n"
		+ "- Host already clicked Host Game\n"
		+ "- IP is correct (Tailscale 100.x.x.x or 127.0.0.1 on same PC)\n"
		+ "- Firewall allows UDP %d" % DEFAULT_PORT
	)


func _on_server_disconnected() -> void:
	close_session()
	session_failed.emit("Disconnected from host.")
