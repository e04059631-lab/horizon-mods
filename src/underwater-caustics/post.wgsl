override caustics_strength: f32 = 0.90;

fn post(input: PostInput) -> vec4<f32> {
    var col = input.color.rgb;
    if (frame.eye_in == 1) {
        let lift = mix(col, col * vec3<f32>(0.90, 1.10, 1.16) + vec3<f32>(0.01, 0.04, 0.06), 0.45 * clamp(caustics_strength, 0.0, 1.2));
        col = lift;
    }
    return vec4<f32>(clamp(col, vec3<f32>(0.0), vec3<f32>(1.0)), input.color.a);
}
