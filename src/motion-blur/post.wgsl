// Motion Blur for Horizon 26.3
// Smooth camera-velocity post-processing motion blur with 144 Hz frame-time normalization
// and interleaved gradient noise dithering to eliminate banding.

override blur_strength: f32 = 0.65;
override blur_samples: i32 = 10;
override blur_sky: bool = true;

fn ign(pixel: vec2<f32>) -> f32 {
    return fract(52.9829189 * fract(dot(pixel, vec2<f32>(0.06711056, 0.00583715))));
}

fn post(input: PostInput) -> vec4<f32> {
    // Skip on first frame, after pause/world load, or invalid delta time
    if (frame.delta_time <= 0.0001) {
        return input.color;
    }

    let uv = input.uv;
    let is_sky = input.depth <= 0.00001;

    if (is_sky && !blur_sky) {
        return input.color;
    }

    // Reconstruct previous clip position
    var prev_clip: vec4<f32>;
    if (is_sky) {
        // Rotation-only reprojection for sky/far plane
        let ndc = vec2<f32>(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);
        let far_view = frame.projection_inverse * vec4<f32>(ndc, 0.5, 1.0);
        let ray_dir = normalize((frame.view_inverse * vec4<f32>(far_view.xyz / far_view.w, 0.0)).xyz);
        prev_clip = frame.previous_view_projection * vec4<f32>(ray_dir * 1000.0, 1.0);
    } else {
        // World-space camera-relative position -> reproject with camera motion
        let world_pos = view_position(uv, input.depth);
        prev_clip = frame.previous_view_projection * vec4<f32>(world_pos + frame.camera_motion, 1.0);
    }

    if (prev_clip.w <= 0.0001) {
        return input.color;
    }

    let prev_ndc = prev_clip.xy / prev_clip.w;
    let prev_uv = vec2<f32>(prev_ndc.x * 0.5 + 0.5, 0.5 - prev_ndc.y * 0.5);

    // Normalize shutter angle to 60 FPS equivalent so blur looks consistent on 144 Hz+ monitors
    let dt_scale = clamp(0.0166667 / max(frame.delta_time, 0.002), 0.35, 2.5);
    var velocity = (uv - prev_uv) * blur_strength * dt_scale;

    let speed = length(velocity);
    if (speed < 0.0005) {
        return input.color;
    }

    // Clamp maximum blur radius to prevent stretching artifacts on sharp flicks
    let max_blur = 0.065;
    if (speed > max_blur) {
        velocity = velocity * (max_blur / speed);
    }

    let samples = max(blur_samples, 4);
    let samples_f = f32(samples);
    let jitter = ign(input.pixel) - 0.5;

    var accum = vec3<f32>(0.0);
    var total_weight = 0.0;

    for (var i: i32 = 0; i < samples; i = i + 1) {
        let t = ((f32(i) + 0.5 + jitter) / samples_f) - 0.5;
        let sample_uv = clamp(uv + velocity * t, vec2<f32>(0.001), vec2<f32>(0.999));

        // Gentle center-weighted kernel for silky trails
        let w = 1.0 - abs(t) * 0.6;
        let sample_col = textureSampleLevel(previous, linear_sampler, sample_uv, 0.0).rgb;

        accum = accum + sample_col * w;
        total_weight = total_weight + w;
    }

    return vec4<f32>(accum / max(total_weight, 0.0001), input.color.a);
}
