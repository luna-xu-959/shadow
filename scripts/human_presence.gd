class_name HumanPresence
extends Node

const ShadowCoreScript = preload("res://scripts/shadow_core.gd")

## Shadow-core lifecycle: spawn in dark, stable, linger on exit, collapse.

enum CoreLifecycle { INACTIVE, SPAWNING, STABLE, LINGER, DISAPPEARING }

const SPAWN_DURATION := 1.2
const LINGER_DURATION := 3.0
const GROWTH_MAX_SCALE := 3.0
const GROWTH_DURATION := 12.0
const SPIRIT_RISE_NEAR := 18.0
const SPIRIT_RISE_CLOSE := 32.0
const SPIRIT_DECAY := 8.0
const GHOST_NEAR_M := 5.0
const GHOST_CLOSE_M := 2.0

signal core_exposed
signal core_hidden
signal core_linger_started
signal escaped_charge

var spirit_pressure: float = 0.0

var _human: CharacterBody3D
var _core: ShadowCore
var _scene_root: Node
var _lifecycle := CoreLifecycle.INACTIVE
var _stable_dark_timer := 0.0
var _linger_timer := 0.0
var _was_in_dark := false
var _ghost: Node3D


func _ready() -> void:
	_human = get_parent() as CharacterBody3D
	if _human == null:
		push_error("HumanPresence must be child of Human CharacterBody3D.")
		set_process(false)
		return
	_scene_root = _human.get_parent()
	_core = ShadowCoreScript.new()
	_core.name = "ShadowCore"
	_core.setup(_human)
	_core.disappear_finished.connect(_on_core_disappear_finished)
	_human.add_child(_core)
	_core.top_level = true
	await get_tree().process_frame
	_find_ghost()


func _find_ghost() -> void:
	if _scene_root == null:
		return
	_ghost = _scene_root.get_node_or_null("Player1") as Node3D


func get_shadow_core() -> ShadowCore:
	return _core


func get_lifecycle() -> int:
	return _lifecycle


func is_core_exposed() -> bool:
	return _core != null and _core.is_attackable()


func is_in_dark_zone() -> bool:
	return _is_foot_in_dark()


func is_in_linger() -> bool:
	return _lifecycle == CoreLifecycle.LINGER


func allows_instant_stomp() -> bool:
	return _lifecycle == CoreLifecycle.LINGER and _core.is_attackable()


func get_core_charge_progress() -> float:
	if _core == null:
		return 0.0
	if _lifecycle == CoreLifecycle.SPAWNING:
		return _core.get_spawn_progress()
	return 0.0


func get_linger_progress() -> float:
	if _lifecycle != CoreLifecycle.LINGER:
		return 0.0
	return clampf(_linger_timer / LINGER_DURATION, 0.0, 1.0)


func notify_escape_attempt() -> void:
	if _human == null:
		return
	var input_dir := Input.get_vector(
		"p0_left", "p0_right", "p0_forward", "p0_back", 0.15
	)
	if input_dir.length_squared() > 0.04:
		escaped_charge.emit()


func _physics_process(delta: float) -> void:
	if _human == null or _scene_root == null:
		return
	if _ghost == null or not is_instance_valid(_ghost):
		_find_ghost()

	var in_dark := _is_foot_in_dark()
	var ghost_dist := _ghost_distance()
	_update_lifecycle(delta, in_dark)
	_update_spirit_pressure(delta, ghost_dist, in_dark)
	_update_core_state(ghost_dist)
	_was_in_dark = in_dark


func _foot_sample() -> Vector3:
	if _human.has_method("get_foot_collision_center"):
		return _human.call("get_foot_collision_center")
	if _human.has_method("get_feet_position"):
		return _human.call("get_feet_position")
	return _human.global_position


func _is_foot_in_dark() -> bool:
	return ShadowRules.is_shadow_core_zone(_scene_root, _foot_sample())


func _update_lifecycle(delta: float, in_dark: bool) -> void:
	match _lifecycle:
		CoreLifecycle.INACTIVE:
			if in_dark:
				_begin_spawn()
		CoreLifecycle.SPAWNING:
			_core.advance_spawn(delta)
			if not in_dark:
				_begin_linger()
			elif _core.is_spawn_complete():
				_begin_stable()
		CoreLifecycle.STABLE:
			if in_dark:
				_stable_dark_timer += delta
			else:
				_begin_linger()
		CoreLifecycle.LINGER:
			_linger_timer += delta
			_core.advance_linger(delta)
			if in_dark:
				_cancel_linger_to_stable()
			elif _linger_timer >= LINGER_DURATION and _lifecycle == CoreLifecycle.LINGER:
				_core.complete_fade_disappear()


func _begin_spawn() -> void:
	_lifecycle = CoreLifecycle.SPAWNING
	_stable_dark_timer = 0.0
	_linger_timer = 0.0
	_core.begin_spawn()
	core_exposed.emit()


func _begin_stable() -> void:
	_lifecycle = CoreLifecycle.STABLE
	_stable_dark_timer = 0.0
	_core.begin_stable()


func _begin_linger() -> void:
	if _lifecycle == CoreLifecycle.DISAPPEARING:
		return
	_lifecycle = CoreLifecycle.LINGER
	_linger_timer = 0.0
	_stable_dark_timer = 0.0
	_core.begin_linger(_core.get_fade_alpha())
	core_linger_started.emit()


func _cancel_linger_to_stable() -> void:
	_lifecycle = CoreLifecycle.STABLE
	_linger_timer = 0.0
	_core.begin_stable()


func _on_core_disappear_finished() -> void:
	_lifecycle = CoreLifecycle.INACTIVE
	_stable_dark_timer = 0.0
	_linger_timer = 0.0
	_core.set_growth_scale(1.0)
	core_hidden.emit()


func _ghost_distance() -> float:
	if _ghost == null or not is_instance_valid(_ghost):
		return 999.0
	return _human.global_position.distance_to(_ghost.global_position)


func _human_moving() -> bool:
	return Vector3(_human.velocity.x, 0.0, _human.velocity.z).length() > 0.5


func _update_spirit_pressure(delta: float, ghost_dist: float, in_dark: bool) -> void:
	var pressure_active := in_dark or _lifecycle == CoreLifecycle.LINGER
	if not pressure_active:
		spirit_pressure = maxf(0.0, spirit_pressure - SPIRIT_DECAY * delta)
		return
	if ghost_dist <= GHOST_CLOSE_M:
		spirit_pressure += SPIRIT_RISE_CLOSE * delta
	elif ghost_dist <= GHOST_NEAR_M:
		spirit_pressure += SPIRIT_RISE_NEAR * delta
	else:
		spirit_pressure = maxf(0.0, spirit_pressure - SPIRIT_DECAY * 0.5 * delta)
	if _human_moving():
		spirit_pressure = maxf(0.0, spirit_pressure - SPIRIT_DECAY * 0.35 * delta)
	spirit_pressure = clampf(spirit_pressure, 0.0, 100.0)


func _update_core_state(ghost_dist: float) -> void:
	if _core == null:
		return
	_core.set_ghost_distance(ghost_dist)
	_core.set_spirit_pressure(spirit_pressure)
	_core.set_human_moving(_human_moving())
	if _lifecycle == CoreLifecycle.STABLE and _is_foot_in_dark():
		_core.set_growth_scale(_compute_growth_scale())
	elif _lifecycle == CoreLifecycle.INACTIVE:
		_core.set_growth_scale(1.0)


func _compute_growth_scale() -> float:
	var grow_t := clampf(_stable_dark_timer / GROWTH_DURATION, 0.0, 1.0)
	grow_t = grow_t * grow_t * (3.0 - 2.0 * grow_t)
	return lerpf(1.0, GROWTH_MAX_SCALE, grow_t)
