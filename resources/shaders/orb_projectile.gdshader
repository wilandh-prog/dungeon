shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec3 color_core : source_color = vec3(0.4, 0.7, 1.0);
uniform vec3 color_rim  : source_color = vec3(0.92, 0.98, 1.0);

uniform float fresnel_power : hint_range(1.0, 5.0) = 1.8;
uniform float glass_alpha   : hint_range(0.0, 1.0) = 0.12;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.04;
uniform float specular_val  : hint_range(0.0, 1.0) = 1.0;
uniform float rim_emission  : hint_range(0.0, 6.0) = 2.0;
uniform float core_emission : hint_range(0.0, 2.0) = 0.35;
uniform float pulse_speed   : hint_range(0.0, 10.0) = 3.0;
uniform float wobble_amount : hint_range(0.0, 0.1) = 0.015;
uniform float noise_scale   : hint_range(0.1, 10.0) = 3.0;
uniform float scatter_scale : hint_range(1.0, 20.0) = 5.0;

varying vec3 world_pos;

float hash(vec3 p) {
	p = fract(p * vec3(127.1, 311.7, 74.7));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i),             hash(i+vec3(1,0,0)), f.x),
			mix(hash(i+vec3(0,1,0)), hash(i+vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i+vec3(0,0,1)), hash(i+vec3(1,0,1)), f.x),
			mix(hash(i+vec3(0,1,1)), hash(i+vec3(1,1,1)), f.x), f.y), f.z);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float n = vnoise(VERTEX * noise_scale + vec3(TIME * 1.5));
	VERTEX += NORMAL * (n - 0.5) * wobble_amount;
}

void fragment() {
	float ndotv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - ndotv, fresnel_power);
	float pulse = sin(TIME * pulse_speed) * 0.08 + 0.92;

	// Two-octave scatter for internal depth illusion
	vec3 p = world_pos * scatter_scale;
	float scatter = vnoise(p) * 0.65 + vnoise(p * 2.3) * 0.35;

	vec3 col = mix(color_core, color_rim, fresnel * 0.65 + scatter * 0.1);

	ALBEDO    = col * pulse;
	ROUGHNESS = roughness_val;
	SPECULAR  = specular_val;
	EMISSION  = color_rim  * fresnel * rim_emission * pulse
	          + color_core * (1.0 - fresnel) * core_emission * scatter;
	ALPHA     = clamp(glass_alpha + fresnel * 0.75 + scatter * 0.08, 0.0, 1.0);
}
