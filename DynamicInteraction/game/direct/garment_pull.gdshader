shader_type spatial;
render_mode cull_disabled;

uniform vec4 fabric_color : source_color = vec4(0.5, 0.14, 0.22, 1.0);
uniform float fabric_roughness = 0.5;
uniform sampler2D cloth_offsets : filter_nearest, repeat_disable;

void vertex() {
	vec3 a = texelFetch(cloth_offsets, ivec2(int(UV2.x + 0.5), 0), 0).xyz;
	vec3 b = texelFetch(cloth_offsets, ivec2(int(UV2.y + 0.5), 0), 0).xyz;
	VERTEX += mix(a, b, UV.x);
}

void fragment() {
	vec3 folded = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(folded, NORMAL) < 0.0) {
		folded = -folded;
	}
	NORMAL = normalize(mix(NORMAL, folded, 0.72));
	ALBEDO = fabric_color.rgb;
	ROUGHNESS = fabric_roughness;
}
