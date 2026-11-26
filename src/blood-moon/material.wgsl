override crimson_strength: f32 = 0.80;

fn material(input: MaterialInput) -> Surface {
    let night = smoothstep(0.06, -0.16, frame.sun_direction.y);
    let outdoor_night = night * smoothstep(0.2, 0.95, input.light.y) * (1.0 - input.light.x * 0.7);
    let blood_tint = mix(vec3<f32>(1.0), vec3<f32>(1.38, 0.62, 0.62), outdoor_night * crimson_strength);
    let lit = input.albedo.rgb * input.tint.rgb * input.lightmap * blood_tint;
    return Surface(vec4<f32>(lit, input.albedo.a * input.tint.a));
}
