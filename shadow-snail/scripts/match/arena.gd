extends Node3D

@onready var _players_root: Node3D = $PlayersRoot
@onready var _match_manager: Node = $MatchManager
@onready var _hud: Control = $HUDLayer/HUD


func _ready() -> void:
	_match_manager.setup(self, _players_root)
	_match_manager.match_finished.connect(_on_match_finished)
	if _hud.has_method("bind_match"):
		_hud.call("bind_match", _match_manager)


func _on_match_finished(_results: Dictionary) -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		GameFlow.leave_match_to_lobby()
