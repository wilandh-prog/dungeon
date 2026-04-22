shader_type spatial;
render_mode unshaded, cull_back, blend_mix, depth_draw_opaque;

uniform vec3 color_core : source_color = vec3(0.4, 0.7, 1.0);
uniform vec3 color_edge : source_color = vec3(0.05, 0.2, 0.9);
uniform float fresnel_power : hint_range(1.0, 6.0) = 2.5;
uniform float emission_strength : hint_range(0.0, 20.0) = 8.0;
uniform float pulse_speed : hint_range(0.0, 10.0) = 4.0;
uniform float wobble_amount : hint_range(0.0, 0.1) = 0.025;
uniform float noise_scale : hint_range(0.1, 10.0) = 4.0;

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

void vertex() {
	float n = vnoise(VERTEX * noise_scale + vec3(TIME * 2.0));
	VERTEX += NORMAL * (n - 0.5) * wobble_amount;
}

void fragment() {
	float ndotv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - ndotv, fresnel_power);
	float pulse = sin(TIME * pulse_speed) * 0.12 + 0.88;

	vec3 col = mix(color_core, color_edge, fresnel);
	ALBEDO = col * emission_strength * pulse;
	EMISSION = ALBEDO;
}
