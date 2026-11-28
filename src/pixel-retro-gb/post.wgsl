override pixel_scale: f32 = 3.0;
override gameboy_palette: bool = false;

fn post(input: PostInput) -> vec4<f32> {
    let res = max(frame.resolution, vec2<f32>(320.0));
    let grid = max(res / max(pixel_scale, 1.0), vec2<f32>(64.0));
    let puv = clamp((floor(input.uv * grid) + vec2<f32>(0.5)) / grid, vec2<f32>(0.001), vec2<f32>(0.999));
    var col = textureSampleLevel(previous, linear_sampler, puv, 0.0).rgb;

    if (gameboy_palette) {
        let luma = clamp(dot(col, vec3<f32>(0.299, 0.587, 0.114)), 0.0, 1.0);
        let q = floor(luma * 3.99);
        if (q < 0.5) {
            col = vec3<f32>(0.06, 0.22, 0.06);
        } else if (q < 1.5) {
            col = vec3<f32>(0.19, 0.38, 0.19);
        } else if (q < 2.5) {
            col = vec3<f32>(0.55, 0.67, 0.06);
        } else {
            col = vec3<f32>(0.61, 0.74, 0.06);
        }
    } else {
        // Crisp 16-bit color posterization
        col = floor(col * 16.0 + vec3<f32>(0.5)) / 16.0;
    }

    return vec4<f32>(clamp(col, vec3<f32>(0.0), vec3<f32>(1.0)), input.color.a);
}
