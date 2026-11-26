override cel_bands: i32 = 4;

fn material(input: MaterialInput) -> Surface {
    let bands = f32(max(cel_bands, 2));
    let luma = max(input.lightmap.r, max(input.lightmap.g, input.lightmap.b));
    let quant = floor(luma * bands + 0.35) / bands;
    let ratio = clamp(quant / max(luma, 0.001), 0.55, 1.35);
    let lit = input.albedo.rgb * input.tint.rgb * (input.lightmap * ratio) * 1.06;
    return Surface(vec4<f32>(lit, input.albedo.a * input.tint.a));
}
