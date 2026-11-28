override frost_amount: f32 = 0.85;

fn af_hash(p: vec2<f32>) -> f32 {
    return fract(sin(dot(p, vec2<f32>(127.1, 311.7))) * 43758.5453);
}

fn af_noise(p: vec2<f32>) -> f32 {
    let i = floor(p);
    let f = fract(p);
    let u = f * f * (vec2<f32>(3.0) - 2.0 * f);
    let a = af_hash(i);
    let b = af_hash(i + vec2<f32>(1.0, 0.0));
    let c = af_hash(i + vec2<f32>(0.0, 1.0));
    let d = af_hash(i + vec2<f32>(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

fn post(input: PostInput) -> vec4<f32> {
    let uv = input.uv;
    let d = length((uv - vec2<f32>(0.5)) * vec2<f32>(1.25, 1.0));

    // Crystalline frost pattern concentrated at screen borders
    let n1 = af_noise(uv * 16.0);
    let n2 = af_noise(uv * 38.0 + vec2<f32>(n1 * 2.5));
    let crystal = n1 * 0.55 + n2 * 0.45;
    let frost_mask = smoothstep(0.46, 0.86, d + (crystal - 0.5) * 0.24) * clamp(frost_amount, 0.0, 1.4);

    // Slight icy refraction inside frosted rim
    let refr_uv = clamp(uv + (vec2<f32>(n2, n1) - vec2<f32>(0.5)) * 0.012 * frost_mask, vec2<f32>(0.001), vec2<f32>(0.999));
    var col = textureSampleLevel(previous, linear_sampler, refr_uv, 0.0).rgb;

    // Crisp winter cool color grade + snow sparkle
    col = col * vec3<f32>(0.92, 0.99, 1.08);
    let luma = dot(col, vec3<f32>(0.2126, 0.7152, 0.0722));
    let sparkle = step(0.96, af_hash(floor(uv * 220.0) + vec2<f32>(floor(frame.time * 4.0), 0.0))) * smoothstep(0.75, 0.98, luma);
    col = col + vec3<f32>(0.6, 0.85, 1.0) * sparkle * 0.45;

    // Icy frosted glass overlay around edges
    let ice_col = mix(vec3<f32>(0.68, 0.88, 1.0), vec3<f32>(0.92, 0.97, 1.0), crystal);
    col = mix(col, ice_col, clamp(frost_mask * 0.62, 0.0, 0.78));
    return vec4<f32>(clamp(col, vec3<f32>(0.0), vec3<f32>(1.0)), input.color.a);
}
