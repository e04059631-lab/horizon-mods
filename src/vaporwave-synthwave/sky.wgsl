override synth_strength: f32 = 0.85;

fn sky(input: SkyInput) -> vec4<f32> {
    let d = normalize(input.direction);
    let h = clamp(d.y * 0.5 + 0.5, 0.0, 1.0);
    let top_col = vec3<f32>(0.08, 0.04, 0.24);
    let mid_col = vec3<f32>(0.42, 0.08, 0.52);
    let hor_col = vec3<f32>(1.0, 0.28, 0.62);
    var synth_sky = mix(hor_col, mid_col, smoothstep(0.46, 0.68, h));
    synth_sky = mix(synth_sky, top_col, smoothstep(0.66, 0.94, h));

    // Striped retro sun glow in sun direction
    let sun_dir = normalize(vec3<f32>(frame.sun_direction.x, max(frame.sun_direction.y, 0.12), frame.sun_direction.z));
    let sd = dot(d, sun_dir);
    let sun_disc = smoothstep(0.988, 0.992, sd);
    let stripe = step(0.32, fract(d.y * 42.0));
    let sun_col = mix(vec3<f32>(1.0, 0.22, 0.55), vec3<f32>(1.0, 0.92, 0.30), smoothstep(0.05, 0.28, d.y));
    synth_sky = synth_sky + sun_col * sun_disc * stripe * 0.95 + vec3<f32>(1.0, 0.35, 0.72) * pow(max(sd, 0.0), 18.0) * 0.55;

    let col = mix(input.color.rgb, synth_sky, clamp(synth_strength * 0.82, 0.0, 1.0));
    return vec4<f32>(col, 1.0);
}
