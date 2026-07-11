extends Node3D

const MultiplayerMenuScene := preload("res://scenes/multiplayer_menu.tscn")
const NetworkScript := preload("res://scripts/network_manager.gd")
const NETWORK_PORT: int = NetworkScript.DEFAULT_PORT

@onready var _split_screen: CanvasLayer = $SplitScreen
@onready var _player0: CharacterBody3D = $Player0
@onready var _player1: CharacterBody3D = $Player1
@onready var _camera_p0: Camera3D = $CameraP0
@onready var _camera_p1: Camera3D = $CameraP1
@onready var _game_manager: Node = $GameManager
@onready var _status_label: Label = $CanvasLayer/StatusLabel

var _menu: Control
var _session_active := false
var _waiting_for_peer := false


func _network() -> ShadowNetworkManager:
	return get_node("/root/NetworkManager") as ShadowNetworkManager


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_menu = MultiplayerMenuScene.instantiate()
	$CanvasLayer.add_child(_menu)
	_menu.local_play_requested.connect(_start_local_session)
	_menu.host_requested.connect(_start_host_session)
	_menu.join_requested.connect(_start_join_session)
	_network().session_started.connect(_on_network_session_started)
	_network().session_failed.connect(_on_network_session_failed)
	_network().peer_joined.connect(_on_peer_joined)
	get_tree().paused = true
	_menu.show_menu("Choose local split screen or online play.")


func _start_local_session() -> void:
	if _session_active:
		return
	_begin_session(false)
	_configure_local_split()


func _start_host_session() -> void:
	if _session_active:
		return
	if _network() == null:
		_menu.set_status("NetworkManager autoload missing. Reload the project.")
		return
	_menu.set_status("Starting host on port %d..." % NETWORK_PORT)
	var err: int = _network().host_game()
	if err != OK:
		_menu.show_menu("Host failed (error %d)." % err)


func _start_join_session(address: String) -> void:
	if _session_active:
		return
	var trimmed := address.strip_edges()
	if trimmed.is_empty():
		_menu.show_menu("Enter the host IP in the text box, then click Join.")
		return
	_menu.show_connecting("Connecting to %s:%d ..." % [trimmed, NETWORK_PORT])
	var err: int = _network().join_game(trimmed)
	if err != OK and err != ERR_BUSY:
		_menu.show_menu("Join failed immediately (error %d)." % err)


func _on_network_session_started(is_host: bool) -> void:
	if _session_active:
		return
	_begin_session(true)
	if is_host:
		_waiting_for_peer = true
		_configure_online_host(true)
		_finish_session_start(
			(
				"Hosting on port %d — waiting for Ghost to join.\n"
				+ "Share your Tailscale IP (run: tailscale ip -4)."
			) % NETWORK_PORT
		)
	else:
		_configure_online_client()
		_finish_session_start("Connected as Ghost. Hunt the Human!")


func _on_peer_joined(peer_id: int) -> void:
	if not _network().is_host:
		return
	_player1.set_multiplayer_authority(peer_id)
	_player1.configure_control(false, 1)
	_waiting_for_peer = false
	if _status_label:
		_status_label.text = "Ghost joined! You are Human — run and hide your shadow."


func _on_network_session_failed(message: String) -> void:
	get_tree().paused = true
	_session_active = false
	_waiting_for_peer = false
	_network().close_session()
	_menu.show_menu(message)


func _begin_session(online: bool) -> void:
	_session_active = true
	_game_manager.set_online_mode(online)


func _finish_session_start(message: String) -> void:
	get_tree().paused = false
	_menu.hide_menu()
	if _status_label:
		_status_label.text = message


func _configure_local_split() -> void:
	_split_screen.visible = true
	_split_screen.process_mode = Node.PROCESS_MODE_INHERIT
	_player0.set_multiplayer_authority(1)
	_player1.set_multiplayer_authority(1)
	_camera_p0.current = false
	_camera_p1.current = false
	_player0.configure_control(true, 0)
	_player1.configure_control(true, 1)
	_camera_p0.configure_for_player(true, false)
	_camera_p1.configure_for_player(true, true)
	_finish_session_start("Local split screen — P0 Human (arrows), P1 Ghost (WASD).")


func _configure_online_host(waiting_for_peer: bool) -> void:
	_disable_split_screen()
	_player0.set_multiplayer_authority(1)
	_player1.set_multiplayer_authority(1 if waiting_for_peer else _player1.get_multiplayer_authority())
	_setup_player_sync(_player0)
	_setup_player_sync(_player1)
	_camera_p0.current = true
	_camera_p1.current = false
	_player0.configure_control(true, 0)
	_player1.configure_control(not waiting_for_peer, 1)
	_camera_p0.configure_for_player(true, false)
	_camera_p1.configure_for_player(false, true)


func _configure_online_client() -> void:
	_disable_split_screen()
	_player0.set_multiplayer_authority(1)
	_player1.set_multiplayer_authority(multiplayer.get_unique_id())
	_setup_player_sync(_player0)
	_setup_player_sync(_player1)
	_camera_p0.current = false
	_camera_p1.current = true
	_player0.configure_control(false, 0)
	_player1.configure_control(true, 1)
	_camera_p0.configure_for_player(false, false)
	_camera_p1.configure_for_player(true, true)


func _disable_split_screen() -> void:
	_split_screen.visible = false
	_split_screen.process_mode = Node.PROCESS_MODE_DISABLED
	get_viewport().disable_3d = false


func _setup_player_sync(player: CharacterBody3D) -> void:
	if player.has_node("MultiplayerSynchronizer"):
		return
	var sync := MultiplayerSynchronizer.new()
	sync.name = "MultiplayerSynchronizer"
	var config := SceneReplicationConfig.new()
	config.add_property(".:position")
	config.add_property(".:rotation")
	config.add_property(".:velocity")
	sync.replication_config = config
	player.add_child(sync)
