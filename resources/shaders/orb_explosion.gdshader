shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, depth_test_disabled;

uniform vec4 color_core : source_color = vec4(1.0, 0.85, 0.5, 1.0);
uniform vec4 color_edge : source_color = vec4(0.2, 0.5, 1.0, 1.0);
uniform float emission_strength : hint_range(0.0, 30.0) = 15.0;
uniform float expand_t : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve_t : hint_range(0.0, 1.0) = 0.0;
uniform float noise_scale : hint_range(0.5, 8.0) = 3.5;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.35;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.3, 0.7));
	p *= dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x),
			mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
			mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	return vnoise(p) * 0.5 + vnoise(p * 2.1) * 0.25 + vnoise(p * 4.3) * 0.125;
}

void vertex() {
	float n = fbm(VERTEX * noise_scale + vec3(TIME * 1.5));
	VERTEX += normalize(VERTEX) * (n - 0.5) * noise_strength * expand_t;
}

void fragment() {
	float n = fbm(VERTEX * noise_scale * 0.8 + vec3(TIME * 1.2));

	float edge_w = 0.15;
	float mask = smoothstep(dissolve_t, dissolve_t + 0.05, n);
	if (mask < 0.01) discard;

	float edge_glow = (1.0 - smoothstep(dissolve_t, dissolve_t + edge_w, n)) * mask;

	float ndotv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - ndotv, 2.0);

	vec3 col = mix(color_core.rgb, color_edge.rgb, fresnel);
	col += color_core.rgb * edge_glow * 6.0;

	ALBEDO = col * emission_strength * (1.0 - dissolve_t * 0.5);
	EMISSION = ALBEDO;
	ALPHA = mask;
}
