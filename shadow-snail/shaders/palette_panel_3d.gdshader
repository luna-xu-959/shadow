shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

uniform sampler2D ui_texture : source_color, filter_linear;

void fragment() {
	vec4 color = texture(ui_texture, UV);
	if (color.a < 0.02) {
		discard;
	}

	vec2 edge_uv = min(UV, 1.0 - UV);
	float edge_dist = min(edge_uv.x, edge_uv.y);
	float inner = smoothstep(0.0, 0.07, edge_dist);
	float outer_rim = smoothstep(0.0, 0.018, edge_dist);

	vec3 shaded = color.rgb * mix(0.78, 1.0, inner);
	shaded *= mix(0.55, 1.0, outer_rim);
	ALBEDO = shaded;
	ALPHA = color.a;
}
