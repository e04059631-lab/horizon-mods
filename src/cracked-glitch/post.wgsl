override glitch_strength: f32 = 0.95;
override rgb_split_strength: f32 = 0.90;

fn cg_hash11(p: f32) -> f32 {
    return fract(sin(p * 127.1 + 311.7) * 43758.5453123);
}

fn cg_hash21(p: vec2<f32>) -> f32 {
    return fract(sin(dot(p, vec2<f32>(127.1, 311.7))) * 43758.5453123);
}

fn post(input: PostInput) -> vec4<f32> {
    let uv = input.uv;
    let res = max(frame.resolution, vec2<f32>(320.0));
    let t = frame.time;

    // 1. Periodic digital glitch bursts + quick random twitches
    let pulse_phase = fract(t * 0.48);
    let burst = smoothstep(0.70, 0.80, pulse_phase) * smoothstep(1.0, 0.90, pulse_phase);
    let micro_twitch = step(0.86, cg_hash11(floor(t * 16.0)));
    let power = (0.35 + burst * 1.25 + micro_twitch * 0.65) * glitch_strength;

    // 2. Chunky horizontal tear bands
    let big_y = floor(uv.y * 20.0);
    let big_tick = floor(t * 14.0);
    let big_rnd = cg_hash21(vec2<f32>(big_y, big_tick));
    let big_active = step(0.84 - burst * 0.36, big_rnd);
    let big_shift = (cg_hash21(vec2<f32>(big_y + 11.7, big_tick)) - 0.5) * 0.095 * big_active * power;

    // 3. Razor-thin high-frequency scanline tears
    let fine_y = floor(uv.y * 95.0);
    let fine_tick = floor(t * 26.0);
    let fine_rnd = cg_hash21(vec2<f32>(fine_y, fine_tick));
    let fine_active = step(0.90 - burst * 0.25, fine_rnd);
    let fine_shift = (cg_hash21(vec2<f32>(fine_y + 3.1, fine_tick)) - 0.5) * 0.045 * fine_active * power;

    // 4. Occasional vertical sync jitter during heavy bursts
    let v_jitter = (cg_hash11(floor(t * 30.0) + 5.0) - 0.5) * 0.012 * burst * glitch_strength;
    var sample_uv = vec2<f32>(uv.x + big_shift + fine_shift, uv.y + v_jitter);

    // 5. RGB chromatic aberration split (always subtly visible, sharpens on tears & bursts)
    let split = (0.0028 + big_active * 0.014 + fine_active * 0.009 + burst * 0.0085) * rgb_split_strength * (0.55 + 0.45 * glitch_strength);
    let uv_r = clamp(sample_uv + vec2<f32>(split, split * 0.22), vec2<f32>(0.001), vec2<f32>(0.999));
    let uv_g = clamp(sample_uv, vec2<f32>(0.001), vec2<f32>(0.999));
    let uv_b = clamp(sample_uv - vec2<f32>(split, split * 0.18), vec2<f32>(0.001), vec2<f32>(0.999));

    let col_r = textureSampleLevel(previous, linear_sampler, uv_r, 0.0).r;
    let col_g = textureSampleLevel(previous, linear_sampler, uv_g, 0.0).g;
    let col_b = textureSampleLevel(previous, linear_sampler, uv_b, 0.0).b;
    var col = vec3<f32>(col_r, col_g, col_b);

    // 6. Digital block corruption flashes (cyan / magenta / neon green glitch blocks during spikes)
    let blk = floor(uv * vec2<f32>(26.0, 18.0));
    let blk_rnd = cg_hash21(blk + vec2<f32>(floor(t * 15.0) * 1.3, 7.0));
    let blk_hit = step(0.985 - burst * 0.06, blk_rnd) * clamp(glitch_strength, 0.0, 1.3);
    let blk_tint = select(
        vec3<f32>(0.10, 0.95, 1.0),
        vec3<f32>(1.0, 0.14, 0.65),
        cg_hash21(blk + vec2<f32>(3.0, 19.0)) > 0.5
    );
    col = mix(col, mix(col, blk_tint, 0.55), blk_hit * 0.65);

    // 7. Subtle animated scanlines & signal noise in glitched slices
    let tear_mask = max(big_active, fine_active);
    let scan = sin(uv.y * res.y * 1.8 + t * 20.0) * 0.5 + 0.5;
    col = col * (1.0 - tear_mask * scan * 0.18 * clamp(glitch_strength, 0.0, 1.4));
    let grain = (cg_hash21(uv * res * 0.5 + vec2<f32>(t * 17.0, t * 9.0)) - 0.5) * 0.08 * tear_mask * clamp(glitch_strength, 0.0, 1.3);
    col = col + vec3<f32>(grain);

    return vec4<f32>(clamp(col, vec3<f32>(0.0), vec3<f32>(1.0)), input.color.a);
}
