extends Node3D

const StreetLampScript = preload("res://scripts/street_lamp.gd")

var _window_materials: Array[StandardMaterial3D] = []
var _interior_lights: Array[OmniLight3D] = []


func _ready() -> void:
	call_deferred("_build_town")


func _process(_delta: float) -> void:
	var night := _night_strength()
	for mat in _window_materials:
		mat.emission_energy_multiplier = lerpf(0.25, 1.45, night)
	for light in _interior_lights:
		light.light_energy = lerpf(0.0, 1.6, night)
		light.omni_range = lerpf(0.0, 9.0, night)


func _night_strength() -> float:
	var sun := get_tree().get_first_node_in_group("day_night")
	if sun and sun.has_method("get_day_factor"):
		return 1.0 - clampf(sun.call("get_day_factor"), 0.0, 1.0)
	return 0.0


func _build_town() -> void:
	var buildings := [
		{"pos": Vector3(-10.0, 0.0, -9.0), "size": Vector3(5.0, 4.2, 4.0), "wall": Color(0.92, 0.88, 0.82), "roof": Color(0.58, 0.28, 0.22), "windows": 4},
		{"pos": Vector3(10.5, 0.0, -8.5), "size": Vector3(4.5, 3.6, 3.8), "wall": Color(0.86, 0.9, 0.94), "roof": Color(0.35, 0.38, 0.48), "windows": 3},
		{"pos": Vector3(-9.5, 0.0, 9.0), "size": Vector3(4.8, 3.8, 4.5), "wall": Color(0.95, 0.9, 0.84), "roof": Color(0.48, 0.32, 0.24), "windows": 3},
		{"pos": Vector3(9.0, 0.0, 10.0), "size": Vector3(5.5, 4.8, 4.2), "wall": Color(0.9, 0.86, 0.8), "roof": Color(0.62, 0.24, 0.2), "windows": 5},
		{"pos": Vector3(0.0, 0.0, -11.0), "size": Vector3(6.0, 3.2, 3.5), "wall": Color(0.88, 0.84, 0.78), "roof": Color(0.42, 0.36, 0.34), "windows": 4},
		{"pos": Vector3(-3.0, 0.0, 11.5), "size": Vector3(3.5, 5.0, 3.2), "wall": Color(0.84, 0.88, 0.92), "roof": Color(0.3, 0.34, 0.42), "windows": 6},
	]

	for i in buildings.size():
		_add_building("Building%d" % i, buildings[i])

	for lamp_pos in [
		Vector3(-7.0, 0.0, 2.5),
		Vector3(7.0, 0.0, -2.0),
		Vector3(-2.0, 0.0, -5.5),
		Vector3(3.0, 0.0, 6.0),
		Vector3(-11.0, 0.0, 0.0),
		Vector3(11.0, 0.0, 0.0),
	]:
		_add_street_lamp(lamp_pos)


func _add_building(building_name: String, spec: Dictionary) -> void:
	var body := StaticBody3D.new()
	body.name = building_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = spec.pos
	add_child(body)

	var size: Vector3 = spec.size
	var wall_color: Color = spec.wall
	var roof_color: Color = spec.roof

	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(size.x, size.y, size.z)
	var wall_inst := MeshInstance3D.new()
	wall_inst.mesh = wall_mesh
	wall_inst.position = Vector3(0.0, size.y * 0.5, 0.0)
	wall_inst.material_override = _mat_wall(wall_color)
	wall_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.add_child(wall_inst)

	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(size.x + 0.5, 0.45, size.z + 0.5)
	var roof_inst := MeshInstance3D.new()
	roof_inst.mesh = roof_mesh
	roof_inst.position = Vector3(0.0, size.y + 0.22, 0.0)
	roof_inst.material_override = _mat_roof(roof_color)
	roof_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.add_child(roof_inst)

	var trim_mesh := BoxMesh.new()
	trim_mesh.size = Vector3(size.x + 0.08, 0.12, size.z + 0.08)
	var trim_inst := MeshInstance3D.new()
	trim_inst.mesh = trim_mesh
	trim_inst.position = Vector3(0.0, size.y * 0.22, 0.0)
	trim_inst.material_override = _mat_trim()
	body.add_child(trim_inst)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x, size.y + 0.5, size.z)
	col.shape = shape
	col.position = Vector3(0.0, (size.y + 0.5) * 0.5, 0.0)
	body.add_child(col)

	_add_windows(body, size, int(spec.windows))
	if int(spec.windows) >= 4:
		_add_interior_light(body, size)


func _add_windows(building: StaticBody3D, size: Vector3, count: int) -> void:
	var front_z := size.z * 0.5 + 0.02
	var rows := maxi(count / 2, 1)
	var cols := ceili(float(count) / float(rows))
	for i in count:
		var row := i / cols
		var col := i % cols
		var wx := lerpf(-size.x * 0.28, size.x * 0.28, float(col) / maxf(float(cols - 1), 1.0))
		var wy := lerpf(size.y * 0.35, size.y * 0.78, float(row) / maxf(float(rows - 1), 1.0))
		var win := MeshInstance3D.new()
		win.name = "Window%d" % i
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.55, 0.7, 0.06)
		win.mesh = mesh
		win.position = Vector3(wx, wy, front_z)
		win.material_override = _mat_window()
		building.add_child(win)
		_window_materials.append(win.material_override as StandardMaterial3D)


func _add_interior_light(building: StaticBody3D, size: Vector3) -> void:
	var light := OmniLight3D.new()
	light.name = "InteriorLight"
	light.position = Vector3(0.0, size.y * 0.55, 0.0)
	light.light_color = Color(1.0, 0.86, 0.58)
	light.light_energy = 0.0
	light.omni_range = 0.0
	light.shadow_enabled = true
	light.add_to_group(ShadowRules.MAIN_SHADOW_LIGHT_GROUP)
	building.add_child(light)
	_interior_lights.append(light)


func _add_street_lamp(world_pos: Vector3) -> void:
	var lamp := Node3D.new()
	lamp.name = "StreetLamp"
	lamp.position = world_pos
	lamp.set_script(StreetLampScript)
	add_child(lamp)

	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.07
	pole_mesh.bottom_radius = 0.09
	pole_mesh.height = 3.2
	var pole := MeshInstance3D.new()
	pole.name = "Pole"
	pole.mesh = pole_mesh
	pole.position = Vector3(0.0, 1.6, 0.0)
	pole.material_override = _mat_metal()
	pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	lamp.add_child(pole)

	var bulb := MeshInstance3D.new()
	bulb.name = "Bulb"
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.18
	bulb_mesh.height = 0.36
	bulb.mesh = bulb_mesh
	bulb.position = Vector3(0.0, 3.28, 0.0)
	bulb.material_override = _mat_lamp_bulb()
	lamp.add_child(bulb)

	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.8, 0.08, 0.08)
	var arm := MeshInstance3D.new()
	arm.mesh = arm_mesh
	arm.position = Vector3(0.35, 3.15, 0.0)
	arm.material_override = _mat_metal()
	lamp.add_child(arm)

	var light := OmniLight3D.new()
	light.name = "OmniLight3D"
	light.position = Vector3(0.0, 3.15, 0.0)
	light.light_color = Color(1.0, 0.88, 0.62)
	light.light_energy = 0.0
	light.omni_range = 0.0
	light.shadow_enabled = true
	light.add_to_group(ShadowRules.MAIN_SHADOW_LIGHT_GROUP)
	lamp.add_child(light)


func _mat_wall(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.92
	return m


func _mat_roof(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.88
	return m


func _mat_trim() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.72, 0.66, 0.58)
	m.roughness = 0.85
	return m


func _mat_window() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.92, 0.55)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.82, 0.38)
	m.emission_energy_multiplier = 0.35
	m.roughness = 0.2
	return m


func _mat_metal() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.28, 0.3, 0.34)
	m.metallic = 0.55
	m.roughness = 0.45
	return m


func _mat_lamp_bulb() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.95, 0.75)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.86, 0.45)
	m.emission_energy_multiplier = 0.2
	m.roughness = 0.15
	return m
