override warmth: f32 = 0.65;
override vignette: f32 = 0.28;

fn post(input: PostInput) -> vec4<f32> {
    var col = input.color.rgb;
    let luma = dot(col, vec3<f32>(0.2126, 0.7152, 0.0722));
    // Split toning: warm golden highlights, rich plum-indigo deep shadows
    let shadows = vec3<f32>(0.94, 0.90, 1.04);
    let highlights = vec3<f32>(1.12, 0.99, 0.84);
    let graded = col * mix(shadows, highlights, smoothstep(0.15, 0.85, luma));
    col = mix(col, graded, warmth * 0.75);

    let centered = input.uv - vec2<f32>(0.5);
    let vig = 1.0 - dot(centered, centered) * vignette * 1.6;
    col = col * clamp(vig, 0.3, 1.0);
    return vec4<f32>(col, input.color.a);
}
