extends Control

@onready var _status_label: Label = %StatusLabel
@onready var _join_panel: PanelContainer = %JoinPanel
@onready var _address_field: LineEdit = %AddressField


func _ready() -> void:
	SessionState.ensure_default_loadout()
	_join_panel.visible = false
	_update_status("影噬 — 踩踏影子，争夺生存。")


func _update_status(text: String) -> void:
	_status_label.text = text


func _on_host_pressed() -> void:
	_update_status("正在创建房间...")
	var err := NetworkManager.host_game()
	if err != OK:
		return
	GameFlow.go_to_lobby()


func _on_join_pressed() -> void:
	_join_panel.visible = true
	_address_field.grab_focus()


func _on_join_confirm_pressed() -> void:
	var address := _address_field.text.strip_edges()
	if address.is_empty():
		_update_status("请输入主机 IP（例如 127.0.0.1 或 Tailscale 100.x.x.x）。")
		return
	_update_status("正在连接 %s..." % address)
	if not NetworkManager.session_started.is_connected(_on_join_connected):
		NetworkManager.session_started.connect(_on_join_connected, CONNECT_ONE_SHOT)
	if not NetworkManager.session_failed.is_connected(_on_join_failed):
		NetworkManager.session_failed.connect(_on_join_failed, CONNECT_ONE_SHOT)
	var err := NetworkManager.join_game(address)
	if err != OK:
		_update_status("加入失败，请重试。")


func _on_join_cancel_pressed() -> void:
	_join_panel.visible = false


func _on_join_connected(_is_host: bool) -> void:
	_join_panel.visible = false
	GameFlow.go_to_lobby()


func _on_join_failed(message: String) -> void:
	_update_status(message.replace("\n", " "))


func _on_offline_lobby_pressed() -> void:
	NetworkManager.close_session()
	LobbySync.reset_lobby()
	GameFlow.go_to_lobby()


func _on_character_select_pressed() -> void:
	GameFlow.go_to_character_select()


func _on_cosmetics_pressed() -> void:
	GameFlow.go_to_cosmetics()


func _on_quit_pressed() -> void:
	get_tree().quit()
