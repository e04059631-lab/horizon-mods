override motion_blur_amount: f32 = 0.35;
override bloom_amount: f32 = 0.30;

fn aces(x: vec3<f32>) -> vec3<f32> {
    return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), vec3<f32>(0.0), vec3<f32>(1.0));
}

fn post(input: PostInput) -> vec4<f32> {
    let uv = input.uv;
    var base = input.color.rgb;

    // Optional camera motion blur
    if (motion_blur_amount > 0.01 && frame.delta_time > 0.0001 && input.depth > 0.00001) {
        let wp = view_position(uv, input.depth);
        let pclip = frame.previous_view_projection * vec4<f32>(wp + frame.camera_motion, 1.0);
        if (pclip.w > 0.0001) {
            let pndc = pclip.xy / pclip.w;
            let puv = vec2<f32>(pndc.x * 0.5 + 0.5, 0.5 - pndc.y * 0.5);
            let dt_s = clamp(0.01667 / max(frame.delta_time, 0.002), 0.35, 2.2);
            var vel = (uv - puv) * motion_blur_amount * dt_s;
            let sp = length(vel);
            if (sp > 0.05) { vel = vel * (0.05 / sp); }
            if (sp > 0.0006) {
                var acc = vec3<f32>(0.0);
                for (var i: i32 = 0; i < 6; i = i + 1) {
                    let t = (f32(i) + 0.5) / 6.0 - 0.5;
                    let suv = clamp(uv + vel * t, vec2<f32>(0.001), vec2<f32>(0.999));
                    acc = acc + textureSampleLevel(previous, linear_sampler, suv, 0.0).rgb;
                }
                base = acc / 6.0;
            }
        }
    }

    // Soft 8-tap highlight bloom
    if (bloom_amount > 0.01) {
        let px = 1.0 / max(frame.resolution, vec2<f32>(320.0));
        var glow = vec3<f32>(0.0);
        for (var k: i32 = 0; k < 8; k = k + 1) {
            let ang = f32(k) * 0.785398;
            let rad = (3.5 + f32(k % 2) * 5.5);
            let off = vec2<f32>(cos(ang), sin(ang)) * px * rad;
            let s = textureSampleLevel(previous, linear_sampler, clamp(uv + off, vec2<f32>(0.001), vec2<f32>(0.999)), 0.0).rgb;
            let br = max(max(s.r, max(s.g, s.b)) - 0.72, 0.0);
            glow = glow + s * br;
        }
        base = base + (glow * 0.22) * bloom_amount;
    }

    let graded = mix(base, aces(base * 1.08), 0.35);
    return vec4<f32>(graded, input.color.a);
}
