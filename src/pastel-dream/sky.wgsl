override pastel_mix: f32 = 0.70;

fn sky(input: SkyInput) -> vec4<f32> {
    let h = clamp(input.direction.y, 0.0, 1.0);
    let dream = mix(vec3<f32>(0.98, 0.84, 0.90), vec3<f32>(0.76, 0.86, 0.99), h);
    let brightness = clamp(dot(input.color.rgb, vec3<f32>(0.333)) * 1.25 + 0.12, 0.18, 1.0);
    let col = mix(input.color.rgb, dream * brightness, pastel_mix * 0.65);
    return vec4<f32>(col, 1.0);
}
