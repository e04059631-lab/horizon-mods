override outline_strength: f32 = 0.75;

fn lin_depth(uv: vec2<f32>) -> f32 {
    let d = depth_at(uv);
    if (d <= 0.00001) { return 1000.0; }
    return length(view_position(uv, d));
}

fn post(input: PostInput) -> vec4<f32> {
    var col = input.color.rgb;
    if (input.depth > 0.00001 && outline_strength > 0.01) {
        let px = 1.0 / max(frame.resolution, vec2<f32>(320.0));
        let dc = lin_depth(input.uv);
        let dn = lin_depth(clamp(input.uv + vec2<f32>(0.0, -px.y), vec2<f32>(0.0), vec2<f32>(1.0)));
        let ds = lin_depth(clamp(input.uv + vec2<f32>(0.0, px.y), vec2<f32>(0.0), vec2<f32>(1.0)));
        let dw = lin_depth(clamp(input.uv + vec2<f32>(-px.x, 0.0), vec2<f32>(0.0), vec2<f32>(1.0)));
        let de = lin_depth(clamp(input.uv + vec2<f32>(px.x, 0.0), vec2<f32>(0.0), vec2<f32>(1.0)));

        let edge = (abs(dn - dc) + abs(ds - dc) + abs(dw - dc) + abs(de - dc)) / max(dc * 0.35, 0.15);
        let ink = smoothstep(0.32, 0.85, edge) * outline_strength;
        col = mix(col, col * 0.12, ink);
    }
    return vec4<f32>(col, input.color.a);
}
