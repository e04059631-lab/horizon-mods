override light_intensity: f32 = 0.85;
override emissive_boost: f32 = 0.35;

fn material(input: MaterialInput) -> Surface {
    let base = input.albedo.rgb * input.tint.rgb * input.lightmap;
    let bl = block_light_color(input.position);
    let reach = clamp(bl.a * light_intensity, 0.0, 1.4);
    let tinted = input.albedo.rgb * input.tint.rgb * bl.rgb * (0.42 * reach * (0.25 + input.light.x));
    let self_glow = input.albedo.rgb * input.emission * emissive_boost;
    let lit = mix(base, base * 0.75 + tinted, clamp(bl.a * 0.85, 0.0, 0.85)) + tinted * 0.35 + self_glow;
    return Surface(vec4<f32>(lit, input.albedo.a * input.tint.a));
}
