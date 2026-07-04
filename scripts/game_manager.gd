extends Node

const ShadowRulesScript = preload("res://scripts/shadow_rules.gd")
const STATUS_REFRESH_INTERVAL := 0.15
const STARTUP_DELAY := 1.5

var _game_finished: bool = false
var _status_timer: Timer
var _sun: DirectionalLight3D
var _sun_system: Node
var _scene_root: Node
var _status_label: Label


func _ready() -> void:
	_scene_root = get_parent()
	_sun_system = _scene_root.get_node_or_null("SunSystem")
	if _sun_system and _sun_system.has_method("get_sun_light"):
		_sun = _sun_system.call("get_sun_light") as DirectionalLight3D
	else:
		_sun = _scene_root.get_node_or_null("SunSystem/MainSun") as DirectionalLight3D

	var player0 := _scene_root.get_node_or_null("Player0")
	var player1 := _scene_root.get_node_or_null("Player1")
	_status_label = _scene_root.get_node_or_null("CanvasLayer/StatusLabel") as Label

	if _sun == null or player0 == null or player1 == null:
		push_error("GameManager: missing Sun/Player nodes in main scene.")
		return

	_connect_jump_landing(player0, player1)
	_connect_jump_landing(player1, player0)
	_update_status_hint()

	_status_timer = Timer.new()
	_status_timer.wait_time = STATUS_REFRESH_INTERVAL
	_status_timer.timeout.connect(_update_status_hint)
	add_child(_status_timer)

	await get_tree().create_timer(STARTUP_DELAY).timeout
	if is_instance_valid(_status_timer):
		_status_timer.start()


func _connect_jump_landing(attacker: Node, opponent: Node) -> void:
	if not attacker.has_signal("jump_landed"):
		push_error("GameManager: player missing jump_landed signal.")
		return
	attacker.jump_landed.connect(
		_on_jump_landed.bind(attacker, opponent)
	)


func _update_status_hint() -> void:
	if _status_label == null or _sun == null:
		return
	var basis := ShadowRulesScript.shadow_basis_from_sun(_sun)
	var time_label := "Day"
	if _sun_system and _sun_system.has_method("get_time_label"):
		time_label = _sun_system.call("get_time_label")
	var active_lights := ShadowRulesScript.count_active_main_shadow_lights(_scene_root)
	_status_label.text = (
		"P0 Human: WASD move, Q/E turn view, Space jump  |  P1 Ghost: Arrows/IJKL move, mouse look, Enter jump\n"
		+ "Ghost wins by jump-landing on Human shadow (sun / lamps / house lights)\n"
		+ "%s  |  Sun yaw: %.0f deg  |  Active main lights: %d" % [
			time_label,
			basis["yaw_degrees"],
			active_lights,
		]
	)


func _on_jump_landed(
	landing_position: Vector3,
	attacker: Node,
	opponent: Node
) -> void:
	if _game_finished:
		return
	if not is_instance_valid(attacker) or not is_instance_valid(opponent):
		return
	if not ShadowRulesScript.can_shadow_capture(attacker, opponent):
		return
	if not ShadowRulesScript.has_active_main_shadow_light(_scene_root):
		return

	var world: World3D = attacker.get_world_3d()
	if world == null:
		return

	var exclude: Array = []
	if attacker.has_method("get_physics_rids"):
		exclude = attacker.call("get_physics_rids")

	var space_state: PhysicsDirectSpaceState3D = world.direct_space_state
	if ShadowRulesScript.is_ground_point_in_caster_main_shadows(
		landing_position, opponent, space_state, exclude, _scene_root
	):
		_finish_match(attacker, opponent)


func _finish_match(ghost: Node, human: Node) -> void:
	_game_finished = true
	if is_instance_valid(_status_timer):
		_status_timer.stop()
	if is_instance_valid(human) and human.has_method("eliminate"):
		human.eliminate()
	if _status_label:
		var ghost_name: String = "Ghost"
		var human_name: String = "Human"
		if ghost.has_method("get_faction_name"):
			ghost_name = ghost.get_faction_name()
		if human.has_method("get_faction_name"):
			human_name = human.get_faction_name()
		_status_label.text = "%s wins! Jump landed on %s's shadow (main light)." % [ghost_name, human_name]
