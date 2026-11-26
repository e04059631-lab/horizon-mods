override cave_floor: f32 = 0.01;
override dark_nights: bool = true;

fn material(input: MaterialInput) -> Surface {
    let night = smoothstep(0.05, -0.18, frame.sun_direction.y);
    let sky_eff = input.light.y * select(1.0, mix(1.0, 0.16, night), dark_nights);
    let total_light = max(input.light.x, sky_eff);
    let curve = clamp(pow(total_light, 2.2), cave_floor, 1.0);
    let lit = input.albedo.rgb * input.tint.rgb * input.lightmap * curve + input.albedo.rgb * input.emission * 0.65;
    return Surface(vec4<f32>(lit, input.albedo.a * input.tint.a));
}
