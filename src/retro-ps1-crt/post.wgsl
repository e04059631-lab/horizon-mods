override pixel_size: i32 = 2;
override scanlines: f32 = 0.25;

fn bayer2(p: vec2<f32>) -> f32 {
    let x = i32(p.x) & 1;
    let y = i32(p.y) & 1;
    let idx = x + y * 2;
    if (idx == 0) { return -0.375; }
    if (idx == 1) { return 0.125; }
    if (idx == 2) { return 0.375; }
    return -0.125;
}

fn post(input: PostInput) -> vec4<f32> {
    let scale = f32(max(pixel_size, 1));
    let grid = max(floor(frame.resolution / scale), vec2<f32>(160.0));
    let puv = (floor(input.uv * grid) + 0.5) / grid;
    var col = textureSampleLevel(previous, nearest_sampler, clamp(puv, vec2<f32>(0.001), vec2<f32>(0.999)), 0.0).rgb;

    // 5-bit per channel PS1 color quantization with ordered dithering
    let dither = bayer2(floor(input.pixel / scale)) / 31.0;
    col = floor(clamp(col + dither, vec3<f32>(0.0), vec3<f32>(1.0)) * 31.0 + 0.5) / 31.0;

    // CRT scanlines
    let line = 0.5 + 0.5 * sin(input.pixel.y * 3.14159265);
    col = col * (1.0 - scanlines * line * 0.45);
    return vec4<f32>(col, input.color.a);
}
