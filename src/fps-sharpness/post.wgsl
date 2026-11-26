override sharpness: f32 = 0.70;

fn post(input: PostInput) -> vec4<f32> {
    let px = 1.0 / max(frame.resolution, vec2<f32>(320.0));
    let uv = input.uv;
    let c = input.color.rgb;
    let n = textureSampleLevel(previous, linear_sampler, clamp(uv + vec2<f32>(0.0, -px.y), vec2<f32>(0.0), vec2<f32>(1.0)), 0.0).rgb;
    let s = textureSampleLevel(previous, linear_sampler, clamp(uv + vec2<f32>(0.0, px.y), vec2<f32>(0.0), vec2<f32>(1.0)), 0.0).rgb;
    let w = textureSampleLevel(previous, linear_sampler, clamp(uv + vec2<f32>(-px.x, 0.0), vec2<f32>(0.0), vec2<f32>(1.0)), 0.0).rgb;
    let e = textureSampleLevel(previous, linear_sampler, clamp(uv + vec2<f32>(px.x, 0.0), vec2<f32>(0.0), vec2<f32>(1.0)), 0.0).rgb;

    let min_rgb = min(c, min(min(n, s), min(w, e)));
    let max_rgb = max(c, max(max(n, s), max(w, e)));
    let amp = sqrt(clamp(min(min_rgb, 1.0 - max_rgb) / max(max_rgb, vec3<f32>(0.0001)), vec3<f32>(0.0), vec3<f32>(1.0)));
    let weight = -amp * (0.125 + 0.10 * sharpness);

    let out_col = clamp((c + (n + s + w + e) * weight) / (1.0 + 4.0 * weight), vec3<f32>(0.0), vec3<f32>(1.0));
    return vec4<f32>(out_col, input.color.a);
}
