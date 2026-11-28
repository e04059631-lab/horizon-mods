override wire_glow: f32 = 1.00;
override keep_world_dim: f32 = 0.32;

fn post(input: PostInput) -> vec4<f32> {
    let uv = input.uv;
    let px = 1.35 / max(frame.resolution, vec2<f32>(320.0));

    let c = input.color.rgb;
    let cl = textureSampleLevel(previous, linear_sampler, clamp(uv - vec2<f32>(px.x, 0.0), vec2<f32>(0.001), vec2<f32>(0.999)), 0.0).rgb;
    let cr = textureSampleLevel(previous, linear_sampler, clamp(uv + vec2<f32>(px.x, 0.0), vec2<f32>(0.001), vec2<f32>(0.999)), 0.0).rgb;
    let cu = textureSampleLevel(previous, linear_sampler, clamp(uv - vec2<f32>(0.0, px.y), vec2<f32>(0.001), vec2<f32>(0.999)), 0.0).rgb;
    let cd = textureSampleLevel(previous, linear_sampler, clamp(uv + vec2<f32>(0.0, px.y), vec2<f32>(0.001), vec2<f32>(0.999)), 0.0).rgb;

    let edge_c = length(cr - cl) + length(cd - cu);
    let d0 = input.depth;
    let d_edge = (abs(d0 - depth_at(clamp(uv + vec2<f32>(px.x, 0.0), vec2<f32>(0.001), vec2<f32>(0.999))))
        + abs(d0 - depth_at(clamp(uv + vec2<f32>(0.0, px.y), vec2<f32>(0.001), vec2<f32>(0.999))))) * 55.0;

    let edge = smoothstep(0.14, 0.45, edge_c + d_edge);

    // Animated cyan-to-magenta neon pulse sweeping across the scene
    let pulse = sin(uv.y * 5.0 - frame.time * 2.2) * 0.5 + 0.5;
    let neon_col = mix(vec3<f32>(0.0, 0.92, 1.0), vec3<f32>(1.0, 0.15, 0.78), pulse * 0.55);

    let bg = c * vec3<f32>(0.45, 0.62, 0.95) * keep_world_dim + vec3<f32>(0.01, 0.02, 0.05);
    let col = bg + neon_col * edge * 1.15 * wire_glow;
    return vec4<f32>(clamp(col, vec3<f32>(0.0), vec3<f32>(1.0)), input.color.a);
}
