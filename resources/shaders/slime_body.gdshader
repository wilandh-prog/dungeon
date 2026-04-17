shader_type spatial;
render_mode depth_draw_opaque, cull_back;

uniform vec3 color_core : source_color = vec3(0.22, 0.92, 0.18);
uniform vec3 color_edge : source_color = vec3(0.04, 0.32, 0.04);
uniform float fresnel_power : hint_range(1.0, 8.0) = 3.2;
uniform float wobble_speed : hint_range(0.0, 10.0) = 2.2;
uniform float wobble_amount : hint_range(0.0, 0.15) = 0.032;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.07;
uniform float specular_val : hint_range(0.0, 1.0) = 0.92;
uniform float emission_strength : hint_range(0.0, 0.5) = 0.1;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.3;

void vertex() {
    float t = TIME * wobble_speed;
    float w = sin(VERTEX.y * 11.0 + t * 1.7)
            * cos(VERTEX.x * 7.0  + t * 1.1)
            * sin(VERTEX.z * 9.0  + t * 0.8);
    VERTEX += NORMAL * w * wobble_amount;
}

void fragment() {
    float ndotv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
    float fresnel = pow(1.0 - ndotv, fresnel_power);

    ALBEDO = mix(color_core, color_edge, fresnel);
    ROUGHNESS = roughness_val;
    SPECULAR = specular_val;

    // Subsurface-style inner glow + edge rim via emission
    float rim = pow(1.0 - ndotv, 2.2) * rim_strength;
    EMISSION = color_core * emission_strength + color_edge * rim;
}
