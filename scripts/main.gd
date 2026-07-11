extends Node3D

const MultiplayerMenuScene := preload("res://scenes/multiplayer_menu.tscn")
const PauseMenuScene := preload("res://scenes/pause_menu.tscn")
const NetworkScript := preload("res://scripts/network_manager.gd")
const NETWORK_PORT: int = NetworkScript.DEFAULT_PORT

@onready var _split_screen: CanvasLayer = $SplitScreen
@onready var _player0: CharacterBody3D = $Player0
@onready var _player1: CharacterBody3D = $Player1
@onready var _camera_p0: Camera3D = $CameraP0
@onready var _camera_p1: Camera3D = $CameraP1
@onready var _game_manager: Node = $GameManager
@onready var _status_label: Label = $CanvasLayer/UIRoot/StatusLabel

var _menu: Control
var _pause_menu: Control
var _session_active := false
var _waiting_for_peer := false
var _online_session := false


func _network() -> ShadowNetworkManager:
	return get_node("/root/NetworkManager") as ShadowNetworkManager


func _ready() -> void:
	_player0.configure_control(false, 0)
	_player1.configure_control(false, 1)
	_split_screen.visible = false
	_split_screen.process_mode = Node.PROCESS_MODE_DISABLED

	_menu = MultiplayerMenuScene.instantiate()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	$CanvasLayer/UIRoot.add_child(_menu)
	_menu.local_play_requested.connect(_start_local_session)
	_menu.host_requested.connect(_start_host_session)
	_menu.join_requested.connect(_start_join_session)

	_pause_menu = PauseMenuScene.instantiate()
	_pause_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	$CanvasLayer/UIRoot.add_child(_pause_menu)
	_pause_menu.resume_requested.connect(_close_pause_menu)
	_pause_menu.main_menu_requested.connect(_return_to_main_menu)
	_pause_menu.quit_requested.connect(_quit_game)

	_network().session_started.connect(_on_network_session_started)
	_network().session_failed.connect(_on_network_session_failed)
	_network().peer_joined.connect(_on_peer_joined)
	get_tree().paused = true
	_menu.show_menu(
		"Choose local split screen or online play.\n"
		+ "Up/Down to select, Enter to confirm."
	)


func is_pause_menu_open() -> bool:
	return _pause_menu != null and _pause_menu.visible


func toggle_pause_menu() -> bool:
	if not _session_active or _menu.visible:
		return false
	if _pause_menu.visible:
		_close_pause_menu()
	else:
		_open_pause_menu()
	return true


func _open_pause_menu() -> void:
	_release_all_mouse_looks()
	_pause_menu.show_pause()
	get_tree().paused = true


func _close_pause_menu() -> void:
	_pause_menu.hide_pause()
	get_tree().paused = false
	_restore_mouse_looks()


func _return_to_main_menu() -> void:
	_pause_menu.hide_pause()
	_session_active = false
	_waiting_for_peer = false
	_online_session = false
	_player0.configure_control(false, 0)
	_player1.configure_control(false, 1)
	_release_all_mouse_looks()
	_disable_split_screen()
	_network().close_session()
	get_tree().paused = true
	_menu.show_menu("Choose local split screen or online play.")


func _quit_game() -> void:
	get_tree().quit()


func _release_all_mouse_looks() -> void:
	for camera in [_camera_p0, _camera_p1]:
		if camera.has_method("release_mouse_look"):
			camera.call("release_mouse_look")


func _restore_mouse_looks() -> void:
	for camera in [_camera_p0, _camera_p1]:
		if camera.has_method("restore_mouse_look_if_needed"):
			camera.call("restore_mouse_look_if_needed")


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
	get_tree().paused = false
	_menu.show_connecting("Connecting to %s:%d ..." % [trimmed, NETWORK_PORT])
	var err: int = _network().join_game(trimmed)
	if err != OK and err != ERR_BUSY:
		get_tree().paused = true
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
				+ "Your Tailscale IP: %s\n"
				+ "Esc = pause menu."
			) % [NETWORK_PORT, _get_tailscale_ip_hint()]
		)
	else:
		_configure_online_client()
		_finish_session_start("Connected as Ghost. Esc = pause menu.")


func _on_peer_joined(peer_id: int) -> void:
	if not _network().is_host:
		return
	_player1.set_multiplayer_authority(peer_id)
	_setup_player_sync(_player1)
	_player1.configure_control(false, 1)
	_waiting_for_peer = false
	if _status_label:
		_status_label.text = "Ghost joined! Esc = pause. Human: arrows, Ghost: WASD."


func _on_network_session_failed(message: String) -> void:
	get_tree().paused = true
	_session_active = false
	_waiting_for_peer = false
	_online_session = false
	_player0.configure_control(false, 0)
	_player1.configure_control(false, 1)
	_network().close_session()
	_menu.show_menu(message)


func _get_tailscale_ip_hint() -> String:
	var output: Array = []
	var exit_code := OS.execute(
		"C:/Program Files/Tailscale/tailscale.exe",
		["ip", "-4"],
		output,
		true,
		false
	)
	if exit_code == 0 and output.size() > 0:
		var ip := str(output[0]).strip_edges()
		if not ip.is_empty():
			return ip
	return "run: tailscale ip -4"


func _begin_session(online: bool) -> void:
	_session_active = true
	_online_session = online
	_game_manager.set_online_mode(online)


func _finish_session_start(message: String) -> void:
	get_tree().paused = false
	_menu.hide_menu()
	if _status_label:
		_status_label.text = message


func _configure_local_split() -> void:
	if _split_screen.has_method("enable_split_view"):
		_split_screen.call("enable_split_view")
	_player0.set_multiplayer_authority(1)
	_player1.set_multiplayer_authority(1)
	_camera_p0.current = false
	_camera_p1.current = false
	_player0.configure_control(true, 0)
	_player1.configure_control(true, 1)
	_camera_p0.configure_for_player(true, false)
	_camera_p1.configure_for_player(true, true)
	_finish_session_start("Local split screen. Esc = pause. P0: arrows, P1: WASD.")


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
	if _split_screen.has_method("disable_split_view"):
		_split_screen.call("disable_split_view")


func _setup_player_sync(player: CharacterBody3D) -> void:
	var sync := player.get_node_or_null("MultiplayerSynchronizer") as MultiplayerSynchronizer
	if sync == null:
		sync = MultiplayerSynchronizer.new()
		sync.name = "MultiplayerSynchronizer"
		player.add_child(sync)
	var config := SceneReplicationConfig.new()
	config.add_property(":position", SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	config.add_property(":rotation", SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	config.add_property(":velocity", SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = config
