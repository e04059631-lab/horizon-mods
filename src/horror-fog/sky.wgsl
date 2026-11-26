fn sky(input: SkyInput) -> vec4<f32> {
    let luma = dot(input.color.rgb, vec3<f32>(0.299, 0.587, 0.114));
    let eerie = vec3<f32>(0.36, 0.40, 0.43) * (0.25 + luma * 0.55);
    return vec4<f32>(eerie, 1.0);
}
