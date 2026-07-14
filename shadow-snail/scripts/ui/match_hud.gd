extends Control

@onready var _mode_label: Label = %ModeLabel
@onready var _timer_label: Label = %TimerLabel
@onready var _hint_label: Label = %HintLabel

var _match_manager: Node


func bind_match(manager: Node) -> void:
	_match_manager = manager
	_mode_label.text = manager.get_mode_label()
	_hint_label.text = "移动：方向键/WASD  跳跃：Enter/Space  Esc：离开对局"


func _process(_delta: float) -> void:
	if _match_manager == null:
		return
	_timer_label.text = "剩余 %d 秒" % int(ceil(_match_manager.get_time_left()))
