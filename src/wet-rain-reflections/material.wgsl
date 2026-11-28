override wetness_boost: f32 = 0.95;
override always_wet: bool = false;

fn wr_puddle(p: vec2<f32>) -> f32 {
    let n = sin(p.x * 0.45 + sin(p.y * 0.35)) * cos(p.y * 0.52 - cos(p.x * 0.38));
    return smoothstep(0.05, 0.55, n * 0.5 + 0.5);
}

fn material(input: MaterialInput) -> Surface {
    var wet = frame.rain;
    if (always_wet) {
        wet = max(wet, 0.75);
    }
    let sky_exposed = smoothstep(0.45, 0.92, input.light.y);
    let top_face = smoothstep(0.55, 0.95, input.normal.y);
    let puddle = wr_puddle(input.position.xz);
    let w = wet * sky_exposed * top_face * wetness_boost;

    var base = input.albedo.rgb * input.tint.rgb;
    // Wet materials look richer and slightly darker
    base = mix(base, base * base * 0.95 + base * 0.28, clamp(w * (0.45 + puddle * 0.35), 0.0, 0.72));
    var lit = base * input.lightmap;

    // Fresnel sky reflection sheen + subtle raindrop ripple sparkle
    let view_dir = normalize(frame.camera_position - input.position);
    let ndotv = clamp(dot(normalize(input.normal), view_dir), 0.0, 1.0);
    let fresnel = pow(1.0 - ndotv, 3.2);
    let ripple = sin(length(fract(input.position.xz * 0.5) - vec2<f32>(0.5)) * 28.0 - frame.time * 9.0) * 0.5 + 0.5;
    let sheen = (fresnel * (0.45 + puddle * 0.65) + ripple * puddle * 0.08 * frame.rain) * w;
    lit = lit + max(frame.sky_color, vec3<f32>(0.25, 0.32, 0.42)) * sheen * 0.55;

    return Surface(vec4<f32>(lit, input.albedo.a * input.tint.a));
}
