shader_type canvas_item;
render_mode unshaded;

// Right wardrobe panel: negative rotate_y_deg tilts inward toward screen center (left).
uniform float rotate_y_deg = -35.0;
uniform float rotate_x_deg = -6.0;
uniform float perspective_strength = 560.0;
uniform float floor_pivot = 0.93;
uniform vec2 panel_size = vec2(400.0, 544.0);

void vertex() {
	vec2 size = panel_size;
	if (size.x <= 1.0 || size.y <= 1.0) {
		size = 1.0 / TEXTURE_PIXEL_SIZE;
	}
	if (size.x <= 1.0 || size.y <= 1.0) {
		return;
	}

	float pivot_x = size.x * 0.5;
	float pivot_y = size.y * floor_pivot;
	vec2 local = VERTEX - vec2(pivot_x, pivot_y);

	float y_angle = radians(rotate_y_deg);
	float x_angle = radians(rotate_x_deg);

	float x_y = local.x * cos(y_angle);
	float z_y = local.x * sin(y_angle);
	float y_y = local.y;

	float y_x = y_y * cos(x_angle) - z_y * sin(x_angle);
	float z_x = y_y * sin(x_angle) + z_y * cos(x_angle);

	float scale = perspective_strength / (perspective_strength + z_x);
	VERTEX.x = pivot_x + x_y * scale;
	VERTEX.y = pivot_y - y_x * scale;
}

void fragment() {
	COLOR = texture(TEXTURE, UV);
}
