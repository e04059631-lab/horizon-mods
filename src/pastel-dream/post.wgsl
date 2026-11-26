override pastel_mix: f32 = 0.70;

fn post(input: PostInput) -> vec4<f32> {
    let c = input.color.rgb;
    let luma = dot(c, vec3<f32>(0.2126, 0.7152, 0.0722));
    // Lift darks into creamy lavender-peach and soften harsh saturation
    let lifted = mix(c, vec3<f32>(luma), 0.22) * 0.86 + vec3<f32>(0.09, 0.075, 0.095);
    let out_col = mix(c, clamp(lifted, vec3<f32>(0.0), vec3<f32>(1.0)), pastel_mix);
    return vec4<f32>(out_col, input.color.a);
}
