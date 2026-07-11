extends CharacterBody3D

const HumanPresenceScript = preload("res://scripts/human_presence.gd")
const GhostStompControllerScript = preload("res://scripts/ghost_stomp_controller.gd")
const ShadowCoreScript = preload("res://scripts/shadow_core.gd")

## Human Fall Flat inspired soft character: wobbly walk, proper jump pose in air.

enum JumpState { IDLE, AIR, LAND }

signal jump_landed(landing_position: Vector3)

@export var player_id: int = 0
@export var faction: FactionInfo.Type = FactionInfo.Type.HUMAN
@export var skin_tint: Color = Color(0.97, 0.96, 0.94)

const WALK_SPEED := 5.8
const ACCEL := 32.0
const FRICTION := 22.0
const GRAVITY := 26.0
const JUMP_SPEED := 7.2
const POSE_LERP := 14.0
const WOBBLE_SPEED := 10.0
const WOBBLE_STRENGTH := 0.14

var _input_prefix: String = "p0"
var _eliminated: bool = false
var _visual: Node3D
var _torso: Node3D
var _head: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_lower: Node3D
var _right_lower: Node3D
var _left_foot: Node3D
var _right_foot: Node3D
var _skin_material: StandardMaterial3D
var _face_material: StandardMaterial3D
var _jump_state: JumpState = JumpState.IDLE
var _land_timer: float = 0.0
var _was_airborne: bool = false
var _jumped_this_airborne: bool = false
var _move_yaw: float = 0.0
var _wobble_phase: float = 0.0
var _airborne_time: float = 0.0
var _pending_jump_land: bool = false
var _follow_camera: Node3D
var _control_enabled := true


func configure_control(enabled: bool, new_player_id: int = -1) -> void:
	_control_enabled = enabled
	if new_player_id >= 0:
		player_id = new_player_id
		_input_prefix = "p0" if player_id == 0 else "p1"


func is_control_enabled() -> bool:
	return _control_enabled


func _should_simulate() -> bool:
	if not _control_enabled:
		return false
	if not multiplayer.has_multiplayer_peer():
		return true
	return is_multiplayer_authority()


func _ready() -> void:
	_input_prefix = "p0" if player_id == 0 else "p1"
	process_physics_priority = 100
	_verify_input_actions()
	_wobble_phase = randf() * TAU
	_skin_material = _make_skin_material(skin_tint)
	_face_material = _make_face_material()
	_build_character()
	_apply_faction_style()
	if player_id == 1:
		_move_yaw = PI
	_attach_faction_components()
	call_deferred("_bind_follow_camera")


func _bind_follow_camera() -> void:
	var root := get_parent()
	if root == null:
		return
	var cam_name := "CameraP0" if player_id == 0 else "CameraP1"
	_follow_camera = root.get_node_or_null(cam_name) as Node3D


func _attach_faction_components() -> void:
	if faction == FactionInfo.Type.HUMAN:
		var presence := HumanPresenceScript.new()
		presence.name = "HumanPresence"
		add_child(presence)
	elif faction == FactionInfo.Type.GHOST:
		var stomp := GhostStompControllerScript.new()
		stomp.name = "GhostStompController"
		add_child(stomp)


func get_spirit_pressure() -> float:
	var presence := get_node_or_null("HumanPresence")
	return presence.spirit_pressure if presence else 0.0


func is_human_moving() -> bool:
	return Vector3(velocity.x, 0.0, velocity.z).length() > 0.5


func _verify_input_actions() -> void:
	for action in ["forward", "back", "left", "right", "jump"]:
		var name := "%s_%s" % [_input_prefix, action]
		if not InputMap.has_action(name):
			push_error("Player %d: missing InputMap action '%s' (check InputSetup autoload)." % [player_id, name])


func _build_character() -> void:
	collision_layer = 2 if faction == FactionInfo.Type.HUMAN else 8
	collision_mask = 1 | ShadowRules.BUILDING_COLLISION_LAYER
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(52.0)
	safe_margin = 0.04

	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.0
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	col.shape = shape
	col.position = Vector3(0.0, 1.02, 0.0)
	add_child(col)

	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	_add_part_mesh(_visual, "Pelvis", _capsule_mesh(0.19, 0.22), Vector3(0.0, 0.95, 0.0))
	_torso = _add_part_mesh(_visual, "Torso", _capsule_mesh(0.17, 0.42), Vector3(0.0, 1.18, 0.0))
	_head = _add_part_mesh(_visual, "Head", _sphere_mesh(0.27), Vector3(0.0, 1.52, 0.0))
	_add_face_dots(_head)

	_left_arm = _add_part_mesh(_visual, "LeftUpperArm", _capsule_mesh(0.07, 0.28), Vector3(-0.27, 1.14, 0.0))
	_add_part_mesh(_left_arm, "LeftLowerArm", _capsule_mesh(0.06, 0.26), Vector3(0.0, -0.28, 0.02))
	_right_arm = _add_part_mesh(_visual, "RightUpperArm", _capsule_mesh(0.07, 0.28), Vector3(0.27, 1.14, 0.0))
	_add_part_mesh(_right_arm, "RightLowerArm", _capsule_mesh(0.06, 0.26), Vector3(0.0, -0.28, 0.02))

	_left_leg = _add_part_mesh(_visual, "LeftUpperLeg", _capsule_mesh(0.08, 0.34), Vector3(-0.11, 0.68, 0.0))
	_right_leg = _add_part_mesh(_visual, "RightUpperLeg", _capsule_mesh(0.08, 0.34), Vector3(0.11, 0.68, 0.0))
	_left_lower = _add_part_mesh(_left_leg, "LeftLowerLeg", _capsule_mesh(0.07, 0.32), Vector3(0.0, -0.34, 0.0))
	_right_lower = _add_part_mesh(_right_leg, "RightLowerLeg", _capsule_mesh(0.07, 0.32), Vector3(0.0, -0.34, 0.0))
	_left_foot = _add_part_mesh(_left_lower, "LeftFoot", _sphere_mesh(0.09), Vector3(0.0, -0.22, 0.05))
	_right_foot = _add_part_mesh(_right_lower, "RightFoot", _sphere_mesh(0.09), Vector3(0.0, -0.22, 0.05))


func _apply_faction_style() -> void:
	if faction == FactionInfo.Type.GHOST:
		_skin_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_skin_material.albedo_color = Color(0.62, 0.78, 0.98, 0.58)
		_skin_material.emission_enabled = true
		_skin_material.emission = Color(0.45, 0.62, 0.95)
		_skin_material.emission_energy_multiplier = 0.35
		_face_material.albedo_color = Color(0.12, 0.16, 0.28)

	var cast_shadows: bool = faction == FactionInfo.Type.HUMAN
	_set_mesh_shadow_casting(_visual, cast_shadows)


func _set_mesh_shadow_casting(node: Node, enabled: bool) -> void:
	var mode: GeometryInstance3D.ShadowCastingSetting = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if enabled
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = mode
	for child in node.get_children():
		_set_mesh_shadow_casting(child, enabled)


func get_faction() -> int:
	return faction


func casts_sun_shadow() -> bool:
	return FactionInfo.casts_sun_shadow(faction)


func get_faction_name() -> String:
	return FactionInfo.display_name(faction)


func _add_part_mesh(parent: Node3D, part_name: String, mesh: Mesh, local_pos: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = part_name
	pivot.position = local_pos
	parent.add_child(pivot)

	var vis := MeshInstance3D.new()
	vis.mesh = mesh
	vis.material_override = _skin_material
	pivot.add_child(vis)
	return pivot


func _add_face_dots(head: Node3D) -> void:
	for spec in [
		{"name": "LeftEye", "pos": Vector3(-0.1, 0.04, 0.24)},
		{"name": "RightEye", "pos": Vector3(0.1, 0.04, 0.24)},
		{"name": "Mouth", "pos": Vector3(0.0, -0.07, 0.25)},
	]:
		var dot := MeshInstance3D.new()
		dot.name = spec.name
		dot.mesh = _sphere_mesh(0.025 if spec.name != "Mouth" else 0.018)
		dot.material_override = _face_material
		dot.position = spec.pos
		if spec.name == "Mouth":
			dot.scale = Vector3(1.6, 0.35, 0.35)
		head.add_child(dot)


func _physics_process(delta: float) -> void:
	if _eliminated:
		return
	if not _should_simulate():
		return

	_handle_jump_input()
	_sync_facing_from_camera()
	var wish_dir := _read_move_direction()
	_update_jump_state(delta)
	_apply_locomotion(delta, wish_dir)

	if _is_charge_stomping():
		_apply_charge_stomp_pose(delta)
	elif _should_use_jump_pose():
		_apply_jump_pose(delta)
	else:
		_apply_walk_pose(delta, wish_dir)

	move_and_slide()

	if _pending_jump_land:
		_pending_jump_land = false
		_emit_jump_landed(_landing_position())


func _emit_jump_landed(landing_position: Vector3) -> void:
	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			jump_landed.emit(landing_position)
		else:
			_report_jump_landed.rpc_id(1, landing_position)
	else:
		jump_landed.emit(landing_position)


@rpc("any_peer", "call_remote", "reliable")
func _report_jump_landed(landing_position: Vector3) -> void:
	if multiplayer.is_server():
		jump_landed.emit(landing_position)


func _should_use_jump_pose() -> bool:
	return _jump_state != JumpState.IDLE or not is_on_floor()


func _read_move_direction() -> Vector3:
	var input_dir := Input.get_vector(
		"%s_left" % _input_prefix,
		"%s_right" % _input_prefix,
		"%s_forward" % _input_prefix,
		"%s_back" % _input_prefix,
		0.15
	)
	if input_dir.length_squared() < 0.01:
		return Vector3.ZERO
	var cam_forward := Vector3(-sin(_move_yaw), 0.0, -cos(_move_yaw))
	var cam_right := Vector3(cos(_move_yaw), 0.0, -sin(_move_yaw))
	return (cam_right * input_dir.x + cam_forward * -input_dir.y).normalized()


func _sync_facing_from_camera() -> void:
	if _follow_camera == null:
		_bind_follow_camera()
	if _follow_camera == null:
		return
	if _follow_camera.has_method("get_view_yaw"):
		_move_yaw = _follow_camera.call("get_view_yaw")
	var view_forward := Vector3(-sin(_move_yaw), 0.0, -cos(_move_yaw))
	if _follow_camera.has_method("get_camera_forward_xz"):
		view_forward = _follow_camera.call("get_camera_forward_xz")
	# 模型正面朝 +Z，需与相机水平视线方向一致。
	rotation.y = atan2(view_forward.x, view_forward.z)


func _wish_dir_local(wish_dir: Vector3) -> Vector3:
	if wish_dir.length_squared() < 0.0001:
		return Vector3.ZERO
	return global_transform.basis.inverse() * wish_dir


func _apply_locomotion(delta: float, wish_dir: Vector3) -> void:
	var vel := velocity
	if not is_on_floor():
		vel.y -= GRAVITY * delta
	elif vel.y < 0.0:
		vel.y = 0.0

	if is_on_floor():
		var speed_mult := _move_speed_multiplier()
		var horizontal := Vector3(vel.x, 0.0, vel.z)
		if wish_dir.length_squared() > 0.01:
			var target := wish_dir * WALK_SPEED * speed_mult
			horizontal = horizontal.lerp(target, clampf(ACCEL * delta, 0.0, 1.0))
		else:
			horizontal = horizontal.lerp(Vector3.ZERO, clampf(FRICTION * delta, 0.0, 1.0))
		vel.x = horizontal.x
		vel.z = horizontal.z

	velocity = vel


func _get_stomp_controller() -> Node:
	return get_node_or_null("GhostStompController")


func _move_speed_multiplier() -> float:
	if faction != FactionInfo.Type.GHOST:
		return 1.0
	var stomp := _get_stomp_controller()
	if stomp and stomp.has_method("get_move_speed_multiplier"):
		return stomp.get_move_speed_multiplier()
	return 1.0


func _is_charge_stomping() -> bool:
	if faction != FactionInfo.Type.GHOST:
		return false
	var stomp := _get_stomp_controller()
	return stomp != null and stomp.has_method("is_charging") and stomp.is_charging()


func _apply_charge_stomp_pose(delta: float) -> void:
	var stomp := _get_stomp_controller()
	var charge_t: float = stomp.get_charge_progress() if stomp and stomp.has_method("get_charge_progress") else 0.0
	var charge_time: float = stomp.get_charge_time() if stomp and stomp.has_method("get_charge_time") else 0.0
	var blend := clampf(POSE_LERP * delta, 0.0, 1.0)
	var raise_t := clampf(charge_time / 0.35, 0.0, 1.0)
	var lift := lerpf(0.0, 0.55, raise_t * raise_t)
	var knee_pitch := lerpf(0.0, deg_to_rad(95.0), raise_t)
	var torso_pitch := lerpf(0.0, 0.22, charge_t)
	var arm_spread := lerpf(0.0, 0.42, charge_t)

	_lerp_visual_y(lerpf(0.0, -0.04, charge_t), blend)
	_lerp_rotation(_torso, Vector3(torso_pitch, 0.0, 0.0), blend)
	_lerp_rotation(_head, Vector3(0.08, 0.0, 0.0), blend)
	_lerp_rotation(_left_arm, Vector3(0.18 + arm_spread, 0.0, 0.22), blend)
	_lerp_rotation(_right_arm, Vector3(0.28 + arm_spread, 0.0, -0.28), blend)
	_lerp_rotation(_left_leg, Vector3(-0.12, 0.0, 0.0), blend)
	_lerp_rotation(_right_leg, Vector3(0.85 * raise_t, 0.0, 0.0), blend)
	_lerp_rotation(_left_lower, Vector3(-0.12, 0.0, 0.0), blend)
	_lerp_rotation(_right_lower, Vector3(knee_pitch, 0.0, 0.0), blend)
	if _right_foot:
		_right_foot.position.y = lerpf(_right_foot.position.y, -0.22 + lift, blend)


func _apply_walk_pose(delta: float, wish_dir: Vector3) -> void:
	var speed := Vector3(velocity.x, 0.0, velocity.z).length()
	var move_amount := clampf(speed / WALK_SPEED, 0.0, 1.0)
	var local_wish := _wish_dir_local(wish_dir)
	_wobble_phase += delta * WOBBLE_SPEED * (0.35 + move_amount * 0.9)

	var sway := sin(_wobble_phase) * WOBBLE_STRENGTH * move_amount
	var bob := sin(_wobble_phase * 2.0) * 0.03 * move_amount
	var blend := clampf(POSE_LERP * delta, 0.0, 1.0)

	_lerp_visual_y(bob, blend)
	_lerp_rotation(_torso, Vector3(-local_wish.z * 0.08 - sway * 0.15, 0.0, sway * 0.55), blend)
	_lerp_rotation(_head, Vector3(0.0, sin(_wobble_phase * 0.5) * 0.05 * move_amount, sway * 0.25), blend)
	_lerp_rotation(_left_arm, Vector3(sin(_wobble_phase) * 0.45 * move_amount + 0.12, 0.0, 0.08), blend)
	_lerp_rotation(_right_arm, Vector3(-sin(_wobble_phase) * 0.45 * move_amount + 0.12, 0.0, -0.08), blend)
	_lerp_rotation(_left_leg, Vector3(sin(_wobble_phase + PI) * 0.28 * move_amount, 0.0, 0.0), blend)
	_lerp_rotation(_right_leg, Vector3(-sin(_wobble_phase + PI) * 0.28 * move_amount, 0.0, 0.0), blend)
	_lerp_rotation(_left_lower, Vector3(-sin(_wobble_phase + PI) * 0.22 * move_amount, 0.0, 0.0), blend)
	_lerp_rotation(_right_lower, Vector3(sin(_wobble_phase + PI) * 0.22 * move_amount, 0.0, 0.0), blend)
	if _right_foot:
		_right_foot.position.y = lerpf(_right_foot.position.y, -0.22, blend)


func _apply_jump_pose(delta: float) -> void:
	var vy := velocity.y
	var rising := vy > 0.5
	var falling := vy < -0.5
	var blend := clampf(POSE_LERP * delta, 0.0, 1.0)

	var leg_pitch := 0.42 if rising else 0.18
	var knee_bend := -0.95 if rising else -0.55
	var arm_lift := -0.72 if rising else -0.35
	var torso_pitch := -0.1 if rising else 0.08
	var visual_y := -0.05 if _jump_state == JumpState.LAND else 0.0

	if falling:
		leg_pitch = 0.28
		knee_bend = -0.42
		arm_lift = -0.2
		torso_pitch = 0.14

	_lerp_visual_y(visual_y, blend)
	_lerp_rotation(_torso, Vector3(torso_pitch, 0.0, 0.0), blend)
	_lerp_rotation(_head, Vector3(-0.06, 0.0, 0.0), blend)
	_lerp_rotation(_left_arm, Vector3(arm_lift, 0.0, 0.18), blend)
	_lerp_rotation(_right_arm, Vector3(arm_lift, 0.0, -0.18), blend)
	_lerp_rotation(_left_leg, Vector3(leg_pitch, 0.0, 0.04), blend)
	_lerp_rotation(_right_leg, Vector3(leg_pitch, 0.0, -0.04), blend)
	_lerp_rotation(_left_lower, Vector3(knee_bend, 0.0, 0.0), blend)
	_lerp_rotation(_right_lower, Vector3(knee_bend, 0.0, 0.0), blend)


func _lerp_visual_y(target_y: float, blend: float) -> void:
	if _visual:
		_visual.position.y = lerpf(_visual.position.y, target_y, blend)


func _lerp_rotation(part: Node3D, target: Vector3, blend: float) -> void:
	if part == null:
		return
	part.rotation.x = lerpf(part.rotation.x, target.x, blend)
	part.rotation.y = lerpf(part.rotation.y, target.y, blend)
	part.rotation.z = lerpf(part.rotation.z, target.z, blend)


func _handle_jump_input() -> void:
	if _is_charge_stomping():
		return
	if not Input.is_action_just_pressed("%s_jump" % _input_prefix):
		return
	if _jump_state != JumpState.IDLE or not is_on_ground():
		return
	_start_jump()


func _start_jump() -> void:
	_jump_state = JumpState.AIR
	_was_airborne = false
	_jumped_this_airborne = true
	_land_timer = 0.0
	_airborne_time = 0.0
	floor_snap_length = 0.08
	var vel := velocity
	vel.y = JUMP_SPEED
	velocity = vel


func _update_jump_state(delta: float) -> void:
	match _jump_state:
		JumpState.AIR:
			if not is_on_floor():
				_was_airborne = true
				_airborne_time += delta
			elif _was_airborne:
				_jump_state = JumpState.LAND
				_land_timer = 0.0
				floor_snap_length = 0.35
				if _jumped_this_airborne:
					_pending_jump_land = true
				_jumped_this_airborne = false
				_airborne_time = 0.0
			elif velocity.y <= 0.05:
				# Still on floor and not rising — jump failed to leave ground.
				_jump_state = JumpState.IDLE
				_jumped_this_airborne = false
		JumpState.LAND:
			_land_timer += delta
			if _land_timer > 0.16:
				_jump_state = JumpState.IDLE


func _landing_position() -> Vector3:
	# Use body root XZ — animated foot bones stay in jump pose at landing frame.
	var pos: Vector3 = global_position
	pos.y = ShadowRules.GROUND_SAMPLE_Y
	return pos


func is_on_ground() -> bool:
	return is_on_floor()


func is_crouching() -> bool:
	return false


func get_foot_collision_center() -> Vector3:
	var feet := get_feet_position()
	return Vector3(feet.x, ShadowRules.GROUND_SAMPLE_Y, feet.z)


func get_feet_position() -> Vector3:
	if _left_foot and _right_foot:
		return (_left_foot.global_position + _right_foot.global_position) * 0.5
	return global_position + Vector3(0.0, 0.08, 0.0)


func get_ankle_position() -> Vector3:
	var feet := get_feet_position()
	var ankle_y := ShadowRules.GROUND_SAMPLE_Y + 0.10
	if _left_lower and _right_lower:
		ankle_y = (_left_lower.global_position.y + _right_lower.global_position.y) * 0.5
	ankle_y = maxf(ankle_y, ShadowRules.GROUND_SAMPLE_Y + 0.06)
	return Vector3(feet.x, ankle_y, feet.z)


func get_camera_anchor() -> Vector3:
	return global_position + Vector3(0.0, 0.95, 0.0)


func set_move_yaw(yaw: float) -> void:
	set_facing_yaw(yaw)


func set_facing_yaw(yaw: float) -> void:
	_move_yaw = yaw
	var view_forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	rotation.y = atan2(view_forward.x, view_forward.z)


func get_facing_yaw() -> float:
	return _move_yaw


func get_physics_rids() -> Array:
	return [get_rid()]


func eliminate() -> void:
	if _eliminated:
		return
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		_apply_eliminate.rpc()
	else:
		_apply_eliminate()


@rpc("authority", "call_local", "reliable")
func _apply_eliminate() -> void:
	if _eliminated:
		return
	_eliminated = true
	var presence: Node = get_node_or_null("HumanPresence")
	var core: ShadowCore = presence.get_shadow_core() as ShadowCore if presence and presence.has_method("get_shadow_core") else null
	if core:
		core.set_exposure_strength(0.0)
	set_physics_process(false)
	visible = false


func _make_skin_material(tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = 0.98
	m.metallic = 0.0
	m.specular = 0.06
	m.rim_enabled = true
	m.rim = 0.07
	return m


func _make_face_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.05, 0.05, 0.07)
	m.roughness = 0.65
	return m


func _capsule_mesh(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	return m


func _sphere_mesh(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	return m
