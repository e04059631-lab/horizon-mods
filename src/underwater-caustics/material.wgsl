override caustics_strength: f32 = 0.90;

fn uc_wave(p: vec2<f32>, t: f32) -> f32 {
    let a = sin(p.x * 1.7 + t * 1.4 + sin(p.y * 1.3 - t * 0.9));
    let b = cos(p.y * 1.9 - t * 1.2 + cos(p.x * 1.5 + t * 1.1));
    return pow(clamp(1.0 - abs(a + b) * 0.55, 0.0, 1.0), 4.0);
}

fn material(input: MaterialInput) -> Surface {
    var lit = input.albedo.rgb * input.tint.rgb * input.lightmap;
    let is_under = select(0.0, 1.0, frame.eye_in == 1);
    let upward = max(input.normal.y, 0.15);
    let sun_up = smoothstep(-0.05, 0.30, frame.sun_direction.y);
    let wp = input.position.xz * 0.85 + vec2<f32>(input.position.y * 0.25, -input.position.y * 0.20);
    let c1 = uc_wave(wp, frame.time);
    let c2 = uc_wave(wp * 1.45 + vec2<f32>(4.2, 1.7), -frame.time * 0.85);
    let caustic = (c1 + c2) * 0.5 * upward * sun_up * is_under * caustics_strength;
    let aqua = vec3<f32>(0.42, 0.92, 1.0) * caustic * 0.65;
    lit = lit + input.albedo.rgb * aqua;
    return Surface(vec4<f32>(lit, input.albedo.a * input.tint.a));
}
