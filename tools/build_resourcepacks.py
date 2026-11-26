"""Builds all 24 client-side PvP & QoL resource packs (.zip) from authentic Minecraft 26.3 assets."""

import json
import os
from pathlib import Path
import shutil
import zipfile

from png_io import read_png_rgba, write_png_rgba

ROOT = Path(__file__).resolve().parent.parent
SRC_RP = ROOT / "src-resourcepacks"
MODS_ROOT = ROOT / "mods"

APPDATA = Path(os.environ["APPDATA"])
VANILLA_MC = (
    APPDATA
    / "horizon-offline-game"
    / "client"
    / "26.3"
    / ".local"
    / "horizon-client"
    / "26.3"
    / "assets"
    / "minecraft"
)

RESOURCEPACKS: list[dict] = []


def make_mcmeta(desc: str) -> str:
    return json.dumps(
        {
            "pack": {
                "description": desc,
                "pack_format": 55,
                "min_format": 15,
                "max_format": 999,
            }
        },
        ensure_ascii=False,
        indent=2,
    )


def copy_mcmeta_if_exists(vanilla_png: Path, out_png: Path) -> None:
    mc = Path(str(vanilla_png) + ".mcmeta")
    if mc.exists():
        out_png.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(mc, Path(str(out_png) + ".mcmeta"))


def save_edited_png(rel_path: str, out_root: Path, fn) -> None:
    src = VANILLA_MC / rel_path
    dst = out_root / "assets" / "minecraft" / rel_path
    w, h, rgba = read_png_rgba(src)
    res = fn(w, h, rgba)
    if res is not None:
        w, h, rgba = res
    write_png_rgba(dst, w, h, rgba)
    copy_mcmeta_if_exists(src, dst)


def register_rp(mod_id: str, name: str, ru_desc: str, builder) -> None:
    RESOURCEPACKS.append(
        {
            "id": mod_id,
            "name": name,
            "description": ru_desc,
            "file_name": f"{mod_id}.zip",
            "builder": builder,
        }
    )


# 17. Low Fire
def build_low_fire(out: Path) -> None:
    def lower_fire(w: int, h: int, px: bytearray):
        frames = max(1, h // w)
        for f in range(frames):
            y0 = f * w
            for y in range(w):
                for x in range(w):
                    i = ((y0 + y) * w + x) * 4
                    if y < 7:
                        px[i + 3] = 0
                    elif y < 10:
                        px[i + 3] = int(px[i + 3] * ((y - 6) / 4.0) * 0.85)
                    else:
                        px[i + 3] = int(px[i + 3] * 0.90)
        return w, h, px

    for f in ["fire_0.png", "fire_1.png", "soul_fire_0.png", "soul_fire_1.png"]:
        save_edited_png(f"textures/block/{f}", out, lower_fire)


register_rp(
    "low-fire",
    "Low Fire",
    "Опускает пламя огня вниз экрана при горении, чтобы оно не закрывало обзор в PvP и Незере.",
    build_low_fire,
)


# 18. No Pumpkin Blur
def build_no_pumpkin(out: Path) -> None:
    def clear_all(w: int, h: int, px: bytearray):
        for i in range(0, len(px), 4):
            px[i] = px[i + 1] = px[i + 2] = px[i + 3] = 0
        return w, h, px

    save_edited_png("textures/misc/pumpkinblur.png", out, clear_all)


register_rp(
    "no-pumpkin-blur",
    "No Pumpkin Blur",
    "Полностью убирает тёмную маску вырезанной тыквы с экрана для комфортных походов в Энд.",
    build_no_pumpkin,
)


# 19. Clear Spyglass
def build_clear_spyglass(out: Path) -> None:
    def thin_scope(w: int, h: int, px: bytearray):
        cx, cy = (w - 1) / 2.0, (h - 1) / 2.0
        rad = min(w, h) * 0.46
        for y in range(h):
            for x in range(w):
                i = (y * w + x) * 4
                dist = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
                if abs(dist - rad) <= 1.4:
                    px[i], px[i + 1], px[i + 2], px[i + 3] = 218, 175, 82, 165
                else:
                    px[i] = px[i + 1] = px[i + 2] = px[i + 3] = 0
        return w, h, px

    save_edited_png("textures/misc/spyglass_scope.png", out, thin_scope)


register_rp(
    "clear-spyglass",
    "Clear Spyglass",
    "Убирает чёрные поля подзорной трубы, оставляя полный широкоэкранный обзор при приближении.",
    build_clear_spyglass,
)


# 20. Outlined Ores
def build_outlined_ores(out: Path) -> None:
    ores = {
        "diamond_ore.png": (45, 238, 255),
        "deepslate_diamond_ore.png": (45, 238, 255),
        "emerald_ore.png": (36, 240, 108),
        "deepslate_emerald_ore.png": (36, 240, 108),
        "gold_ore.png": (255, 214, 48),
        "deepslate_gold_ore.png": (255, 214, 48),
        "nether_gold_ore.png": (255, 206, 42),
        "iron_ore.png": (238, 198, 168),
        "deepslate_iron_ore.png": (238, 198, 168),
        "copper_ore.png": (240, 132, 78),
        "deepslate_copper_ore.png": (240, 132, 78),
        "redstone_ore.png": (255, 42, 42),
        "deepslate_redstone_ore.png": (255, 42, 42),
        "lapis_ore.png": (58, 122, 255),
        "deepslate_lapis_ore.png": (58, 122, 255),
        "coal_ore.png": (92, 98, 108),
        "deepslate_coal_ore.png": (92, 98, 108),
        "nether_quartz_ore.png": (245, 238, 230),
        "ancient_debris_side.png": (214, 145, 96),
        "ancient_debris_top.png": (214, 145, 96),
    }
    for fname, (cr, cg, cb) in ores.items():
        def add_border(w: int, h: int, px: bytearray, r=cr, g=cg, b=cb):
            for y in range(h):
                for x in range(w):
                    on_edge = x == 0 or y == 0 or x == w - 1 or y == h - 1
                    corner_inner = (x in (1, w - 2)) and (y in (1, h - 2))
                    if on_edge or corner_inner:
                        i = (y * w + x) * 4
                        mix = 0.92 if on_edge else 0.55
                        px[i] = int(px[i] * (1.0 - mix) + r * mix)
                        px[i + 1] = int(px[i + 1] * (1.0 - mix) + g * mix)
                        px[i + 2] = int(px[i + 2] * (1.0 - mix) + b * mix)
                        px[i + 3] = 255
            return w, h, px

        save_edited_png(f"textures/block/{fname}", out, add_border)


register_rp(
    "outlined-ores",
    "Outlined Ores",
    "Яркая цветная окантовка всех руд и древних обломков — мгновенно заметны в шахтах и пещерах.",
    build_outlined_ores,
)


# 21. Clear Glass
def build_clear_glass(out: Path) -> None:
    colors = [
        "white", "orange", "magenta", "light_blue", "yellow", "lime", "pink", "gray",
        "light_gray", "cyan", "purple", "blue", "brown", "green", "red", "black",
    ]

    def clean_glass(w: int, h: int, px: bytearray):
        # Sample border color from (0, 0)
        br, bg, bb, ba = px[0], px[1], px[2], max(px[3], 170)
        for y in range(h):
            for x in range(w):
                i = (y * w + x) * 4
                if x == 0 or y == 0 or x == w - 1 or y == h - 1:
                    px[i], px[i + 1], px[i + 2], px[i + 3] = br, bg, bb, min(ba, 185)
                else:
                    # Keep subtle 8% tint on stained glass, 0% on plain glass
                    px[i + 3] = int(px[i + 3] * 0.14)
        return w, h, px

    save_edited_png("textures/block/glass.png", out, clean_glass)
    save_edited_png("textures/block/tinted_glass.png", out, clean_glass)
    for c in colors:
        save_edited_png(f"textures/block/{c}_stained_glass.png", out, clean_glass)


register_rp(
    "clear-glass",
    "Clear Glass",
    "Чистое прозрачное стекло и витражи с тонкой аккуратной рамкой без лишних бликов и полос.",
    build_clear_glass,
)


# 22. Short Swords
def build_short_swords(out: Path) -> None:
    swords = [
        "wooden_sword.png",
        "stone_sword.png",
        "copper_sword.png",
        "iron_sword.png",
        "golden_sword.png",
        "diamond_sword.png",
        "netherite_sword.png",
    ]

    def shorten(w: int, h: int, px: bytearray):
        # Vanilla 16x16 swords run from bottom-left hilt (x=0..6, y=9..15) to top-right tip (x=15, y=0).
        # Shift upper-right blade portion down-left by (dx=-3, dy=+3) so blade is compact & crisp!
        out_px = bytearray(len(px))
        # Keep hilt & guard region (x <= 7 and y >= 8) untouched
        for y in range(h):
            for x in range(w):
                if x <= 7 and y >= 8:
                    s = (y * w + x) * 4
                    out_px[s : s + 4] = px[s : s + 4]

        # Shift blade pixels (x >= 5 and y <= 10) by (-3, +3)
        for y in range(h):
            for x in range(w):
                if x >= 6 and y <= 9:
                    s = (y * w + x) * 4
                    if px[s + 3] > 0:
                        nx, ny = x - 3, y + 3
                        if 0 <= nx < w and 0 <= ny < h:
                            d = (ny * w + nx) * 4
                            if out_px[d + 3] == 0 or (nx >= 5 and ny <= 10):
                                out_px[d : d + 4] = px[s : s + 4]
        return w, h, out_px

    for sw in swords:
        save_edited_png(f"textures/item/{sw}", out, shorten)


register_rp(
    "short-swords",
    "Short Swords",
    "Укороченные мечи всех тиров (включая медный и незеритовый) для чистого обзора в PvP.",
    build_short_swords,
)


# 23. Low Shield
def build_low_shield(out: Path) -> None:
    for fname, dy_r, dy_l in [("shield.json", -5.5, -5.5), ("shield_blocking.json", -3.2, -3.2)]:
        data = json.loads((VANILLA_MC / "models" / "item" / fname).read_text(encoding="utf-8"))
        disp = data.setdefault("display", {})
        if "firstperson_righthand" in disp:
            t = list(disp["firstperson_righthand"]["translation"])
            t[1] = round(t[1] + dy_r, 2)
            disp["firstperson_righthand"]["translation"] = t
        if "firstperson_lefthand" in disp:
            t = list(disp["firstperson_lefthand"]["translation"])
            t[1] = round(t[1] + dy_l, 2)
            disp["firstperson_lefthand"]["translation"] = t
        dst = out / "assets" / "minecraft" / "models" / "item" / fname
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_text(json.dumps(data, indent=2), encoding="utf-8")


register_rp(
    "low-shield",
    "Low Shield",
    "Опускает щит ниже в руке (и в покое, и в блоке), чтобы он не перекрывал прицел и противника.",
    build_low_shield,
)


# 24. Dark Glass UI
def build_dark_glass_ui(out: Path) -> None:
    containers = [
        "inventory.png",
        "crafting_table.png",
        "furnace.png",
        "blast_furnace.png",
        "generic_54.png",
    ]
    for extra in ["anvil.png", "enchanting_table.png", "brewing_stand.png", "hopper.png", "shulker_box.png", "smithing.png", "smoker.png", "crafter.png"]:
        if (VANILLA_MC / "textures" / "gui" / "container" / extra).exists():
            containers.append(extra)

    def darken_panel(w: int, h: int, px: bytearray):
        for i in range(0, len(px), 4):
            r, g, b, a = px[i], px[i + 1], px[i + 2], px[i + 3]
            if a == 0:
                continue
            # Neutral gray GUI pixels -> sleek translucent dark obsidian glass
            if abs(r - g) <= 12 and abs(g - b) <= 12:
                luma = (r + g + b) / (3.0 * 255.0)
                nr = int(16 + luma * 36)
                ng = int(19 + luma * 40)
                nb = int(28 + luma * 50)
                na = 218 if luma > 0.35 else min(242, a)
                px[i], px[i + 1], px[i + 2], px[i + 3] = nr, ng, nb, na
        return w, h, px

    for c in containers:
        save_edited_png(f"textures/gui/container/{c}", out, darken_panel)


register_rp(
    "dark-glass-ui",
    "Dark Glass UI",
    "Тёмный полупрозрачный интерфейс инвентаря, сундуков, верстака и печей в стиле Liquid Glass.",
    build_dark_glass_ui,
)


# 25. Clean PvP Crosshair
def build_clean_crosshair(out: Path) -> None:
    def make_crosshair(w: int, h: int, px: bytearray):
        out_px = bytearray(w * h * 4)
        cx, cy = w // 2, h // 2

        def put(x: int, y: int, r: int, g: int, b: int, a: int) -> None:
            if 0 <= x < w and 0 <= y < h:
                idx = (y * w + x) * 4
                out_px[idx], out_px[idx + 1], out_px[idx + 2], out_px[idx + 3] = r, g, b, a

        # Center dot + 4 crisp arms with 1px gap
        put(cx, cy, 255, 255, 255, 255)
        for d in (2, 3, 4):
            put(cx - d, cy, 255, 255, 255, 255)
            put(cx + d, cy, 255, 255, 255, 255)
            put(cx, cy - d, 255, 255, 255, 255)
            put(cx, cy + d, 255, 255, 255, 255)
        return w, h, out_px

    save_edited_png("textures/gui/sprites/hud/crosshair.png", out, make_crosshair)


register_rp(
    "clean-pvp-crosshair",
    "Clean PvP Crosshair",
    "Аккуратный киберспортивный прицел с центральной точкой и зазором для точной наводки.",
    build_clean_crosshair,
)


# 26. Minimal Weather
def build_minimal_weather(out: Path) -> None:
    def soften_weather(w: int, h: int, px: bytearray):
        for y in range(h):
            for x in range(w):
                i = (y * w + x) * 4
                if (x % 2) == 1:
                    px[i + 3] = int(px[i + 3] * 0.18)
                else:
                    px[i + 3] = int(px[i + 3] * 0.34)
        return w, h, px

    save_edited_png("textures/environment/rain.png", out, soften_weather)
    save_edited_png("textures/environment/snow.png", out, soften_weather)


register_rp(
    "minimal-weather",
    "Minimal Weather",
    "Тонкие полупрозрачные капли дождя и снежинки — сохраняют атмосферу, но не мешают обзору.",
    build_minimal_weather,
)


# 27. Clean Particles
def build_clean_particles(out: Path) -> None:
    def fade_alpha(factor: float):
        def _fn(w: int, h: int, px: bytearray):
            for i in range(3, len(px), 4):
                px[i] = int(px[i] * factor)
            return w, h, px

        return _fn

    for idx in range(16):
        save_edited_png(f"textures/particle/explosion_{idx}.png", out, fade_alpha(0.38))
    for idx in range(12):
        save_edited_png(f"textures/particle/big_smoke_{idx}.png", out, fade_alpha(0.35))
    for idx in range(8):
        save_edited_png(f"textures/particle/effect_{idx}.png", out, fade_alpha(0.22))


register_rp(
    "clean-particles",
    "Clean Particles",
    "Делает частицы взрывов, дыма и зелий компактными и полупрозрачными для чистого экрана в бою.",
    build_clean_particles,
)


# 28. Cleaner Hotbar
def build_cleaner_hotbar(out: Path) -> None:
    def sleek_bar(w: int, h: int, px: bytearray):
        for y in range(h):
            for x in range(w):
                i = (y * w + x) * 4
                if px[i + 3] == 0:
                    continue
                border = x == 0 or y == 0 or x == w - 1 or y == h - 1
                if border:
                    px[i], px[i + 1], px[i + 2], px[i + 3] = 72, 82, 104, 195
                else:
                    px[i], px[i + 1], px[i + 2], px[i + 3] = 16, 19, 27, 165
        return w, h, px

    def glow_select(w: int, h: int, px: bytearray):
        out_px = bytearray(w * h * 4)
        for y in range(h):
            for x in range(w):
                i = (y * w + x) * 4
                d = min(x, y, w - 1 - x, h - 1 - y)
                if d == 0:
                    out_px[i : i + 4] = bytes((90, 208, 255, 245))
                elif d == 1:
                    out_px[i : i + 4] = bytes((255, 148, 64, 225))
                elif d == 2:
                    out_px[i : i + 4] = bytes((255, 255, 255, 55))
        return w, h, out_px

    for f in ["hotbar.png", "hotbar_offhand_left.png", "hotbar_offhand_right.png"]:
        save_edited_png(f"textures/gui/sprites/hud/{f}", out, sleek_bar)
    save_edited_png("textures/gui/sprites/hud/hotbar_selection.png", out, glow_select)


register_rp(
    "cleaner-hotbar",
    "Cleaner Hotbar",
    "Полупрозрачный тёмно-стеклянный хотбар с яркой неоново-оранжевой рамкой выбранного слота.",
    build_cleaner_hotbar,
)


# 29. Bright Water & Ice
def build_bright_water_ice(out: Path) -> None:
    def clear_ice(w: int, h: int, px: bytearray):
        for y in range(h):
            for x in range(w):
                i = (y * w + x) * 4
                edge = x == 0 or y == 0 or x == w - 1 or y == h - 1
                px[i] = min(255, int(px[i] * 0.85 + 38))
                px[i + 1] = min(255, int(px[i + 1] * 0.90 + 44))
                px[i + 2] = 255
                px[i + 3] = 185 if edge else 88
        return w, h, px

    def clean_water(w: int, h: int, px: bytearray):
        for i in range(0, len(px), 4):
            px[i] = min(255, int(px[i] * 1.05 + 12))
            px[i + 1] = min(255, int(px[i + 1] * 1.12 + 20))
            px[i + 2] = min(255, int(px[i + 2] * 1.15 + 24))
            px[i + 3] = min(255, int(px[i + 3] * 0.62))
        return w, h, px

    save_edited_png("textures/block/ice.png", out, clear_ice)
    save_edited_png("textures/block/water_still.png", out, clean_water)


register_rp(
    "bright-water-ice",
    "Bright Water & Ice",
    "Кристально прозрачный лёд с аккуратной гранью и более чистая бирюзовая поверхность воды.",
    build_bright_water_ice,
)


# 30. Compact Totem & Hearts (Crisp HUD Hearts & Armor)
def build_crisp_hearts(out: Path) -> None:
    def boost_icon(tr: int, tg: int, tb: int):
        def _fn(w: int, h: int, px: bytearray):
            for i in range(0, len(px), 4):
                r, g, b, a = px[i], px[i + 1], px[i + 2], px[i + 3]
                if a == 0:
                    continue
                luma = (r + g + b) / (3.0 * 255.0)
                if luma < 0.18:
                    px[i], px[i + 1], px[i + 2] = 18, 18, 24
                else:
                    px[i] = min(255, int(r * 0.55 + tr * 0.55))
                    px[i + 1] = min(255, int(g * 0.55 + tg * 0.55))
                    px[i + 2] = min(255, int(b * 0.55 + tb * 0.55))
            return w, h, px

        return _fn

    for f in ["full.png", "half.png"]:
        save_edited_png(f"textures/gui/sprites/hud/heart/{f}", out, boost_icon(255, 52, 72))
    for f in ["absorbing_full.png", "absorbing_half.png"]:
        save_edited_png(f"textures/gui/sprites/hud/heart/{f}", out, boost_icon(255, 214, 46))
    for f in ["armor_full.png", "armor_half.png"]:
        save_edited_png(f"textures/gui/sprites/hud/{f}", out, boost_icon(120, 215, 255))


register_rp(
    "compact-totem-hearts",
    "Crisp Hearts & Armor",
    "Контрастные сочные иконки здоровья, золотых сердец и брони в HUD для мгновенного чтения ХП.",
    build_crisp_hearts,
)


# 41. No Screen Borders (Vignette & Powder Snow Outline)
def build_no_screen_borders(out: Path) -> None:
    def neutralize_vignette(w: int, h: int, px: bytearray):
        # Fill entire vignette with its exact center pixel (zero corner darkening)
        ci = ((h // 2) * w + (w // 2)) * 4
        cr, cg, cb, ca = px[ci], px[ci + 1], px[ci + 2], px[ci + 3]
        for i in range(0, len(px), 4):
            px[i], px[i + 1], px[i + 2], px[i + 3] = cr, cg, cb, ca
        return w, h, px

    def clear_frost(w: int, h: int, px: bytearray):
        for i in range(3, len(px), 4):
            px[i] = int(px[i] * 0.08)
        return w, h, px

    save_edited_png("textures/misc/vignette.png", out, neutralize_vignette)
    save_edited_png("textures/misc/powder_snow_outline.png", out, clear_frost)


register_rp(
    "no-screen-borders",
    "No Screen Borders",
    "Убирает тёмную виньетку по углам экрана и ледяную корку от рыхлого снега.",
    build_no_screen_borders,
)


# 42. Clear Water Overlay
def build_clear_water_overlay(out: Path) -> None:
    def clear_underwater(w: int, h: int, px: bytearray):
        for i in range(0, len(px), 4):
            px[i + 3] = 0
        return w, h, px

    save_edited_png("textures/misc/underwater.png", out, clear_underwater)


register_rp(
    "clear-water-overlay",
    "Clear Water Overlay",
    "Полностью убирает мутную текстуру воды с экрана при плавании под водой.",
    build_clear_water_overlay,
)


# 43. Bright Crit Particles
def build_bright_crits(out: Path) -> None:
    def color_particle(tr: int, tg: int, tb: int):
        def _fn(w: int, h: int, px: bytearray):
            cx, cy = (w - 1) / 2.0, (h - 1) / 2.0
            for y in range(h):
                for x in range(w):
                    i = (y * w + x) * 4
                    dx, dy = abs(x - cx), abs(y - cy)
                    # Crisp 4-point star flare
                    star = min(dx, dy) <= 0.8 and max(dx, dy) <= w * 0.44
                    core = (dx * dx + dy * dy) <= (w * 0.22) ** 2
                    if core:
                        px[i], px[i + 1], px[i + 2], px[i + 3] = 255, 255, 245, 255
                    elif star or px[i + 3] > 20:
                        px[i], px[i + 1], px[i + 2], px[i + 3] = tr, tg, tb, 255
            return w, h, px

        return _fn

    save_edited_png("textures/particle/critical_hit.png", out, color_particle(255, 92, 36))
    save_edited_png("textures/particle/enchanted_hit.png", out, color_particle(42, 232, 255))


register_rp(
    "bright-crit-particles",
    "Bright Crit Particles",
    "Яркие контрастные звёзды критических ударов и ударов с Заговором/Остротой в PvP.",
    build_bright_crits,
)


# 44. Sticky Piston Marker
def build_sticky_piston_marker(out: Path) -> None:
    w, h, px = read_png_rgba(VANILLA_MC / "textures" / "block" / "piston_side.png")
    # Paint clean slime-green stripe & dot on piston collar/side
    for y in range(h):
        for x in range(w):
            i = (y * w + x) * 4
            if 3 <= y <= 4 and 2 <= x <= w - 3:
                px[i], px[i + 1], px[i + 2], px[i + 3] = 118, 214, 72, 255
            elif 8 <= y <= 11 and 6 <= x <= 9:
                edge = x in (6, 9) or y in (8, 11)
                px[i : i + 4] = bytes((72, 160, 40, 255) if edge else (138, 228, 86, 255))
    write_png_rgba(out / "assets" / "minecraft" / "textures" / "block" / "piston_side_sticky.png", w, h, px)

    sp_model = {
        "parent": "minecraft:block/template_piston",
        "textures": {
            "bottom": "minecraft:block/piston_bottom",
            "platform": "minecraft:block/piston_top_sticky",
            "side": "minecraft:block/piston_side_sticky",
        },
    }
    sp_base = {
        "parent": "minecraft:block/piston_extended",
        "textures": {
            "bottom": "minecraft:block/piston_bottom",
            "side": "minecraft:block/piston_side_sticky",
            "inside": "minecraft:block/piston_inner",
        },
    }
    m_dir = out / "assets" / "minecraft" / "models" / "block"
    m_dir.mkdir(parents=True, exist_ok=True)
    (m_dir / "sticky_piston.json").write_text(json.dumps(sp_model, indent=2), encoding="utf-8")
    (m_dir / "sticky_piston_base.json").write_text(json.dumps(sp_base, indent=2), encoding="utf-8")

    bs = json.loads((VANILLA_MC / "blockstates" / "sticky_piston.json").read_text(encoding="utf-8"))
    for k, v in bs.get("variants", {}).items():
        if v.get("model") == "minecraft:block/piston_base":
            v["model"] = "minecraft:block/sticky_piston_base"
    bs_dir = out / "assets" / "minecraft" / "blockstates"
    bs_dir.mkdir(parents=True, exist_ok=True)
    (bs_dir / "sticky_piston.json").write_text(json.dumps(bs, indent=2), encoding="utf-8")


register_rp(
    "sticky-piston-marker",
    "Sticky Piston Marker",
    "Зелёная метка слизи по бокам липких поршней, чтобы сразу отличать их от обычных в механизмах.",
    build_sticky_piston_marker,
)


# 45. Redstone Clarity
def build_redstone_clarity(out: Path) -> None:
    def add_arrow_up(w: int, h: int, px: bytearray):
        # Clear bright red/amber directional chevron pointing toward output (south/bottom or top)
        pts = [
            (7, 3), (8, 3),
            (6, 4), (7, 4), (8, 4), (9, 4),
            (5, 5), (6, 5), (9, 5), (10, 5),
            (7, 5), (8, 5), (7, 6), (8, 6), (7, 7), (8, 7),
        ]
        for x, y in pts:
            if 0 <= x < w and 0 <= y < h:
                i = (y * w + x) * 4
                px[i : i + 4] = bytes((255, 68, 52, 255))
        return w, h, px

    def boost_lit(w: int, h: int, px: bytearray):
        for i in range(0, len(px), 4):
            if px[i] > px[i + 1] + 25:
                px[i] = min(255, int(px[i] * 1.35 + 30))
                px[i + 1] = min(255, int(px[i + 1] * 1.15 + 10))
        return w, h, px

    save_edited_png("textures/block/observer_top.png", out, add_arrow_up)
    save_edited_png("textures/block/observer_back_on.png", out, boost_lit)
    save_edited_png("textures/block/repeater_on.png", out, boost_lit)
    save_edited_png("textures/block/comparator_on.png", out, boost_lit)


register_rp(
    "redstone-clarity",
    "Redstone Clarity",
    "Чёткие стрелки направления на Наблюдателях (Observer) и яркая индикация активных повторителей.",
    build_redstone_clarity,
)


# 46. Bow Charge Indicator
def build_bow_indicator(out: Path) -> None:
    stages = [
        ("bow_pulling_0.png", (255, 72, 58)),
        ("bow_pulling_1.png", (255, 196, 42)),
        ("bow_pulling_2.png", (52, 245, 108)),
    ]
    for fname, (tr, tg, tb) in stages:
        def tint_bow(w: int, h: int, px: bytearray, r=tr, g=tg, b=tb):
            for y in range(h):
                for x in range(w):
                    i = (y * w + x) * 4
                    if px[i + 3] == 0:
                        continue
                    luma = (px[i] + px[i + 1] + px[i + 2]) / (3.0 * 255.0)
                    # Tint bright string/arrowtip pixels strongly, wood subtly
                    mix = 0.78 if luma > 0.48 else 0.35
                    px[i] = min(255, int(px[i] * (1.0 - mix) + r * mix))
                    px[i + 1] = min(255, int(px[i + 1] * (1.0 - mix) + g * mix))
                    px[i + 2] = min(255, int(px[i + 2] * (1.0 - mix) + b * mix))
            return w, h, px

        save_edited_png(f"textures/item/{fname}", out, tint_bow)


register_rp(
    "bow-charge-indicator",
    "Bow Charge Indicator",
    "Цветовая подсветка стадий натяжения лука (красный → жёлтый → ярко-зелёный при 100% заряде).",
    build_bow_indicator,
)


# 47. Crossbow Ready Glow
def build_crossbow_glow(out: Path) -> None:
    stages = [
        ("crossbow_pulling_0.png", (255, 80, 64)),
        ("crossbow_pulling_1.png", (255, 198, 48)),
        ("crossbow_pulling_2.png", (64, 242, 125)),
        ("crossbow_arrow.png", (48, 245, 180)),
        ("crossbow_firework.png", (255, 92, 235)),
    ]
    for fname, (tr, tg, tb) in stages:
        def tint_cb(w: int, h: int, px: bytearray, r=tr, g=tg, b=tb):
            for i in range(0, len(px), 4):
                if px[i + 3] == 0:
                    continue
                luma = (px[i] + px[i + 1] + px[i + 2]) / (3.0 * 255.0)
                mix = 0.75 if luma > 0.45 else 0.30
                px[i] = min(255, int(px[i] * (1.0 - mix) + r * mix))
                px[i + 1] = min(255, int(px[i + 1] * (1.0 - mix) + g * mix))
                px[i + 2] = min(255, int(px[i + 2] * (1.0 - mix) + b * mix))
            return w, h, px

        save_edited_png(f"textures/item/{fname}", out, tint_cb)


register_rp(
    "crossbow-ready-glow",
    "Crossbow Ready Glow",
    "Яркая индикация зарядки арбалета и подсветка заряженного снаряда (стрела / фейерверк).",
    build_crossbow_glow,
)


# 48. Small Totem
def build_small_totem(out: Path) -> None:
    model = {
        "parent": "minecraft:item/generated",
        "textures": {"layer0": "minecraft:item/totem_of_undying"},
        "display": {
            "firstperson_righthand": {
                "rotation": [0, -90, 25],
                "translation": [1.13, -2.6, 1.13],
                "scale": [0.38, 0.38, 0.38],
            },
            "firstperson_lefthand": {
                "rotation": [0, 90, -25],
                "translation": [1.13, -2.6, 1.13],
                "scale": [0.38, 0.38, 0.38],
            },
        },
    }
    dst = out / "assets" / "minecraft" / "models" / "item" / "totem_of_undying.json"
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(json.dumps(model, indent=2), encoding="utf-8")


register_rp(
    "small-totem",
    "Small Totem",
    "Компактный тотем бессмертия в руке — занимает минимум места внизу экрана и не мешает в PvP.",
    build_small_totem,
)


# 49. Clear Nether Portal
def build_clear_portal(out: Path) -> None:
    def calm_portal(w: int, h: int, px: bytearray):
        for i in range(0, len(px), 4):
            px[i + 3] = int(px[i + 3] * 0.34)
        return w, h, px

    save_edited_png("textures/block/nether_portal.png", out, calm_portal)


register_rp(
    "clear-nether-portal",
    "Clear Nether Portal",
    "Мягкая полупрозрачная плёнка портала в Незер — сквозь портал отлично видно другую сторону.",
    build_clear_portal,
)


# 50. Clean Enchant Glint
def build_clean_glint(out: Path) -> None:
    def soft_glint(w: int, h: int, px: bytearray):
        for i in range(0, len(px), 4):
            px[i] = int(px[i] * 0.42)
            px[i + 1] = int(px[i + 1] * 0.42)
            px[i + 2] = int(px[i + 2] * 0.48)
        return w, h, px

    save_edited_png("textures/misc/enchanted_glint_item.png", out, soft_glint)
    save_edited_png("textures/misc/enchanted_glint_armor.png", out, soft_glint)


register_rp(
    "clean-enchant-glint",
    "Clean Enchant Glint",
    "Спокойный деликатный перелив зачарования, не скрывающий цвет брони и отделку кузнечных шаблонов.",
    build_clean_glint,
)


def main() -> None:
    assert len(RESOURCEPACKS) == 24, f"Expected 24 resourcepacks, got {len(RESOURCEPACKS)}"
    MODS_ROOT.mkdir(parents=True, exist_ok=True)

    for rp in RESOURCEPACKS:
        work = SRC_RP / rp["id"]
        if work.exists():
            shutil.rmtree(work)
        work.mkdir(parents=True, exist_ok=True)

        (work / "pack.mcmeta").write_text(make_mcmeta(f"{rp['name']} — {rp['description']}"), encoding="utf-8", newline="\n")
        rp["builder"](work)

        out_zip = MODS_ROOT / rp["file_name"]
        with zipfile.ZipFile(out_zip, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
            for file_path in sorted(work.rglob("*")):
                if file_path.is_file():
                    arcname = file_path.relative_to(work).as_posix()
                    zf.writestr(arcname, file_path.read_bytes())

        print(f"[OK] Built {rp['file_name']} ({out_zip.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
