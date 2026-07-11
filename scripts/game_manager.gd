extends Node

const ShadowRulesScript = preload("res://scripts/shadow_rules.gd")
const HumanPresenceScript = preload("res://scripts/human_presence.gd")
const GhostStompControllerScript = preload("res://scripts/ghost_stomp_controller.gd")
const ShadowCoreScript = preload("res://scripts/shadow_core.gd")
const STATUS_REFRESH_INTERVAL := 0.15
const STARTUP_DELAY := 1.5

var _game_finished: bool = false
var _online: bool = false
var _status_timer: Timer
var _status_refresh_paused: bool = false
var _sun: DirectionalLight3D
var _sun_system: Node
var _scene_root: Node
var _status_label: Label
var _ghost: Node
var _human: Node
var _ghost_stomp: Node


func set_online_mode(online: bool) -> void:
	_online = online


func is_online_mode() -> bool:
	return _online


func _is_rule_authority() -> bool:
	return not _online or multiplayer.is_server()


func _ready() -> void:
	_scene_root = get_parent()
	_sun_system = _scene_root.get_node_or_null("SunSystem")
	if _sun_system and _sun_system.has_method("get_sun_light"):
		_sun = _sun_system.call("get_sun_light") as DirectionalLight3D
	else:
		_sun = _scene_root.get_node_or_null("SunSystem/MainSun") as DirectionalLight3D

	_human = _scene_root.get_node_or_null("Player0")
	_ghost = _scene_root.get_node_or_null("Player1")
	_status_label = _scene_root.get_node_or_null("CanvasLayer/StatusLabel") as Label

	if _sun == null or _human == null or _ghost == null:
		push_error("GameManager: missing Sun/Player nodes in main scene.")
		return

	_connect_jump_landing(_ghost, _human)
	_connect_dark_stomp()
	if _human.has_signal("jump_landed"):
		_human.jump_landed.connect(_on_human_jump_landed)
	_update_status_hint()

	_status_timer = Timer.new()
	_status_timer.wait_time = STATUS_REFRESH_INTERVAL
	_status_timer.timeout.connect(_update_status_hint)
	add_child(_status_timer)

	await get_tree().create_timer(STARTUP_DELAY).timeout
	if is_instance_valid(_status_timer):
		_status_timer.start()


func is_game_finished() -> bool:
	return _game_finished


func _connect_jump_landing(ghost: Node, human: Node) -> void:
	if not ghost.has_signal("jump_landed"):
		push_error("GameManager: Ghost player missing jump_landed signal.")
		return
	ghost.jump_landed.connect(
		_on_ghost_jump_landed.bind(ghost, human)
	)


func _connect_dark_stomp() -> void:
	_ghost_stomp = _ghost.get_node_or_null("GhostStompController")
	if _ghost_stomp == null:
		push_warning("GameManager: Ghost missing GhostStompController.")
		return
	_ghost_stomp.stomp_hit.connect(_on_dark_stomp_hit)
	_ghost_stomp.stomp_missed.connect(_on_dark_stomp_missed)
	_ghost_stomp.charge_interrupted.connect(_on_charge_interrupted)


func _on_human_jump_landed(_landing_position: Vector3) -> void:
	if not _is_rule_authority() or _game_finished:
		return
	_show_jump_message("Human jumped — only RIGHT Ghost can stomp shadows.")


func _on_ghost_jump_landed(
	landing_position: Vector3,
	ghost: Node,
	human: Node
) -> void:
	if not _is_rule_authority() or _game_finished:
		return
	if not is_instance_valid(ghost) or not is_instance_valid(human):
		return

	print("Ghost jump-land at ", landing_position, " Human at ", human.global_position)
	_show_jump_message("Ghost landed — checking shadow...")

	if ShadowRulesScript.is_dark_zone(_scene_root, landing_position):
		var zone := ShadowRulesScript.get_zone_label(_scene_root, landing_position)
		_show_jump_message(
			"%s zone — no jump shadow. Hold F / LMB near Human 影核 (after 3s)." % zone
		)
		return

	if not ShadowRulesScript.can_shadow_capture(ghost, human):
		_show_jump_message("Wrong player — only Ghost can stomp Human shadows.")
		return
	if not ShadowRulesScript.has_active_main_shadow_light(_scene_root, landing_position):
		_show_jump_message("No main light at landing spot (light-zone jump stomp).")
		return

	var world: World3D = ghost.get_world_3d()
	if world == null:
		return

	var exclude: Array = []
	if ghost.has_method("get_physics_rids"):
		exclude = ghost.call("get_physics_rids")

	var space_state: PhysicsDirectSpaceState3D = world.direct_space_state
	if ShadowRulesScript.is_ground_point_in_caster_main_shadows(
		landing_position, human, space_state, exclude, _scene_root
	):
		_finish_match(ghost, human, landing_position, "light_jump")
	else:
		_show_jump_message(
			ShadowRulesScript.describe_shadow_check(
				landing_position, human, space_state, exclude, _scene_root
			)
		)


func _on_dark_stomp_hit(human: Node, _method: String) -> void:
	if not _is_rule_authority() or _game_finished:
		return
	if not is_instance_valid(_ghost) or not is_instance_valid(human):
		return
	var core_pos: Vector3 = human.global_position
	var presence: Node = human.get_node_or_null("HumanPresence")
	var core: ShadowCore = presence.get_shadow_core() as ShadowCore if presence and presence.has_method("get_shadow_core") else null
	if core:
		core_pos = core.get_world_anchor()
	_finish_match(_ghost, human, core_pos, "dark_core")


func _on_dark_stomp_missed(method: String) -> void:
	if not _is_rule_authority() or _game_finished:
		return
	if method == "dark_escape":
		_show_jump_message("Human escaped! Ghost cooldown 1.0s.")
	elif method == "dark_charge":
		_show_jump_message("Ghost wins! 影核噬影 — Human eliminated.")
	elif method == "dark_charge_no_core":
		_show_jump_message("Stomp landed — no 影核 in final range, no kill.")
	elif method == "dark_charge_weak":
		_show_jump_message("Released too early — hold 1.2s+ then release.")
	else:
		_show_jump_message("Dark stomp missed — stay within 0.5m of 影核.")


func _on_charge_interrupted() -> void:
	if not _is_rule_authority() or _game_finished:
		return
	print("[Stomp] Human escaped charge.")


func _show_jump_message(message: String) -> void:
	if _online and multiplayer.is_server():
		_rpc_show_jump_message.rpc(message)
	elif not _online:
		_apply_jump_message(message)


@rpc("authority", "call_local", "reliable")
func _rpc_show_jump_message(message: String) -> void:
	_apply_jump_message(message)


func _apply_jump_message(message: String) -> void:
	if _status_label == null:
		return
	_status_refresh_paused = true
	if is_instance_valid(_status_timer):
		_status_timer.stop()
	_status_label.text = "[Jump] %s" % message
	print("[Jump] ", message)
	var timer := get_tree().create_timer(2.5)
	timer.timeout.connect(_on_jump_flash_timeout, CONNECT_ONE_SHOT)


func _on_jump_flash_timeout() -> void:
	_status_refresh_paused = false
	if is_instance_valid(_status_timer) and not _game_finished:
		_status_timer.start()
	if is_instance_valid(_status_label) and not _game_finished:
		_update_status_hint()


func _update_status_hint() -> void:
	if _status_refresh_paused or _status_label == null or _sun == null:
		return
	var time_label := "Day"
	if _sun_system and _sun_system.has_method("get_time_label"):
		time_label = _sun_system.call("get_time_label")
	var sample_point: Vector3 = _human.global_position if is_instance_valid(_human) else Vector3.ZERO
	var zone := ShadowRulesScript.get_zone_label(_scene_root, sample_point)
	var local_light := ShadowRulesScript.get_local_main_light_strength(_scene_root, sample_point)
	var core_label := "none"
	var spirit := 0.0
	var charge_hint := ""
	var shade_hint := ShadowRulesScript.describe_shade_at(_scene_root, sample_point)
	if _ghost_stomp and _ghost_stomp.is_charging():
		var status := ""
		if _ghost_stomp.has_method("get_charge_status_hint"):
			status = _ghost_stomp.get_charge_status_hint()
		var range_m: float = _ghost_stomp.get_current_charge_range() if _ghost_stomp.has_method("get_current_charge_range") else 0.0
		var range_pct: float = _ghost_stomp.get_range_progress() * 100.0 if _ghost_stomp.has_method("get_range_progress") else 0.0
		charge_hint = " | %s range %.0f%% r=%.1fm" % [status, range_pct, range_m]
	elif _ghost_stomp and _ghost_stomp.has_method("get_last_block_reason"):
		var block: String = _ghost_stomp.get_last_block_reason()
		var attacking := (InputMap.has_action("p1_attack") and Input.is_action_pressed("p1_attack")) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
		if not block.is_empty() and attacking:
			charge_hint = " | %s" % block
	if is_instance_valid(_human):
		spirit = _human.get_spirit_pressure() if _human.has_method("get_spirit_pressure") else 0.0
		var presence := _human.get_node_or_null("HumanPresence")
		if presence and presence.has_method("get_lifecycle"):
			match presence.get_lifecycle():
				HumanPresenceScript.CoreLifecycle.SPAWNING:
					core_label = "影核 spawning"
					charge_hint = " %.0f%%" % (presence.get_core_charge_progress() * 100.0)
				HumanPresenceScript.CoreLifecycle.STABLE:
					core_label = "影核 ON"
				HumanPresenceScript.CoreLifecycle.LINGER:
					core_label = "影核 fading"
					charge_hint = " %.1fs" % (HumanPresenceScript.LINGER_DURATION * (1.0 - presence.get_linger_progress()))
				_:
					if presence.has_method("is_in_dark_zone") and presence.is_in_dark_zone():
						core_label = "entering dark"
	_status_label.text = (
		"P0 Human: Arrows/IJKL  |  P1 Ghost: Space (LIGHT) / Hold LMB release (charge stomp)\n"
		+ "Dark enter -> 1.2s fade in  |  leave dark -> 3.0s fade out (tap LMB instant stomp)\n"
		+ "Ghost: mouse always steers view (Esc to free) | hold LMB/F charge 0.1→0.5m | 影核 in range = kill\n"
		+ "%s %s  |  main-light %.2f  |  %s%s  |  %s" % [
			time_label,
			zone,
			local_light,
			core_label,
			charge_hint,
			shade_hint,
		]
	)


func _finish_match(ghost: Node, human: Node, landing_position: Vector3, method: String) -> void:
	if not _is_rule_authority():
		return
	_game_finished = true
	if is_instance_valid(_status_timer):
		_status_timer.stop()
	if is_instance_valid(human) and human.has_method("eliminate"):
		human.eliminate()
	var ghost_name: String = "Ghost"
	var human_name: String = "Human"
	if ghost.has_method("get_faction_name"):
		ghost_name = ghost.get_faction_name()
	if human.has_method("get_faction_name"):
		human_name = human.get_faction_name()
	var method_label := "影核噬影" if method == "dark_core" else "踩影"
	var light_label := ShadowRulesScript.dominant_light_label(
		ShadowRulesScript.get_dominant_main_shadow_light(_scene_root, landing_position)
	)
	if _online:
		_rpc_finish_match.rpc(ghost_name, human_name, method_label, light_label)
	else:
		_apply_finish_match(ghost_name, human_name, method_label, light_label)


@rpc("authority", "call_local", "reliable")
func _rpc_finish_match(
	ghost_name: String,
	human_name: String,
	method_label: String,
	light_label: String
) -> void:
	_apply_finish_match(ghost_name, human_name, method_label, light_label)


func _apply_finish_match(
	ghost_name: String,
	human_name: String,
	method_label: String,
	light_label: String
) -> void:
	_game_finished = true
	if is_instance_valid(_status_timer):
		_status_timer.stop()
	if _status_label:
		_status_label.text = "%s wins! %s on %s (%s)." % [
			ghost_name,
			method_label,
			human_name,
			light_label,
		]
