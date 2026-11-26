override neon_intensity: f32 = 0.70;

fn material(input: MaterialInput) -> Surface {
    var lit = input.albedo.rgb * input.tint.rgb * input.lightmap;
    let bl = block_light_color(input.position);
    lit = lit + input.albedo.rgb * bl.rgb * bl.a * 0.45 * neon_intensity;
    lit = lit + input.albedo.rgb * vec3<f32>(1.25, 0.75, 1.45) * input.emission * 0.45 * neon_intensity;
    return Surface(vec4<f32>(lit, input.albedo.a * input.tint.a));
}
