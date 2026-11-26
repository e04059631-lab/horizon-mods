override crimson_strength: f32 = 0.80;

fn sky(input: SkyInput) -> vec4<f32> {
    let d = normalize(input.direction);
    let night = smoothstep(0.06, -0.16, frame.sun_direction.y);
    let moon_glow = pow(max(dot(d, frame.moon_direction), 0.0), 12.0);
    let horizon = pow(1.0 - clamp(abs(d.y), 0.0, 1.0), 2.5);
    let blood_sky = vec3<f32>(0.22, 0.03, 0.05) * (0.45 + horizon * 0.85) + vec3<f32>(0.95, 0.14, 0.10) * moon_glow * 0.75;
    let col = mix(input.color.rgb, input.color.rgb * vec3<f32>(1.25, 0.45, 0.45) + blood_sky, night * crimson_strength);
    return vec4<f32>(col, 1.0);
}
