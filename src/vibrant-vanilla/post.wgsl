override vibrance: f32 = 0.35;

fn aces_tonemap(x: vec3<f32>) -> vec3<f32> {
    let a = 2.51;
    let b = 0.03;
    let c = 2.43;
    let d = 0.59;
    let e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), vec3<f32>(0.0), vec3<f32>(1.0));
}

fn post(input: PostInput) -> vec4<f32> {
    var col = input.color.rgb * 1.06;
    let luma = dot(col, vec3<f32>(0.2126, 0.7152, 0.0722));
    let max_c = max(col.r, max(col.g, col.b));
    let min_c = min(col.r, min(col.g, col.b));
    let sat = max_c - min_c;
    col = mix(vec3<f32>(luma), col, 1.0 + vibrance * (1.0 - sat));
    col = mix(col, aces_tonemap(col * 1.12), 0.38);
    return vec4<f32>(col, input.color.a);
}
