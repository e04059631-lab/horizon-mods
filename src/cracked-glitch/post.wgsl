override crack_strength: f32 = 0.95;
override glitch_strength: f32 = 0.90;

fn cg_hash11(p: f32) -> f32 {
    return fract(sin(p * 127.1 + 311.7) * 43758.5453123);
}

fn cg_hash21(p: vec2<f32>) -> f32 {
    return fract(sin(dot(p, vec2<f32>(127.1, 311.7))) * 43758.5453123);
}

fn cg_hash22(p: vec2<f32>) -> vec2<f32> {
    let n = vec2<f32>(
        dot(p, vec2<f32>(127.1, 311.7)),
        dot(p, vec2<f32>(269.5, 183.3))
    );
    return fract(sin(n) * 43758.5453123);
}

// Returns vec4(edge_dist, cell_id_x, cell_id_y, nearest_dist)
fn cg_voronoi(x: vec2<f32>) -> vec4<f32> {
    let ip = floor(x);
    let fp = fract(x);

    var md1: f32 = 8.0;
    var md2: f32 = 8.0;
    var best_id = vec2<f32>(0.0, 0.0);
    var best_r = vec2<f32>(0.0, 0.0);

    for (var j: i32 = -1; j <= 1; j = j + 1) {
        for (var i: i32 = -1; i <= 1; i = i + 1) {
            let g = vec2<f32>(f32(i), f32(j));
            let o = cg_hash22(ip + g) * 0.82 + vec2<f32>(0.09, 0.09);
            let r = g + o - fp;
            let d = dot(r, r);
            if (d < md1) {
                md2 = md1;
                md1 = d;
                best_id = ip + g;
                best_r = r;
            } else if (d < md2) {
                md2 = d;
            }
        }
    }

    // Approximate perpendicular distance to nearest Voronoi border
    var edge: f32 = 8.0;
    for (var j: i32 = -1; j <= 1; j = j + 1) {
        for (var i: i32 = -1; i <= 1; i = i + 1) {
            let g = vec2<f32>(f32(i), f32(j));
            let o = cg_hash22(ip + g) * 0.82 + vec2<f32>(0.09, 0.09);
            let r = g + o - fp;
            let diff = r - best_r;
            if (dot(diff, diff) > 0.0001) {
                let mid = 0.5 * (best_r + r);
                let dist_to_edge = dot(mid, normalize(diff));
                edge = min(edge, dist_to_edge);
            }
        }
    }

    return vec4<f32>(edge, best_id.x, best_id.y, sqrt(md1));
}

fn post(input: PostInput) -> vec4<f32> {
    let uv = input.uv;
    let res = max(frame.resolution, vec2<f32>(320.0));
    let aspect = res.x / res.y;
    let t = frame.time;

    // Aspect-corrected coords around impact point (upper-right so center crosshair remains playable)
    let impact = vec2<f32>(0.68, 0.36);
    var p = uv - impact;
    p.x = p.x * aspect;
    let r = length(p);
    let ang = atan2(p.y, p.x);

    // 1. Spiderweb radial fracture lines with jagged glass jitter
    let ray_count = 13.0;
    let jitter = sin(r * 22.0 + sin(ang * 5.0) * 2.0) * 0.055 + sin(r * 54.0) * 0.022;
    let sector_raw = (ang + 3.14159265) / (6.2831853 / ray_count) + jitter;
    let sector_id = floor(sector_raw);
    let sector_f = fract(sector_raw);
    let ray_dist_ang = min(sector_f, 1.0 - sector_f) * (6.2831853 / ray_count);
    let ray_dist = ray_dist_ang * max(r, 0.015);
    let ray_reach = 0.55 + cg_hash11(sector_id * 17.3 + 4.1) * 0.95;
    let ray_mask = smoothstep(0.0042, 0.0006, ray_dist) * smoothstep(ray_reach, ray_reach * 0.35, r);

    // 2. Concentric shock rings connecting the radial fractures
    let ring_space = r * 8.5 + cg_hash11(sector_id * 9.1 + 1.7) * 0.42 + sin(ang * 3.0) * 0.14;
    let ring_f = fract(ring_space);
    let ring_dist = min(ring_f, 1.0 - ring_f) / 8.5;
    let ring_mask = smoothstep(0.0036, 0.0005, ring_dist) * smoothstep(0.62, 0.04, r) * smoothstep(0.015, 0.05, r);

    // 3. Voronoi glass shards around the impact crater (stretched radially for realistic shatter)
    let shard_uv = p * (4.6 + 1.4 / (r + 0.35));
    let vor = cg_voronoi(shard_uv);
    let vor_crack = smoothstep(0.032, 0.004, vor.x) * smoothstep(0.75, 0.06, r);
    let crater = smoothstep(0.055, 0.008, r);

    // Combine all crack channels
    let crack = clamp((ray_mask + ring_mask * 0.85 + vor_crack * 0.95 + crater * 0.85) * crack_strength, 0.0, 1.0);
    let edge_glow = clamp((smoothstep(0.0085, 0.0018, ray_dist) * smoothstep(ray_reach, ray_reach * 0.4, r)
        + smoothstep(0.065, 0.012, vor.x) * smoothstep(0.72, 0.08, r)) * 0.55 * crack_strength, 0.0, 1.0);

    // 4. Per-shard glass refraction offset (shifts image across cracks!)
    let shard_seed = vec2<f32>(vor.y + sector_id * 3.0, vor.z);
    let shard_dir = (cg_hash22(shard_seed) - vec2<f32>(0.5, 0.5)) * 2.0;
    let shard_strength = smoothstep(0.88, 0.04, r) * 0.011 * crack_strength;
    var sample_uv = uv + shard_dir * shard_strength;

    // 5. Animated digital glitch bursts + horizontal tear slices
    let pulse_phase = fract(t * 0.42);
    let burst = smoothstep(0.74, 0.82, pulse_phase) * smoothstep(1.0, 0.92, pulse_phase);
    let micro_twitch = step(0.91, cg_hash11(floor(t * 14.0)));
    let glitch_power = (0.28 + burst * 1.15 + micro_twitch * 0.55) * glitch_strength;

    let band_y = floor(uv.y * 28.0);
    let band_tick = floor(t * 18.0);
    let band_rnd = cg_hash21(vec2<f32>(band_y, band_tick));
    let band_active = step(0.82 - burst * 0.38, band_rnd);
    let tear_shift = (cg_hash21(vec2<f32>(band_y + 7.3, band_tick)) - 0.5) * 0.085 * band_active * glitch_power;
    sample_uv.x = sample_uv.x + tear_shift;

    // Fine LCD sub-band jitter near the impact crater
    let fine_y = floor(uv.y * 140.0);
    let fine_rnd = cg_hash21(vec2<f32>(fine_y, floor(t * 24.0)));
    let impact_lcd = smoothstep(0.32, 0.02, r) * step(0.72, fine_rnd) * glitch_power;
    sample_uv.x = sample_uv.x + (fine_rnd - 0.85) * 0.05 * impact_lcd;

    // 6. RGB chromatic aberration split (stronger during glitch bursts and near cracks)
    let rgb_split = (0.0022 + crack * 0.0055 + band_active * 0.012 + burst * 0.008) * glitch_power;
    let uv_r = clamp(sample_uv + vec2<f32>(rgb_split, rgb_split * 0.25), vec2<f32>(0.001), vec2<f32>(0.999));
    let uv_g = clamp(sample_uv, vec2<f32>(0.001), vec2<f32>(0.999));
    let uv_b = clamp(sample_uv - vec2<f32>(rgb_split, rgb_split * 0.20), vec2<f32>(0.001), vec2<f32>(0.999));

    let col_r = textureSampleLevel(previous, linear_sampler, uv_r, 0.0).r;
    let col_g = textureSampleLevel(previous, linear_sampler, uv_g, 0.0).g;
    let col_b = textureSampleLevel(previous, linear_sampler, uv_b, 0.0).b;
    var col = vec3<f32>(col_r, col_g, col_b);

    // 7. Broken LCD color bleed lines & dead glitch blocks near impact point
    let lcd_stripe = smoothstep(0.24, 0.0, abs(uv.x - impact.x)) * smoothstep(0.45, 0.0, abs(uv.y - impact.y));
    let dead_line = step(0.94, cg_hash21(vec2<f32>(floor(uv.x * 180.0), 3.0))) * lcd_stripe * crack_strength;
    let dead_col = vec3<f32>(
        step(0.5, cg_hash11(floor(uv.x * 180.0) + floor(t * 8.0))),
        step(0.4, cg_hash11(floor(uv.x * 180.0) * 1.7 + 2.0)),
        step(0.3, cg_hash11(floor(uv.x * 180.0) * 2.3 + 5.0))
    );
    col = mix(col, dead_col, dead_line * 0.55 * clamp(glitch_strength, 0.0, 1.0));

    // Subtle scanlines inside glitched bands
    let scan = sin(uv.y * res.y * 1.6) * 0.5 + 0.5;
    col = col * (1.0 - band_active * scan * 0.16 * clamp(glitch_power, 0.0, 1.5));

    // 8. Glass crack shading: dark fracture core + crisp white/cyan glass bevel highlight
    col = mix(col, col * 0.12, crack * 0.72);
    let glass_spec = vec3<f32>(0.84, 0.94, 1.0);
    col = col + glass_spec * edge_glow * 0.42;
    col = mix(col, vec3<f32>(0.95, 0.98, 1.0), smoothstep(0.65, 1.0, crack) * 0.58);
    // Dark impact crater center
    col = mix(col, vec3<f32>(0.02, 0.03, 0.05), smoothstep(0.028, 0.004, r) * crack_strength * 0.85);

    return vec4<f32>(clamp(col, vec3<f32>(0.0), vec3<f32>(1.0)), input.color.a);
}
