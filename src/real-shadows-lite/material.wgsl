override shadow_strength: f32 = 0.55;
override softness: f32 = 1.25;

fn material(input: MaterialInput) -> Surface {
    var lit = input.albedo.rgb * input.tint.rgb * input.lightmap;

    if (frame.has_shadow == 1u && input.emission < 0.2) {
        let ndotl = dot(input.normal, frame.light_direction);
        let bias = frame.shadow_center_texel * 0.015 + 0.0008;
        let sp = shadow_position(input.position + input.normal * 0.04);
        let texel = (1.0 / max(frame.shadow_resolution, 512.0)) * softness;

        let s0 = textureSampleCompareLevel(shadow_map, shadow_sampler, sp.xy, sp.z - bias);
        let s1 = textureSampleCompareLevel(shadow_map, shadow_sampler, sp.xy + vec2<f32>(texel, texel * 0.4), sp.z - bias);
        let s2 = textureSampleCompareLevel(shadow_map, shadow_sampler, sp.xy + vec2<f32>(-texel, -texel * 0.4), sp.z - bias);
        let s3 = textureSampleCompareLevel(shadow_map, shadow_sampler, sp.xy + vec2<f32>(-texel * 0.4, texel), sp.z - bias);
        let s4 = textureSampleCompareLevel(shadow_map, shadow_sampler, sp.xy + vec2<f32>(texel * 0.4, -texel), sp.z - bias);
        let solid_lit = (s0 + s1 + s2 + s3 + s4) * 0.2;

        let trans_lit = textureSampleCompareLevel(shadow_map_translucent, shadow_sampler, sp.xy, sp.z - bias);
        let sc_dim = vec2<f32>(textureDimensions(shadow_color));
        let sc_texel = vec2<i32>(clamp(sp.xy * sc_dim, vec2<f32>(0.0), sc_dim - 1.0));
        let stained = textureLoad(shadow_color, sc_texel, 0).rgb;

        let facing = clamp(ndotl * 2.2, 0.0, 1.0);
        let sun_vis = solid_lit * facing;
        let outdoor = smoothstep(0.25, 0.90, input.light.y) * (1.0 - frame.rain * 0.65);

        let shade_factor = mix(1.0, mix(1.0 - shadow_strength, 1.12, sun_vis), outdoor);
        let tint_factor = mix(vec3<f32>(1.0), stained, clamp((solid_lit - trans_lit) * outdoor, 0.0, 0.85));
        lit = lit * shade_factor * tint_factor;
    }

    return Surface(vec4<f32>(lit, input.albedo.a * input.tint.a));
}
