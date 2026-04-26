shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, depth_test_disabled;

uniform vec4 beam_color : source_color = vec4(0.3, 0.7, 1.0, 1.0);
uniform float emission_strength : hint_range(0.0, 30.0) = 20.0;
uniform float core_width : hint_range(0.01, 0.5) = 0.15;
uniform float glow_falloff : hint_range(0.5, 8.0) = 4.0;
uniform float scroll_speed : hint_range(0.0, 20.0) = 8.0;
uniform float pulse_speed : hint_range(0.0, 30.0) = 15.0;
uniform float flicker_speed : hint_range(0.0, 30.0) = 20.0;

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

void vertex() {
	// The mesh local X axis in view space — horizontal spread for H-plane, vertical for V-plane
	vec3 x_dir_vs = normalize((MODELVIEW_MATRIX * vec4(1.0, 0.0, 0.0, 0.0)).xyz);

	// Along-beam position in view space from VERTEX.z (mesh local Z)
	vec3 along_vs = (MODELVIEW_MATRIX * vec4(0.0, 0.0, VERTEX.z, 1.0)).xyz;
	vec3 vertex_vs = along_vs + x_dir_vs * VERTEX.x;

	POSITION = PROJECTION_MATRIX * vec4(vertex_vs, 1.0);
}

void fragment() {
	float along = UV.y;
	float across = UV.x;

	// Radial distance from center (0 = center line, 1 = edge)
	float radial = abs(across - 0.5) * 2.0;

	// Tight bright core
	float core = pow(max(0.0, 1.0 - radial / core_width), 2.5);

	// Soft outer glow
	float glow = pow(max(0.0, 1.0 - radial), glow_falloff);

	// Scrolling energy noise along beam
	float t = along * 8.0 + TIME * scroll_speed;
	float turbulence = vnoise(vec3(across * 6.0, t, 0.5));

	// Pulse rings traveling along beam
	float pulse = pow(max(0.0, sin(along * 20.0 + TIME * pulse_speed) * 0.5 + 0.5), 3.0);

	// Tip/origin fade
	float endcap = smoothstep(0.0, 0.05, along) * smoothstep(1.0, 0.95, along);

	// Flicker
	float flicker = sin(TIME * flicker_speed) * 0.08 + 0.92;
	float flicker2 = sin(TIME * flicker_speed * 1.6 + 1.1) * 0.05 + 0.95;

	float total = (core * 3.0 + glow * 0.7 + turbulence * glow * 0.6 + pulse * glow * 0.4) * flicker * flicker2 * endcap;

	if (total < 0.01) discard;

	// White-hot at core center, beam color at glow edges
	float whiteness = clamp(core * 1.5, 0.0, 1.0);
	vec3 color = mix(beam_color.rgb, vec3(1.0), whiteness * 0.8);

	ALBEDO = color * total * emission_strength;
	EMISSION = ALBEDO;
	ALPHA = clamp(total, 0.0, 1.0);
}
