override wave_strength: f32 = 0.45;
override reflection_mix: f32 = 0.75;

fn material(input: MaterialInput) -> Surface {
    var lit = input.albedo.rgb * input.tint.rgb * input.lightmap;
    var alpha = input.albedo.a * input.tint.a;

    if (input.fluid == 1u) {
        let world_xz = input.position.xz + frame.camera_position.xz;
        let t = frame.time * 2.1;
        let w1 = sin(world_xz.x * 1.9 + t) * cos(world_xz.y * 1.5 - t * 0.8);
        let w2 = sin((world_xz.x + world_xz.y) * 3.1 - t * 1.4) * 0.5;
        let ripple = vec2<f32>(w1 + w2, w1 - w2) * 0.012 * wave_strength;

        let view_dir = normalize(-input.position);
        let n = normalize(vec3<f32>(ripple.x * 6.0, 1.0, ripple.y * 6.0));
        let fresnel = clamp(0.08 + 0.92 * pow(1.0 - max(dot(view_dir, n), 0.0), 4.0), 0.0, 1.0);

        let water_deep = vec3<f32>(0.05, 0.24, 0.36) * (0.35 + 0.65 * input.light.y);
        var surface_col = mix(lit * 0.85, water_deep, 0.45);

        if (frame.has_reflection == 1u) {
            let refl_uv = clamp(input.screen + ripple, vec2<f32>(0.002), vec2<f32>(0.998));
            let refl = textureSampleLevel(reflection, reflection_sampler, refl_uv, 0.0).rgb;
            surface_col = mix(surface_col, refl, fresnel * reflection_mix);
        } else {
            surface_col = mix(surface_col, frame.sky_color, fresnel * reflection_mix * 0.7);
        }

        // Sun specular glint
        let half_v = normalize(view_dir + frame.light_direction);
        let spec = pow(max(dot(n, half_v), 0.0), 64.0) * smoothstep(0.0, 0.2, frame.light_direction.y);
        surface_col = surface_col + vec3<f32>(1.0, 0.95, 0.82) * spec * 0.85 * input.light.y;
        alpha = clamp(mix(0.62, 0.92, fresnel), 0.45, 0.96);
        lit = surface_col;
    }

    return Surface(vec4<f32>(lit, alpha));
}
