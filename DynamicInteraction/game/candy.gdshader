shader_type spatial;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float angle = atan(p.y, p.x);
	float swirl = 0.5 + 0.5 * cos(length(p) * 36.0 - angle * 2.0);
	ALBEDO = mix(vec3(0.72, 0.041, 0.16), vec3(1.0, 0.62, 0.72), smoothstep(0.53, 0.64, swirl));
	ROUGHNESS = 0.27;
}
