override clarity_boost: f32 = 0.10;

fn material(input: MaterialInput) -> Surface {
    var lit = input.albedo.rgb * input.tint.rgb * input.lightmap;
    lit = clamp((lit - 0.5) * (1.0 + clarity_boost) + 0.5, vec3<f32>(0.0), vec3<f32>(1.5));
    return Surface(vec4<f32>(lit, input.albedo.a * input.tint.a));
}
