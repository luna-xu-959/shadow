extends StaticBody3D


func _ready() -> void:
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh == null:
		return
	mesh.material_override = _build_grass_material()


func _build_grass_material() -> StandardMaterial3D:
	var color_noise := FastNoiseLite.new()
	color_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	color_noise.frequency = 0.045
	color_noise.fractal_octaves = 4

	var color_ramp := Gradient.new()
	color_ramp.set_color(0, Color(0.14, 0.34, 0.1))
	color_ramp.set_color(1, Color(0.32, 0.58, 0.2))
	color_ramp.add_point(0.35, Color(0.2, 0.46, 0.14))
	color_ramp.add_point(0.7, Color(0.26, 0.52, 0.18))

	var albedo_tex := NoiseTexture2D.new()
	albedo_tex.noise = color_noise
	albedo_tex.color_ramp = color_ramp
	albedo_tex.width = 1024
	albedo_tex.height = 1024
	albedo_tex.seamless = true

	var bump_noise := FastNoiseLite.new()
	bump_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	bump_noise.frequency = 0.18
	bump_noise.fractal_octaves = 2

	var normal_tex := NoiseTexture2D.new()
	normal_tex.noise = bump_noise
	normal_tex.as_normal_map = true
	normal_tex.bump_strength = 1.4
	normal_tex.width = 512
	normal_tex.height = 512
	normal_tex.seamless = true

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.92, 1.0, 0.88)
	material.albedo_texture = albedo_tex
	material.normal_enabled = true
	material.normal_texture = normal_tex
	material.normal_scale = 0.55
	material.uv1_scale = Vector3(10, 10, 10)
	material.roughness = 0.94
	material.metallic = 0.0
	material.specular = 0.05
	return material
