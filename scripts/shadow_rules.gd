class_name ShadowRules
extends RefCounted

const RAY_LENGTH := 200.0
const GROUND_SAMPLE_Y := 0.04
const FOOT_SAMPLE_RADIUS := 0.28
const FOOT_SAMPLE_COUNT := 6
const HUMAN_COLLISION_LAYER := 2
const MIN_MAIN_LIGHT_ENERGY := 0.01
## Scene brightness below this still allows the strongest main light to cast a shadow.
const MIN_SCENE_BRIGHTNESS := 0.22
## Local main-light strength below this spawns a shadow core (1s in shade / weak light).
const SHADOW_CORE_LIGHT_THRESHOLD := 0.32
const AMBIENT_BRIGHTNESS_REFERENCE := 0.38
const MAIN_SHADOW_LIGHT_GROUP := "main_shadow_light"
const WORLD_OCCLUSION_LAYER := 4
const BUILDING_COLLISION_LAYER := 4
const BUILDING_SHADOW_MAX_LENGTH := 14.0
const OCCLUSION_SAMPLE_HEIGHT := 1.05


static func get_dominant_main_shadow_light(
	scene_root: Node,
	world_point: Vector3 = Vector3.ZERO
) -> Light3D:
	if scene_root == null:
		return null
	var tree := scene_root.get_tree()
	if tree == null:
		return null

	var best: Light3D = null
	var best_raw := 0.0
	for node in tree.get_nodes_in_group(MAIN_SHADOW_LIGHT_GROUP):
		var light := node as Light3D
		if light == null:
			continue
		if _is_interior_light(light):
			continue
		var raw := _raw_main_light_strength_at(light, world_point)
		if raw > best_raw:
			best_raw = raw
			best = light

	if best == null:
		return null
	var low := is_low_brightness_scene(scene_root, world_point)
	if best_raw >= MIN_MAIN_LIGHT_ENERGY or (low and best_raw > 0.0):
		return best
	return null


static func dominant_light_label(light: Light3D) -> String:
	if light == null:
		return "None"
	if light is DirectionalLight3D:
		return "Sun"
	if light.name.contains("Interior"):
		return "House light"
	if light.get_parent() and str(light.get_parent().name).contains("StreetLamp"):
		return "Street lamp"
	return light.name


static func has_active_main_shadow_light(
	scene_root: Node,
	world_point: Vector3 = Vector3.ZERO
) -> bool:
	return get_dominant_main_shadow_light(scene_root, world_point) != null


static func is_sunlight_active(sun: DirectionalLight3D) -> bool:
	if sun == null or not is_instance_valid(sun):
		return false
	return sun.visible and sun.light_energy > MIN_MAIN_LIGHT_ENERGY


static func count_active_main_shadow_lights(scene_root: Node) -> int:
	if scene_root == null:
		return 0
	var tree := scene_root.get_tree()
	if tree == null:
		return 0
	var count := 0
	for node in tree.get_nodes_in_group(MAIN_SHADOW_LIGHT_GROUP):
		var light := node as Light3D
		if light and _main_light_strength_at(light, Vector3.ZERO, scene_root) >= MIN_MAIN_LIGHT_ENERGY:
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

	var dominant := get_dominant_main_shadow_light(scene_root, ground_point)
	if dominant == null:
		return false

	return is_ground_point_in_caster_shadow_from_light(
		ground_point, caster, dominant, space_state, exclude
	)


static func describe_shadow_check(
	landing_position: Vector3,
	caster: Node,
	space_state: PhysicsDirectSpaceState3D,
	exclude: Array,
	scene_root: Node
) -> String:
	if not is_instance_valid(caster):
		return "Invalid Human player."
	var caster_g := _caster_ground_anchor(caster)
	var dist := Vector2(
		landing_position.x - caster_g.x,
		landing_position.z - caster_g.z
	).length()
	var dominant := get_dominant_main_shadow_light(scene_root, landing_position)
	if dominant == null:
		return "No main light at landing (dist to Human %.1fm)." % dist
	var in_footprint := _point_in_caster_shadow_footprint(
		landing_position, caster, dominant
	)
	var hit := is_ground_point_in_caster_shadow_from_light(
		landing_position, caster, dominant, space_state, exclude
	)
	return "dist %.1fm | brightness %.2f | light %s ONLY | in_zone %s | shadow_hit %s" % [
		dist,
		get_scene_brightness(scene_root, landing_position),
		dominant_light_label(dominant),
		str(in_footprint),
		str(hit),
	]


static func get_scene_brightness(scene_root: Node, world_point: Vector3 = Vector3.ZERO) -> float:
	if scene_root == null:
		return 1.0
	var day_factor := _get_day_factor(scene_root)
	var ambient := _get_ambient_energy(scene_root)
	var ambient_norm := ambient / AMBIENT_BRIGHTNESS_REFERENCE

	var max_raw := 0.0
	var tree := scene_root.get_tree()
	if tree:
		for node in tree.get_nodes_in_group(MAIN_SHADOW_LIGHT_GROUP):
			var light := node as Light3D
			if light:
				max_raw = maxf(max_raw, _raw_main_light_strength_at(light, world_point))

	return clampf(day_factor * 0.5 + ambient_norm * 0.35 + max_raw * 0.3, 0.0, 2.0)


static func get_local_brightness(scene_root: Node, world_point: Vector3 = Vector3.ZERO) -> float:
	if scene_root == null:
		return 1.0
	var day_factor := _get_day_factor(scene_root)
	var ambient := _get_ambient_energy(scene_root)
	var ambient_norm := ambient / AMBIENT_BRIGHTNESS_REFERENCE
	var ambient_part := day_factor * 0.12 + ambient_norm * 0.55

	var space_state := _get_space_state(scene_root)
	if space_state == null or not is_point_in_direct_light_shadow(scene_root, world_point, space_state):
		var dominant := get_dominant_main_shadow_light(scene_root, world_point)
		if dominant:
			var direct := _raw_main_light_strength_at(dominant, world_point)
			return clampf(ambient_part + direct * 0.45, 0.0, 2.0)
	return clampf(ambient_part, 0.0, 2.0)


static func is_low_brightness_scene(scene_root: Node, world_point: Vector3 = Vector3.ZERO) -> bool:
	return get_scene_brightness(scene_root, world_point) < MIN_SCENE_BRIGHTNESS


static func is_point_in_direct_light_shadow(
	scene_root: Node,
	world_point: Vector3,
	space_state: PhysicsDirectSpaceState3D
) -> bool:
	if scene_root == null:
		return false
	var sun := _get_sun_light(scene_root)
	if sun == null or not is_sunlight_active(sun):
		return false
	if space_state and _is_in_directional_light_shadow(world_point, sun, space_state):
		return true
	return _is_in_building_sun_shadow(scene_root, world_point, sun)


static func get_local_main_light_strength(scene_root: Node, world_point: Vector3 = Vector3.ZERO) -> float:
	if scene_root == null:
		return 0.0
	var dominant := get_dominant_main_shadow_light(scene_root, world_point)
	if dominant == null:
		return 0.0
	var raw := _raw_main_light_strength_at(dominant, world_point)
	if raw <= 0.0:
		return 0.0
	var space_state := _get_space_state(scene_root)
	if space_state == null:
		return raw
	if dominant is DirectionalLight3D:
		var sun := dominant as DirectionalLight3D
		if _is_in_directional_light_shadow(world_point, sun, space_state):
			return 0.0
		if _is_in_building_sun_shadow(scene_root, world_point, sun):
			return 0.0
	elif dominant is OmniLight3D:
		if _is_occluded_from_omni(world_point, dominant, space_state):
			return 0.0
	return raw


static func is_shadow_core_zone(scene_root: Node, world_point: Vector3 = Vector3.ZERO) -> bool:
	if is_low_brightness_scene(scene_root, world_point):
		return true
	return get_local_main_light_strength(scene_root, world_point) < SHADOW_CORE_LIGHT_THRESHOLD


static func describe_shade_at(scene_root: Node, world_point: Vector3) -> String:
	if is_low_brightness_scene(scene_root, world_point):
		return "night"
	var local := get_local_main_light_strength(scene_root, world_point)
	if local < 0.01:
		return "no-main-light"
	if local < SHADOW_CORE_LIGHT_THRESHOLD:
		return "weak-light(%.2f)" % local
	return "bright(%.2f)" % local


static func get_zone_label(scene_root: Node, world_point: Vector3 = Vector3.ZERO) -> String:
	if is_low_brightness_scene(scene_root, world_point):
		return "NIGHT"
	if is_shadow_core_zone(scene_root, world_point):
		return "SHADE"
	return "LIGHT"


static func is_dark_zone(scene_root: Node, world_point: Vector3 = Vector3.ZERO) -> bool:
	return is_shadow_core_zone(scene_root, world_point)


static func is_light_zone(scene_root: Node, world_point: Vector3 = Vector3.ZERO) -> bool:
	return not is_shadow_core_zone(scene_root, world_point)


static func _get_space_state(scene_root: Node) -> PhysicsDirectSpaceState3D:
	var world: World3D = scene_root.get_world_3d()
	if world == null:
		return null
	return world.direct_space_state


static func _occlusion_origin(world_point: Vector3) -> Vector3:
	var origin := world_point
	origin.y = GROUND_SAMPLE_Y + OCCLUSION_SAMPLE_HEIGHT
	return origin


static func _get_sun_light(scene_root: Node) -> DirectionalLight3D:
	var tree := scene_root.get_tree()
	if tree == null:
		return null
	var sun_system := tree.get_first_node_in_group("day_night")
	if sun_system and sun_system.has_method("get_sun_light"):
		return sun_system.call("get_sun_light") as DirectionalLight3D
	return scene_root.get_node_or_null("SunSystem/MainSun") as DirectionalLight3D


static func _is_interior_light(light: Light3D) -> bool:
	return light.name.contains("Interior")


static func _is_in_directional_light_shadow(
	world_point: Vector3,
	light: DirectionalLight3D,
	space_state: PhysicsDirectSpaceState3D
) -> bool:
	var toward_sun := light.global_transform.basis.z.normalized()
	for height in [0.08, 0.55, 1.05, 1.75]:
		var sample := world_point
		sample.y = GROUND_SAMPLE_Y + height
		if _ray_to_sun_blocked(sample, toward_sun, space_state):
			return true
	return false


static func _ray_to_sun_blocked(
	sample: Vector3,
	toward_sun: Vector3,
	space_state: PhysicsDirectSpaceState3D
) -> bool:
	var sun_origin := sample + toward_sun * RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(sun_origin, sample)
	query.collision_mask = WORLD_OCCLUSION_LAYER
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.hit_from_inside = true
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var hit_pos: Vector3 = hit.get("position", sample)
	return sun_origin.distance_to(hit_pos) < sun_origin.distance_to(sample) - 0.05


static func _is_in_building_sun_shadow(
	scene_root: Node,
	world_point: Vector3,
	sun: DirectionalLight3D
) -> bool:
	var town := scene_root.get_node_or_null("Town")
	if town == null:
		return false
	var shadow_dir := _sun_shadow_dir_xz(sun)
	if shadow_dir.length_squared() < 0.0001:
		return false
	var px := world_point.x
	var pz := world_point.z
	var to_sun := Vector2(-shadow_dir.x, -shadow_dir.y)

	for child in town.get_children():
		if not child is StaticBody3D:
			continue
		var col := (child as StaticBody3D).get_node_or_null("CollisionShape3D") as CollisionShape3D
		if col == null or not col.shape is BoxShape3D:
			continue
		var box := col.shape as BoxShape3D
		var center := col.global_transform.origin
		var half := box.size * 0.5
		if _point_in_building_extruded_shadow(
			px, pz, center.x, center.z, half.x, half.z, shadow_dir
		):
			return true
		if _xz_ray_hits_aabb(
			px, pz, to_sun.x, to_sun.y,
			center.x - half.x, center.z - half.z,
			center.x + half.x, center.z + half.z
		):
			return true
	return false


static func _sun_shadow_dir_xz(sun: DirectionalLight3D) -> Vector2:
	var travel := -sun.global_transform.basis.z
	travel.y = 0.0
	if travel.length_squared() < 0.0001:
		return Vector2.ZERO
	travel = travel.normalized()
	return Vector2(travel.x, travel.z)


static func _point_in_building_extruded_shadow(
	px: float,
	pz: float,
	cx: float,
	cz: float,
	half_x: float,
	half_z: float,
	shadow_dir: Vector2
) -> bool:
	var rx := px - cx
	var rz := pz - cz
	var along := rx * shadow_dir.x + rz * shadow_dir.y
	var extent := maxf(half_x * absf(shadow_dir.x), half_z * absf(shadow_dir.y))
	if along < extent * 0.35:
		return false
	var perp := absf(-rx * shadow_dir.y + rz * shadow_dir.x)
	if perp > maxf(half_x, half_z) + 1.35:
		return false
	if along > BUILDING_SHADOW_MAX_LENGTH + extent:
		return false
	return true


static func _xz_ray_hits_aabb(
	ox: float,
	oz: float,
	dx: float,
	dz: float,
	min_x: float,
	min_z: float,
	max_x: float,
	max_z: float
) -> bool:
	var t := 0.2
	while t < RAY_LENGTH:
		var x := ox + dx * t
		var z := oz + dz * t
		if x >= min_x and x <= max_x and z >= min_z and z <= max_z:
			return true
		t += 0.4
	return false


static func _is_occluded_from_directional(
	world_point: Vector3,
	light: DirectionalLight3D,
	space_state: PhysicsDirectSpaceState3D
) -> bool:
	return _is_in_directional_light_shadow(world_point, light, space_state)


static func _is_occluded_from_omni(
	world_point: Vector3,
	light: Light3D,
	space_state: PhysicsDirectSpaceState3D
) -> bool:
	var origin := _occlusion_origin(world_point)
	var light_pos := light.global_position
	if origin.distance_squared_to(light_pos) < 0.0001:
		return false
	var query := PhysicsRayQueryParameters3D.create(origin, light_pos)
	query.collision_mask = WORLD_OCCLUSION_LAYER
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var hit_dist := origin.distance_to(hit.get("position", origin))
	var light_dist := origin.distance_to(light_pos)
	return hit_dist < light_dist - 0.15


static func _get_day_factor(scene_root: Node) -> float:
	var tree := scene_root.get_tree()
	if tree == null:
		return 1.0
	var sun_system := tree.get_first_node_in_group("day_night")
	if sun_system and sun_system.has_method("get_day_factor"):
		return clampf(sun_system.call("get_day_factor"), 0.0, 1.0)
	return 1.0


static func _get_ambient_energy(scene_root: Node) -> float:
	var env_node := scene_root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node and env_node.environment:
		return env_node.environment.ambient_light_energy
	return AMBIENT_BRIGHTNESS_REFERENCE * 0.5


static func _point_in_caster_shadow_footprint(
	ground_point: Vector3,
	caster: Node,
	light: Light3D
) -> bool:
	if light is DirectionalLight3D:
		return _is_point_in_directional_shadow_footprint(
			ground_point, caster, light as DirectionalLight3D
		)
	if light is OmniLight3D:
		return _is_point_in_omni_shadow_footprint(
			ground_point, caster, light as OmniLight3D
		)
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


static func _is_main_light_active(light: Light3D, scene_root: Node = null) -> bool:
	return _main_light_strength_at(light, Vector3.ZERO, scene_root) >= MIN_MAIN_LIGHT_ENERGY


static func _main_light_strength_at(
	light: Light3D,
	world_point: Vector3,
	_scene_root: Node = null
) -> float:
	return _raw_main_light_strength_at(light, world_point)


static func _raw_main_light_strength_at(light: Light3D, world_point: Vector3) -> float:
	if not is_instance_valid(light) or not light.visible:
		return 0.0

	var energy := light.light_energy
	if energy <= 0.0:
		return 0.0

	if light is DirectionalLight3D:
		return energy

	if light is OmniLight3D:
		var omni := light as OmniLight3D
		var reach := maxf(omni.omni_range, 0.001)
		var dist := world_point.distance_to(omni.global_position)
		if dist > reach:
			return 0.0
		var falloff := 1.0 - (dist / reach)
		return energy * falloff * falloff

	if light is SpotLight3D:
		var spot := light as SpotLight3D
		var reach := maxf(spot.spot_range, 0.001)
		var dist := world_point.distance_to(spot.global_position)
		if dist > reach:
			return 0.0
		var falloff := 1.0 - (dist / reach)
		return energy * falloff * falloff

	return energy


static func _caster_ground_anchor(caster: Node) -> Vector3:
	var pos: Vector3 = caster.global_position
	pos.y = GROUND_SAMPLE_Y
	return pos


static func _caster_feet(caster: Node) -> Vector3:
	return _caster_ground_anchor(caster)


static func _is_point_in_directional_shadow(
	ground_point: Vector3,
	caster: Node,
	light: DirectionalLight3D,
	space_state: PhysicsDirectSpaceState3D,
	exclude: Array
) -> bool:
	if not _is_point_in_directional_shadow_footprint(ground_point, caster, light):
		return false

	var toward_light := light.global_transform.basis.z.normalized()
	for offset in _foot_sample_offsets():
		for lift in [0.35, 0.75, 1.05]:
			var origin := _ground_sample(ground_point + offset)
			origin.y += lift
			var target := origin + toward_light * RAY_LENGTH
			if _ray_hits_caster(origin, target, caster, space_state, exclude):
				return true
	return false


static func _is_point_in_directional_shadow_footprint(
	ground_point: Vector3,
	caster: Node,
	light: DirectionalLight3D
) -> bool:
	var caster_anchor := _caster_ground_anchor(caster)
	# Shadow falls on the ground away from the light source (opposite basis.z on XZ).
	var toward_light := light.global_transform.basis.z.normalized()
	var away_from_light := Vector3(-toward_light.x, 0.0, -toward_light.z)
	if away_from_light.length_squared() < 0.0001:
		return false
	away_from_light = away_from_light.normalized()
	var right := Vector3(-away_from_light.z, 0.0, away_from_light.x)

	var delta := ground_point - caster_anchor
	delta.y = 0.0
	var forward_dist := delta.dot(away_from_light)
	if forward_dist < 0.15 or forward_dist > 8.0:
		return false

	var side_dist := absf(delta.dot(right))
	var half_width := 0.55 + forward_dist * 0.12
	return side_dist <= half_width


static func _is_point_in_omni_shadow(
	ground_point: Vector3,
	caster: Node,
	light: OmniLight3D,
	space_state: PhysicsDirectSpaceState3D,
	exclude: Array
) -> bool:
	if not _is_point_in_omni_shadow_footprint(ground_point, caster, light):
		return false

	var light_pos := light.global_position
	var reach := light.omni_range
	for offset in _foot_sample_offsets():
		for lift in [0.35, 0.75, 1.05]:
			var origin := _ground_sample(ground_point + offset)
			origin.y += lift
			if origin.distance_to(light_pos) > reach:
				continue
			if _ray_hits_caster(origin, light_pos, caster, space_state, exclude):
				return true
	return false


static func _is_point_in_omni_shadow_footprint(
	ground_point: Vector3,
	caster: Node,
	light: OmniLight3D
) -> bool:
	var caster_anchor := _caster_ground_anchor(caster)
	var light_pos := light.global_position
	var to_light := Vector3(light_pos.x - caster_anchor.x, 0.0, light_pos.z - caster_anchor.z)
	if to_light.length_squared() < 0.0001:
		return false
	to_light = to_light.normalized()

	var delta := ground_point - caster_anchor
	delta.y = 0.0
	var away_from_lamp := -to_light
	var behind := delta.dot(away_from_lamp)
	if behind < 0.2:
		return false

	var lateral := (delta - away_from_lamp * behind).length()
	var reach := maxf(light.omni_range, 0.001)
	var max_behind := clampf(reach * 0.75, 1.2, 6.0)
	if behind > max_behind:
		return false

	var half_width := 0.65 + behind * 0.1
	return lateral <= half_width


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
