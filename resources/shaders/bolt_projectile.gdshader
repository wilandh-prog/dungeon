shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, depth_test_disabled;

uniform vec4 bolt_color : source_color = vec4(0.4, 0.6, 1.0, 1.0);
uniform float emission_strength : hint_range(0.0, 30.0) = 18.0;
uniform float arc_speed : hint_range(0.0, 20.0) = 9.0;
uniform float noise_scale : hint_range(1.0, 10.0) = 4.0;
uniform float arc_sharpness : hint_range(1.0, 6.0) = 3.0;
uniform float flicker_speed : hint_range(0.0, 30.0) = 14.0;
uniform float wobble_amount : hint_range(0.0, 0.1) = 0.018;

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
	float body = smoothstep(0.0, 0.15, UV.y) * smoothstep(1.0, 0.85, UV.y);
	float n = vnoise(VERTEX * 8.0 + vec3(TIME * 12.0));
	VERTEX += NORMAL * (n - 0.5) * wobble_amount * body;
}

void fragment() {
	float along = UV.y;
	float around = UV.x;

	// Normal-facing glow: bright on the front-facing surface of the cylinder
	float ndotv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float core_glow = pow(ndotv, 1.0) * 1.2;

	// Main arc: noise-displaced position along the bolt creates a zigzag
	float arc1_pos = 0.5 + vnoise(vec3(0.0, along * 5.0, TIME * arc_speed * 0.8)) * 0.7 - 0.35;
	arc1_pos = fract(arc1_pos);
	float arc1_dist = abs(around - arc1_pos);
	arc1_dist = min(arc1_dist, 1.0 - arc1_dist);
	float arc1 = pow(max(0.0, 1.0 - arc1_dist * 14.0), 4.0) * 1.8;

	// Secondary arc offset from main
	float arc2_pos = fract(arc1_pos + 0.45 + (vnoise(vec3(3.0, along * 4.0, TIME * arc_speed * 0.6)) - 0.5) * 0.3);
	float arc2_dist = abs(around - arc2_pos);
	arc2_dist = min(arc2_dist, 1.0 - arc2_dist);
	float arc2 = pow(max(0.0, 1.0 - arc2_dist * 20.0), 5.0) * 0.7;

	// Crackle fill
	float n1 = vnoise(vec3(around * noise_scale, along * noise_scale * 3.0, TIME * arc_speed));
	float crackle = pow(max(0.0, n1), arc_sharpness) * 0.4;

	// Rapid erratic flicker
	float flicker = sin(TIME * flicker_speed) * 0.15 + 0.85;
	float flicker2 = sin(TIME * flicker_speed * 2.3 + 0.7) * 0.1 + 0.9;

	// Tip/tail fade
	float endcap = smoothstep(0.0, 0.15, along) * smoothstep(1.0, 0.85, along);

	float total = (core_glow * 0.5 + arc1 + arc2 + crackle) * flicker * flicker2 * endcap;

	if (total < 0.01) discard;

	ALBEDO = bolt_color.rgb * total * emission_strength;
	EMISSION = ALBEDO;
	ALPHA = clamp(total, 0.0, 1.0);
}
