override shadow_lift: f32 = 0.72;

fn material(input: MaterialInput) -> Surface {
    let lm = max(input.lightmap, vec3<f32>(shadow_lift));
    let lit = input.albedo.rgb * input.tint.rgb * lm;
    return Surface(vec4<f32>(lit, input.albedo.a * input.tint.a));
}
