override dark_nights: bool = true;

fn sky(input: SkyInput) -> vec4<f32> {
    let night = smoothstep(0.05, -0.18, frame.sun_direction.y);
    let factor = select(1.0, mix(1.0, 0.18, night), dark_nights);
    return vec4<f32>(input.color.rgb * factor, 1.0);
}
