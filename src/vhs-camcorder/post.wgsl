override tape_wear: f32 = 0.80;

fn vhs_hash(p: vec2<f32>) -> f32 {
    return fract(sin(dot(p, vec2<f32>(127.1, 311.7))) * 43758.5453);
}

fn post(input: PostInput) -> vec4<f32> {
    var uv = input.uv;
    let t = frame.time;

    // Rolling analog tracking distortion band
    let roll = fract(t * 0.14);
    let band = exp(-pow((uv.y - roll) * 14.0, 2.0));
    let jitter = (vhs_hash(vec2<f32>(floor(uv.y * 180.0), floor(t * 24.0))) - 0.5) * 0.018 * band * tape_wear;
    let bottom_tear = smoothstep(0.94, 1.0, uv.y) * (vhs_hash(vec2<f32>(floor(uv.y * 120.0), floor(t * 30.0))) - 0.5) * 0.035 * tape_wear;
    uv.x = uv.x + jitter + bottom_tear;

    // Horizontal chroma bleed (classic VHS Y/C separation)
    let bleed = (0.0035 + band * 0.006) * tape_wear;
    let r = textureSampleLevel(previous, linear_sampler, clamp(uv + vec2<f32>(bleed, 0.0), vec2<f32>(0.001), vec2<f32>(0.999)), 0.0).r;
    let g = textureSampleLevel(previous, linear_sampler, clamp(uv, vec2<f32>(0.001), vec2<f32>(0.999)), 0.0).g;
    let b = textureSampleLevel(previous, linear_sampler, clamp(uv - vec2<f32>(bleed * 1.2, 0.0), vec2<f32>(0.001), vec2<f32>(0.999)), 0.0).b;
    var col = vec3<f32>(r, g, b);

    // Warm slightly washed analog tape grade
    let luma = dot(col, vec3<f32>(0.299, 0.587, 0.114));
    col = mix(vec3<f32>(luma), col, 0.86) * vec3<f32>(1.04, 1.01, 0.94) + vec3<f32>(0.015, 0.010, 0.020);

    // Scanlines + tape snow noise
    let scan = sin(uv.y * max(frame.resolution.y, 320.0) * 1.4) * 0.5 + 0.5;
    col = col * (1.0 - scan * 0.09 * tape_wear);
    let snow = (vhs_hash(uv * 420.0 + vec2<f32>(t * 19.0, t * 31.0)) - 0.5) * (0.07 + band * 0.16) * tape_wear;
    col = col + vec3<f32>(snow);

    // Soft camcorder vignette
    let d = length(input.uv - vec2<f32>(0.5));
    col = col * smoothstep(0.92, 0.36, d);
    return vec4<f32>(clamp(col, vec3<f32>(0.0), vec3<f32>(1.0)), input.color.a);
}
