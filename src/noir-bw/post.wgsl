override contrast: f32 = 1.25;
override keep_reds: bool = true;

fn post(input: PostInput) -> vec4<f32> {
    let col = input.color.rgb;
    let luma = dot(col, vec3<f32>(0.299, 0.587, 0.114));
    let bw = clamp((luma - 0.5) * contrast + 0.5, 0.0, 1.0);
    var out_col = vec3<f32>(bw);

    if (keep_reds) {
        let redness = smoothstep(0.14, 0.34, col.r - max(col.g, col.b));
        out_col = mix(out_col, col * vec3<f32>(1.18, 0.85, 0.85), redness);
    }

    let c = input.uv - vec2<f32>(0.5);
    out_col = out_col * clamp(1.0 - dot(c, c) * 0.55, 0.45, 1.0);
    return vec4<f32>(out_col, input.color.a);
}
