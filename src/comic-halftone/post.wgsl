override ink_strength: f32 = 0.90;
override halftone_amount: f32 = 0.65;

fn post(input: PostInput) -> vec4<f32> {
    let uv = input.uv;
    let res = max(frame.resolution, vec2<f32>(320.0));
    let px = 1.5 / res;

    let c = input.color.rgb;
    let c_r = textureSampleLevel(previous, linear_sampler, clamp(uv + vec2<f32>(px.x, 0.0), vec2<f32>(0.001), vec2<f32>(0.999)), 0.0).rgb;
    let c_l = textureSampleLevel(previous, linear_sampler, clamp(uv - vec2<f32>(px.x, 0.0), vec2<f32>(0.001), vec2<f32>(0.999)), 0.0).rgb;
    let c_u = textureSampleLevel(previous, linear_sampler, clamp(uv + vec2<f32>(0.0, px.y), vec2<f32>(0.001), vec2<f32>(0.999)), 0.0).rgb;
    let c_d = textureSampleLevel(previous, linear_sampler, clamp(uv - vec2<f32>(0.0, px.y), vec2<f32>(0.001), vec2<f32>(0.999)), 0.0).rgb;

    let gx = length(c_r - c_l);
    let gy = length(c_u - c_d);
    let col_edge = sqrt(gx * gx + gy * gy);

    // Depth silhouette edges
    let d0 = input.depth;
    let dr = depth_at(clamp(uv + vec2<f32>(px.x, 0.0), vec2<f32>(0.001), vec2<f32>(0.999)));
    let du = depth_at(clamp(uv + vec2<f32>(0.0, px.y), vec2<f32>(0.001), vec2<f32>(0.999)));
    let depth_edge = (abs(d0 - dr) + abs(d0 - du)) * 45.0;

    let ink = smoothstep(0.18, 0.42, (col_edge + depth_edge) * ink_strength);

    // Vibrant cel-shaded comic posterization
    let luma = dot(c, vec3<f32>(0.2126, 0.7152, 0.0722));
    var col = mix(vec3<f32>(luma), c, 1.28);
    col = floor(col * 7.0 + vec3<f32>(0.5)) / 7.0;

    // Halftone dots in darker shadow regions
    let dot_pos = fract(uv * res * 0.16) - vec2<f32>(0.5);
    let dot_r = length(dot_pos);
    let shadow_amt = smoothstep(0.58, 0.10, luma);
    let halftone = smoothstep(0.38 * shadow_amt, 0.38 * shadow_amt - 0.06, dot_r);
    col = col * (1.0 - halftone * 0.28 * halftone_amount);

    // Apply black ink outline
    col = mix(col, vec3<f32>(0.04, 0.04, 0.06), clamp(ink, 0.0, 0.92));
    return vec4<f32>(clamp(col, vec3<f32>(0.0), vec3<f32>(1.0)), input.color.a);
}
