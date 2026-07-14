class_name GhostStompController
extends Node

const HumanPresenceScript = preload(GamePaths.HUMAN_PRESENCE)
const ShadowCoreScript = preload(GamePaths.SHADOW_CORE)

## Ghost charged stomp: hold LMB/F anywhere; stomp range grows during charge.
## Full charge + 影核 inside final range eliminates the Human.

signal stomp_hit(victim: Node, attacker: Node, method: String)
signal stomp_missed(method: String)
signal charge_interrupted

const CHARGE_DURATION := 1.5
const CHARGE_COOLDOWN := 1.0
const MIN_ATTACK_CHARGE := 0.3
const FULL_CHARGE_TIME := 1.2
const RANGE_MIN := 0.1
const RANGE_MAX := 0.5
const MOVE_SLOW_MULT := 0.38

const FOOT_ORB_START := 0.12
const FOOT_ORB_MAX := 0.35
const SHOCKWAVE_EXPAND_MULT := 1.08
const CRACK_DECAL_DURATION := 2.0
const CM := 0.01
const CORE_FLOAT_HEIGHT := ShadowCoreScript.FLOAT_HEIGHT

enum ChargePhase { IDLE, CHARGING, COOLDOWN }

var _attacker: CharacterBody3D
var _target: CharacterBody3D
var _target_presence: Node
var _scene_root: Node
var _game_manager: Node
var _sun_system: Node

var _phase := ChargePhase.IDLE
var _charge_time := 0.0
var _cooldown_timer := 0.0
var _ambient_dim := 0.0

var _foot_orb: MeshInstance3D
var _ground_ring: MeshInstance3D
var _orb_mat: StandardMaterial3D
var _ring_mat: StandardMaterial3D
var _right_foot: Node3D
var _left_foot: Node3D
var _saved_ambient_energy := -1.0
var _last_block_reason := ""
var _attack_key_held := false
var _mouse_lmb_held := false
var _mouse_lmb_was_held := false


func _ready() -> void:
	_attacker = get_parent() as CharacterBody3D
	if _attacker == null:
		set_process(false)
		return
	_scene_root = _attacker.get_parent()
	_game_manager = _scene_root.get_node_or_null("GameManager")
	_sun_system = _scene_root.get_node_or_null("SunSystem")
	await get_tree().process_frame
	_refresh_stomp_target()
	_connect_target_escape()
	_build_fx()
	_cache_feet()


func _refresh_stomp_target() -> void:
	_target = _find_best_stomp_target()
	_target_presence = null
	if _target:
		_target_presence = _target.get_node_or_null("HumanPresence")
		_connect_target_escape()


func _find_best_stomp_target() -> CharacterBody3D:
	if _attacker == null:
		return null
	var registry := _scene_root.get_node_or_null("GameManager/PlayerRegistry") as PlayerRegistry
	var enemies: Array[CharacterBody3D] = []
	if registry:
		enemies = registry.get_enemies_of(_attacker)
	else:
		for node in get_tree().get_nodes_in_group("players"):
			if node == _attacker or not (node is CharacterBody3D):
				continue
			if node.has_method("get_team") and node.call("get_team") != _attacker.call("get_team"):
				if not node.has_method("is_eliminated") or not node.call("is_eliminated"):
					enemies.append(node as CharacterBody3D)
	if enemies.is_empty():
		return null
	var best: CharacterBody3D = null
	var best_dist: float = INF
	for enemy in enemies:
		var dist: float = _attacker.global_position.distance_squared_to(enemy.global_position)
		if dist < best_dist:
			best_dist = dist
			best = enemy
	return best


func _connect_target_escape() -> void:
	if _target_presence and _target_presence.has_signal("escaped_charge"):
		if not _target_presence.escaped_charge.is_connected(_on_target_escaped):
			_target_presence.escaped_charge.connect(_on_target_escaped)


func _cache_feet() -> void:
	var visual := _attacker.get_node_or_null("Visual")
	if visual == null:
		return
	_left_foot = visual.get_node_or_null("LeftUpperLeg/LeftLowerLeg/LeftFoot")
	_right_foot = visual.get_node_or_null("RightUpperLeg/RightLowerLeg/RightFoot")


func _build_fx() -> void:
	_orb_mat = _fx_mat(Color("#4A0E4E"), 1.2)
	_foot_orb = _make_orb("FootEnergy", FOOT_ORB_START, _orb_mat)
	_attacker.add_child(_foot_orb)
	_foot_orb.visible = false

	_ring_mat = _fx_mat(Color("#8B2FC9"), 1.4)
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color.a = 0.72
	_ground_ring = _make_ring("GroundRing", RANGE_MIN, _ring_mat)
	_scene_root.add_child(_ground_ring)
	_ground_ring.visible = false


func _fx_mat(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat


func _make_orb(name: String, diameter: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var mesh := SphereMesh.new()
	mesh.radius = diameter * 0.5
	mesh.height = diameter
	node.mesh = mesh
	node.material_override = mat
	return node


func _make_ring(name: String, radius: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.012
	node.mesh = mesh
	node.material_override = mat
	return node


func is_charging() -> bool:
	return _phase == ChargePhase.CHARGING


func get_charge_progress() -> float:
	return clampf(_charge_time / CHARGE_DURATION, 0.0, 1.0)


func get_charge_time() -> float:
	return _charge_time


func get_move_speed_multiplier() -> float:
	if _phase == ChargePhase.CHARGING:
		return MOVE_SLOW_MULT
	return 1.0


func is_in_light_zone() -> bool:
	if _scene_root == null or _attacker == null:
		return true
	return ShadowRules.is_light_zone(_scene_root, _attacker.global_position)


func is_in_dark_zone() -> bool:
	return not is_in_light_zone()


func get_last_block_reason() -> String:
	return _last_block_reason


func get_charge_status_hint() -> String:
	if _phase == ChargePhase.CHARGING:
		var radius := _charge_range_at_time(_charge_time)
		if _is_core_in_range(radius):
			return "charging 影核 %.1fm" % radius
		return "charging %.1fm (no 影核)" % radius
	if _phase == ChargePhase.COOLDOWN:
		return "cooldown %.1fs" % _cooldown_timer
	return ""


func get_current_charge_range() -> float:
	return _charge_range_at_time(_charge_time)


func get_range_progress() -> float:
	return clampf(_charge_time / FULL_CHARGE_TIME, 0.0, 1.0)


func _attack_radius_at_time(time: float) -> float:
	var grow_t := clampf(time / FULL_CHARGE_TIME, 0.0, 1.0)
	grow_t = grow_t * grow_t * (3.0 - 2.0 * grow_t)
	return lerpf(RANGE_MIN, RANGE_MAX, grow_t)


func _charge_range_at_time(time: float) -> float:
	return _attack_radius_at_time(time)


func _ensure_target() -> void:
	if _target == null or not is_instance_valid(_target):
		_refresh_stomp_target()


func _attack_action() -> String:
	if _attacker and _attacker.has_method("get_input_prefix"):
		return "%s_attack" % _attacker.call("get_input_prefix")
	return "p1_attack"


func _sync_attack_input_edges() -> void:
	_mouse_lmb_was_held = _mouse_lmb_held
	var attack_action := _attack_action()
	_attack_key_held = InputMap.has_action(attack_action) and Input.is_action_pressed(attack_action)
	_mouse_lmb_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _attack_held() -> bool:
	return _attack_key_held or _mouse_lmb_held


func _attack_just_pressed() -> bool:
	var attack_action := _attack_action()
	if InputMap.has_action(attack_action) and Input.is_action_just_pressed(attack_action):
		return true
	return _mouse_lmb_held and not _mouse_lmb_was_held


func _attack_just_released() -> bool:
	var attack_action := _attack_action()
	if InputMap.has_action(attack_action) and Input.is_action_just_released(attack_action):
		return true
	return (not _mouse_lmb_held) and _mouse_lmb_was_held


func _physics_process(delta: float) -> void:
	if _attacker == null:
		return
	if multiplayer.has_multiplayer_peer() and not _attacker.is_multiplayer_authority():
		return
	_sync_attack_input_edges()
	_ensure_target()
	match _phase:
		ChargePhase.IDLE:
			_handle_idle(delta)
		ChargePhase.CHARGING:
			_update_charge(delta)
		ChargePhase.COOLDOWN:
			_cooldown_timer -= delta
			if _cooldown_timer <= 0.0:
				_phase = ChargePhase.IDLE
	_restore_ambient_dim(delta)


func _handle_idle(delta: float) -> void:
	_handle_attack_input()


func _handle_attack_input() -> void:
	if _game_manager and _game_manager.has_method("is_game_finished") and _game_manager.call("is_game_finished"):
		return
	_ensure_target()
	if _target_presence and _target_presence.has_method("allows_instant_stomp") and _target_presence.allows_instant_stomp():
		if _attack_just_pressed() and _in_instant_stomp_range():
			_last_block_reason = ""
			_resolve_instant_stomp()
			return
	if not _attack_held():
		_last_block_reason = ""
		return
	if _phase == ChargePhase.COOLDOWN:
		_last_block_reason = "cooldown %.1fs" % _cooldown_timer
		return
	_last_block_reason = ""
	_begin_charge()


func _has_attackable_core() -> bool:
	if _target_presence == null or not _target_presence.has_method("is_core_exposed"):
		return false
	if not _target_presence.is_core_exposed():
		return false
	if not _target_presence.has_method("get_lifecycle"):
		return false
	var lifecycle: int = _target_presence.get_lifecycle()
	return (
		lifecycle == HumanPresenceScript.CoreLifecycle.SPAWNING
		or lifecycle == HumanPresenceScript.CoreLifecycle.STABLE
	)


func _stomp_anchor() -> Vector3:
	return _left_foot_anchor()


func _is_core_in_range(radius: float) -> bool:
	if not _has_attackable_core():
		return false
	var core: ShadowCore = _get_core()
	if core == null:
		return false
	var core_pos: Vector3 = core.get_world_anchor()
	var anchor: Vector3 = _stomp_anchor()
	return Vector2(core_pos.x - anchor.x, core_pos.z - anchor.z).length() <= radius


func _has_chargeable_core_in_range() -> bool:
	return _is_core_in_range(_charge_range_at_time(_charge_time))


func _get_core() -> ShadowCore:
	if _target_presence == null or not _target_presence.has_method("get_shadow_core"):
		return null
	return _target_presence.get_shadow_core() as ShadowCore


func _in_instant_stomp_range() -> bool:
	var core: ShadowCore = _get_core()
	if core == null:
		return false
	var core_pos: Vector3 = core.get_world_anchor()
	var ghost_feet: Vector3 = _foot_position()
	ghost_feet.y = ShadowRules.GROUND_SAMPLE_Y
	var radius: float = core.get_kernel_stomp_radius()
	return Vector2(core_pos.x - ghost_feet.x, core_pos.z - ghost_feet.z).length() <= radius


func _resolve_instant_stomp() -> void:
	var core: ShadowCore = _get_core()
	if core:
		core.play_burst()
	if _in_instant_stomp_range():
		_emit_stomp_hit("dark_linger")
	else:
		_emit_stomp_missed("dark_linger")


func _emit_stomp_hit(method: String) -> void:
	if _target == null or _attacker == null:
		return
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		if _game_manager and _attacker.has_method("get_slot_id") and _target.has_method("get_slot_id"):
			_game_manager.rpc_stomp_hit.rpc_id(
				1, _attacker.call("get_slot_id"), _target.call("get_slot_id"), method
			)
		return
	stomp_hit.emit(_target, _attacker, method)


func _emit_stomp_missed(method: String) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		if _game_manager:
			_game_manager.rpc_stomp_missed.rpc_id(1, method)
		return
	stomp_missed.emit(method)


func _resolve_charge_release() -> void:
	if _charge_time < MIN_ATTACK_CHARGE:
		_cancel_charge(false)
		return
	var release_time := _charge_time
	var hit_radius := _attack_radius_at_time(release_time)
	_update_charge_fx(release_time)
	_spawn_stomp_impact(hit_radius)
	var can_hit := release_time >= FULL_CHARGE_TIME and _is_core_in_range(hit_radius)
	var core: ShadowCore = _get_core()
	if can_hit and core:
		core.play_stomp_crush()
		_emit_stomp_hit("dark_charge")
	elif release_time >= FULL_CHARGE_TIME:
		_emit_stomp_missed("dark_charge_no_core")
	else:
		_emit_stomp_missed("dark_charge_weak")
	_end_charge_fx()
	_start_cooldown()


func _spawn_stomp_impact(radius: float) -> void:
	var impact_pos := _stomp_anchor()
	impact_pos.y = ShadowRules.GROUND_SAMPLE_Y
	_spawn_shockwave(impact_pos, radius)
	_spawn_ground_crack(impact_pos, radius)
	_spawn_hit_zone_flash(impact_pos, radius)


func _begin_charge() -> void:
	if _phase == ChargePhase.CHARGING:
		return
	_phase = ChargePhase.CHARGING
	_charge_time = 0.0
	_ambient_dim = 0.0
	_foot_orb.visible = true
	_ground_ring.visible = true
	_sync_core_charge_target(0.0)


func _sync_core_charge_target(time: float) -> void:
	var core: ShadowCore = _get_core()
	if core == null:
		return
	if _is_core_in_range(_charge_range_at_time(time)):
		core.set_locked_by_ghost(true)
		core.set_ghost_charge_time(time)
	else:
		core.set_locked_by_ghost(false)
		core.set_ghost_charge_time(0.0)


func _update_charge(delta: float) -> void:
	if _attack_just_released():
		_resolve_charge_release()
		return
	if not _attack_held():
		_cancel_charge(false)
		return
	if _target_presence and _has_chargeable_core_in_range():
		_target_presence.notify_escape_attempt()
	_charge_time += delta
	_update_charge_fx(_charge_time)
	_sync_core_charge_target(_charge_time)


func _update_charge_fx(time: float) -> void:
	var t := clampf(time / CHARGE_DURATION, 0.0, 1.0)
	var right_foot := _right_foot_position()
	var left_anchor := _left_foot_anchor()

	# 0.0s: 5cm orb under raised right foot.
	var orb_size := FOOT_ORB_START
	if time >= 0.3:
		orb_size = FOOT_ORB_MAX
	else:
		orb_size = lerpf(FOOT_ORB_START, FOOT_ORB_MAX, time / 0.3)
	_foot_orb.global_position = right_foot + Vector3(0.0, 0.02, 0.0)
	_resize_orb(_foot_orb, orb_size)

	if time >= 0.8:
		var crack_t := clampf((time - 0.8) / 0.4, 0.0, 1.0)
		_orb_mat.emission = Color("#FF8C00").lerp(Color("#FFD060"), sin(time * 42.0) * 0.15 * crack_t)
		_orb_mat.emission_energy_multiplier = lerpf(1.6, 3.2, crack_t)
	else:
		_orb_mat.emission = Color("#4A0E4E")
		_orb_mat.emission_energy_multiplier = lerpf(1.0, 1.8, t)

	var ring_radius := _attack_radius_at_time(time)
	_resize_ring(_ground_ring, ring_radius)
	_ground_ring.global_position = Vector3(
		left_anchor.x, ShadowRules.GROUND_SAMPLE_Y + 0.01, left_anchor.z
	)

	var core_height := _core_height_at_time(time)
	var max_horiz := _core_max_horiz_at_time(time)
	var core: ShadowCore = _get_core()
	if core and _has_chargeable_core_in_range():
		core.set_pull_target(left_anchor, core_height, max_horiz)

	if time >= 1.2 and _has_chargeable_core_in_range():
		_ambient_dim = lerpf(0.0, 0.35, clampf((time - 1.2) / 0.3, 0.0, 1.0))
		_apply_ambient_dim(_ambient_dim)


func _core_height_at_time(time: float) -> float:
	var float_h := CORE_FLOAT_HEIGHT
	if time <= 0.3:
		return maxf(float_h - 2.0 * CM * time, 0.003)
	var h := float_h - 2.0 * CM * 0.3
	h -= 8.0 * CM * (time - 0.3)
	if time >= 0.8 and time < 1.2:
		var end_h := 0.3 * CM
		var start_h := 1.0 * CM
		var blend := (time - 0.8) / 0.4
		h = lerpf(start_h, end_h, blend)
	elif time >= 1.2:
		h = lerpf(0.3 * CM, 0.05 * CM, clampf((time - 1.2) / 0.3, 0.0, 1.0))
	return maxf(h, 0.001)


func _core_max_horiz_at_time(time: float) -> float:
	if time < 0.3:
		return 0.0
	if time < 0.8:
		return lerpf(0.12, 0.05, (time - 0.3) / 0.5)
	if time < 1.2:
		return lerpf(0.05, 0.02, (time - 0.8) / 0.4)
	return 0.02


func _spawn_shockwave(at: Vector3, hit_radius: float) -> void:
	var end_radius := hit_radius * SHOCKWAVE_EXPAND_MULT
	var mat := _fx_mat(Color("#6B1A7A"), 1.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.7
	var ring := _make_ring("Shockwave", hit_radius * 0.15, mat)
	_scene_root.add_child(ring)
	ring.global_position = at + Vector3(0.0, 0.02, 0.0)
	var tween := ring.create_tween()
	tween.tween_method(
		func(r: float) -> void: _resize_ring(ring, r),
		hit_radius * 0.15, end_radius, 0.35
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tween.tween_callback(ring.queue_free)


func _spawn_hit_zone_flash(at: Vector3, hit_radius: float) -> void:
	var mat := _fx_mat(Color("#FF5533"), 2.2)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.55
	var ring := _make_ring("HitZoneFlash", hit_radius, mat)
	_scene_root.add_child(ring)
	ring.global_position = at + Vector3(0.0, 0.015, 0.0)
	var tween := ring.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tween.tween_callback(ring.queue_free)


func _spawn_ground_crack(at: Vector3, radius: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.08, 0.04, 0.12, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var decal := MeshInstance3D.new()
	decal.name = "StompCrack"
	var disk := CylinderMesh.new()
	disk.top_radius = radius
	disk.bottom_radius = radius
	disk.height = 0.004
	decal.mesh = disk
	decal.material_override = mat
	_scene_root.add_child(decal)
	decal.global_position = at + Vector3(0.0, 0.003, 0.0)
	var tween := decal.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, CRACK_DECAL_DURATION)
	tween.tween_callback(decal.queue_free)


func _on_target_escaped() -> void:
	if _phase != ChargePhase.CHARGING or not _has_chargeable_core_in_range():
		return
	_cancel_charge(true)


func _cancel_charge(escaped: bool) -> void:
	_end_charge_fx()
	if escaped:
		var core: ShadowCore = _get_core()
		if core:
			core.snap_back(0.1)
		_spawn_smoke(_right_foot_position())
		charge_interrupted.emit()
		_emit_stomp_missed("dark_escape")
		_start_cooldown()
	else:
		_phase = ChargePhase.IDLE
		_charge_time = 0.0
		_ambient_dim = 0.0


func _start_cooldown() -> void:
	_phase = ChargePhase.COOLDOWN
	_cooldown_timer = CHARGE_COOLDOWN
	_charge_time = 0.0
	_ambient_dim = 0.0


func _end_charge_fx() -> void:
	_foot_orb.visible = false
	_ground_ring.visible = false
	var core: ShadowCore = _get_core()
	if core:
		core.set_locked_by_ghost(false)
		core.set_ghost_charge_time(0.0)


func _spawn_smoke(at: Vector3) -> void:
	var puff := _make_orb("Smoke", 0.12, _fx_mat(Color(0.05, 0.05, 0.08), 0.3))
	_scene_root.add_child(puff)
	puff.global_position = at + Vector3(0.0, 0.05, 0.0)
	var tween := puff.create_tween()
	tween.tween_property(puff, "scale", Vector3(2.0, 2.0, 2.0), 0.5)
	tween.parallel().tween_property(puff.material_override, "albedo_color:a", 0.0, 0.5)
	tween.tween_callback(puff.queue_free)


func _right_foot_position() -> Vector3:
	if _right_foot and is_instance_valid(_right_foot):
		return _right_foot.global_position
	return _attacker.global_position + Vector3(0.11, 0.15, 0.0)


func _left_foot_anchor() -> Vector3:
	if _left_foot and is_instance_valid(_left_foot):
		var p := _left_foot.global_position
		return Vector3(p.x, ShadowRules.GROUND_SAMPLE_Y, p.z)
	var body := _attacker.global_position
	return Vector3(body.x - 0.11, ShadowRules.GROUND_SAMPLE_Y, body.z)


func _foot_position() -> Vector3:
	return _right_foot_position()


func _resize_orb(node: MeshInstance3D, diameter: float) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = diameter * 0.5
	mesh.height = diameter
	node.mesh = mesh


func _resize_ring(node: MeshInstance3D, radius: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.012
	node.mesh = mesh


func _apply_ambient_dim(amount: float) -> void:
	if _sun_system == null:
		return
	var world_env: WorldEnvironment = _scene_root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env == null or world_env.environment == null:
		return
	var env := world_env.environment
	if _saved_ambient_energy < 0.0:
		_saved_ambient_energy = env.ambient_light_energy
	env.ambient_light_energy = _saved_ambient_energy * (1.0 - amount)


func _restore_ambient_dim(delta: float) -> void:
	if _ambient_dim <= 0.0 and _saved_ambient_energy < 0.0:
		return
	if _phase == ChargePhase.CHARGING and _charge_time >= 1.2:
		return
	if _ambient_dim > 0.0:
		_ambient_dim = maxf(0.0, _ambient_dim - delta * 2.5)
		_apply_ambient_dim(_ambient_dim)
	if _ambient_dim <= 0.0 and _saved_ambient_energy >= 0.0:
		var world_env: WorldEnvironment = _scene_root.get_node_or_null("WorldEnvironment") as WorldEnvironment
		if world_env and world_env.environment:
			world_env.environment.ambient_light_energy = _saved_ambient_energy
		_saved_ambient_energy = -1.0
