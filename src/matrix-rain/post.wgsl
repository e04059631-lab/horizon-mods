override rain_intensity: f32 = 0.75;
override green_grade: f32 = 0.65;

fn mx_hash(p: vec2<f32>) -> f32 {
    return fract(sin(dot(p, vec2<f32>(127.1, 311.7))) * 43758.5453);
}

fn post(input: PostInput) -> vec4<f32> {
    let uv = input.uv;
    let t = frame.time;
    var col = input.color.rgb;

    // Matrix cinema emerald color grading
    let luma = dot(col, vec3<f32>(0.2126, 0.7152, 0.0722));
    let matrix_col = vec3<f32>(col.r * 0.62, max(col.g * 1.12, luma * 1.08), col.b * 0.66);
    col = mix(col, matrix_col, green_grade);

    // Falling digital glyph columns (subtle in center, stronger on outer frame)
    let cols = 64.0;
    let rows = 36.0;
    let cell = vec2<f32>(floor(uv.x * cols), floor(uv.y * rows));
    let local = fract(uv * vec2<f32>(cols, rows));

    let speed = 3.5 + mx_hash(vec2<f32>(cell.x, 1.3)) * 6.5;
    let offset = mx_hash(vec2<f32>(cell.x, 7.9)) * 40.0;
    let stream_pos = fract((uv.y * 1.8) - (t * speed * 0.06) + offset);
    let trail = pow(clamp(1.0 - stream_pos, 0.0, 1.0), 4.5);
    let head = smoothstep(0.06, 0.0, stream_pos);

    // Crisp procedural micro-glyph pattern per cell
    let glyph_seed = mx_hash(cell + vec2<f32>(0.0, floor(t * 7.0 + cell.x)));
    let sub = floor(local * vec2<f32>(3.0, 4.0));
    let glyph_px = step(0.45, mx_hash(sub + vec2<f32>(glyph_seed * 19.0, cell.x)));
    let pad = step(0.18, local.x) * step(local.x, 0.82) * step(0.15, local.y) * step(local.y, 0.85);
    let glyph = glyph_px * pad;

    let edge_boost = 0.45 + 0.55 * smoothstep(0.18, 0.62, length(uv - vec2<f32>(0.5)));
    let code_glow = vec3<f32>(0.10, 0.95, 0.35) * trail * glyph * 0.55 + vec3<f32>(0.78, 1.0, 0.85) * head * glyph * 0.85;
    col = col + code_glow * rain_intensity * edge_boost;

    return vec4<f32>(clamp(col, vec3<f32>(0.0), vec3<f32>(1.0)), input.color.a);
}
