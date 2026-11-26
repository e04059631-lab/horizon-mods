override aperture: f32 = 0.55;
override focus_range: f32 = 14.0;

fn dist_at(uv: vec2<f32>) -> f32 {
    let d = depth_at(uv);
    if (d <= 0.00001) { return 250.0; }
    return length(view_position(uv, d));
}

fn post(input: PostInput) -> vec4<f32> {
    let focus_d = clamp(dist_at(vec2<f32>(0.5, 0.5)), 1.5, 120.0);
    let my_d = dist_at(input.uv);
    let coc = clamp((abs(my_d - focus_d) - focus_range * 0.35) / max(focus_range, 1.0), 0.0, 1.0) * aperture;

    if (coc < 0.02) {
        return input.color;
    }

    let px = 1.0 / max(frame.resolution, vec2<f32>(320.0));
    var acc = input.color.rgb;
    var wsum = 1.0;

    // 12-tap Vogel disk bokeh
    for (var i: i32 = 0; i < 12; i = i + 1) {
        let fi = f32(i);
        let r = sqrt((fi + 0.5) / 12.0) * coc * 10.0;
        let ang = fi * 2.3999632;
        let suv = clamp(input.uv + vec2<f32>(cos(ang), sin(ang)) * px * r, vec2<f32>(0.001), vec2<f32>(0.999));
        let s = textureSampleLevel(previous, linear_sampler, suv, 0.0).rgb;
        acc = acc + s;
        wsum = wsum + 1.0;
    }

    return vec4<f32>(acc / wsum, input.color.a);
}
