override aurora_intensity: f32 = 0.85;
override star_density: f32 = 0.90;

fn hash3(p: vec3<f32>) -> f32 {
    let q = fract(p * vec3<f32>(443.897, 441.423, 437.195));
    let r = q + dot(q, q.yzx + 19.19);
    return fract((r.x + r.y) * r.z);
}

fn sky(input: SkyInput) -> vec4<f32> {
    let d = normalize(input.direction);
    var col = input.color.rgb;

    // Night factor based on sun elevation
    let night = smoothstep(0.08, -0.18, frame.sun_direction.y) * (1.0 - frame.rain * 0.85);
    if (night > 0.01 && d.y > 0.02) {
        // Twinkling procedural stars
        let cell = floor(d * 260.0);
        let h = hash3(cell);
        if (h > 0.992) {
            let twinkle = 0.65 + 0.35 * sin(frame.time * 3.5 + h * 90.0);
            let star_col = mix(vec3<f32>(0.75, 0.86, 1.0), vec3<f32>(1.0, 0.92, 0.80), fract(h * 17.3));
            col = col + star_col * ((h - 0.992) * 125.0) * twinkle * star_density * night * smoothstep(0.02, 0.25, d.y);
        }

        // Aurora curtains
        let uv = d.xz / (d.y + 0.22);
        let t = frame.time * 0.28;
        let wave1 = sin(uv.x * 1.8 + sin(uv.y * 1.3 + t) * 1.6 + t);
        let wave2 = sin(uv.y * 2.4 - uv.x * 1.1 - t * 1.3);
        let ribbon = pow(clamp(1.0 - abs(wave1 * 0.65 + wave2 * 0.35), 0.0, 1.0), 5.0);
        let fade = smoothstep(0.03, 0.28, d.y) * smoothstep(0.98, 0.35, d.y);
        let a_col = mix(vec3<f32>(0.10, 0.95, 0.58), vec3<f32>(0.52, 0.28, 0.98), clamp(wave2 * 0.5 + 0.5, 0.0, 1.0));
        col = col + a_col * ribbon * fade * aurora_intensity * night * 0.65;
    }

    return vec4<f32>(col, 1.0);
}
