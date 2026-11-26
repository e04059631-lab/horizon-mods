fn sky(input: SkyInput) -> vec4<f32> {
    let h = clamp(input.direction.y, 0.0, 1.0);
    let sun_dot = max(dot(input.direction, frame.sun_direction), 0.0);
    var col = input.color.rgb * mix(vec3<f32>(1.04, 1.01, 0.98), vec3<f32>(0.90, 0.98, 1.12), h);
    col = col + vec3<f32>(1.0, 0.72, 0.42) * pow(sun_dot, 8.0) * 0.22 * clamp(frame.sun_direction.y + 0.25, 0.0, 1.0);
    return vec4<f32>(col, 1.0);
}
