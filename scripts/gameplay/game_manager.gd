extends Node

const ShadowRulesScript = preload(GamePaths.SHADOW_RULES)
const HumanPresenceScript = preload(GamePaths.HUMAN_PRESENCE)
const GhostStompControllerScript = preload(GamePaths.GHOST_STOMP_CONTROLLER)
const ShadowCoreScript = preload(GamePaths.SHADOW_CORE)
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
var _registry: PlayerRegistry


func set_online_mode(online: bool) -> void:
	_online = online


func is_online_mode() -> bool:
	return _online


func get_registry() -> PlayerRegistry:
	return _registry


func _is_rule_authority() -> bool:
	return not _online or multiplayer.is_server()


func _ready() -> void:
	_scene_root = get_parent()
	_sun_system = _scene_root.get_node_or_null("SunSystem")
	if _sun_system and _sun_system.has_method("get_sun_light"):
		_sun = _sun_system.call("get_sun_light") as DirectionalLight3D
	else:
		_sun = _scene_root.get_node_or_null("SunSystem/MainSun") as DirectionalLight3D

	_status_label = _scene_root.get_node_or_null("CanvasLayer/UIRoot/StatusLabel") as Label
	_registry = get_node_or_null("PlayerRegistry") as PlayerRegistry
	if _registry == null:
		_registry = PlayerRegistry.new()
		_registry.name = "PlayerRegistry"
		add_child(_registry)

	if _sun == null:
		push_error("GameManager: missing Sun in main scene.")
		return


func reset_match() -> void:
	_game_finished = false
	_registry.clear()
	if is_instance_valid(_status_timer):
		_status_timer.stop()


func start_match() -> void:
	_game_finished = false
	_registry.register_from_group(&"players")
	_connect_players()
	_update_status_hint()

	if _status_timer == null:
		_status_timer = Timer.new()
		_status_timer.wait_time = STATUS_REFRESH_INTERVAL
		_status_timer.timeout.connect(_update_status_hint)
		add_child(_status_timer)

	await get_tree().create_timer(STARTUP_DELAY).timeout
	if is_instance_valid(_status_timer):
		_status_timer.start()


func is_game_finished() -> bool:
	return _game_finished


func _process(delta: float) -> void:
	_registry.tick_respawns(delta, _is_rule_authority())


func _connect_players() -> void:
	for pawn in _registry.get_all_pawns():
		if pawn.has_signal("jump_landed"):
			if not pawn.jump_landed.is_connected(_on_player_jump_landed):
				pawn.jump_landed.connect(_on_player_jump_landed.bind(pawn))
		var stomp := pawn.get_node_or_null("StompController")
		if stomp == null:
			stomp = pawn.get_node_or_null("GhostStompController")
		if stomp:
			if stomp.has_signal("stomp_hit") and not stomp.stomp_hit.is_connected(_on_stomp_hit):
				stomp.stomp_hit.connect(_on_stomp_hit)
			if stomp.has_signal("stomp_missed") and not stomp.stomp_missed.is_connected(_on_stomp_missed):
				stomp.stomp_missed.connect(_on_stomp_missed)
			if stomp.has_signal("charge_interrupted") and not stomp.charge_interrupted.is_connected(_on_charge_interrupted):
				stomp.charge_interrupted.connect(_on_charge_interrupted)


@rpc("any_peer", "call_remote", "reliable")
func rpc_player_jump_landed(attacker_slot_id: int, landing_position: Vector3) -> void:
	var attacker := _registry.get_pawn(attacker_slot_id)
	if attacker:
		_on_player_jump_landed(landing_position, attacker)


@rpc("any_peer", "call_remote", "reliable")
func rpc_stomp_hit(attacker_slot_id: int, victim_slot_id: int, method: String) -> void:
	var attacker := _registry.get_pawn(attacker_slot_id)
	var victim := _registry.get_pawn(victim_slot_id)
	if attacker and victim:
		_on_stomp_hit(victim, attacker, method)


@rpc("any_peer", "call_remote", "reliable")
func rpc_stomp_missed(method: String) -> void:
	_on_stomp_missed(method)


func _on_player_jump_landed(landing_position: Vector3, attacker: Node) -> void:
	if not _is_rule_authority() or _game_finished:
		return
	if not is_instance_valid(attacker):
		return
	if attacker.has_method("is_eliminated") and attacker.call("is_eliminated"):
		return

	for victim in _registry.get_enemies_of(attacker):
		_try_light_jump_stomp(attacker, victim, landing_position)


func _try_light_jump_stomp(attacker: Node, victim: Node, landing_position: Vector3) -> void:
	if not is_instance_valid(victim):
		return
	if victim.has_method("is_eliminated") and victim.call("is_eliminated"):
		return
	if not ShadowRulesScript.can_shadow_capture(attacker, victim):
		return
	if ShadowRulesScript.is_dark_zone(_scene_root, landing_position):
		return
	if not ShadowRulesScript.has_active_main_shadow_light(_scene_root, landing_position):
		return

	var world: World3D = attacker.get_world_3d()
	if world == null:
		return

	var exclude: Array = []
	if attacker.has_method("get_physics_rids"):
		exclude = attacker.call("get_physics_rids")

	var space_state: PhysicsDirectSpaceState3D = world.direct_space_state
	if ShadowRulesScript.is_ground_point_in_caster_main_shadows(
		landing_position, victim, space_state, exclude, _scene_root
	):
		_eliminate_player(victim, attacker, "light_jump")
	else:
		_show_jump_message(
			"%s jump — no hit on %s shadow."
			% [TeamInfo.display_name(attacker.call("get_team")), TeamInfo.display_name(victim.call("get_team"))]
		)


func _on_stomp_hit(victim: Node, attacker: Node, method: String) -> void:
	if not _is_rule_authority() or _game_finished:
		return
	if not is_instance_valid(victim) or not is_instance_valid(attacker):
		return
	if not ShadowRulesScript.can_shadow_capture(attacker, victim):
		return
	_eliminate_player(victim, attacker, method)


func _on_stomp_missed(method: String) -> void:
	if not _is_rule_authority() or _game_finished:
		return
	if method == "dark_escape":
		_show_jump_message("Target escaped stomp charge.")
	elif method == "dark_charge_no_core":
		_show_jump_message("Stomp landed — no shadow core in range.")
	elif method == "dark_charge_weak":
		_show_jump_message("Released too early — hold longer before release.")
	else:
		_show_jump_message("Stomp missed.")


func _on_charge_interrupted() -> void:
	if not _is_rule_authority() or _game_finished:
		return
	print("[Stomp] Charge interrupted.")


func _eliminate_player(victim: Node, attacker: Node, method: String) -> void:
	var victim_name := TeamInfo.display_name(victim.call("get_team")) if victim.has_method("get_team") else "Player"
	var attacker_name := TeamInfo.display_name(attacker.call("get_team")) if attacker.has_method("get_team") else "Player"
	var method_label := "影核噬影" if method == "dark_core" or method.begins_with("dark") else "踩影"
	_registry.eliminate_player(victim, attacker)
	_show_jump_message(
		"%s stomped %s (%s)! Respawn in %ds."
		% [attacker_name, victim_name, method_label, int(SessionConfig.RESPAWN_SECONDS)]
	)
	_check_team_elimination()


func _check_team_elimination() -> void:
	if (
		_registry.count_alive_team(TeamInfo.Id.TEAM_A) == 0
		and _registry.count_respawning_team(TeamInfo.Id.TEAM_A) == 0
	):
		_finish_team_win(TeamInfo.Id.TEAM_B)
	elif (
		_registry.count_alive_team(TeamInfo.Id.TEAM_B) == 0
		and _registry.count_respawning_team(TeamInfo.Id.TEAM_B) == 0
	):
		_finish_team_win(TeamInfo.Id.TEAM_A)


func _finish_team_win(team: int) -> void:
	if not _is_rule_authority() or _game_finished:
		return
	_game_finished = true
	if is_instance_valid(_status_timer):
		_status_timer.stop()
	var label := TeamInfo.display_name(team)
	if _online:
		_rpc_finish_match.rpc(label)
	else:
		_apply_finish_match(label)


@rpc("authority", "call_local", "reliable")
func _rpc_finish_match(winner_label: String) -> void:
	_apply_finish_match(winner_label)


func _apply_finish_match(winner_label: String) -> void:
	_game_finished = true
	if is_instance_valid(_status_timer):
		_status_timer.stop()
	if _status_label:
		_status_label.text = "%s wins the round!" % winner_label


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
	_status_label.text = "[Event] %s" % message
	print("[Event] ", message)
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

	var alive_a := _registry.count_alive_team(TeamInfo.Id.TEAM_A)
	var alive_b := _registry.count_alive_team(TeamInfo.Id.TEAM_B)

	var sample_point: Vector3 = Vector3.ZERO
	var pawns := _registry.get_alive_pawns()
	if not pawns.is_empty():
		sample_point = pawns[0].global_position
	var zone := ShadowRulesScript.get_zone_label(_scene_root, sample_point)
	var shade_hint := ShadowRulesScript.describe_shade_at(_scene_root, sample_point)

	_status_label.text = (
		"Team A vs Team B — everyone has shadows, stomp enemy shadows only.\n"
		+ "Move: arrows/IJKL or WASD | Jump: Enter/Space | Stomp: hold F/LMB | Esc: pause\n"
		+ "%s | Alive A:%d B:%d | %s | Respawn: %ds"
		% [time_label, alive_a, alive_b, zone, int(SessionConfig.RESPAWN_SECONDS)]
		+ (" | %s" % shade_hint if not shade_hint.is_empty() else "")
	)
