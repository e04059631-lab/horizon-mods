override fog_density: f32 = 0.045;
override desaturation: f32 = 0.55;

fn grain(p: vec2<f32>, t: f32) -> f32 {
    return fract(52.9829189 * fract(dot(p + vec2<f32>(t * 17.0, t * 31.0), vec2<f32>(0.06711056, 0.00583715))));
}

fn post(input: PostInput) -> vec4<f32> {
    var col = input.color.rgb;
    let fog_tint = vec3<f32>(0.32, 0.36, 0.39) * clamp(dot(frame.sky_color, vec3<f32>(0.333)) + 0.22, 0.14, 0.78);

    var dist = 120.0;
    if (input.depth > 0.00001) {
        dist = length(view_position(input.uv, input.depth));
    }
    let fog_amt = clamp(1.0 - exp(-dist * fog_density), 0.0, 0.96);
    col = mix(col, fog_tint, fog_amt);

    let luma = dot(col, vec3<f32>(0.2126, 0.7152, 0.0722));
    col = mix(col, vec3<f32>(luma) * vec3<f32>(0.94, 1.0, 1.05), desaturation);

    // Subtle film grain + claustrophobic vignette
    let g = (grain(input.pixel, fract(frame.time)) - 0.5) * 0.035;
    let c = input.uv - vec2<f32>(0.5);
    let vig = clamp(1.0 - dot(c, c) * 1.25, 0.22, 1.0);
    col = clamp((col + g) * vig, vec3<f32>(0.0), vec3<f32>(1.0));
    return vec4<f32>(col, input.color.a);
}
