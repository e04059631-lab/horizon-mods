fn sky(input: SkyInput) -> vec4<f32> {
    let h = clamp(input.direction.y, 0.0, 1.0);
    let sun_glow = pow(max(dot(input.direction, frame.sun_direction), 0.0), 10.0);
    var col = input.color.rgb * mix(vec3<f32>(1.06, 1.01, 0.96), vec3<f32>(0.86, 0.96, 1.14), h);
    col = col + vec3<f32>(1.0, 0.76, 0.46) * sun_glow * 0.28 * clamp(frame.sun_direction.y + 0.25, 0.0, 1.0);
    return vec4<f32>(col, 1.0);
}
