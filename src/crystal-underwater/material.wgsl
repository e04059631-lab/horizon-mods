override underwater_brightness: f32 = 0.75;
override caustics: bool = true;

fn material(input: MaterialInput) -> Surface {
    var lm = input.lightmap;
    if (frame.eye_in == 1u) {
        lm = max(lm, vec3<f32>(0.55 * underwater_brightness, 0.72 * underwater_brightness, 0.82 * underwater_brightness));
    }
    var lit = input.albedo.rgb * input.tint.rgb * lm;

    if (caustics && frame.eye_in == 1u && input.fluid == 0u) {
        let wp = input.position + frame.camera_position;
        let t = frame.time * 1.8;
        let c1 = sin(wp.x * 2.3 + t) * cos(wp.z * 2.1 - t * 0.7);
        let c2 = sin((wp.x - wp.z) * 3.4 - t * 1.3);
        let pattern = pow(clamp((c1 + c2) * 0.5 + 0.5, 0.0, 1.0), 3.0);
        lit = lit + vec3<f32>(0.12, 0.26, 0.32) * pattern * max(input.normal.y, 0.15);
    }

    return Surface(vec4<f32>(lit, input.albedo.a * input.tint.a));
}
