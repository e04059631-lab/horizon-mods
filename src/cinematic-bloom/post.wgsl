override bloom_strength: f32 = 0.55;
override bloom_threshold: f32 = 0.68;

fn post(input: PostInput) -> vec4<f32> {
    let uv = input.uv;
    let px = 1.0 / max(frame.resolution, vec2<f32>(320.0));
    var glow = vec3<f32>(0.0);
    var wsum = 0.0;

    // 12-tap golden-angle spiral multi-radius halo
    for (var i: i32 = 0; i < 12; i = i + 1) {
        let fi = f32(i);
        let ang = fi * 2.3999632;
        let rad = 2.0 + fi * 2.1;
        let off = vec2<f32>(cos(ang), sin(ang)) * px * rad;
        let suv = clamp(uv + off, vec2<f32>(0.001), vec2<f32>(0.999));
        let s = textureSampleLevel(previous, linear_sampler, suv, 0.0).rgb;
        let peak = max(s.r, max(s.g, s.b));
        let knee = smoothstep(bloom_threshold - 0.12, bloom_threshold + 0.25, peak);
        let w = 1.0 / (1.0 + fi * 0.22);
        glow = glow + s * knee * w;
        wsum = wsum + w;
    }

    let bloom = (glow / max(wsum, 0.001)) * bloom_strength;
    let out_col = 1.0 - (1.0 - clamp(input.color.rgb, vec3<f32>(0.0), vec3<f32>(1.0))) * (1.0 - clamp(bloom, vec3<f32>(0.0), vec3<f32>(0.95)));
    return vec4<f32>(out_col, input.color.a);
}
