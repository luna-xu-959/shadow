class_name ShadowRules
extends RefCounted

const FactionInfo := preload("res://scripts/faction.gd")

const RAY_LENGTH := 200.0
const GROUND_SAMPLE_Y := 0.04
const FOOT_SAMPLE_RADIUS := 0.16
const FOOT_SAMPLE_COUNT := 5
const HUMAN_COLLISION_LAYER := 2
const MIN_MAIN_LIGHT_ENERGY := 0.12
const MAIN_SHADOW_LIGHT_GROUP := "main_shadow_light"


static func is_sunlight_active(sun: DirectionalLight3D) -> bool:
	if sun == null or not is_instance_valid(sun):
		return false
	return sun.visible and sun.light_energy > MIN_MAIN_LIGHT_ENERGY


static func has_active_main_shadow_light(scene_root: Node) -> bool:
	if scene_root == null:
		return false
	var tree := scene_root.get_tree()
	if tree == null:
		return false
	for node in tree.get_nodes_in_group(MAIN_SHADOW_LIGHT_GROUP):
		var light := node as Light3D
		if light and _is_main_light_active(light):
			return true
	return false


static func count_active_main_shadow_lights(scene_root: Node) -> int:
	if scene_root == null:
		return 0
	var tree := scene_root.get_tree()
	if tree == null:
		return 0
	var count := 0
	for node in tree.get_nodes_in_group(MAIN_SHADOW_LIGHT_GROUP):
		var light := node as Light3D
		if light and _is_main_light_active(light):
			count += 1
	return count


static func shadow_basis_from_sun(sun: DirectionalLight3D) -> Dictionary:
	var light_dir := -sun.global_transform.basis.z
	var forward := Vector3(light_dir.x, 0.0, light_dir.z)
	if forward.length_squared() < 0.0001:
		forward = Vector3(0.0, 0.0, -1.0)
	else:
		forward = forward.normalized()
	return {
		"forward": forward,
		"yaw_degrees": rad_to_deg(atan2(forward.x, forward.z)),
	}


static func toward_light_direction(light: Light3D) -> Vector3:
	if light is DirectionalLight3D:
		return (light as DirectionalLight3D).global_transform.basis.z.normalized()
	return Vector3.UP


static func can_shadow_capture(attacker: Node, caster: Node) -> bool:
	if not is_instance_valid(attacker) or not is_instance_valid(caster):
		return false
	if not attacker.has_method("get_faction") or not caster.has_method("get_faction"):
		return false
	return FactionInfo.can_capture_shadow(
		attacker.call("get_faction"),
		caster.call("get_faction")
	)


static func is_ground_point_in_caster_main_shadows(
	ground_point: Vector3,
	caster: Node,
	space_state: PhysicsDirectSpaceState3D,
	exclude: Array,
	scene_root: Node
) -> bool:
	if not is_instance_valid(caster):
		return false
	if caster.has_method("casts_sun_shadow") and not caster.call("casts_sun_shadow"):
		return false
	if scene_root == null:
		return false

	var tree := scene_root.get_tree()
	if tree == null:
		return false

	for node in tree.get_nodes_in_group(MAIN_SHADOW_LIGHT_GROUP):
		var light := node as Light3D
		if light == null or not _is_main_light_active(light):
			continue
		if is_ground_point_in_caster_shadow_from_light(
			ground_point, caster, light, space_state, exclude
		):
			return true
	return false


static func is_ground_point_in_caster_shadow_from_light(
	ground_point: Vector3,
	caster: Node,
	light: Light3D,
	space_state: PhysicsDirectSpaceState3D,
	exclude: Array = []
) -> bool:
	if light is DirectionalLight3D:
		return _is_point_in_directional_shadow(
			ground_point, caster, light as DirectionalLight3D, space_state, exclude
		)
	if light is OmniLight3D:
		return _is_point_in_omni_shadow(
			ground_point, caster, light as OmniLight3D, space_state, exclude
		)
	if light is SpotLight3D:
		return _is_point_in_spot_shadow(
			ground_point, caster, light as SpotLight3D, space_state, exclude
		)
	return false


static func is_ground_point_in_caster_sun_shadow(
	ground_point: Vector3,
	caster: Node,
	sun: DirectionalLight3D,
	space_state: PhysicsDirectSpaceState3D,
	exclude: Array = []
) -> bool:
	if not is_sunlight_active(sun):
		return false
	return is_ground_point_in_caster_shadow_from_light(
		ground_point, caster, sun, space_state, exclude
	)


static func is_attacker_in_caster_sun_shadow(
	attacker: Node,
	caster: Node,
	sun: DirectionalLight3D,
	space_state: PhysicsDirectSpaceState3D
) -> bool:
	if not can_shadow_capture(attacker, caster):
		return false
	if attacker.has_method("is_on_ground") and not attacker.call("is_on_ground"):
		return false

	var feet_pos: Vector3 = (
		attacker.call("get_feet_position")
		if attacker.has_method("get_feet_position")
		else attacker.global_position
	)
	var exclude: Array = []
	if attacker.has_method("get_physics_rids"):
		exclude = attacker.call("get_physics_rids")

	return is_ground_point_in_caster_sun_shadow(
		feet_pos, caster, sun, space_state, exclude
	)


static func _is_main_light_active(light: Light3D) -> bool:
	if not is_instance_valid(light) or not light.visible:
		return false
	return light.light_energy >= MIN_MAIN_LIGHT_ENERGY


static func _is_point_in_directional_shadow(
	ground_point: Vector3,
	caster: Node,
	light: DirectionalLight3D,
	space_state: PhysicsDirectSpaceState3D,
	exclude: Array
) -> bool:
	var toward_light := light.global_transform.basis.z.normalized()
	for offset in _foot_sample_offsets():
		var origin := _ground_sample(ground_point + offset)
		var target := origin + toward_light * RAY_LENGTH
		if _ray_hits_caster(origin, target, caster, space_state, exclude):
			return true
	return false


static func _is_point_in_omni_shadow(
	ground_point: Vector3,
	caster: Node,
	light: OmniLight3D,
	space_state: PhysicsDirectSpaceState3D,
	exclude: Array
) -> bool:
	var light_pos := light.global_position
	var reach := light.omni_range
	for offset in _foot_sample_offsets():
		var origin := _ground_sample(ground_point + offset)
		if origin.distance_to(light_pos) > reach:
			continue
		if _ray_hits_caster(origin, light_pos, caster, space_state, exclude):
			return true
	return false


static func _is_point_in_spot_shadow(
	ground_point: Vector3,
	caster: Node,
	light: SpotLight3D,
	space_state: PhysicsDirectSpaceState3D,
	exclude: Array
) -> bool:
	var light_pos := light.global_position
	var reach := light.spot_range
	for offset in _foot_sample_offsets():
		var origin := _ground_sample(ground_point + offset)
		if origin.distance_to(light_pos) > reach:
			continue
		if _ray_hits_caster(origin, light_pos, caster, space_state, exclude):
			return true
	return false


static func _ray_hits_caster(
	origin: Vector3,
	target: Vector3,
	caster: Node,
	space_state: PhysicsDirectSpaceState3D,
	exclude: Array
) -> bool:
	if origin.distance_squared_to(target) < 0.0001:
		return false

	var query := PhysicsRayQueryParameters3D.create(origin, target)
	query.collision_mask = HUMAN_COLLISION_LAYER
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = exclude

	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	return _collider_belongs_to_player(hit.get("collider"), caster)


static func _foot_sample_offsets() -> Array[Vector3]:
	var offsets: Array[Vector3] = [Vector3.ZERO]
	var angle_step := TAU / float(FOOT_SAMPLE_COUNT - 1)
	for i in range(1, FOOT_SAMPLE_COUNT):
		var angle := angle_step * float(i - 1)
		offsets.append(Vector3(cos(angle), 0.0, sin(angle)) * FOOT_SAMPLE_RADIUS)
	return offsets


static func _ground_sample(world_pos: Vector3) -> Vector3:
	world_pos.y = GROUND_SAMPLE_Y
	return world_pos


static func _collider_belongs_to_player(collider: Object, player: Node) -> bool:
	if collider == null or not is_instance_valid(player):
		return false
	if collider == player:
		return true
	if collider is Node:
		var node := collider as Node
		return player == node or player.is_ancestor_of(node)
	return false
