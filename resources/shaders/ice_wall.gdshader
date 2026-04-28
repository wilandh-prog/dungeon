shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec3 color_deep    : source_color = vec3(0.04, 0.22, 0.55);
uniform vec3 color_mid     : source_color = vec3(0.35, 0.72, 0.92);
uniform vec3 color_rim     : source_color = vec3(0.82, 0.96, 1.0);

uniform float fresnel_power    : hint_range(1.0, 6.0)   = 2.2;
uniform float base_alpha       : hint_range(0.0, 1.0)   = 0.62;
uniform float roughness_val    : hint_range(0.0, 1.0)   = 0.04;
uniform float specular_val     : hint_range(0.0, 1.0)   = 1.0;
uniform float rim_emission     : hint_range(0.0, 4.0)   = 1.8;
uniform float inner_emission   : hint_range(0.0, 1.0)   = 0.06;
uniform float shimmer_speed    : hint_range(0.0, 4.0)   = 0.7;
uniform float crystal_scale    : hint_range(1.0, 20.0)  = 6.0;

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
}

void fragment() {
	float ndotv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - ndotv, fresnel_power);

	// Volumetric crystal structure — three octaves of noise in world space
	vec3 p = world_pos * crystal_scale * 0.12;
	float n  = vnoise(p)        * 0.500;
	      n += vnoise(p * 2.3)  * 0.250;
	      n += vnoise(p * 5.1)  * 0.125;
	      n += vnoise(p * 11.7) * 0.062;

	// Sharp crack planes: where noise crosses 0.5, values are thin bright lines
	float crack = 1.0 - abs(n * 2.0 - 1.0);
	crack = pow(max(crack - 0.72, 0.0) / 0.28, 2.5);

	// Slow internal shimmer — not uniform, drifts with world position
	float shimmer = 0.9 + 0.1 * sin(TIME * shimmer_speed + world_pos.y * 5.0
	                                  + world_pos.x * 3.7 + world_pos.z * 2.1);

	// Color: deep interior → mid blue → white rim
	vec3 col = mix(color_deep, color_mid, n);
	col = mix(col, color_rim, crack * 0.5 + fresnel * 0.6);

	ALBEDO    = col * shimmer;
	ROUGHNESS = roughness_val;
	SPECULAR  = specular_val;
	EMISSION  = color_rim * fresnel * rim_emission
	          + color_mid * crack  * 0.4
	          + color_deep         * inner_emission;
	ALPHA     = clamp(base_alpha + fresnel * 0.33 + crack * 0.15, 0.0, 1.0);
}
