extends CharacterBody3D

## Human Fall Flat inspired soft character: wobbly walk, proper jump pose in air.
const FactionInfo := preload("res://scripts/faction.gd")

enum Faction { HUMAN, GHOST }

enum JumpState { IDLE, AIR, LAND }

signal jump_landed(landing_position: Vector3)

@export var player_id: int = 0
@export var faction: Faction = Faction.HUMAN
@export var skin_tint: Color = Color(0.97, 0.96, 0.94)

const WALK_SPEED := 5.8
const ACCEL := 32.0
const FRICTION := 22.0
const GRAVITY := 26.0
const JUMP_SPEED := 7.2
const POSE_LERP := 14.0
const FACE_TURN_SPEED := 14.0
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


func _ready() -> void:
	_input_prefix = "p0" if player_id == 0 else "p1"
	_wobble_phase = randf() * TAU
	_skin_material = _make_skin_material(skin_tint)
	_face_material = _make_face_material()
	_build_character()
	_apply_faction_style()
	if player_id == 1:
		_move_yaw = PI
		rotation.y = -PI


func _build_character() -> void:
	collision_layer = 2 if faction == Faction.HUMAN else 8
	collision_mask = 1
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
	if faction == Faction.GHOST:
		_skin_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_skin_material.albedo_color = Color(0.62, 0.78, 0.98, 0.58)
		_skin_material.emission_enabled = true
		_skin_material.emission = Color(0.45, 0.62, 0.95)
		_skin_material.emission_energy_multiplier = 0.35
		_face_material.albedo_color = Color(0.12, 0.16, 0.28)

	var cast_shadows: bool = faction == Faction.HUMAN
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

	_handle_jump_input()
	var wish_dir := _read_move_direction()
	_update_jump_state(delta)
	_apply_facing(delta)
	_apply_locomotion(delta, wish_dir)

	if _should_use_jump_pose():
		_apply_jump_pose(delta)
	else:
		_apply_walk_pose(delta, wish_dir)

	move_and_slide()


func _should_use_jump_pose() -> bool:
	return _jump_state != JumpState.IDLE or not is_on_floor()


func _read_move_direction() -> Vector3:
	var input_dir := Vector2(
		Input.get_action_strength("%s_right" % _input_prefix)
			- Input.get_action_strength("%s_left" % _input_prefix),
		Input.get_action_strength("%s_back" % _input_prefix)
			- Input.get_action_strength("%s_forward" % _input_prefix)
	)
	if input_dir.length_squared() < 0.01:
		return Vector3.ZERO
	input_dir = input_dir.normalized()
	var cam_forward := Vector3(-sin(_move_yaw), 0.0, -cos(_move_yaw))
	var cam_right := Vector3(cos(_move_yaw), 0.0, -sin(_move_yaw))
	return (cam_right * input_dir.x + cam_forward * -input_dir.y).normalized()


func _apply_facing(delta: float) -> void:
	var blend := clampf(FACE_TURN_SPEED * delta, 0.0, 1.0)
	rotation.y = lerp_angle(rotation.y, -_move_yaw, blend)


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

	if _jump_state == JumpState.IDLE or _jump_state == JumpState.LAND:
		var horizontal := Vector3(vel.x, 0.0, vel.z)
		if wish_dir.length_squared() > 0.01:
			var target := wish_dir * WALK_SPEED
			horizontal = horizontal.lerp(target, clampf(ACCEL * delta, 0.0, 1.0))
		else:
			horizontal = horizontal.lerp(Vector3.ZERO, clampf(FRICTION * delta, 0.0, 1.0))
		vel.x = horizontal.x
		vel.z = horizontal.z

	velocity = vel


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
	var vel := velocity
	vel.y = JUMP_SPEED
	velocity = vel


func _update_jump_state(delta: float) -> void:
	match _jump_state:
		JumpState.AIR:
			if not is_on_floor():
				_was_airborne = true
			elif _was_airborne:
				_jump_state = JumpState.LAND
				_land_timer = 0.0
				if _jumped_this_airborne:
					jump_landed.emit(_landing_position())
				_jumped_this_airborne = false
		JumpState.LAND:
			_land_timer += delta
			if _land_timer > 0.16:
				_jump_state = JumpState.IDLE


func _landing_position() -> Vector3:
	var pos := get_feet_position()
	pos.y = 0.04
	return pos


func is_on_ground() -> bool:
	return is_on_floor()


func get_feet_position() -> Vector3:
	if _left_foot and _right_foot:
		return (_left_foot.global_position + _right_foot.global_position) * 0.5
	return global_position + Vector3(0.0, 0.08, 0.0)


func get_camera_anchor() -> Vector3:
	return global_position + Vector3(0.0, 0.95, 0.0)


func set_move_yaw(yaw: float) -> void:
	_move_yaw = yaw


func get_physics_rids() -> Array:
	return [get_rid()]


func eliminate() -> void:
	if _eliminated:
		return
	_eliminated = true
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
