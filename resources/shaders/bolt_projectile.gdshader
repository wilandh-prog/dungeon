shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, depth_test_disabled;

uniform vec4 bolt_color : source_color = vec4(0.4, 0.6, 1.0, 1.0);
uniform float emission_strength : hint_range(0.0, 30.0) = 14.0;
uniform float arc_speed : hint_range(0.0, 20.0) = 9.0;
uniform float noise_scale : hint_range(1.0, 10.0) = 4.0;
uniform float arc_sharpness : hint_range(1.0, 6.0) = 2.8;
uniform float flicker_speed : hint_range(0.0, 30.0) = 14.0;
uniform float wobble_amount : hint_range(0.0, 0.05) = 0.012;

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
	float body = smoothstep(0.0, 0.2, UV.y) * smoothstep(1.0, 0.8, UV.y);
	float n = vnoise(VERTEX * 6.0 + vec3(TIME * 10.0));
	VERTEX += NORMAL * (n - 0.5) * wobble_amount * body;
}

void fragment() {
	float along = UV.y;
	float around = UV.x;

	// Radial core glow
	float radial = abs(around - 0.5) * 2.0;
	float core_glow = pow(max(0.0, 1.0 - radial), 1.5);

	// Crackling noise texture
	float n1 = vnoise(vec3(around * noise_scale, along * noise_scale * 3.0, TIME * arc_speed));
	float n2 = vnoise(vec3(around * noise_scale * 2.0 + 5.1, along * noise_scale * 5.0, TIME * arc_speed * 1.3));
	float crackle = pow(n1 * 0.7 + n2 * 0.3, arc_sharpness);

	// Arc 1: helical line spiraling along the bolt
	float arc1_center = fract(along * 2.0 + TIME * arc_speed * 0.5);
	float arc1_dist = abs(around - arc1_center);
	arc1_dist = min(arc1_dist, 1.0 - arc1_dist);
	float arc1 = pow(max(0.0, 1.0 - arc1_dist * 8.0), 3.5) * 0.8;

	// Arc 2: opposite spiral, faster
	float arc2_center = fract(along * 3.0 - TIME * arc_speed * 0.7 + 0.5);
	float arc2_dist = abs(around - arc2_center);
	arc2_dist = min(arc2_dist, 1.0 - arc2_dist);
	float arc2 = pow(max(0.0, 1.0 - arc2_dist * 11.0), 4.0) * 0.45;

	// Flicker
	float flicker = sin(TIME * flicker_speed) * 0.1 + 0.9;
	float flicker2 = sin(TIME * flicker_speed * 1.7 + 1.3) * 0.06 + 0.94;

	// Tip/tail fade
	float endcap = smoothstep(0.0, 0.12, along) * smoothstep(1.0, 0.88, along);

	float total = (core_glow * 0.55 + crackle * 0.7 + arc1 + arc2) * flicker * flicker2 * endcap;

	if (total < 0.01) discard;

	ALBEDO = bolt_color.rgb * total * emission_strength;
	EMISSION = ALBEDO;
	ALPHA = clamp(total, 0.0, 1.0);
}
