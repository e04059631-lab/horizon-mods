override neon_intensity: f32 = 0.70;
override chroma_shift: f32 = 0.35;

fn post(input: PostInput) -> vec4<f32> {
    let uv = input.uv;
    let from_center = uv - vec2<f32>(0.5);
    let shift = from_center * 0.005 * chroma_shift;

    let r = textureSampleLevel(previous, linear_sampler, clamp(uv + shift, vec2<f32>(0.001), vec2<f32>(0.999)), 0.0).r;
    let g = input.color.g;
    let b = textureSampleLevel(previous, linear_sampler, clamp(uv - shift, vec2<f32>(0.001), vec2<f32>(0.999)), 0.0).b;
    var col = vec3<f32>(r, g, b);

    let luma = dot(col, vec3<f32>(0.2126, 0.7152, 0.0722));
    let cyber = col * mix(vec3<f32>(0.78, 0.95, 1.25), vec3<f32>(1.22, 0.86, 1.18), smoothstep(0.15, 0.85, luma));
    col = mix(col, cyber, neon_intensity * 0.75);
    return vec4<f32>(col, input.color.a);
}
