override dream_glow: f32 = 0.75;

fn post(input: PostInput) -> vec4<f32> {
    let uv = input.uv;
    let px = 1.0 / max(frame.resolution, vec2<f32>(320.0));

    var blur = input.color.rgb * 0.20;
    for (var i: i32 = 0; i < 8; i = i + 1) {
        let a = f32(i) * 0.78539816;
        let off1 = vec2<f32>(cos(a), sin(a)) * px * 5.0;
        let off2 = vec2<f32>(cos(a + 0.39), sin(a + 0.39)) * px * 11.0;
        blur = blur + textureSampleLevel(previous, linear_sampler, clamp(uv + off1, vec2<f32>(0.001), vec2<f32>(0.999)), 0.0).rgb * 0.06;
        blur = blur + textureSampleLevel(previous, linear_sampler, clamp(uv + off2, vec2<f32>(0.001), vec2<f32>(0.999)), 0.0).rgb * 0.04;
    }

    // Orton-style soft dreamy blend + warm pastel shadow lift
    let screen_blend = vec3<f32>(1.0) - (vec3<f32>(1.0) - input.color.rgb) * (vec3<f32>(1.0) - blur * 0.72);
    var col = mix(input.color.rgb, screen_blend, clamp(dream_glow * 0.58, 0.0, 0.85));
    col = col + vec3<f32>(0.025, 0.018, 0.032) * dream_glow * (1.0 - col);
    return vec4<f32>(clamp(col, vec3<f32>(0.0), vec3<f32>(1.0)), input.color.a);
}
