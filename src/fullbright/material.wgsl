override min_brightness: f32 = 0.92;
override keep_face_shade: bool = true;

fn material(input: MaterialInput) -> Surface {
    let lifted_light = max(input.lightmap, vec3<f32>(min_brightness));
    let shade = select(vec3<f32>(1.0), mix(vec3<f32>(1.0), input.tint.rgb, 0.88), keep_face_shade);
    let lit = input.albedo.rgb * shade * lifted_light;
    return Surface(vec4<f32>(lit, input.albedo.a * input.tint.a));
}
