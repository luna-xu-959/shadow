extends Control

signal resume_requested
signal main_menu_requested
signal quit_requested

@onready var _resume_button: Button = %ResumeButton
@onready var _main_menu_button: Button = %MainMenuButton
@onready var _quit_button: Button = %QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_resume_button.pressed.connect(func() -> void: resume_requested.emit())
	_main_menu_button.pressed.connect(func() -> void: main_menu_requested.emit())
	_quit_button.pressed.connect(func() -> void: quit_requested.emit())


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	var main := get_tree().current_scene
	if main == null or not main.has_method("toggle_pause_menu"):
		return
	if not main.call("toggle_pause_menu"):
		return
	get_viewport().set_input_as_handled()


func show_pause() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	call_deferred("_focus_resume")


func hide_pause() -> void:
	visible = false


func _focus_resume() -> void:
	if _resume_button:
		_resume_button.grab_focus()
