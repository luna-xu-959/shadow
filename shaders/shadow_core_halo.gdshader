shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform vec4 glow_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float center_alpha : hint_range(0.0, 1.0) = 0.3;
uniform float exposure : hint_range(0.0, 2.0) = 1.0;
uniform float pulse_brightness : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	// 球心半透明，越靠近轮廓边缘越透明，边缘完全透明。
	float facing = clamp(dot(n, v), 0.0, 1.0);
	float radial = smoothstep(0.0, 1.0, facing);
	float fade = exposure * exposure;
	float alpha = radial * center_alpha * fade;
	float core_glow = radial * radial;
	ALBEDO = glow_color.rgb;
	EMISSION = glow_color.rgb * core_glow * 2.2 * fade * pulse_brightness;
	ALPHA = alpha;
}
