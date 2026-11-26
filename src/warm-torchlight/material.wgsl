override torch_warmth: f32 = 0.75;
override flicker_amount: f32 = 0.08;

fn material(input: MaterialInput) -> Surface {
    let t = frame.time;
    let flicker = 1.0 + (sin(t * 7.3) * 0.5 + sin(t * 13.7 + 1.4) * 0.3 + cos(t * 21.1) * 0.2) * flicker_amount * input.light.x;
    let indoor = clamp(input.light.x * (1.0 - input.light.y * 0.55), 0.0, 1.0);
    let warm_tint = mix(vec3<f32>(1.0), vec3<f32>(1.32, 0.96, 0.62) * flicker, indoor * torch_warmth);
    let lit = input.albedo.rgb * input.tint.rgb * input.lightmap * warm_tint;
    return Surface(vec4<f32>(lit, input.albedo.a * input.tint.a));
}
