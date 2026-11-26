override sun_warmth: f32 = 0.30;

fn material(input: MaterialInput) -> Surface {
    var lit = input.albedo.rgb * input.tint.rgb * input.lightmap;
    let ndotl = max(dot(input.normal, frame.light_direction), 0.0);
    let outdoor = smoothstep(0.35, 0.95, input.light.y);
    let day = clamp(frame.sun_direction.y * 2.5 + 0.2, 0.0, 1.0);
    let sun_tint = mix(vec3<f32>(0.72, 0.80, 1.05), vec3<f32>(1.18, 1.04, 0.86), day);
    lit = lit * mix(vec3<f32>(1.0), sun_tint * (0.90 + 0.28 * ndotl), outdoor * sun_warmth);
    lit = lit + input.albedo.rgb * input.emission * 0.22;
    return Surface(vec4<f32>(lit, input.albedo.a * input.tint.a));
}
