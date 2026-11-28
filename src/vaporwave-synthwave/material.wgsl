override synth_strength: f32 = 0.85;

fn material(input: MaterialInput) -> Surface {
    let rim = pow(1.0 - abs(input.normal.y), 2.0);
    let tint = mix(vec3<f32>(1.0), vec3<f32>(1.14, 0.88, 1.18), synth_strength * 0.55);
    let cyan_bounce = vec3<f32>(0.10, 0.32, 0.42) * rim * synth_strength * 0.28;
    let lit = input.albedo.rgb * input.tint.rgb * input.lightmap * tint + input.albedo.rgb * cyan_bounce;
    return Surface(vec4<f32>(lit, input.albedo.a * input.tint.a));
}
