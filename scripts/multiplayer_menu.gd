extends Control

signal local_play_requested
signal host_requested
signal join_requested(address: String)

const HINT := (
	"Internet play: both install Tailscale, host runs tailscale ip -4.\n"
	+ "Same PC test: host first, then join 127.0.0.1 below."
)

@onready var _hint_label: Label = %HintLabel
@onready var _address_field: LineEdit = %AddressField
@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hint_label.text = HINT
	_status_label.text = ""
	_address_field.placeholder_text = "Host IP, e.g. 100.64.0.5 or 127.0.0.1"
	_address_field.text = ""
	_address_field.text_submitted.connect(_on_join_pressed)
	_address_field.gui_input.connect(_on_address_gui_input)


func show_menu(message: String = "") -> void:
	visible = true
	_set_buttons_enabled(true)
	_address_field.editable = true
	_status_label.text = message
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	call_deferred("_focus_address_field")


func hide_menu() -> void:
	visible = false


func set_status(message: String) -> void:
	_status_label.text = message


func show_connecting(message: String) -> void:
	visible = true
	_set_buttons_enabled(false)
	_address_field.editable = false
	_status_label.text = message


func get_join_address() -> String:
	return _address_field.text.strip_edges()


func _focus_address_field() -> void:
	if _address_field:
		_address_field.grab_focus()


func _on_address_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_address_field.grab_focus()


func _on_local_pressed() -> void:
	_set_buttons_enabled(false)
	local_play_requested.emit()


func _on_host_pressed() -> void:
	_set_buttons_enabled(false)
	host_requested.emit()


func _on_join_pressed(_text: String = "") -> void:
	var address := get_join_address()
	if address.is_empty():
		set_status("Type the host IP in the box above, then click Join.")
		_focus_address_field()
		return
	if not _looks_like_ip(address):
		set_status("Invalid IP format. Example: 100.64.0.5 or 127.0.0.1")
		_focus_address_field()
		return
	show_connecting("Connecting to %s ..." % address)
	join_requested.emit(address)


func _looks_like_ip(address: String) -> bool:
	var host := address
	if host.contains(":"):
		host = host.split(":", false, 1)[0]
	var parts := host.split(".")
	if parts.size() != 4:
		return false
	for part in parts:
		if not part.is_valid_int():
			return false
		var value := part.to_int()
		if value < 0 or value > 255:
			return false
	return true


func _set_buttons_enabled(enabled: bool) -> void:
	var panel := get_node_or_null("Panel")
	if panel == null:
		return
	for child in panel.get_children():
		if child is BaseButton:
			(child as BaseButton).disabled = not enabled
