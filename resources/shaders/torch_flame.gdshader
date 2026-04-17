// Spatial Fire - Raymarched (adapted from godotshaders.com/shader/spatial-fire-raymarched)
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

group_uniforms quality;
uniform int raymarch_steps : hint_range(2, 32) = 16;
uniform bool sample_jitter = true;

group_uniforms parameters;
uniform bool billboard = true;
uniform float billboard_z_offset = 0.3;
uniform float time_scale = 0.03;
uniform float noise_scale = 0.5;
uniform float noise_threshold = 0.43;

group_uniforms shape;
uniform float fire_height = 0.42;
uniform float fire_width = 0.22;
uniform vec3 box_center = vec3(0.0, 0.0, 0.0);
uniform vec3 box_rotation = vec3(0.0);
uniform float taper_factor = 0.5;
uniform float wobble_strength = 2.0;
uniform float wobble_speed = 6.0;
uniform float wobble_noise_frequency : hint_range(0.1, 10.0) = 0.15;
uniform float sharpness_cutoff : hint_range(0.0, 20.0) = 4.5;

group_uniforms visuals;
uniform float emission_strength = 10.0;
uniform float core_glow_multiplier : hint_range(0.0, 20.0) = 14.0;
uniform vec3 color_core = vec3(1.0, 0.95, 0.55);
uniform vec3 color_mid = vec3(1.0, 0.55, 0.0);
uniform vec3 color_outer = vec3(0.85, 0.08, 0.0);
uniform vec3 color_smoke = vec3(-0.05, -0.05, -0.05);

varying vec3 world_position;
varying vec3 world_camera;

vec3 get_box_center(vec3 npw) {
    return box_center + npw + vec3(0.0, fire_height * 0.5, 0.0);
}

float get_animated_time() {
    return -TIME * time_scale;
}

mat3 rotation_matrix(vec3 angles) {
    float cx = cos(angles.x), sx = sin(angles.x);
    float cy = cos(angles.y), sy = sin(angles.y);
    float cz = cos(angles.z), sz = sin(angles.z);
    return mat3(
        vec3(cy*cz, -cy*sz, sy),
        vec3(cx*sz + sx*sy*cz, cx*cz - sx*sy*sz, -sx*cy),
        vec3(sx*sz - cx*sy*cz, sx*cz + cx*sy*sz, cx*cy)
    );
}

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
        mix(mix(hash(i),               hash(i + vec3(1,0,0)), f.x),
            mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
        mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
            mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y),
        f.z);
}

float get_noise_value(vec3 p, float scale, float tz) {
    vec3 q = (p + vec3(0.0, tz, 0.0)) * scale * 10.0;
    return vnoise(q) * 0.65 + vnoise(q * 2.1 + vec3(31.7, 17.3, 5.1)) * 0.35;
}

float sdf_box(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(vec3(0.0), q)) + min(0.0, max(q.x, max(q.y, q.z)));
}

vec3 get_wobble(vec3 p, float strength, float freq, float speed) {
    float t = get_animated_time();
    float wx = get_noise_value(p + vec3(100.0, 0.0, 0.0), freq, t * speed);
    float wy = get_noise_value(p + vec3(0.0, 200.0, 0.0), freq, t * speed * 1.2);
    float wz = get_noise_value(p + vec3(0.0, 0.0, 300.0), freq, t * speed * 0.8);
    return vec3(wx - 0.5, wy - 0.5, wz - 0.5) * strength;
}

float fire_sdf(vec3 p, vec3 npw) {
    vec3 lp = p - get_box_center(npw);
    lp = transpose(rotation_matrix(box_rotation)) * lp;
    vec3 box_size = vec3(fire_width, fire_height, fire_width);
    float nh = (lp.y + box_size.y * 0.5) / box_size.y;
    float taper = max(0.01, 1.0 - nh * taper_factor);
    vec3 tp = lp;
    tp.xz /= taper;
    vec3 wobble = get_wobble(lp, wobble_strength, wobble_noise_frequency, wobble_speed);
    float dist = sdf_box(tp, box_size * 0.5);
    float noise_t = get_animated_time() * 20.0;
    float distortion = get_noise_value(lp + wobble, noise_scale * 0.5, noise_t) * 0.3;
    return dist + distortion;
}

void vertex() {
    if (billboard) {
        mat3 cam_rot = mat3(
            MAIN_CAM_INV_VIEW_MATRIX[0].xyz,
            MAIN_CAM_INV_VIEW_MATRIX[1].xyz,
            MAIN_CAM_INV_VIEW_MATRIX[2].xyz
        );
        VERTEX = cam_rot * VERTEX;
        NORMAL = cam_rot * NORMAL;
        float post_offset = -MAIN_CAM_INV_VIEW_MATRIX[2].y + billboard_z_offset;
        VERTEX += MAIN_CAM_INV_VIEW_MATRIX[2].xyz * post_offset;
    }
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_camera = MAIN_CAM_INV_VIEW_MATRIX[3].xyz;
}

void fragment() {
    if (noise_threshold <= 0.001) { discard; }

    vec3 ray_dir = normalize(world_position - world_camera);
    vec3 fire_center = get_box_center(NODE_POSITION_WORLD);
    vec3 box_size = vec3(fire_width, fire_height, fire_width);
    float max_dim = max(box_size.x, max(box_size.y, box_size.z));
    vec3 he = vec3(max_dim);

    vec3 inv_rd = 1.0 / ray_dir;
    vec3 t0 = (fire_center - he * 0.5 - world_camera) * inv_rd;
    vec3 t1 = (fire_center + he * 0.5 - world_camera) * inv_rd;
    vec3 ts = min(t0, t1);
    vec3 tl = max(t0, t1);
    float t_enter = max(0.0, max(ts.x, max(ts.y, ts.z)));
    float t_exit = min(length(fire_center - world_camera) + length(he),
                       min(tl.x, min(tl.y, tl.z)));

    if (t_enter >= t_exit) { discard; }

    float march_range = t_exit - t_enter;
    if (march_range <= 0.0001) { discard; }

    float angle_f = clamp(1.0 - abs(dot(ray_dir, vec3(0.0, 1.0, 0.0))), 0.0, 1.0);
    int steps = clamp(int(float(raymarch_steps) * mix(1.0, 2.5, angle_f)), raymarch_steps, 48);
    float step_size = march_range / float(steps);

    vec3 final_color = vec3(0.0);
    float alpha = 0.0;
    float dist = t_enter;

    for (int i = 0; i < 64; i++) {
        if (i >= steps || dist >= t_exit || alpha > 0.99) break;

        vec3 pos = world_camera + ray_dir * dist;
        if (sample_jitter) {
            vec3 hi = pos * 1.25 + ray_dir * 33.0;
            pos += ray_dir * (hash(hi) - 0.5) * step_size;
        }

        float sdf = fire_sdf(pos, NODE_POSITION_WORLD);
        float dn_t = get_animated_time() * 30.0;
        vec3 wb = get_wobble(pos, wobble_strength * 0.7, wobble_noise_frequency * 1.1, wobble_speed * 0.9);
        float nv = get_noise_value(pos + wb, noise_scale * 0.7, dn_t);

        float density = 0.0;
        if (sdf < 0.0) {
            float ns = max(0.15, 1.0 - smoothstep(noise_threshold * 0.8, noise_threshold * 1.2, nv));
            density = clamp(smoothstep(0.0, sharpness_cutoff, -sdf * 0.5 + ns), 0.0, 1.0);

            vec3 lp = pos - get_box_center(NODE_POSITION_WORLD);
            lp = transpose(rotation_matrix(box_rotation)) * lp;
            float ha = pow(smoothstep(0.5, 1.0, (lp.y + box_size.y * 0.5) / box_size.y), 0.333);
            density *= (1.0 - ha);
            density *= smoothstep(0.7, 0.0, length(lp.xz) / (box_size.x * 0.5));
        }

        float a_step = 1.0 - exp(-density * step_size * 25.0);
        vec3 col = mix(color_outer, color_mid, nv);
        col = mix(col, color_core, smoothstep(0.7, 1.0, density * core_glow_multiplier));

        vec3 lp2 = pos - get_box_center(NODE_POSITION_WORLD);
        lp2 = transpose(rotation_matrix(box_rotation)) * lp2;
        float hf = (lp2.y + box_size.y * 0.5) / box_size.y;
        col = mix(col, color_smoke, smoothstep(0.6, 1.0, hf * (1.0 - density)));

        final_color += col * a_step * (1.0 - alpha);
        alpha += a_step * (1.0 - alpha);
        dist += step_size;
    }

    ALPHA = clamp(alpha, 0.0, 1.0);

    ALBEDO = final_color * emission_strength;
    EMISSION = ALBEDO;
}
