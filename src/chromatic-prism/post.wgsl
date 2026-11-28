override prism_strength: f32 = 0.80;

fn post(input: PostInput) -> vec4<f32> {
    let uv = input.uv;
    let delta = uv - vec2<f32>(0.5);
    let dist = length(delta);
    let shift = delta * (0.006 + dist * 0.018) * prism_strength;

    let uv_r = clamp(uv + shift, vec2<f32>(0.001), vec2<f32>(0.999));
    let uv_b = clamp(uv - shift, vec2<f32>(0.001), vec2<f32>(0.999));

    let r = textureSampleLevel(previous, linear_sampler, uv_r, 0.0).r;
    let g = input.color.g;
    let b = textureSampleLevel(previous, linear_sampler, uv_b, 0.0).b;
    var col = vec3<f32>(r, g, b);

    // Subtle horizontal anamorphic cyan-blue streak on very bright highlights
    let px = 1.0 / max(frame.resolution, vec2<f32>(320.0));
    var flare = vec3<f32>(0.0);
    for (var i: i32 = -3; i <= 3; i = i + 1) {
        let fuv = clamp(uv + vec2<f32>(f32(i) * px.x * 7.0, 0.0), vec2<f32>(0.001), vec2<f32>(0.999));
        let s = textureSampleLevel(previous, linear_sampler, fuv, 0.0).rgb;
        let br = max(dot(s, vec3<f32>(0.2126, 0.7152, 0.0722)) - 0.82, 0.0);
        flare = flare + vec3<f32>(0.35, 0.65, 1.0) * br;
    }
    col = col + (flare / 7.0) * 0.35 * prism_strength;
    return vec4<f32>(clamp(col, vec3<f32>(0.0), vec3<f32>(1.0)), input.color.a);
}
