override haze_strength: f32 = 0.65;
override always_on: bool = false;

fn post(input: PostInput) -> vec4<f32> {
    var biome_heat = smoothstep(0.95, 1.85, frame.temperature);
    if (frame.dimension == -1) { biome_heat = 1.0; }
    if (always_on) { biome_heat = max(biome_heat, 0.75); }
    biome_heat = biome_heat * (1.0 - frame.rain * 0.85);

    if (biome_heat < 0.02 || input.depth <= 0.00001) {
        return input.color;
    }

    let dist = length(view_position(input.uv, input.depth));
    let dist_mask = smoothstep(10.0, 48.0, dist);
    if (dist_mask < 0.01) {
        return input.color;
    }

    let t = frame.time * 3.4;
    let wave = vec2<f32>(
        sin(input.uv.y * 55.0 + t + input.uv.x * 18.0),
        cos(input.uv.x * 42.0 - t * 1.2 + input.uv.y * 24.0) * 0.5
    );
    let offset = wave * 0.0022 * haze_strength * biome_heat * dist_mask;
    let suv = clamp(input.uv + offset, vec2<f32>(0.001), vec2<f32>(0.999));

    // Only accept distorted sample if it is also distant (avoids foreground edge halos)
    let sd = depth_at(suv);
    if (sd > input.depth * 2.5 + 0.01) {
        return input.color;
    }

    let col = textureSampleLevel(previous, linear_sampler, suv, 0.0).rgb;
    return vec4<f32>(col, input.color.a);
}
