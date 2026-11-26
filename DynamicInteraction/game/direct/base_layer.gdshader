shader_type spatial;

uniform bool top_visible = false;
uniform bool bottom_visible = false;
varying vec2 bind_xy;

void vertex() {
	bind_xy = UV2;
	VERTEX += NORMAL * 0.0025;
}

void fragment() {
	float x = abs(bind_xy.x);
	float y = bind_xy.y;
	float band_top = 1.582 - 0.25 * max(0.0, x - 0.115);
	bool band = x < 0.225 && y > 1.365 && y < band_top;
	bool straps = abs(x - 0.102) < 0.024 && y >= band_top && y < 1.66;
	bool top = top_visible && (band || straps);
	bool bottom = bottom_visible && x < 0.29 && y > 0.845 + 0.12 * x && y < 1.087;
	if (!top && !bottom) { discard; }

	float seam = top ? min(abs(y - 1.375), abs(y - band_top + 0.009)) : abs(y - 1.070);
	ALBEDO = mix(vec3(0.025, 0.021, 0.031), vec3(0.105, 0.084, 0.119), 1.0 - smoothstep(0.0, 0.004, seam));
	ROUGHNESS = 0.94;
}
