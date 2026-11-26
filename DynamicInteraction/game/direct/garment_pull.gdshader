shader_type spatial;
render_mode cull_disabled;

uniform vec4 fabric_color : source_color = vec4(0.5, 0.14, 0.22, 1.0);
uniform float fabric_roughness = 0.5;
uniform float gather : hint_range(0.0, 1.0) = 0.0;
uniform float side = 1.0;
uniform float flutter = 0.0;

void vertex() {
	// Puxe o baixo da peça para a mão em vez de transladar a malha toda como uma placa.
	float hem = clamp(-VERTEX.y / 0.46, 0.0, 1.0);
	float wave = sin(26.0 * VERTEX.x + 13.0 * VERTEX.y) * hem;
	VERTEX.x *= 1.0 - 0.32 * gather * hem;
	VERTEX.y *= 1.0 - 0.30 * gather;
	VERTEX.z = VERTEX.z * (1.0 - 0.23 * gather) + wave * (0.024 * gather + 0.013 * flutter);
	VERTEX.x -= side * 0.09 * gather * hem;
}

void fragment() {
	ALBEDO = fabric_color.rgb;
	ROUGHNESS = fabric_roughness;
}
