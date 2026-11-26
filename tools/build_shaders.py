"""Builds all 26 client-side WGSL Horizon 26.3 shader packs (.hshader)."""

from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parent.parent
SRC_ROOT = ROOT / "src"
MODS_ROOT = ROOT / "mods"

SHADERS: list[dict] = []


def add_shader(
    mod_id: str,
    toml_id: str,
    name: str,
    ru_desc: str,
    toml_body: str,
    files: dict[str, str],
) -> None:
    header = (
        f'schema = 1\n'
        f'api = "0.1"\n'
        f'id = "{toml_id}"\n'
        f'name = "{name}"\n'
        f'version = "1.0.0"\n\n'
    )
    SHADERS.append(
        {
            "id": mod_id,
            "name": name,
            "description": ru_desc,
            "file_name": f"{mod_id}.hshader",
            "toml": header + toml_body.strip() + "\n",
            "files": {k: v.strip() + "\n" for k, v in files.items()},
        }
    )


# 1. Fullbright
add_shader(
    "fullbright",
    "fullbright",
    "Fullbright",
    "Максимальная яркость в пещерах, под водой и ночью без факелов и зелий с сохранением объёма блоков.",
    """
[[options]]
id = "min_brightness"
name = "Minimum Brightness"
description = "Minimum light floor in caves and at night."
type = "float"
default = 0.92
min = 0.35
max = 1.25
step = 0.05

[[options]]
id = "keep_face_shade"
name = "Keep Block Shading"
description = "Preserve subtle directional block face contrast."
type = "bool"
default = true

[material]
file = "material.wgsl"
""",
    {
        "material.wgsl": """
override min_brightness: f32 = 0.92;
override keep_face_shade: bool = true;

fn material(input: MaterialInput) -> Surface {
    let lifted_light = max(input.lightmap, vec3<f32>(min_brightness));
    let shade = select(vec3<f32>(1.0), mix(vec3<f32>(1.0), input.tint.rgb, 0.88), keep_face_shade);
    let lit = input.albedo.rgb * shade * lifted_light;
    return Surface(vec4<f32>(lit, input.albedo.a * input.tint.a));
}
"""
    },
)

# 2. Vibrant Vanilla+
add_shader(
    "vibrant-vanilla",
    "vibrant_vanilla",
    "Vibrant Vanilla+",
    "Сочные краски, тёплый солнечный свет на гранях блоков, мягкий контраст и ACES-цветокоррекция без потери FPS.",
    """
[[options]]
id = "vibrance"
name = "Color Vibrance"
description = "Boosts muted colors without clipping already saturated tones."
type = "float"
default = 0.35
min = 0.0
max = 0.85
step = 0.05

[[options]]
id = "sun_warmth"
name = "Sunlight Warmth"
description = "Warm directional sunlight highlight on outdoor blocks."
type = "float"
default = 0.30
min = 0.0
max = 0.70
step = 0.05

[sky]
file = "sky.wgsl"

[material]
file = "material.wgsl"

[[post]]
file = "post.wgsl"
""",
    {
        "sky.wgsl": """
fn sky(input: SkyInput) -> vec4<f32> {
    let h = clamp(input.direction.y, 0.0, 1.0);
    let sun_dot = max(dot(input.direction, frame.sun_direction), 0.0);
    var col = input.color.rgb * mix(vec3<f32>(1.04, 1.01, 0.98), vec3<f32>(0.90, 0.98, 1.12), h);
    col = col + vec3<f32>(1.0, 0.72, 0.42) * pow(sun_dot, 8.0) * 0.22 * clamp(frame.sun_direction.y + 0.25, 0.0, 1.0);
    return vec4<f32>(col, 1.0);
}
""",
        "material.wgsl": """
override sun_warmth: f32 = 0.30;

fn material(input: MaterialInput) -> Surface {
    var lit = input.albedo.rgb * input.tint.rgb * input.lightmap;
    let ndotl = max(dot(input.normal, frame.light_direction), 0.0);
    let outdoor = smoothstep(0.35, 0.95, input.light.y);
    let day = clamp(frame.sun_direction.y * 2.5 + 0.2, 0.0, 1.0);
    let sun_tint = mix(vec3<f32>(0.72, 0.80, 1.05), vec3<f32>(1.18, 1.04, 0.86), day);
    lit = lit * mix(vec3<f32>(1.0), sun_tint * (0.90 + 0.28 * ndotl), outdoor * sun_warmth);
    lit = lit + input.albedo.rgb * input.emission * 0.22;
    return Surface(vec4<f32>(lit, input.albedo.a * input.tint.a));
}
""",
        "post.wgsl": """
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
""",
    },
)

# 3. Dynamic Colored Lights
add_shader(
    "colored-lights",
    "colored_lights",
    "Dynamic Colored Lights",
    "Реалистичное цветное 3D-освещение от факелов, душ, редстоуна, лавы, аметистов, порталов и морских фонарей.",
    """
[[options]]
id = "light_intensity"
name = "Colored Light Strength"
description = "Intensity of colored block lighting around light sources."
type = "float"
default = 0.85
min = 0.2
max = 1.6
step = 0.05

[[options]]
id = "emissive_boost"
name = "Glowing Blocks Boost"
description = "Extra self-illumination on light-emitting blocks."
type = "float"
default = 0.35
min = 0.0
max = 0.9
step = 0.05

[[lights]]
color = [1.8, 1.05, 0.42]
blocks = ["minecraft:torch", "minecraft:wall_torch", "minecraft:lantern", "minecraft:campfire", "minecraft:jack_o_lantern", "minecraft:shroomlight", "minecraft:ochre_froglight"]

[[lights]]
color = [0.35, 1.45, 1.85]
blocks = ["minecraft:soul_torch", "minecraft:soul_wall_torch", "minecraft:soul_lantern", "minecraft:soul_campfire", "minecraft:soul_fire"]

[[lights]]
color = [1.85, 0.22, 0.18]
blocks = ["minecraft:redstone_torch", "minecraft:redstone_wall_torch", "minecraft:redstone_ore", "minecraft:deepslate_redstone_ore"]

[[lights]]
color = [1.95, 0.68, 0.16]
blocks = ["minecraft:lava", "minecraft:flowing_lava", "minecraft:magma_block", "minecraft:fire"]

[[lights]]
color = [0.55, 1.65, 1.45]
blocks = ["minecraft:sea_lantern", "minecraft:conduit", "minecraft:verdant_froglight", "minecraft:glow_lichen"]

[[lights]]
color = [1.45, 0.55, 1.95]
blocks = ["minecraft:crying_obsidian", "minecraft:respawn_anchor", "minecraft:nether_portal", "minecraft:amethyst_cluster", "minecraft:pearlescent_froglight"]

[[lights]]
color = [1.65, 1.38, 0.72]
blocks = ["minecraft:glowstone", "minecraft:end_rod", "minecraft:beacon"]

[material]
file = "material.wgsl"
""",
    {
        "material.wgsl": """
override light_intensity: f32 = 0.85;
override emissive_boost: f32 = 0.35;

fn material(input: MaterialInput) -> Surface {
    let base = input.albedo.rgb * input.tint.rgb * input.lightmap;
    let bl = block_light_color(input.position);
    let reach = clamp(bl.a * light_intensity, 0.0, 1.4);
    let tinted = input.albedo.rgb * input.tint.rgb * bl.rgb * (0.42 * reach * (0.25 + input.light.x));
    let self_glow = input.albedo.rgb * input.emission * emissive_boost;
    let lit = mix(base, base * 0.75 + tinted, clamp(bl.a * 0.85, 0.0, 0.85)) + tinted * 0.35 + self_glow;
    return Surface(vec4<f32>(lit, input.albedo.a * input.tint.a));
}
"""
    },
)

# 4. Realistic Water & Reflections
add_shader(
    "water-reflections",
    "water_reflections",
    "Realistic Water & Reflections",
    "Зеркальные отражения мира в воде, живые процедурные волны с бликами солнца и чистая глубина водоёмов.",
    """
[[options]]
id = "wave_strength"
name = "Wave Amplitude"
description = "Strength of animated water surface ripples."
type = "float"
default = 0.45
min = 0.0
max = 1.0
step = 0.05

[[options]]
id = "reflection_mix"
name = "Reflection Intensity"
description = "How strongly water reflects sky and terrain."
type = "float"
default = 0.75
min = 0.15
max = 1.0
step = 0.05

[reflection]

[material]
file = "material.wgsl"
""",
    {
        "material.wgsl": """
override wave_strength: f32 = 0.45;
override reflection_mix: f32 = 0.75;

fn material(input: MaterialInput) -> Surface {
    var lit = input.albedo.rgb * input.tint.rgb * input.lightmap;
    var alpha = input.albedo.a * input.tint.a;

    if (input.fluid == 1u) {
        let world_xz = input.position.xz + frame.camera_position.xz;
        let t = frame.time * 2.1;
        let w1 = sin(world_xz.x * 1.9 + t) * cos(world_xz.y * 1.5 - t * 0.8);
        let w2 = sin((world_xz.x + world_xz.y) * 3.1 - t * 1.4) * 0.5;
        let ripple = vec2<f32>(w1 + w2, w1 - w2) * 0.012 * wave_strength;

        let view_dir = normalize(-input.position);
        let n = normalize(vec3<f32>(ripple.x * 6.0, 1.0, ripple.y * 6.0));
        let fresnel = clamp(0.08 + 0.92 * pow(1.0 - max(dot(view_dir, n), 0.0), 4.0), 0.0, 1.0);

        let water_deep = vec3<f32>(0.05, 0.24, 0.36) * (0.35 + 0.65 * input.light.y);
        var surface_col = mix(lit * 0.85, water_deep, 0.45);

        if (frame.has_reflection == 1u) {
            let refl_uv = clamp(input.screen + ripple, vec2<f32>(0.002), vec2<f32>(0.998));
            let refl = textureSampleLevel(reflection, reflection_sampler, refl_uv, 0.0).rgb;
            surface_col = mix(surface_col, refl, fresnel * reflection_mix);
        } else {
            surface_col = mix(surface_col, frame.sky_color, fresnel * reflection_mix * 0.7);
        }

        // Sun specular glint
        let half_v = normalize(view_dir + frame.light_direction);
        let spec = pow(max(dot(n, half_v), 0.0), 64.0) * smoothstep(0.0, 0.2, frame.light_direction.y);
        surface_col = surface_col + vec3<f32>(1.0, 0.95, 0.82) * spec * 0.85 * input.light.y;
        alpha = clamp(mix(0.62, 0.92, fresnel), 0.45, 0.96);
        lit = surface_col;
    }

    return Surface(vec4<f32>(lit, alpha));
}
"""
    },
)

# 5. Real Shadows Lite
add_shader(
    "real-shadows-lite",
    "real_shadows_lite",
    "Real Shadows Lite",
    "Мягкие динамические тени от солнца и луны с цветными тенями от витражей, оптимизированные под высокий FPS.",
    """
[[options]]
id = "shadow_strength"
name = "Shadow Darkness"
description = "How deep outdoor shadows look."
type = "float"
default = 0.55
min = 0.15
max = 0.85
step = 0.05

[[options]]
id = "softness"
name = "Shadow Softness"
description = "PCF filter radius for smooth shadow edges."
type = "float"
default = 1.25
min = 0.4
max = 2.5
step = 0.05

[shadow]
resolution = 1024
distance = 72.0

[material]
file = "material.wgsl"
""",
    {
        "material.wgsl": """
override shadow_strength: f32 = 0.55;
override softness: f32 = 1.25;

fn material(input: MaterialInput) -> Surface {
    var lit = input.albedo.rgb * input.tint.rgb * input.lightmap;

    if (frame.has_shadow == 1u && input.emission < 0.2) {
        let ndotl = dot(input.normal, frame.light_direction);
        let bias = frame.shadow_center_texel * 0.015 + 0.0008;
        let sp = shadow_position(input.position + input.normal * 0.04);
        let texel = (1.0 / max(frame.shadow_resolution, 512.0)) * softness;

        let s0 = textureSampleCompareLevel(shadow_map, shadow_sampler, sp.xy, sp.z - bias);
        let s1 = textureSampleCompareLevel(shadow_map, shadow_sampler, sp.xy + vec2<f32>(texel, texel * 0.4), sp.z - bias);
        let s2 = textureSampleCompareLevel(shadow_map, shadow_sampler, sp.xy + vec2<f32>(-texel, -texel * 0.4), sp.z - bias);
        let s3 = textureSampleCompareLevel(shadow_map, shadow_sampler, sp.xy + vec2<f32>(-texel * 0.4, texel), sp.z - bias);
        let s4 = textureSampleCompareLevel(shadow_map, shadow_sampler, sp.xy + vec2<f32>(texel * 0.4, -texel), sp.z - bias);
        let solid_lit = (s0 + s1 + s2 + s3 + s4) * 0.2;

        let trans_lit = textureSampleCompareLevel(shadow_map_translucent, shadow_sampler, sp.xy, sp.z - bias);
        let sc_dim = vec2<f32>(textureDimensions(shadow_color));
        let sc_texel = vec2<i32>(clamp(sp.xy * sc_dim, vec2<f32>(0.0), sc_dim - 1.0));
        let stained = textureLoad(shadow_color, sc_texel, 0).rgb;

        let facing = clamp(ndotl * 2.2, 0.0, 1.0);
        let sun_vis = solid_lit * facing;
        let outdoor = smoothstep(0.25, 0.90, input.light.y) * (1.0 - frame.rain * 0.65);

        let shade_factor = mix(1.0, mix(1.0 - shadow_strength, 1.12, sun_vis), outdoor);
        let tint_factor = mix(vec3<f32>(1.0), stained, clamp((solid_lit - trans_lit) * outdoor, 0.0, 0.85));
        lit = lit * shade_factor * tint_factor;
    }

    return Surface(vec4<f32>(lit, input.albedo.a * input.tint.a));
}
"""
    },
)

# 6. Horizon Ultra
add_shader(
    "horizon-ultra",
    "horizon_ultra",
    "Horizon Ultra",
    "Флагманский комбо-шейдер: мягкие тени, зеркальная вода, цветной 3D-свет, атмосферное небо, Bloom и Motion Blur.",
    """
[[options]]
id = "shadow_quality"
name = "Shadow Strength"
description = "Intensity of sun and moon shadows."
type = "float"
default = 0.52
min = 0.0
max = 0.85
step = 0.05

[[options]]
id = "motion_blur_amount"
name = "Motion Blur"
description = "Camera motion blur strength (set 0 to disable)."
type = "float"
default = 0.35
min = 0.0
max = 1.0
step = 0.05

[[options]]
id = "bloom_amount"
name = "Bloom Glow"
description = "Soft highlight glow intensity."
type = "float"
default = 0.30
min = 0.0
max = 0.80
step = 0.05

[shadow]
resolution = 1536
distance = 88.0

[reflection]

[[lights]]
color = [1.75, 1.02, 0.42]
blocks = ["minecraft:torch", "minecraft:wall_torch", "minecraft:lantern", "minecraft:campfire", "minecraft:shroomlight"]

[[lights]]
color = [0.38, 1.45, 1.85]
blocks = ["minecraft:soul_torch", "minecraft:soul_wall_torch", "minecraft:soul_lantern", "minecraft:soul_campfire"]

[[lights]]
color = [1.90, 0.62, 0.16]
blocks = ["minecraft:lava", "minecraft:flowing_lava", "minecraft:fire", "minecraft:magma_block"]

[[lights]]
color = [0.55, 1.65, 1.50]
blocks = ["minecraft:sea_lantern", "minecraft:conduit", "minecraft:glowstone"]

[sky]
file = "sky.wgsl"

[material]
file = "material.wgsl"

[[post]]
file = "post.wgsl"
""",
    {
        "sky.wgsl": """
fn sky(input: SkyInput) -> vec4<f32> {
    let h = clamp(input.direction.y, 0.0, 1.0);
    let sun_glow = pow(max(dot(input.direction, frame.sun_direction), 0.0), 10.0);
    var col = input.color.rgb * mix(vec3<f32>(1.06, 1.01, 0.96), vec3<f32>(0.86, 0.96, 1.14), h);
    col = col + vec3<f32>(1.0, 0.76, 0.46) * sun_glow * 0.28 * clamp(frame.sun_direction.y + 0.25, 0.0, 1.0);
    return vec4<f32>(col, 1.0);
}
""",
        "material.wgsl": """
override shadow_quality: f32 = 0.52;

fn material(input: MaterialInput) -> Surface {
    var lit = input.albedo.rgb * input.tint.rgb * input.lightmap;
    var alpha = input.albedo.a * input.tint.a;

    // 3D colored block light
    let bl = block_light_color(input.position);
    lit = lit + input.albedo.rgb * input.tint.rgb * bl.rgb * bl.a * 0.32 + input.albedo.rgb * input.emission * 0.25;

    // Soft PCF shadows
    if (frame.has_shadow == 1u && shadow_quality > 0.01 && input.emission < 0.25) {
        let sp = shadow_position(input.position + input.normal * 0.04);
        let bias = frame.shadow_center_texel * 0.015 + 0.0008;
        let texel = 1.15 / max(frame.shadow_resolution, 512.0);
        let s0 = textureSampleCompareLevel(shadow_map, shadow_sampler, sp.xy, sp.z - bias);
        let s1 = textureSampleCompareLevel(shadow_map, shadow_sampler, sp.xy + vec2<f32>(texel, 0.0), sp.z - bias);
        let s2 = textureSampleCompareLevel(shadow_map, shadow_sampler, sp.xy - vec2<f32>(texel, 0.0), sp.z - bias);
        let s3 = textureSampleCompareLevel(shadow_map, shadow_sampler, sp.xy + vec2<f32>(0.0, texel), sp.z - bias);
        let s4 = textureSampleCompareLevel(shadow_map, shadow_sampler, sp.xy - vec2<f32>(0.0, texel), sp.z - bias);
        let vis = ((s0 + s1 + s2 + s3 + s4) * 0.2) * clamp(dot(input.normal, frame.light_direction) * 2.2, 0.0, 1.0);
        let outdoor = smoothstep(0.25, 0.90, input.light.y) * (1.0 - frame.rain * 0.65);
        lit = lit * mix(1.0, mix(1.0 - shadow_quality, 1.14, vis), outdoor);
    }

    // Water reflections + waves
    if (input.fluid == 1u) {
        let wxz = input.position.xz + frame.camera_position.xz;
        let t = frame.time * 2.0;
        let r = vec2<f32>(sin(wxz.x * 2.0 + t), cos(wxz.y * 1.7 - t * 0.9)) * 0.008;
        let vdir = normalize(-input.position);
        let n = normalize(vec3<f32>(r.x * 5.0, 1.0, r.y * 5.0));
        let fresnel = clamp(0.10 + 0.90 * pow(1.0 - max(dot(vdir, n), 0.0), 4.0), 0.0, 1.0);
        if (frame.has_reflection == 1u) {
            let ruv = clamp(input.screen + r, vec2<f32>(0.002), vec2<f32>(0.998));
            let refl = textureSampleLevel(reflection, reflection_sampler, ruv, 0.0).rgb;
            lit = mix(lit * vec3<f32>(0.75, 0.95, 1.05), refl, fresnel * 0.72);
        }
        alpha = clamp(mix(0.65, 0.92, fresnel), 0.5, 0.95);
    }

    return Surface(vec4<f32>(lit, alpha));
}
""",
        "post.wgsl": """
override motion_blur_amount: f32 = 0.35;
override bloom_amount: f32 = 0.30;

fn aces(x: vec3<f32>) -> vec3<f32> {
    return clamp((x * (2.51 * x + 0.03)) / (x * (2.43 * x + 0.59) + 0.14), vec3<f32>(0.0), vec3<f32>(1.0));
}

fn post(input: PostInput) -> vec4<f32> {
    let uv = input.uv;
    var base = input.color.rgb;

    // Optional camera motion blur
    if (motion_blur_amount > 0.01 && frame.delta_time > 0.0001 && input.depth > 0.00001) {
        let wp = view_position(uv, input.depth);
        let pclip = frame.previous_view_projection * vec4<f32>(wp + frame.camera_motion, 1.0);
        if (pclip.w > 0.0001) {
            let pndc = pclip.xy / pclip.w;
            let puv = vec2<f32>(pndc.x * 0.5 + 0.5, 0.5 - pndc.y * 0.5);
            let dt_s = clamp(0.01667 / max(frame.delta_time, 0.002), 0.35, 2.2);
            var vel = (uv - puv) * motion_blur_amount * dt_s;
            let sp = length(vel);
            if (sp > 0.05) { vel = vel * (0.05 / sp); }
            if (sp > 0.0006) {
                var acc = vec3<f32>(0.0);
                for (var i: i32 = 0; i < 6; i = i + 1) {
                    let t = (f32(i) + 0.5) / 6.0 - 0.5;
                    let suv = clamp(uv + vel * t, vec2<f32>(0.001), vec2<f32>(0.999));
                    acc = acc + textureSampleLevel(previous, linear_sampler, suv, 0.0).rgb;
                }
                base = acc / 6.0;
            }
        }
    }

    // Soft 8-tap highlight bloom
    if (bloom_amount > 0.01) {
        let px = 1.0 / max(frame.resolution, vec2<f32>(320.0));
        var glow = vec3<f32>(0.0);
        for (var k: i32 = 0; k < 8; k = k + 1) {
            let ang = f32(k) * 0.785398;
            let rad = (3.5 + f32(k % 2) * 5.5);
            let off = vec2<f32>(cos(ang), sin(ang)) * px * rad;
            let s = textureSampleLevel(previous, linear_sampler, clamp(uv + off, vec2<f32>(0.001), vec2<f32>(0.999)), 0.0).rgb;
            let br = max(max(s.r, max(s.g, s.b)) - 0.72, 0.0);
            glow = glow + s * br;
        }
        base = base + (glow * 0.22) * bloom_amount;
    }

    let graded = mix(base, aces(base * 1.08), 0.35);
    return vec4<f32>(graded, input.color.a);
}
""",
    },
)

# 7. FPS Sharpness (AMD CAS)
add_shader(
    "fps-sharpness",
    "fps_sharpness",
    "FPS Sharpness (CAS)",
    "Адаптивная чёткость AMD CAS — убирает «мыло» с текстур вдали без ореолов и практически с 0% нагрузки на видеокарту.",
    """
[[options]]
id = "sharpness"
name = "Sharpness Strength"
description = "Contrast-adaptive sharpening intensity."
type = "float"
default = 0.70
min = 0.10
max = 1.25
step = 0.05

[[post]]
file = "post.wgsl"
""",
    {
        "post.wgsl": """
override sharpness: f32 = 0.70;

fn post(input: PostInput) -> vec4<f32> {
    let px = 1.0 / max(frame.resolution, vec2<f32>(320.0));
    let uv = input.uv;
    let c = input.color.rgb;
    let n = textureSampleLevel(previous, linear_sampler, clamp(uv + vec2<f32>(0.0, -px.y), vec2<f32>(0.0), vec2<f32>(1.0)), 0.0).rgb;
    let s = textureSampleLevel(previous, linear_sampler, clamp(uv + vec2<f32>(0.0, px.y), vec2<f32>(0.0), vec2<f32>(1.0)), 0.0).rgb;
    let w = textureSampleLevel(previous, linear_sampler, clamp(uv + vec2<f32>(-px.x, 0.0), vec2<f32>(0.0), vec2<f32>(1.0)), 0.0).rgb;
    let e = textureSampleLevel(previous, linear_sampler, clamp(uv + vec2<f32>(px.x, 0.0), vec2<f32>(0.0), vec2<f32>(1.0)), 0.0).rgb;

    let min_rgb = min(c, min(min(n, s), min(w, e)));
    let max_rgb = max(c, max(max(n, s), max(w, e)));
    let amp = sqrt(clamp(min(min_rgb, 1.0 - max_rgb) / max(max_rgb, vec3<f32>(0.0001)), vec3<f32>(0.0), vec3<f32>(1.0)));
    let weight = -amp * (0.125 + 0.10 * sharpness);

    let out_col = clamp((c + (n + s + w + e) * weight) / (1.0 + 4.0 * weight), vec3<f32>(0.0), vec3<f32>(1.0));
    return vec4<f32>(out_col, input.color.a);
}
"""
    },
)

# 8. Crystal Underwater
add_shader(
    "crystal-underwater",
    "crystal_underwater",
    "Crystal Underwater",
    "Кристально чистая видимость под водой без мутного тумана + красивые солнечные каустики на морском дне.",
    """
[[options]]
id = "underwater_brightness"
name = "Underwater Brightness"
description = "Extra visibility boost while submerged."
type = "float"
default = 0.75
min = 0.2
max = 1.2
step = 0.05

[[options]]
id = "caustics"
name = "Seafloor Caustics"
description = "Animated water light ripples underwater."
type = "bool"
default = true

[material]
file = "material.wgsl"
fog = false
""",
    {
        "material.wgsl": """
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
"""
    },
)

# 9. Clear Nether & End
add_shader(
    "clear-nether-end",
    "clear_nether_end",
    "Clear Nether & End",
    "Полностью убирает густой туман в Незере и Энде и слегка подсвечивает тёмные своды для отличного обзора.",
    """
[[options]]
id = "nether_lift"
name = "Nether & End Lift"
description = "Gentle brightness lift in the Nether and End."
type = "float"
default = 0.45
min = 0.0
max = 1.0
step = 0.05

[material]
file = "material.wgsl"
fog = false
""",
    {
        "material.wgsl": """
override nether_lift: f32 = 0.45;

fn material(input: MaterialInput) -> Surface {
    var lm = input.lightmap;
    if (frame.dimension == -1) {
        lm = max(lm, vec3<f32>(0.42, 0.34, 0.32) * nether_lift + lm * 0.85);
    } else if (frame.dimension == 1) {
        lm = max(lm, vec3<f32>(0.40, 0.38, 0.48) * nether_lift + lm * 0.85);
    }
    let lit = input.albedo.rgb * input.tint.rgb * lm;
    return Surface(vec4<f32>(lit, input.albedo.a * input.tint.a));
}
"""
    },
)

# 10. Aurora & Starry Sky
add_shader(
    "aurora-starry-sky",
    "aurora_starry_sky",
    "Aurora & Starry Sky",
    "Переливающееся северное сияние и яркая россыпь звёзд с Млечным Путём на ночном небе.",
    """
[[options]]
id = "aurora_intensity"
name = "Aurora Brightness"
description = "Brightness of the northern lights at night."
type = "float"
default = 0.85
min = 0.1
max = 1.6
step = 0.05

[[options]]
id = "star_density"
name = "Star Brightness"
description = "Intensity of night stars and Milky Way glow."
type = "float"
default = 0.90
min = 0.0
max = 1.6
step = 0.05

[sky]
file = "sky.wgsl"
""",
    {
        "sky.wgsl": """
override aurora_intensity: f32 = 0.85;
override star_density: f32 = 0.90;

fn hash3(p: vec3<f32>) -> f32 {
    let q = fract(p * vec3<f32>(443.897, 441.423, 437.195));
    let r = q + dot(q, q.yzx + 19.19);
    return fract((r.x + r.y) * r.z);
}

fn sky(input: SkyInput) -> vec4<f32> {
    let d = normalize(input.direction);
    var col = input.color.rgb;

    // Night factor based on sun elevation
    let night = smoothstep(0.08, -0.18, frame.sun_direction.y) * (1.0 - frame.rain * 0.85);
    if (night > 0.01 && d.y > 0.02) {
        // Twinkling procedural stars
        let cell = floor(d * 260.0);
        let h = hash3(cell);
        if (h > 0.992) {
            let twinkle = 0.65 + 0.35 * sin(frame.time * 3.5 + h * 90.0);
            let star_col = mix(vec3<f32>(0.75, 0.86, 1.0), vec3<f32>(1.0, 0.92, 0.80), fract(h * 17.3));
            col = col + star_col * ((h - 0.992) * 125.0) * twinkle * star_density * night * smoothstep(0.02, 0.25, d.y);
        }

        // Aurora curtains
        let uv = d.xz / (d.y + 0.22);
        let t = frame.time * 0.28;
        let wave1 = sin(uv.x * 1.8 + sin(uv.y * 1.3 + t) * 1.6 + t);
        let wave2 = sin(uv.y * 2.4 - uv.x * 1.1 - t * 1.3);
        let ribbon = pow(clamp(1.0 - abs(wave1 * 0.65 + wave2 * 0.35), 0.0, 1.0), 5.0);
        let fade = smoothstep(0.03, 0.28, d.y) * smoothstep(0.98, 0.35, d.y);
        let a_col = mix(vec3<f32>(0.10, 0.95, 0.58), vec3<f32>(0.52, 0.28, 0.98), clamp(wave2 * 0.5 + 0.5, 0.0, 1.0));
        col = col + a_col * ribbon * fade * aurora_intensity * night * 0.65;
    }

    return vec4<f32>(col, 1.0);
}
"""
    },
)

# 11. Golden Sunset
add_shader(
    "golden-sunset",
    "golden_sunset",
    "Golden Sunset",
    "Тёплая кинематографическая атмосфера золотого часа, янтарное свечение солнца, мягкая виньетка и плёночный тон.",
    """
[[options]]
id = "warmth"
name = "Golden Warmth"
description = "Intensity of warm golden-hour color grading."
type = "float"
default = 0.65
min = 0.1
max = 1.2
step = 0.05

[[options]]
id = "vignette"
name = "Cinema Vignette"
description = "Subtle darkening at screen corners."
type = "float"
default = 0.28
min = 0.0
max = 0.7
step = 0.05

[sky]
file = "sky.wgsl"

[[post]]
file = "post.wgsl"
""",
    {
        "sky.wgsl": """
override warmth: f32 = 0.65;

fn sky(input: SkyInput) -> vec4<f32> {
    let d = normalize(input.direction);
    let horizon = pow(1.0 - clamp(abs(d.y), 0.0, 1.0), 3.0);
    let sun_glow = pow(max(dot(d, frame.sun_direction), 0.0), 6.0);
    var col = mix(input.color.rgb, input.color.rgb * vec3<f32>(1.18, 0.94, 0.78) + vec3<f32>(0.24, 0.10, 0.03) * horizon, warmth * 0.55);
    col = col + vec3<f32>(1.0, 0.58, 0.22) * sun_glow * 0.35 * warmth;
    return vec4<f32>(col, 1.0);
}
""",
        "post.wgsl": """
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
""",
    },
)

# 12. Cinematic Bloom
add_shader(
    "cinematic-bloom",
    "cinematic_bloom",
    "Cinematic Bloom",
    "Мягкое кинематографическое свечение ярких источников света — факелов, лавы, порталов, маяков и солнца.",
    """
[[options]]
id = "bloom_strength"
name = "Bloom Intensity"
description = "How strongly bright objects glow."
type = "float"
default = 0.55
min = 0.10
max = 1.40
step = 0.05

[[options]]
id = "bloom_threshold"
name = "Brightness Threshold"
description = "Minimum pixel brightness that triggers bloom."
type = "float"
default = 0.68
min = 0.35
max = 0.95
step = 0.05

[[post]]
file = "post.wgsl"
""",
    {
        "post.wgsl": """
override bloom_strength: f32 = 0.55;
override bloom_threshold: f32 = 0.68;

fn post(input: PostInput) -> vec4<f32> {
    let uv = input.uv;
    let px = 1.0 / max(frame.resolution, vec2<f32>(320.0));
    var glow = vec3<f32>(0.0);
    var wsum = 0.0;

    // 12-tap golden-angle spiral multi-radius halo
    for (var i: i32 = 0; i < 12; i = i + 1) {
        let fi = f32(i);
        let ang = fi * 2.3999632;
        let rad = 2.0 + fi * 2.1;
        let off = vec2<f32>(cos(ang), sin(ang)) * px * rad;
        let suv = clamp(uv + off, vec2<f32>(0.001), vec2<f32>(0.999));
        let s = textureSampleLevel(previous, linear_sampler, suv, 0.0).rgb;
        let peak = max(s.r, max(s.g, s.b));
        let knee = smoothstep(bloom_threshold - 0.12, bloom_threshold + 0.25, peak);
        let w = 1.0 / (1.0 + fi * 0.22);
        glow = glow + s * knee * w;
        wsum = wsum + w;
    }

    let bloom = (glow / max(wsum, 0.001)) * bloom_strength;
    let out_col = 1.0 - (1.0 - clamp(input.color.rgb, vec3<f32>(0.0), vec3<f32>(1.0))) * (1.0 - clamp(bloom, vec3<f32>(0.0), vec3<f32>(0.95)));
    return vec4<f32>(out_col, input.color.a);
}
"""
    },
)

# 13. Anime Cel-Shading
add_shader(
    "anime-cel-shading",
    "anime_cel_shading",
    "Anime Cel-Shading",
    "Мультяшный стиль в духе аниме и Borderlands: чёткая контурная обводка граней по глубине и ступенчатый свет.",
    """
[[options]]
id = "outline_strength"
name = "Ink Outline Strength"
description = "Darkness of edge outlines around blocks and mobs."
type = "float"
default = 0.75
min = 0.0
max = 1.0
step = 0.05

[[options]]
id = "cel_bands"
name = "Toon Light Bands"
description = "Number of quantized shading steps."
type = "int"
default = 4
min = 2
max = 8

[material]
file = "material.wgsl"

[[post]]
file = "post.wgsl"
""",
    {
        "material.wgsl": """
override cel_bands: i32 = 4;

fn material(input: MaterialInput) -> Surface {
    let bands = f32(max(cel_bands, 2));
    let luma = max(input.lightmap.r, max(input.lightmap.g, input.lightmap.b));
    let quant = floor(luma * bands + 0.35) / bands;
    let ratio = clamp(quant / max(luma, 0.001), 0.55, 1.35);
    let lit = input.albedo.rgb * input.tint.rgb * (input.lightmap * ratio) * 1.06;
    return Surface(vec4<f32>(lit, input.albedo.a * input.tint.a));
}
""",
        "post.wgsl": """
override outline_strength: f32 = 0.75;

fn lin_depth(uv: vec2<f32>) -> f32 {
    let d = depth_at(uv);
    if (d <= 0.00001) { return 1000.0; }
    return length(view_position(uv, d));
}

fn post(input: PostInput) -> vec4<f32> {
    var col = input.color.rgb;
    if (input.depth > 0.00001 && outline_strength > 0.01) {
        let px = 1.0 / max(frame.resolution, vec2<f32>(320.0));
        let dc = lin_depth(input.uv);
        let dn = lin_depth(clamp(input.uv + vec2<f32>(0.0, -px.y), vec2<f32>(0.0), vec2<f32>(1.0)));
        let ds = lin_depth(clamp(input.uv + vec2<f32>(0.0, px.y), vec2<f32>(0.0), vec2<f32>(1.0)));
        let dw = lin_depth(clamp(input.uv + vec2<f32>(-px.x, 0.0), vec2<f32>(0.0), vec2<f32>(1.0)));
        let de = lin_depth(clamp(input.uv + vec2<f32>(px.x, 0.0), vec2<f32>(0.0), vec2<f32>(1.0)));

        let edge = (abs(dn - dc) + abs(ds - dc) + abs(dw - dc) + abs(de - dc)) / max(dc * 0.35, 0.15);
        let ink = smoothstep(0.32, 0.85, edge) * outline_strength;
        col = mix(col, col * 0.12, ink);
    }
    return vec4<f32>(col, input.color.a);
}
""",
    },
)

# 14. Retro PS1 / CRT
add_shader(
    "retro-ps1-crt",
    "retro_ps1_crt",
    "Retro PS1 / CRT",
    "Атмосфера консолей 90-х: пикселизация, дизеринг палитры 15-bit и мягкие CRT-сканлайны кинескопа.",
    """
[[options]]
id = "pixel_size"
name = "Pixel Scale"
description = "Retro pixel blockiness (1 = native resolution, 3 = classic PS1)."
type = "int"
default = 2
min = 1
max = 6

[[options]]
id = "scanlines"
name = "CRT Scanlines"
description = "Strength of horizontal CRT scanlines."
type = "float"
default = 0.25
min = 0.0
max = 0.70
step = 0.05

[[post]]
file = "post.wgsl"
""",
    {
        "post.wgsl": """
override pixel_size: i32 = 2;
override scanlines: f32 = 0.25;

fn bayer2(p: vec2<f32>) -> f32 {
    let x = i32(p.x) & 1;
    let y = i32(p.y) & 1;
    let idx = x + y * 2;
    if (idx == 0) { return -0.375; }
    if (idx == 1) { return 0.125; }
    if (idx == 2) { return 0.375; }
    return -0.125;
}

fn post(input: PostInput) -> vec4<f32> {
    let scale = f32(max(pixel_size, 1));
    let grid = max(floor(frame.resolution / scale), vec2<f32>(160.0));
    let puv = (floor(input.uv * grid) + 0.5) / grid;
    var col = textureSampleLevel(previous, nearest_sampler, clamp(puv, vec2<f32>(0.001), vec2<f32>(0.999)), 0.0).rgb;

    // 5-bit per channel PS1 color quantization with ordered dithering
    let dither = bayer2(floor(input.pixel / scale)) / 31.0;
    col = floor(clamp(col + dither, vec3<f32>(0.0), vec3<f32>(1.0)) * 31.0 + 0.5) / 31.0;

    // CRT scanlines
    let line = 0.5 + 0.5 * sin(input.pixel.y * 3.14159265);
    col = col * (1.0 - scanlines * line * 0.45);
    return vec4<f32>(col, input.color.a);
}
"""
    },
)

# 15. Horror Fog
add_shader(
    "horror-fog",
    "horror_fog",
    "Horror Fog",
    "Густой холодный туман как в Silent Hill, приглушённые мрачные тона, плёночное зерно и плотная виньетка.",
    """
[[options]]
id = "fog_density"
name = "Fog Density"
description = "How close the eerie fog closes in."
type = "float"
default = 0.045
min = 0.015
max = 0.12
step = 0.005

[[options]]
id = "desaturation"
name = "Bleakness"
description = "Color desaturation for a cold horror atmosphere."
type = "float"
default = 0.55
min = 0.0
max = 0.90
step = 0.05

[sky]
file = "sky.wgsl"

[[post]]
file = "post.wgsl"
""",
    {
        "sky.wgsl": """
fn sky(input: SkyInput) -> vec4<f32> {
    let luma = dot(input.color.rgb, vec3<f32>(0.299, 0.587, 0.114));
    let eerie = vec3<f32>(0.36, 0.40, 0.43) * (0.25 + luma * 0.55);
    return vec4<f32>(eerie, 1.0);
}
""",
        "post.wgsl": """
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
""",
    },
)

# 16. Cyberpunk Neon
add_shader(
    "cyberpunk-neon",
    "cyberpunk_neon",
    "Cyberpunk Neon",
    "Неоновый киберпанк-стиль: бирюзово-пурпурное освещение, яркие светящиеся блоки и лёгкая хроматическая аберрация.",
    """
[[options]]
id = "neon_intensity"
name = "Neon Intensity"
description = "Strength of cyberpunk color grading and glow."
type = "float"
default = 0.70
min = 0.15
max = 1.25
step = 0.05

[[options]]
id = "chroma_shift"
name = "Chromatic Fringe"
description = "Subtle neon lens RGB edge shift."
type = "float"
default = 0.35
min = 0.0
max = 1.0
step = 0.05

[[lights]]
color = [2.0, 0.25, 1.45]
blocks = ["minecraft:torch", "minecraft:wall_torch", "minecraft:lantern", "minecraft:redstone_torch", "minecraft:crying_obsidian", "minecraft:nether_portal"]

[[lights]]
color = [0.20, 1.85, 2.0]
blocks = ["minecraft:soul_torch", "minecraft:soul_lantern", "minecraft:sea_lantern", "minecraft:glowstone", "minecraft:end_rod", "minecraft:beacon"]

[material]
file = "material.wgsl"

[[post]]
file = "post.wgsl"
""",
    {
        "material.wgsl": """
override neon_intensity: f32 = 0.70;

fn material(input: MaterialInput) -> Surface {
    var lit = input.albedo.rgb * input.tint.rgb * input.lightmap;
    let bl = block_light_color(input.position);
    lit = lit + input.albedo.rgb * bl.rgb * bl.a * 0.45 * neon_intensity;
    lit = lit + input.albedo.rgb * vec3<f32>(1.25, 0.75, 1.45) * input.emission * 0.45 * neon_intensity;
    return Surface(vec4<f32>(lit, input.albedo.a * input.tint.a));
}
""",
        "post.wgsl": """
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
""",
    },
)

# 17 (#31). No Fog
add_shader(
    "no-fog",
    "no_fog",
    "No Fog",
    "Полностью отключает любой туман в Обычном мире, Незере, Энде, под водой и в дождь для 100% видимости вдаль.",
    """
[[options]]
id = "clarity_boost"
name = "Distant Contrast"
description = "Slight contrast boost for faraway terrain."
type = "float"
default = 0.10
min = 0.0
max = 0.50
step = 0.05

[material]
file = "material.wgsl"
fog = false
""",
    {
        "material.wgsl": """
override clarity_boost: f32 = 0.10;

fn material(input: MaterialInput) -> Surface {
    var lit = input.albedo.rgb * input.tint.rgb * input.lightmap;
    lit = clamp((lit - 0.5) * (1.0 + clarity_boost) + 0.5, vec3<f32>(0.0), vec3<f32>(1.5));
    return Surface(vec4<f32>(lit, input.albedo.a * input.tint.a));
}
"""
    },
)

# 18 (#32). True Darkness
add_shader(
    "true-darkness",
    "true_darkness",
    "True Darkness",
    "Хардкорная реалистичная темнота в пещерах и безлунной ночью — без факела в шахте действительно ничего не видно.",
    """
[[options]]
id = "cave_floor"
name = "Minimum Cave Light"
description = "0.0 = pitch black caves, higher leaves faint silhouette visibility."
type = "float"
default = 0.01
min = 0.0
max = 0.10
step = 0.01

[[options]]
id = "dark_nights"
name = "Dark Moonless Nights"
description = "Also darken the outdoor world at night."
type = "bool"
default = true

[sky]
file = "sky.wgsl"

[material]
file = "material.wgsl"
""",
    {
        "sky.wgsl": """
override dark_nights: bool = true;

fn sky(input: SkyInput) -> vec4<f32> {
    let night = smoothstep(0.05, -0.18, frame.sun_direction.y);
    let factor = select(1.0, mix(1.0, 0.18, night), dark_nights);
    return vec4<f32>(input.color.rgb * factor, 1.0);
}
""",
        "material.wgsl": """
override cave_floor: f32 = 0.01;
override dark_nights: bool = true;

fn material(input: MaterialInput) -> Surface {
    let night = smoothstep(0.05, -0.18, frame.sun_direction.y);
    let sky_eff = input.light.y * select(1.0, mix(1.0, 0.16, night), dark_nights);
    let total_light = max(input.light.x, sky_eff);
    let curve = clamp(pow(total_light, 2.2), cave_floor, 1.0);
    let lit = input.albedo.rgb * input.tint.rgb * input.lightmap * curve + input.albedo.rgb * input.emission * 0.65;
    return Surface(vec4<f32>(lit, input.albedo.a * input.tint.a));
}
""",
    },
)

# 19 (#33). Warm Cozy Torchlight
add_shader(
    "warm-torchlight",
    "warm_torchlight",
    "Warm Cozy Torchlight",
    "Уютный тёплый янтарный свет от факелов, костров и фонарей с мягким живым мерцанием пламени.",
    """
[[options]]
id = "torch_warmth"
name = "Amber Warmth"
description = "How warm and golden indoor torchlight appears."
type = "float"
default = 0.75
min = 0.15
max = 1.30
step = 0.05

[[options]]
id = "flicker_amount"
name = "Flame Flicker"
description = "Subtle organic flame flicker on block light."
type = "float"
default = 0.08
min = 0.0
max = 0.25
step = 0.01

[material]
file = "material.wgsl"
""",
    {
        "material.wgsl": """
override torch_warmth: f32 = 0.75;
override flicker_amount: f32 = 0.08;

fn material(input: MaterialInput) -> Surface {
    let t = frame.time;
    let flicker = 1.0 + (sin(t * 7.3) * 0.5 + sin(t * 13.7 + 1.4) * 0.3 + cos(t * 21.1) * 0.2) * flicker_amount * input.light.x;
    let indoor = clamp(input.light.x * (1.0 - input.light.y * 0.55), 0.0, 1.0);
    let warm_tint = mix(vec3<f32>(1.0), vec3<f32>(1.32, 0.96, 0.62) * flicker, indoor * torch_warmth);
    let lit = input.albedo.rgb * input.tint.rgb * input.lightmap * warm_tint;
    return Surface(vec4<f32>(lit, input.albedo.a * input.tint.a));
}
"""
    },
)

# 20 (#34). Noir Black & White
add_shader(
    "noir-bw",
    "noir_bw",
    "Noir Black & White",
    "Контрастный чёрно-белый фильтр в стиле классического нуар-кино с опцией сохранения ярко-красных акцентов (Sin City).",
    """
[[options]]
id = "contrast"
name = "Noir Contrast"
description = "Strength of black-and-white S-curve contrast."
type = "float"
default = 1.25
min = 0.85
max = 1.80
step = 0.05

[[options]]
id = "keep_reds"
name = "Sin City Red Accents"
description = "Keep crimson/red objects vivid against monochrome."
type = "bool"
default = true

[[post]]
file = "post.wgsl"
""",
    {
        "post.wgsl": """
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
"""
    },
)

# 21 (#35). Pastel Dream
add_shader(
    "pastel-dream",
    "pastel_dream",
    "Pastel Dream",
    "Мягкая сказочная пастельная цветовая гамма, осветлённые кремовые тени и нежное розово-лавандовое небо.",
    """
[[options]]
id = "pastel_mix"
name = "Pastel Softness"
description = "Strength of dreamy pastel tone mapping."
type = "float"
default = 0.70
min = 0.20
max = 1.0
step = 0.05

[sky]
file = "sky.wgsl"

[[post]]
file = "post.wgsl"
""",
    {
        "sky.wgsl": """
override pastel_mix: f32 = 0.70;

fn sky(input: SkyInput) -> vec4<f32> {
    let h = clamp(input.direction.y, 0.0, 1.0);
    let dream = mix(vec3<f32>(0.98, 0.84, 0.90), vec3<f32>(0.76, 0.86, 0.99), h);
    let brightness = clamp(dot(input.color.rgb, vec3<f32>(0.333)) * 1.25 + 0.12, 0.18, 1.0);
    let col = mix(input.color.rgb, dream * brightness, pastel_mix * 0.65);
    return vec4<f32>(col, 1.0);
}
""",
        "post.wgsl": """
override pastel_mix: f32 = 0.70;

fn post(input: PostInput) -> vec4<f32> {
    let c = input.color.rgb;
    let luma = dot(c, vec3<f32>(0.2126, 0.7152, 0.0722));
    // Lift darks into creamy lavender-peach and soften harsh saturation
    let lifted = mix(c, vec3<f32>(luma), 0.22) * 0.86 + vec3<f32>(0.09, 0.075, 0.095);
    let out_col = mix(c, clamp(lifted, vec3<f32>(0.0), vec3<f32>(1.0)), pastel_mix);
    return vec4<f32>(out_col, input.color.a);
}
""",
    },
)

# 22 (#36). Night Vision & Thermal
add_shader(
    "night-vision-thermal",
    "night_vision_thermal",
    "Night Vision & Thermal",
    "Тактический ПНВ и тепловизор (переключается одной галочкой в настройках шейдера: зелёный ПНВ или ИК-спектр).",
    """
[[options]]
id = "thermal_mode"
name = "Thermal Spectrum Mode"
description = "Off = Tactical Green NVG, On = Thermal Heat Vision."
type = "bool"
default = false

[[options]]
id = "gain"
name = "Sensor Gain"
description = "Amplification in dark caves and at night."
type = "float"
default = 1.0
min = 0.5
max = 1.8
step = 0.05

[material]
file = "material.wgsl"

[[post]]
file = "post.wgsl"
""",
    {
        "material.wgsl": """
override gain: f32 = 1.0;

fn material(input: MaterialInput) -> Surface {
    let lifted = max(input.lightmap, vec3<f32>(0.65 * gain));
    let heat = input.emission * 0.65;
    let lit = input.albedo.rgb * input.tint.rgb * lifted + vec3<f32>(heat, heat * 0.6, 0.0);
    return Surface(vec4<f32>(lit, input.albedo.a * input.tint.a));
}
""",
        "post.wgsl": """
override thermal_mode: bool = false;

fn thermal_palette(t: f32) -> vec3<f32> {
    let x = clamp(t, 0.0, 1.0);
    let c0 = vec3<f32>(0.06, 0.02, 0.28);
    let c1 = vec3<f32>(0.58, 0.08, 0.55);
    let c2 = vec3<f32>(0.98, 0.48, 0.06);
    let c3 = vec3<f32>(1.00, 0.98, 0.82);
    if (x < 0.33) { return mix(c0, c1, x / 0.33); }
    if (x < 0.66) { return mix(c1, c2, (x - 0.33) / 0.33); }
    return mix(c2, c3, (x - 0.66) / 0.34);
}

fn post(input: PostInput) -> vec4<f32> {
    let c = input.color.rgb;
    let luma = clamp(dot(c, vec3<f32>(0.299, 0.587, 0.114)), 0.0, 1.0);
    let scan = 0.94 + 0.06 * sin(input.pixel.y * 2.4);
    var out_col: vec3<f32>;

    if (thermal_mode) {
        let heat = clamp(luma * 0.85 + max(c.r - c.b, 0.0) * 0.55, 0.0, 1.0);
        out_col = thermal_palette(heat) * scan;
    } else {
        let phosphor = pow(luma, 0.72);
        out_col = vec3<f32>(phosphor * 0.22, phosphor * 1.12, phosphor * 0.32) * scan;
    }

    let d = input.uv - vec2<f32>(0.5);
    out_col = out_col * clamp(1.0 - dot(d, d) * 0.95, 0.25, 1.0);
    return vec4<f32>(clamp(out_col, vec3<f32>(0.0), vec3<f32>(1.0)), input.color.a);
}
""",
    },
)

# 23 (#37). Depth of Field
add_shader(
    "depth-of-field",
    "depth_of_field",
    "Depth of Field",
    "Кинематографическое размытие фона (боке) с плавным автофокусом по центру прицела.",
    """
[[options]]
id = "aperture"
name = "Bokeh Blur Amount"
description = "Strength of out-of-focus background and foreground blur."
type = "float"
default = 0.55
min = 0.10
max = 1.25
step = 0.05

[[options]]
id = "focus_range"
name = "In-Focus Depth Range"
description = "How wide the sharp focal zone is."
type = "float"
default = 14.0
min = 3.0
max = 45.0
step = 1.0

[[post]]
file = "post.wgsl"
""",
    {
        "post.wgsl": """
override aperture: f32 = 0.55;
override focus_range: f32 = 14.0;

fn dist_at(uv: vec2<f32>) -> f32 {
    let d = depth_at(uv);
    if (d <= 0.00001) { return 250.0; }
    return length(view_position(uv, d));
}

fn post(input: PostInput) -> vec4<f32> {
    let focus_d = clamp(dist_at(vec2<f32>(0.5, 0.5)), 1.5, 120.0);
    let my_d = dist_at(input.uv);
    let coc = clamp((abs(my_d - focus_d) - focus_range * 0.35) / max(focus_range, 1.0), 0.0, 1.0) * aperture;

    if (coc < 0.02) {
        return input.color;
    }

    let px = 1.0 / max(frame.resolution, vec2<f32>(320.0));
    var acc = input.color.rgb;
    var wsum = 1.0;

    // 12-tap Vogel disk bokeh
    for (var i: i32 = 0; i < 12; i = i + 1) {
        let fi = f32(i);
        let r = sqrt((fi + 0.5) / 12.0) * coc * 10.0;
        let ang = fi * 2.3999632;
        let suv = clamp(input.uv + vec2<f32>(cos(ang), sin(ang)) * px * r, vec2<f32>(0.001), vec2<f32>(0.999));
        let s = textureSampleLevel(previous, linear_sampler, suv, 0.0).rgb;
        acc = acc + s;
        wsum = wsum + 1.0;
    }

    return vec4<f32>(acc / wsum, input.color.a);
}
"""
    },
)

# 24 (#38). Heat Haze
add_shader(
    "heat-haze",
    "heat_haze",
    "Heat Haze",
    "Реалистичное марево раскалённого воздуха в пустынях, саваннах, бесплодных землях и в Незере.",
    """
[[options]]
id = "haze_strength"
name = "Shimmer Strength"
description = "Intensity of distant heat distortion."
type = "float"
default = 0.65
min = 0.15
max = 1.50
step = 0.05

[[options]]
id = "always_on"
name = "Enable In All Biomes"
description = "Show subtle heat shimmer everywhere, not just hot biomes and Nether."
type = "bool"
default = false

[[post]]
file = "post.wgsl"
""",
    {
        "post.wgsl": """
override haze_strength: f32 = 0.65;
override always_on: bool = false;

fn post(input: PostInput) -> vec4<f32> {
    var biome_heat = smoothstep(0.95, 1.85, frame.temperature);
    if (frame.dimension == -1) { biome_heat = 1.0; }
    if (always_on) { biome_heat = max(biome_heat, 0.75); }
    biome_heat = biome_heat * (1.0 - frame.rain * 0.85);

    if (biome_heat < 0.02 || input.depth <= 0.00001) {
        return input.color;
    }

    let dist = length(view_position(input.uv, input.depth));
    let dist_mask = smoothstep(10.0, 48.0, dist);
    if (dist_mask < 0.01) {
        return input.color;
    }

    let t = frame.time * 3.4;
    let wave = vec2<f32>(
        sin(input.uv.y * 55.0 + t + input.uv.x * 18.0),
        cos(input.uv.x * 42.0 - t * 1.2 + input.uv.y * 24.0) * 0.5
    );
    let offset = wave * 0.0022 * haze_strength * biome_heat * dist_mask;
    let suv = clamp(input.uv + offset, vec2<f32>(0.001), vec2<f32>(0.999));

    // Only accept distorted sample if it is also distant (avoids foreground edge halos)
    let sd = depth_at(suv);
    if (sd > input.depth * 2.5 + 0.01) {
        return input.color;
    }

    let col = textureSampleLevel(previous, linear_sampler, suv, 0.0).rgb;
    return vec4<f32>(col, input.color.a);
}
"""
    },
)

# 25 (#39). Blood Moon
add_shader(
    "blood-moon",
    "blood_moon",
    "Blood Moon",
    "Багровое ночное небо, кроваво-красный ореол вокруг луны и зловещее алое освещение по ночам.",
    """
[[options]]
id = "crimson_strength"
name = "Crimson Intensity"
description = "How strongly the blood moon tints night sky and terrain."
type = "float"
default = 0.80
min = 0.20
max = 1.30
step = 0.05

[sky]
file = "sky.wgsl"

[material]
file = "material.wgsl"
""",
    {
        "sky.wgsl": """
override crimson_strength: f32 = 0.80;

fn sky(input: SkyInput) -> vec4<f32> {
    let d = normalize(input.direction);
    let night = smoothstep(0.06, -0.16, frame.sun_direction.y);
    let moon_glow = pow(max(dot(d, frame.moon_direction), 0.0), 12.0);
    let horizon = pow(1.0 - clamp(abs(d.y), 0.0, 1.0), 2.5);
    let blood_sky = vec3<f32>(0.22, 0.03, 0.05) * (0.45 + horizon * 0.85) + vec3<f32>(0.95, 0.14, 0.10) * moon_glow * 0.75;
    let col = mix(input.color.rgb, input.color.rgb * vec3<f32>(1.25, 0.45, 0.45) + blood_sky, night * crimson_strength);
    return vec4<f32>(col, 1.0);
}
""",
        "material.wgsl": """
override crimson_strength: f32 = 0.80;

fn material(input: MaterialInput) -> Surface {
    let night = smoothstep(0.06, -0.16, frame.sun_direction.y);
    let outdoor_night = night * smoothstep(0.2, 0.95, input.light.y) * (1.0 - input.light.x * 0.7);
    let blood_tint = mix(vec3<f32>(1.0), vec3<f32>(1.38, 0.62, 0.62), outdoor_night * crimson_strength);
    let lit = input.albedo.rgb * input.tint.rgb * input.lightmap * blood_tint;
    return Surface(vec4<f32>(lit, input.albedo.a * input.tint.a));
}
""",
    },
)

# 26 (#40). PvP Boost Minimal
add_shader(
    "pvp-boost-minimal",
    "pvp_boost_minimal",
    "PvP Boost Minimal",
    "Киберспортивный PvP-шейдер: мягкий Fullbright, чёткость CAS, отключённый туман и сочный контраст с нулевой потерей FPS.",
    """
[[options]]
id = "shadow_lift"
name = "Shadow Visibility"
description = "Minimum brightness so opponents never hide in dark corners."
type = "float"
default = 0.72
min = 0.30
max = 1.05
step = 0.05

[[options]]
id = "pvp_sharpness"
name = "Crisp Edges (CAS)"
description = "Adaptive sharpening for clean target tracking."
type = "float"
default = 0.55
min = 0.0
max = 1.0
step = 0.05

[material]
file = "material.wgsl"
fog = false

[[post]]
file = "post.wgsl"
""",
    {
        "material.wgsl": """
override shadow_lift: f32 = 0.72;

fn material(input: MaterialInput) -> Surface {
    let lm = max(input.lightmap, vec3<f32>(shadow_lift));
    let lit = input.albedo.rgb * input.tint.rgb * lm;
    return Surface(vec4<f32>(lit, input.albedo.a * input.tint.a));
}
""",
        "post.wgsl": """
override pvp_sharpness: f32 = 0.55;

fn post(input: PostInput) -> vec4<f32> {
    let px = 1.0 / max(frame.resolution, vec2<f32>(320.0));
    let uv = input.uv;
    let c = input.color.rgb;
    let n = textureSampleLevel(previous, linear_sampler, clamp(uv + vec2<f32>(0.0, -px.y), vec2<f32>(0.0), vec2<f32>(1.0)), 0.0).rgb;
    let s = textureSampleLevel(previous, linear_sampler, clamp(uv + vec2<f32>(0.0, px.y), vec2<f32>(0.0), vec2<f32>(1.0)), 0.0).rgb;
    let w = textureSampleLevel(previous, linear_sampler, clamp(uv + vec2<f32>(-px.x, 0.0), vec2<f32>(0.0), vec2<f32>(1.0)), 0.0).rgb;
    let e = textureSampleLevel(previous, linear_sampler, clamp(uv + vec2<f32>(px.x, 0.0), vec2<f32>(0.0), vec2<f32>(1.0)), 0.0).rgb;

    let min_rgb = min(c, min(min(n, s), min(w, e)));
    let max_rgb = max(c, max(max(n, s), max(w, e)));
    let amp = sqrt(clamp(min(min_rgb, 1.0 - max_rgb) / max(max_rgb, vec3<f32>(0.0001)), vec3<f32>(0.0), vec3<f32>(1.0)));
    let weight = -amp * (0.12 * pvp_sharpness);
    var col = clamp((c + (n + s + w + e) * weight) / (1.0 + 4.0 * weight), vec3<f32>(0.0), vec3<f32>(1.0));

    // Clean 12% saturation boost for instant item/armor recognition
    let luma = dot(col, vec3<f32>(0.2126, 0.7152, 0.0722));
    col = clamp(mix(vec3<f32>(luma), col, 1.14), vec3<f32>(0.0), vec3<f32>(1.0));
    return vec4<f32>(col, input.color.a);
}
""",
    },
)


def main() -> None:
    assert len(SHADERS) == 26, f"Expected 26 shaders, got {len(SHADERS)}"
    MODS_ROOT.mkdir(parents=True, exist_ok=True)
    for sh in SHADERS:
        sdir = SRC_ROOT / sh["id"]
        sdir.mkdir(parents=True, exist_ok=True)
        (sdir / "horizon-shaders.toml").write_text(sh["toml"], encoding="utf-8", newline="\n")
        for fname, content in sh["files"].items():
            (sdir / fname).write_text(content, encoding="utf-8", newline="\n")

        out_zip = MODS_ROOT / sh["file_name"]
        with zipfile.ZipFile(out_zip, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
            zf.writestr("horizon-shaders.toml", sh["toml"].encode("utf-8"))
            for fname, content in sh["files"].items():
                zf.writestr(fname, content.encode("utf-8"))
        print(f"[OK] Built {sh['file_name']} ({out_zip.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
