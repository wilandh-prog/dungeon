shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, depth_test_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform float ring_progress : hint_range(0.0, 1.0) = 0.0;
uniform float emission_strength : hint_range(0.0, 20.0) = 10.0;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered) * 2.0;

	float dist_from_ring = abs(dist - ring_progress);
	float width = mix(0.25, 0.05, ring_progress);
	float ring_mask = (1.0 - smoothstep(0.0, width, dist_from_ring)) * step(0.005, ring_progress);

	float fade = pow(max(0.0, 1.0 - ring_progress), 0.5);
	float alpha = ring_mask * fade;

	if (alpha < 0.01) discard;

	ALBEDO = color.rgb * emission_strength * fade;
	EMISSION = ALBEDO;
	ALPHA = alpha;
}
