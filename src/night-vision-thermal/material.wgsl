override gain: f32 = 1.0;

fn material(input: MaterialInput) -> Surface {
    let lifted = max(input.lightmap, vec3<f32>(0.65 * gain));
    let heat = input.emission * 0.65;
    let lit = input.albedo.rgb * input.tint.rgb * lifted + vec3<f32>(heat, heat * 0.6, 0.0);
    return Surface(vec4<f32>(lit, input.albedo.a * input.tint.a));
}
