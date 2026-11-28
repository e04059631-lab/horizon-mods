override letterbox: bool = true;
override film_grain: f32 = 0.45;

fn cf_hash(p: vec2<f32>) -> f32 {
    return fract(sin(dot(p, vec2<f32>(127.1, 311.7))) * 43758.5453);
}

fn post(input: PostInput) -> vec4<f32> {
    let uv = input.uv;
    if (letterbox && (uv.y < 0.11 || uv.y > 0.89)) {
        return vec4<f32>(0.0, 0.0, 0.0, input.color.a);
    }

    var col = input.color.rgb;
    // Hollywood Teal & Orange cinema color grading
    let luma = dot(col, vec3<f32>(0.2126, 0.7152, 0.0722));
    let teal_shadow = vec3<f32>(0.04, 0.14, 0.19);
    let orange_high = vec3<f32>(1.14, 0.96, 0.82);
    col = mix(col + teal_shadow * (1.0 - luma) * 0.42, col * orange_high, smoothstep(0.28, 0.82, luma) * 0.52);

    // Filmic S-curve contrast
    col = clamp((col - vec3<f32>(0.04)) * 1.10, vec3<f32>(0.0), vec3<f32>(1.0));

    // Fine 35mm film grain
    let grain = (cf_hash(uv * max(frame.resolution, vec2<f32>(320.0)) + vec2<f32>(frame.time * 24.0, frame.time * 13.0)) - 0.5) * 0.055 * film_grain;
    col = col + vec3<f32>(grain);

    // Subtle cinema lens vignette
    let d = length(uv - vec2<f32>(0.5));
    col = col * smoothstep(0.95, 0.42, d);
    return vec4<f32>(clamp(col, vec3<f32>(0.0), vec3<f32>(1.0)), input.color.a);
}
