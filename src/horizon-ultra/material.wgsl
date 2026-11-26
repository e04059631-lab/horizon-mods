override shadow_quality: f32 = 0.52;

fn material(input: MaterialInput) -> Surface {
    var lit = input.albedo.rgb * input.tint.rgb * input.lightmap;
    var alpha = input.albedo.a * input.tint.a;

    // 3D colored block light
    let bl = block_light_color(input.position);
    lit = lit + input.albedo.rgb * input.tint.rgb * bl.rgb * bl.a * 0.32 + input.albedo.rgb * input.emission * 0.25;

    // Soft PCF shadows
    if (frame.has_shadow == 1u && shadow_quality > 0.01 && input.emission < 0.25) {
        let sp = shadow_position(input.position + input.normal * 0.04);
        let bias = frame.shadow_center_texel * 0.015 + 0.0008;
        let texel = 1.15 / max(frame.shadow_resolution, 512.0);
        let s0 = textureSampleCompareLevel(shadow_map, shadow_sampler, sp.xy, sp.z - bias);
        let s1 = textureSampleCompareLevel(shadow_map, shadow_sampler, sp.xy + vec2<f32>(texel, 0.0), sp.z - bias);
        let s2 = textureSampleCompareLevel(shadow_map, shadow_sampler, sp.xy - vec2<f32>(texel, 0.0), sp.z - bias);
        let s3 = textureSampleCompareLevel(shadow_map, shadow_sampler, sp.xy + vec2<f32>(0.0, texel), sp.z - bias);
        let s4 = textureSampleCompareLevel(shadow_map, shadow_sampler, sp.xy - vec2<f32>(0.0, texel), sp.z - bias);
        let vis = ((s0 + s1 + s2 + s3 + s4) * 0.2) * clamp(dot(input.normal, frame.light_direction) * 2.2, 0.0, 1.0);
        let outdoor = smoothstep(0.25, 0.90, input.light.y) * (1.0 - frame.rain * 0.65);
        lit = lit * mix(1.0, mix(1.0 - shadow_quality, 1.14, vis), outdoor);
    }

    // Water reflections + waves
    if (input.fluid == 1u) {
        let wxz = input.position.xz + frame.camera_position.xz;
        let t = frame.time * 2.0;
        let r = vec2<f32>(sin(wxz.x * 2.0 + t), cos(wxz.y * 1.7 - t * 0.9)) * 0.008;
        let vdir = normalize(-input.position);
        let n = normalize(vec3<f32>(r.x * 5.0, 1.0, r.y * 5.0));
        let fresnel = clamp(0.10 + 0.90 * pow(1.0 - max(dot(vdir, n), 0.0), 4.0), 0.0, 1.0);
        if (frame.has_reflection == 1u) {
            let ruv = clamp(input.screen + r, vec2<f32>(0.002), vec2<f32>(0.998));
            let refl = textureSampleLevel(reflection, reflection_sampler, ruv, 0.0).rgb;
            lit = mix(lit * vec3<f32>(0.75, 0.95, 1.05), refl, fresnel * 0.72);
        }
        alpha = clamp(mix(0.65, 0.92, fresnel), 0.5, 0.95);
    }

    return Surface(vec4<f32>(lit, alpha));
}
