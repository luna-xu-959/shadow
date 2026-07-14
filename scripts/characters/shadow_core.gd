class_name ShadowCore
extends Node3D

## 影核视觉规格：内核 + 贝塞尔丝线 + 径向渐变外晕（尺寸 cm→m）

enum VisualState {
	HIDDEN, NORMAL, MOVING, SPIRIT_HIGH, SPIRIT_CRITICAL, ITEM_USE, LOCKED,
}

enum LifecyclePhase { HIDDEN, SPAWN, STABLE, LINGER, COLLAPSE, FALL, SPLASH }

const CM := 0.01
const SIZE_SCALE := 2.5
## 游戏内可见尺寸（脚踝处白色发光球体，保持规格比例）。
const CORE_DIAMETER := 0.06 * SIZE_SCALE
const CORE_RADIUS := CORE_DIAMETER * 0.5
const THREAD_DIAMETER := 0.008 * SIZE_SCALE
const THREAD_RADIUS := THREAD_DIAMETER * 0.5
const SHELL_OFFSET_MIN := 0.03 * SIZE_SCALE
const SHELL_OFFSET_MAX := 0.12 * SIZE_SCALE
const HALO_DIAMETER := 0.30 * SIZE_SCALE
const HALO_RADIUS := HALO_DIAMETER * 0.5
const FLOAT_HEIGHT := 5.0 * CM
const CROUCH_FORWARD_OFFSET := 5.0 * CM
const THREAD_BOB_AMPLITUDE := 0.015 * SIZE_SCALE
const CORE_PULSE_HZ := 1.2
const THREAD_SPIN_DEG := 45.0
const THREAD_COUNT_MIN := 8
const THREAD_COUNT_MAX := 12
const BEZIER_STEPS := 16
const TUBE_SIDES := 8
const THREAD_ALPHA := 0.55

const CORE_EMISSION_PEAK := 24.0
const THREAD_EMISSION_RATIO := 0.4
const SHOW_STRENGTH_THRESHOLD := 0.005
const GROWTH_SCALE_MIN := 1.0
const GROWTH_SCALE_MAX := 3.0

const SPAWN_DURATION := 1.2
const SPAWN_PHASE_CORE := 0.4
const SPAWN_PHASE_THREADS := 0.8
const FADE_DISAPPEAR_DURATION := 3.0
const LINGER_FOLLOW_LAG := 0.2
const SPLASH_DIAMETER := 0.20
const SPLASH_DURATION := 0.3
const INSTANT_STOMP_KERNEL_RADIUS := 0.10
const PINPOINT_DIAMETER := 0.004
const LINGER_FLASH_HZ := 10.0
const CHARGE_FLASH_HZ := 8.0
const CHARGE_LOCK_BRIGHTNESS := 1.5

const COLOR_WARM := Color("#FFF0B8")
const COLOR_MOVE := Color("#FF6B4A")
const COLOR_SPIRIT_CRIT := Color("#E8F0FF")
const COLOR_ITEM := Color("#7EC8E3")
const COLOR_LOCKED := Color("#FF3333")
const COLOR_CORE := Color("#FFFFFF")
const COLOR_HALO := Color("#FFFFFF")

const HALO_SHADER := preload(GamePaths.SHADOW_CORE_HALO_SHADER)

signal burst_finished
signal disappear_finished

var _human: Node3D
var _visual_root: Node3D
var _pinpoint_mesh: MeshInstance3D
var _core_mesh: MeshInstance3D
var _thread_rig: Node3D
var _thread_meshes: Array[MeshInstance3D] = []
var _thread_specs: Array[Dictionary] = []
var _thread_mat: StandardMaterial3D
var _halo_mat: ShaderMaterial

var _visible_strength := 0.0
var _target_strength := 0.0
var _pulse_time := 0.0
var _state := VisualState.HIDDEN
var _locked := false
var _pull_offset := Vector3.ZERO
var _pull_height := 0.0
var _pull_horiz_max := 999.0
var _ghost_charge_time := 0.0
var _spirit_pressure := 0.0
var _human_moving := false
var _bursting := false
var _core_brightness := 1.0
var _thread_count := 10
var _growth_scale := 1.0
var _lifecycle := LifecyclePhase.HIDDEN
var _phase_time := 0.0
var _spawn_time := 0.0
var _thread_grow := 0.0
var _halo_grow := 0.0
var _threads_spin_enabled := false
var _linger_follow_vel := Vector3.ZERO
var _halo_jitter := Vector3.ZERO
var _fade_start_alpha := 1.0
var _splash_mesh: MeshInstance3D
var _pinpoint_mat: StandardMaterial3D
var _snap_back_start_off := Vector3.ZERO
var _snap_back_start_h := 0.0


func setup(human: Node3D) -> void:
	_human = human
	_build_visuals()


func _build_visuals() -> void:
	_thread_count = randi_range(THREAD_COUNT_MIN, THREAD_COUNT_MAX)
	_thread_mat = _make_thread_material(COLOR_WARM)
	_halo_mat = ShaderMaterial.new()
	_halo_mat.shader = HALO_SHADER
	_halo_mat.set_shader_parameter("glow_color", COLOR_HALO)
	_halo_mat.set_shader_parameter("center_alpha", 0.3)

	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)

	_pinpoint_mat = _make_core_material()
	_pinpoint_mesh = _make_sphere("Pinpoint", PINPOINT_DIAMETER, _pinpoint_mat)
	_pinpoint_mesh.sorting_offset = 11.0
	_visual_root.add_child(_pinpoint_mesh)

	# 影核本体：半透明径向发光球（中心较实，边缘渐透）。
	_core_mesh = _make_sphere("CoreGlow", HALO_DIAMETER, _halo_mat)
	_core_mesh.sorting_offset = 10.0
	_visual_root.add_child(_core_mesh)

	_thread_rig = Node3D.new()
	_thread_rig.name = "ThreadRig"
	_visual_root.add_child(_thread_rig)

	for i in _thread_count:
		_thread_specs.append(_random_bezier_spec())
		var thread_mesh := MeshInstance3D.new()
		thread_mesh.name = "Thread%d" % i
		thread_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		thread_mesh.material_override = _thread_mat
		_thread_rig.add_child(thread_mesh)
		_thread_meshes.append(thread_mesh)

	_apply_growth_scale()
	visible = false


func _apply_growth_scale() -> void:
	if _visual_root:
		_visual_root.scale = Vector3.ONE * _growth_scale


func _make_core_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = COLOR_CORE
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 1.0
	mat.emission_enabled = true
	mat.emission = COLOR_CORE
	mat.emission_energy_multiplier = CORE_EMISSION_PEAK
	mat.no_depth_test = true
	mat.render_priority = 10
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _make_thread_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, THREAD_ALPHA)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = CORE_EMISSION_PEAK * THREAD_EMISSION_RATIO
	mat.no_depth_test = true
	mat.render_priority = 9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _make_sphere(part_name: String, diameter: float, mat: Material) -> MeshInstance3D:
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.name = part_name
	var sphere := SphereMesh.new()
	sphere.radius = diameter * 0.5
	sphere.height = diameter
	sphere.radial_segments = 32 if part_name == "CoreGlow" else 20
	sphere.rings = 20 if part_name == "CoreGlow" else 12
	mesh_inst.mesh = sphere
	mesh_inst.material_override = mat
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh_inst


func _random_bezier_spec() -> Dictionary:
	var p0 := _random_shell_point()
	var p3 := _random_shell_point()
	var mid := (p0 + p3) * 0.5
	var tangent := (p3 - p0).cross(Vector3.UP)
	if tangent.length_squared() < 0.000001:
		tangent = Vector3.RIGHT
	tangent = tangent.normalized()
	var spread := CORE_RADIUS + (SHELL_OFFSET_MIN + SHELL_OFFSET_MAX) * 0.5
	return {
		"p0": p0,
		"p1": mid + tangent * spread * randf_range(0.35, 0.9),
		"p2": mid - tangent * spread * randf_range(0.35, 0.9),
		"p3": p3,
		"phase": randf() * TAU,
		"freq": randf_range(0.8, 1.5),
	}


func _random_shell_point() -> Vector3:
	var dir := Vector3(
		randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)
	).normalized()
	var dist := CORE_RADIUS + randf_range(SHELL_OFFSET_MIN, SHELL_OFFSET_MAX)
	return dir * dist


func set_exposure_strength(strength: float) -> void:
	_target_strength = clampf(strength, 0.0, 1.15)


func is_attackable() -> bool:
	return (
		_lifecycle != LifecyclePhase.HIDDEN
		and _lifecycle != LifecyclePhase.SPLASH
		and not _bursting
		and _visible_strength > SHOW_STRENGTH_THRESHOLD
	)


func is_exposed() -> bool:
	return is_attackable() and (_visible_strength > 0.02 or _lifecycle == LifecyclePhase.SPAWN)


func get_spawn_progress() -> float:
	return clampf(_spawn_time / SPAWN_DURATION, 0.0, 1.0)


func get_fade_alpha() -> float:
	return _visible_strength


func is_spawn_complete() -> bool:
	return _spawn_time >= SPAWN_DURATION


func get_kernel_stomp_radius() -> float:
	return INSTANT_STOMP_KERNEL_RADIUS * _growth_scale


func begin_spawn() -> void:
	_lifecycle = LifecyclePhase.SPAWN
	_spawn_time = 0.0
	_phase_time = 0.0
	_thread_grow = 0.0
	_halo_grow = 0.0
	_threads_spin_enabled = false
	_target_strength = 1.0
	_visible_strength = 0.0
	_pinpoint_mat.emission_energy_multiplier = 0.0
	visible = true


func begin_stable() -> void:
	_lifecycle = LifecyclePhase.STABLE
	_threads_spin_enabled = true
	_thread_grow = 1.0
	_halo_grow = 1.0
	_target_strength = 1.0
	_visible_strength = 1.0
	_halo_jitter = Vector3.ZERO
	_linger_follow_vel = Vector3.ZERO


func begin_linger(start_alpha: float = 1.0) -> void:
	_lifecycle = LifecyclePhase.LINGER
	_phase_time = 0.0
	_fade_start_alpha = clampf(start_alpha, 0.0, 1.0)
	_threads_spin_enabled = false
	_target_strength = 0.0
	_visible_strength = _fade_start_alpha


func complete_fade_disappear() -> void:
	_spawn_splash()
	_finish_disappear()


func advance_spawn(delta: float) -> void:
	if _lifecycle != LifecyclePhase.SPAWN:
		return
	_spawn_time += delta
	_update_spawn_visuals()


func advance_linger(delta: float) -> void:
	if _lifecycle != LifecyclePhase.LINGER:
		return
	_phase_time += delta
	_halo_jitter = Vector3(
		randf_range(-0.012, 0.012) * _growth_scale,
		randf_range(-0.008, 0.008) * _growth_scale,
		randf_range(-0.012, 0.012) * _growth_scale,
	)


func _smoothstep01(t: float) -> float:
	var x := clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _update_spawn_visuals() -> void:
	var t := _spawn_time
	if t <= SPAWN_PHASE_CORE:
		_pinpoint_mesh.visible = true
		_core_mesh.visible = false
		_thread_rig.visible = false
		_thread_grow = 0.0
		_halo_grow = 0.0
	elif t <= SPAWN_PHASE_THREADS:
		var thread_t := (t - SPAWN_PHASE_CORE) / (SPAWN_PHASE_THREADS - SPAWN_PHASE_CORE)
		_pinpoint_mesh.visible = true
		_core_mesh.visible = false
		_thread_rig.visible = true
		_thread_grow = _smoothstep01(thread_t)
		_halo_grow = 0.0
	else:
		var halo_t := (t - SPAWN_PHASE_THREADS) / (SPAWN_DURATION - SPAWN_PHASE_THREADS)
		_pinpoint_mesh.visible = _smoothstep01(1.0 - halo_t) > 0.2
		_core_mesh.visible = true
		_thread_rig.visible = true
		_thread_grow = 1.0
		_halo_grow = _smoothstep01(halo_t)
		_threads_spin_enabled = halo_t > 0.15
	var core_scale_t := _smoothstep01(t / SPAWN_PHASE_CORE)
	_pinpoint_mesh.scale = Vector3.ONE * lerpf(0.15, 1.0, core_scale_t)


func _spawn_splash() -> void:
	if _splash_mesh and is_instance_valid(_splash_mesh):
		_splash_mesh.queue_free()
	var mat := _make_core_material()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.55)
	mat.emission_energy_multiplier = 8.0
	_splash_mesh = MeshInstance3D.new()
	var disk := CylinderMesh.new()
	disk.top_radius = SPLASH_DIAMETER * 0.5
	disk.bottom_radius = SPLASH_DIAMETER * 0.5
	disk.height = 0.01
	_splash_mesh.mesh = disk
	_splash_mesh.material_override = mat
	var parent := get_tree().current_scene
	if parent:
		parent.add_child(_splash_mesh)
		_splash_mesh.global_position = Vector3(
			global_position.x,
			ShadowRules.GROUND_SAMPLE_Y + 0.005,
			global_position.z,
		)
	if _visual_root:
		_visual_root.visible = false


func _finish_disappear() -> void:
	if _splash_mesh and is_instance_valid(_splash_mesh):
		_splash_mesh.queue_free()
		_splash_mesh = null
	_lifecycle = LifecyclePhase.HIDDEN
	_target_strength = 0.0
	_visible_strength = 0.0
	visible = false
	if _visual_root:
		_visual_root.visible = true
		_visual_root.scale = Vector3.ONE * _growth_scale
	disappear_finished.emit()


func get_world_anchor() -> Vector3:
	return global_position


func set_ghost_distance(_dist: float) -> void:
	pass


func set_spirit_pressure(value: float) -> void:
	_spirit_pressure = clampf(value, 0.0, 100.0)


func set_human_moving(moving: bool) -> void:
	_human_moving = moving


func set_growth_scale(scale: float) -> void:
	_growth_scale = clampf(scale, GROWTH_SCALE_MIN, GROWTH_SCALE_MAX)
	_apply_growth_scale()


func set_locked_by_ghost(locked: bool) -> void:
	_locked = locked
	if locked:
		_state = VisualState.LOCKED
	elif _state == VisualState.LOCKED:
		_state = VisualState.NORMAL


func set_ghost_charge_time(seconds: float) -> void:
	_ghost_charge_time = maxf(seconds, 0.0)


func set_pull_target(world_center: Vector3, height_above_ground: float, max_horiz: float) -> void:
	_pull_horiz_max = max_horiz
	var base := _compute_base_anchor()
	var flat := Vector2(world_center.x - base.x, world_center.z - base.z)
	if max_horiz < 900.0 and flat.length() > max_horiz:
		flat = flat.normalized() * max_horiz
	_pull_offset = Vector3(flat.x, 0.0, flat.y)
	_pull_height = height_above_ground - FLOAT_HEIGHT


func snap_back(duration: float = 0.1) -> void:
	var start_off := _pull_offset
	var start_h := _pull_height
	_pull_horiz_max = 999.0
	_snap_back_start_off = start_off
	_snap_back_start_h = start_h
	var tween := create_tween()
	tween.tween_method(_apply_snap_back, 0.0, 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _apply_snap_back(t: float) -> void:
	_pull_offset = _snap_back_start_off.lerp(Vector3.ZERO, t)
	_pull_height = lerpf(_snap_back_start_h, 0.0, t)


func play_burst() -> void:
	if _bursting:
		return
	_bursting = true
	_spawn_burst_flash()
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: _visible_strength = v, _visible_strength, 0.0, 0.35)
	tween.tween_callback(_on_burst_done)


func play_stomp_crush() -> void:
	if _bursting:
		return
	_bursting = true
	_threads_spin_enabled = false
	_spawn_burst_flash()
	var tween := create_tween()
	tween.tween_method(_set_core_brightness, 2.2, 0.4, 0.12)
	tween.tween_method(_set_pinpoint_scale, 1.0, 2.5, 0.1)
	tween.tween_method(_set_thread_scatter, 1.0, 0.0, 0.45).set_delay(0.08)
	tween.tween_method(_set_visible_strength, _visible_strength, 0.0, 0.55).set_delay(0.2)
	tween.tween_callback(_on_burst_done)


func _set_core_brightness(value: float) -> void:
	_core_brightness = value


func _set_pinpoint_scale(value: float) -> void:
	if _pinpoint_mesh:
		_pinpoint_mesh.scale = Vector3.ONE * value


func _set_thread_scatter(value: float) -> void:
	_thread_grow = value
	for i in _thread_meshes.size():
		if _thread_meshes[i]:
			_thread_meshes[i].scale = Vector3.ONE * lerpf(1.0, 1.8, 1.0 - value)


func _set_visible_strength(value: float) -> void:
	_visible_strength = value


func _on_burst_done() -> void:
	_bursting = false
	_target_strength = 0.0
	_lifecycle = LifecyclePhase.HIDDEN
	visible = false
	burst_finished.emit()
	disappear_finished.emit()


func _process(delta: float) -> void:
	if _human == null or not is_instance_valid(_human):
		return

	if _lifecycle == LifecyclePhase.HIDDEN and not _bursting:
		visible = false
		return

	_update_state()
	_update_visibility(delta)
	if _visible_strength <= 0.01 and _lifecycle == LifecyclePhase.HIDDEN:
		visible = false
		return
	visible = true

	_update_anchor(delta)
	_update_core_pulse()
	_update_threads(delta)
	_apply_colors()
	_apply_lifecycle_visuals()


func _update_anchor(delta: float) -> void:
	if _lifecycle == LifecyclePhase.SPLASH:
		return
	var target := _compute_anchor() + _pull_offset
	if _lifecycle == LifecyclePhase.LINGER:
		if global_position.distance_squared_to(target) > 0.000001:
			var desired_vel := (target - global_position) / maxf(LINGER_FOLLOW_LAG, 0.001)
			_linger_follow_vel = _linger_follow_vel.move_toward(desired_vel, 12.0 * delta)
			global_position += _linger_follow_vel * delta
		else:
			global_position = target
			_linger_follow_vel = Vector3.ZERO
	else:
		global_position = target


func _apply_lifecycle_visuals() -> void:
	if _lifecycle == LifecyclePhase.SPAWN:
		_update_spawn_visuals()
		if _visual_root:
			_visual_root.scale = Vector3.ONE * _growth_scale * maxf(_halo_grow, 0.001)
	elif _lifecycle == LifecyclePhase.LINGER:
		if _visual_root:
			_visual_root.scale = Vector3.ONE * _growth_scale
			_visual_root.position = _halo_jitter
	elif _lifecycle == LifecyclePhase.STABLE:
		if _visual_root:
			_visual_root.position = Vector3.ZERO
			_visual_root.scale = Vector3.ONE * _growth_scale
	else:
		if _visual_root:
			_visual_root.position = Vector3.ZERO


func _update_state() -> void:
	if _lifecycle == LifecyclePhase.LINGER:
		_state = VisualState.LOCKED
		return
	if _locked:
		_state = VisualState.LOCKED
	elif _spirit_pressure >= 90.0:
		_state = VisualState.SPIRIT_CRITICAL
	elif _spirit_pressure >= 70.0:
		_state = VisualState.SPIRIT_HIGH
	elif _human_moving:
		_state = VisualState.MOVING
	else:
		_state = VisualState.NORMAL


func _update_visibility(delta: float) -> void:
	if _lifecycle == LifecyclePhase.SPAWN:
		_visible_strength = _smoothstep01(_spawn_time / SPAWN_DURATION)
		_target_strength = 1.0
		return
	if _lifecycle == LifecyclePhase.LINGER:
		var fade_t := _smoothstep01(_phase_time / FADE_DISAPPEAR_DURATION)
		_visible_strength = lerpf(_fade_start_alpha, 0.0, fade_t)
		_target_strength = 0.0
		return
	if _lifecycle == LifecyclePhase.STABLE:
		_target_strength = 1.0
		var rate := 2.5 if _target_strength > _visible_strength else 3.5
		_visible_strength = move_toward(_visible_strength, _target_strength, delta * rate)
		return
	_target_strength = 0.0
	_visible_strength = move_toward(_visible_strength, 0.0, delta * 3.5)


func _is_human_crouching() -> bool:
	if _human.has_method("is_crouching"):
		return _human.call("is_crouching")
	return false


func _compute_base_anchor() -> Vector3:
	var feet: Vector3 = _human.global_position
	if _human.has_method("get_feet_position"):
		feet = _human.call("get_feet_position")
	var anchor := Vector3(
		feet.x, ShadowRules.GROUND_SAMPLE_Y + FLOAT_HEIGHT, feet.z
	)
	if _is_human_crouching():
		var forward := -_human.global_transform.basis.z
		forward.y = 0.0
		if forward.length_squared() < 0.0001:
			forward = Vector3(0.0, 0.0, 1.0)
		else:
			forward = forward.normalized()
		anchor += forward * CROUCH_FORWARD_OFFSET
	return anchor


func _compute_anchor() -> Vector3:
	var anchor := _compute_base_anchor()
	anchor += _pull_offset
	anchor.y += _pull_height
	return anchor


func _update_core_pulse() -> void:
	_pulse_time += get_process_delta_time()
	var wave := (sin(_pulse_time * TAU * CORE_PULSE_HZ) + 1.0) * 0.5
	_core_brightness = lerpf(0.7, 1.0, wave)
	if _halo_mat:
		_halo_mat.set_shader_parameter(
			"pulse_brightness", _core_brightness * _visible_strength
		)


func _update_threads(delta: float) -> void:
	if _threads_spin_enabled:
		_thread_rig.rotation.y += deg_to_rad(THREAD_SPIN_DEG) * delta
	var grow := clampf(_thread_grow, 0.0, 1.0)
	for i in _thread_specs.size():
		var spec: Dictionary = _thread_specs[i]
		if _threads_spin_enabled:
			spec["phase"] = float(spec["phase"]) + delta * float(spec["freq"]) * TAU
		var bob := 0.0
		if _threads_spin_enabled:
			bob = sin(float(spec["phase"])) * THREAD_BOB_AMPLITUDE
		var y_off := Vector3(0.0, bob, 0.0)
		var p0: Vector3 = (spec["p0"] as Vector3) * grow + y_off
		var p1: Vector3 = (spec["p1"] as Vector3) * grow + y_off
		var p2: Vector3 = (spec["p2"] as Vector3) * grow + y_off
		var p3: Vector3 = (spec["p3"] as Vector3) * grow + y_off
		if grow < 0.02:
			_thread_meshes[i].mesh = null
			continue
		var points := _sample_cubic_bezier(p0, p1, p2, p3, BEZIER_STEPS)
		_thread_meshes[i].mesh = _build_tube_mesh(points, THREAD_RADIUS * maxf(grow, 0.15))
		_thread_specs[i] = spec


func _sample_cubic_bezier(
	p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, steps: int
) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for step in steps + 1:
		var t := float(step) / float(steps)
		var u := 1.0 - t
		var pt := (
			u * u * u * p0
			+ 3.0 * u * u * t * p1
			+ 3.0 * u * t * t * p2
			+ t * t * t * p3
		)
		pts.append(pt)
	return pts


func _build_tube_mesh(path: PackedVector3Array, radius: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if path.size() < 2:
		return mesh

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var ring_starts: Array[int] = []

	for i in path.size():
		var tangent := Vector3.ZERO
		if i == 0:
			tangent = path[1] - path[0]
		elif i == path.size() - 1:
			tangent = path[i] - path[i - 1]
		else:
			tangent = path[i + 1] - path[i - 1]
		if tangent.length_squared() < 0.0000001:
			tangent = Vector3.UP
		tangent = tangent.normalized()
		var ref := Vector3.UP
		if absf(tangent.dot(ref)) > 0.92:
			ref = Vector3.RIGHT
		var right := tangent.cross(ref).normalized()
		var up := right.cross(tangent).normalized()
		ring_starts.append(vertices.size())
		for s in TUBE_SIDES:
			var angle := TAU * float(s) / float(TUBE_SIDES)
			var normal := (right * cos(angle) + up * sin(angle)).normalized()
			vertices.append(path[i] + normal * radius)
			normals.append(normal)

	for i in path.size() - 1:
		var base_a: int = ring_starts[i]
		var base_b: int = ring_starts[i + 1]
		for s in TUBE_SIDES:
			var s_next := (s + 1) % TUBE_SIDES
			var i0 := base_a + s
			var i1 := base_a + s_next
			var i2 := base_b + s
			var i3 := base_b + s_next
			indices.append_array([i0, i2, i1, i1, i2, i3])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _spawn_burst_flash() -> void:
	var flash := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	var burst_diameter := HALO_DIAMETER * _growth_scale
	sphere.radius = burst_diameter * 0.5
	sphere.height = burst_diameter
	flash.mesh = sphere
	var mat := _make_core_material()
	flash.material_override = mat
	var parent := get_tree().current_scene
	if parent:
		parent.add_child(flash)
		flash.global_position = global_position
		var tween := flash.create_tween()
		tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.12)
		tween.tween_callback(flash.queue_free)


func _thread_color() -> Color:
	match _state:
		VisualState.MOVING:
			return COLOR_MOVE
		VisualState.SPIRIT_CRITICAL:
			return COLOR_SPIRIT_CRIT
		VisualState.LOCKED:
			return COLOR_LOCKED
		VisualState.ITEM_USE:
			return COLOR_ITEM
		VisualState.SPIRIT_HIGH:
			return COLOR_SPIRIT_CRIT if sin(_pulse_time * TAU * 2.0) > 0.0 else COLOR_WARM
		_:
			return COLOR_WARM


func _apply_colors() -> void:
	var alpha := _visible_strength
	var thread_col := _thread_color()
	var locked_charge := _locked and _lifecycle != LifecyclePhase.LINGER
	if locked_charge:
		thread_col = COLOR_LOCKED
	_thread_mat.albedo_color = Color(thread_col.r, thread_col.g, thread_col.b, THREAD_ALPHA * alpha)
	_thread_mat.emission = thread_col
	var core_emission := CORE_EMISSION_PEAK * _core_brightness * alpha
	var thread_energy := core_emission * THREAD_EMISSION_RATIO * alpha
	if locked_charge:
		thread_energy *= CHARGE_LOCK_BRIGHTNESS
	_thread_mat.emission_energy_multiplier = thread_energy

	_pinpoint_mat.albedo_color = Color(1.0, 1.0, 1.0, alpha)
	_pinpoint_mat.emission_energy_multiplier = CORE_EMISSION_PEAK * _core_brightness * alpha
	if locked_charge:
		_pinpoint_mat.emission = COLOR_LOCKED
		_pinpoint_mat.emission_energy_multiplier *= CHARGE_LOCK_BRIGHTNESS

	var halo_col := COLOR_HALO
	var pulse := _core_brightness * alpha
	if _lifecycle == LifecyclePhase.LINGER:
		halo_col = COLOR_LOCKED if sin(_phase_time * TAU * LINGER_FLASH_HZ) > 0.0 else COLOR_CORE
		pulse = 1.2 * alpha
		_pinpoint_mat.emission = halo_col
	elif locked_charge:
		if _ghost_charge_time >= 1.2:
			halo_col = COLOR_LOCKED if sin(_ghost_charge_time * TAU * CHARGE_FLASH_HZ) > 0.0 else COLOR_CORE
			pulse = CHARGE_LOCK_BRIGHTNESS * alpha
		else:
			halo_col = COLOR_LOCKED
			pulse = CHARGE_LOCK_BRIGHTNESS * _core_brightness * alpha

	var halo_exposure := alpha * alpha * maxf(_halo_grow, 0.0)
	if _lifecycle in [LifecyclePhase.STABLE, LifecyclePhase.LINGER]:
		halo_exposure = alpha * alpha
	if locked_charge:
		halo_exposure *= CHARGE_LOCK_BRIGHTNESS
	_halo_mat.set_shader_parameter("glow_color", halo_col)
	_halo_mat.set_shader_parameter("exposure", halo_exposure)
	_halo_mat.set_shader_parameter("pulse_brightness", pulse)

	var show := alpha > SHOW_STRENGTH_THRESHOLD or _lifecycle == LifecyclePhase.SPAWN
	if _lifecycle == LifecyclePhase.SPAWN:
		_pinpoint_mesh.visible = alpha > SHOW_STRENGTH_THRESHOLD
		return
	_core_mesh.visible = show
	_thread_rig.visible = show and _thread_grow > 0.02
	_pinpoint_mesh.visible = false
