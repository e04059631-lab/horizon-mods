override warmth: f32 = 0.65;

fn sky(input: SkyInput) -> vec4<f32> {
    let d = normalize(input.direction);
    let horizon = pow(1.0 - clamp(abs(d.y), 0.0, 1.0), 3.0);
    let sun_glow = pow(max(dot(d, frame.sun_direction), 0.0), 6.0);
    var col = mix(input.color.rgb, input.color.rgb * vec3<f32>(1.18, 0.94, 0.78) + vec3<f32>(0.24, 0.10, 0.03) * horizon, warmth * 0.55);
    col = col + vec3<f32>(1.0, 0.58, 0.22) * sun_glow * 0.35 * warmth;
    return vec4<f32>(col, 1.0);
}
