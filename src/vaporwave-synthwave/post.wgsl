override synth_strength: f32 = 0.85;

fn post(input: PostInput) -> vec4<f32> {
    var col = input.color.rgb;
    let shadows = vec3<f32>(0.06, 0.02, 0.14) * (1.0 - col) * synth_strength * 0.35;
    let highs = max(col - vec3<f32>(0.68), vec3<f32>(0.0)) * vec3<f32>(1.25, 0.65, 1.35) * synth_strength * 0.45;
    col = col + shadows + highs;
    return vec4<f32>(clamp(col, vec3<f32>(0.0), vec3<f32>(1.0)), input.color.a);
}
