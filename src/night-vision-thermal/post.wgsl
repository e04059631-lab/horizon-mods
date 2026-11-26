override thermal_mode: bool = false;

fn thermal_palette(t: f32) -> vec3<f32> {
    let x = clamp(t, 0.0, 1.0);
    let c0 = vec3<f32>(0.06, 0.02, 0.28);
    let c1 = vec3<f32>(0.58, 0.08, 0.55);
    let c2 = vec3<f32>(0.98, 0.48, 0.06);
    let c3 = vec3<f32>(1.00, 0.98, 0.82);
    if (x < 0.33) { return mix(c0, c1, x / 0.33); }
    if (x < 0.66) { return mix(c1, c2, (x - 0.33) / 0.33); }
    return mix(c2, c3, (x - 0.66) / 0.34);
}

fn post(input: PostInput) -> vec4<f32> {
    let c = input.color.rgb;
    let luma = clamp(dot(c, vec3<f32>(0.299, 0.587, 0.114)), 0.0, 1.0);
    let scan = 0.94 + 0.06 * sin(input.pixel.y * 2.4);
    var out_col: vec3<f32>;

    if (thermal_mode) {
        let heat = clamp(luma * 0.85 + max(c.r - c.b, 0.0) * 0.55, 0.0, 1.0);
        out_col = thermal_palette(heat) * scan;
    } else {
        let phosphor = pow(luma, 0.72);
        out_col = vec3<f32>(phosphor * 0.22, phosphor * 1.12, phosphor * 0.32) * scan;
    }

    let d = input.uv - vec2<f32>(0.5);
    out_col = out_col * clamp(1.0 - dot(d, d) * 0.95, 0.25, 1.0);
    return vec4<f32>(clamp(out_col, vec3<f32>(0.0), vec3<f32>(1.0)), input.color.a);
}
