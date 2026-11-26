override nether_lift: f32 = 0.45;

fn material(input: MaterialInput) -> Surface {
    var lm = input.lightmap;
    if (frame.dimension == -1) {
        lm = max(lm, vec3<f32>(0.42, 0.34, 0.32) * nether_lift + lm * 0.85);
    } else if (frame.dimension == 1) {
        lm = max(lm, vec3<f32>(0.40, 0.38, 0.48) * nether_lift + lm * 0.85);
    }
    let lit = input.albedo.rgb * input.tint.rgb * lm;
    return Surface(vec4<f32>(lit, input.albedo.a * input.tint.a));
}
