shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, depth_test_disabled;

uniform vec4 beam_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform float emission_strength : hint_range(0.0, 30.0) = 16.0;
uniform float scroll_speed : hint_range(0.0, 20.0) = 6.0;
uniform float turbulence_scale : hint_range(1.0, 20.0) = 8.0;
uniform float core_sharpness : hint_range(0.5, 5.0) = 1.8;
uniform float glow_sharpness : hint_range(0.1, 3.0) = 0.6;
uniform float pulse_speed : hint_range(0.0, 30.0) = 12.0;
uniform float flicker_speed : hint_range(0.0, 30.0) = 18.0;

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
		mix(mix(hash(i), hash(i+vec3(1,0,0)), f.x),
			mix(hash(i+vec3(0,1,0)), hash(i+vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i+vec3(0,0,1)), hash(i+vec3(1,0,1)), f.x),
			mix(hash(i+vec3(0,1,1)), hash(i+vec3(1,1,1)), f.x), f.y), f.z);
}

void fragment() {
	float along = UV.y;
	float around = UV.x;

	// Radial glow from normal facing camera: bright at center, falls off at edges
	float ndotv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float core = pow(ndotv, core_sharpness);
	float glow = pow(ndotv, glow_sharpness);

	// Turbulence scrolling toward target
	float t = along * turbulence_scale - TIME * scroll_speed;
	float n1 = vnoise(vec3(around * 4.0, t, 0.5));
	float n2 = vnoise(vec3(around * 8.0 + 2.1, t * 1.7, 1.3));
	float turbulence = n1 * 0.6 + n2 * 0.4;

	// Energy pulse rings traveling toward target
	float pulse = pow(max(0.0, sin(along * 18.0 - TIME * pulse_speed) * 0.5 + 0.5), 3.0);

	// Origin/tip fade
	float endcap = smoothstep(0.0, 0.04, along) * smoothstep(1.0, 0.96, along);

	// Flicker
	float flicker = sin(TIME * flicker_speed) * 0.08 + 0.92;
	float flicker2 = sin(TIME * flicker_speed * 1.6 + 1.1) * 0.05 + 0.95;

	float total = (glow * 0.4 + core * 1.2 + turbulence * core * 0.9 + pulse * core * 0.7) * flicker * flicker2 * endcap;

	if (total < 0.01) discard;

	ALBEDO = beam_color.rgb * total * emission_strength;
	EMISSION = ALBEDO;
	ALPHA = clamp(total, 0.0, 1.0);
}
