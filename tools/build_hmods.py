"""Builds 12 genuine, verified Horizon 26.3 content mods (.hmod) with custom 16x16 pixel art,
items, throwables, blocks, creative tabs, recipes, and Russian/English translations."""

import json
from pathlib import Path
import shutil
import zipfile

from png_io import write_png_rgba

ROOT = Path(__file__).resolve().parent.parent
SRC_HMODS = ROOT / "src-hmods"
MODS_ROOT = ROOT / "mods"

HMODS: list[dict] = []


def _shade(c: tuple[int, int, int], mul: float) -> tuple[int, int, int, int]:
    return (
        max(0, min(255, int(c[0] * mul))),
        max(0, min(255, int(c[1] * mul))),
        max(0, min(255, int(c[2] * mul))),
        255,
    )


def draw_sprite_16(kind: str, main_c: tuple[int, int, int], accent_c: tuple[int, int, int]) -> bytearray:
    """Draws crisp, recognizable 16x16 pixel-art textures for custom items & blocks."""
    px = bytearray(16 * 16 * 4)

    def put(x: int, y: int, col: tuple[int, int, int, int]) -> None:
        if 0 <= x < 16 and 0 <= y < 16:
            i = (y * 16 + x) * 4
            px[i : i + 4] = bytes(col)

    dark = _shade(main_c, 0.45)
    mid = _shade(main_c, 0.92)
    hi = _shade(main_c, 1.30)
    ac_hi = _shade(accent_c, 1.20)
    ac_dark = _shade(accent_c, 0.55)
    wood = (118, 82, 46, 255)
    wood_d = (78, 52, 28, 255)

    if kind == "sword":
        # Handle
        for k in range(3):
            put(1 + k, 14 - k, wood_d)
            put(2 + k, 14 - k, wood)
        put(1, 14, ac_dark)
        # Crossguard
        for k in range(-2, 3):
            put(5 + k, 10 + k, ac_hi if k == 0 else ac_dark)
        # Diagonal blade
        for k in range(6, 15):
            bx, by = k, 15 - k
            put(bx, by, hi)
            put(bx - 1, by, mid)
            put(bx, by + 1, dark)
        put(14, 1, hi)
        put(14, 2, mid)
        put(13, 1, mid)
    elif kind == "pickaxe":
        for k in range(1, 12):
            put(k, 15 - k, wood if k % 2 == 0 else wood_d)
        # Curved head
        head = [
            (5, 1), (6, 1), (7, 1), (8, 1), (9, 1), (10, 2), (11, 2), (12, 3),
            (13, 4), (13, 5), (14, 6), (14, 7), (14, 8), (14, 9), (14, 10),
        ]
        for x, y in head:
            put(x, y, hi)
            put(x - 1, y + 1, mid)
            put(x - 1, y, dark)
    elif kind == "axe":
        for k in range(1, 13):
            put(k, 15 - k, wood if k % 2 == 0 else wood_d)
        for y in range(2, 9):
            for x in range(8, 15):
                if (x - 11) ** 2 + (y - 5) ** 2 <= 11:
                    col = hi if x + y < 15 else (mid if x < 14 else dark)
                    put(x, y, col)
    elif kind == "shuriken":
        # 4-blade throwing star
        for d in range(1, 7):
            put(7, 7 - d, hi); put(8, 7 - d, mid)
            put(8, 8 + d, hi); put(7, 8 + d, mid)
            put(7 - d, 8, hi); put(7 - d, 7, mid)
            put(8 + d, 7, hi); put(8 + d, 8, mid)
        for x in (6, 7, 8, 9):
            for y in (6, 7, 8, 9):
                put(x, y, ac_hi if (x in (7, 8) and y in (7, 8)) else dark)
        put(7, 7, (0, 0, 0, 0)); put(8, 8, (0, 0, 0, 0))
    elif kind == "orb":
        for y in range(16):
            for x in range(16):
                dist2 = (x - 7.5) ** 2 + (y - 7.5) ** 2
                if dist2 <= 28:
                    if dist2 >= 20:
                        put(x, y, dark)
                    elif (x - 5.5) ** 2 + (y - 5.5) ** 2 <= 5:
                        put(x, y, ac_hi)
                    else:
                        put(x, y, hi if y < 8 else mid)
    elif kind == "gem":
        for y in range(2, 14):
            span = 6 - abs(y - 7)
            for x in range(8 - span, 8 + span):
                edge = x == 8 - span or x == 7 + span or y in (2, 13)
                put(x, y, dark if edge else (hi if x < 8 and y < 8 else mid))
    elif kind == "food":
        for y in range(3, 14):
            for x in range(3, 13):
                d2 = (x - 7.5) ** 2 + (y - 8.5) ** 2
                if d2 <= 23:
                    if d2 >= 16:
                        put(x, y, dark)
                    elif x < 7 and y < 8:
                        put(x, y, hi)
                    else:
                        put(x, y, mid)
        put(7, 2, wood_d); put(8, 3, wood); put(9, 2, ac_hi); put(10, 2, ac_hi)
    elif kind == "lamp":
        for y in range(16):
            for x in range(16):
                border = x == 0 or y == 0 or x == 15 or y == 15
                inner = x == 1 or y == 1 or x == 14 or y == 14
                core = 4 <= x <= 11 and 4 <= y <= 11
                if border:
                    put(x, y, ac_dark)
                elif inner:
                    put(x, y, dark)
                elif core:
                    put(x, y, hi if (x + y) % 3 != 0 else ac_hi)
                else:
                    put(x, y, mid)
    elif kind == "block":
        for y in range(16):
            for x in range(16):
                border = x == 0 or y == 0 or x == 15 or y == 15
                brick_line = (y in (0, 8)) or (x == 0 and y < 8) or (x == 8 and y >= 8)
                if border:
                    put(x, y, dark)
                elif brick_line:
                    put(x, y, ac_dark)
                else:
                    n = ((x * 13 + y * 29) % 5)
                    put(x, y, hi if n == 0 else (mid if n < 4 else _shade(main_c, 0.78)))
    elif kind == "glass":
        for y in range(16):
            for x in range(16):
                border = x == 0 or y == 0 or x == 15 or y == 15
                inner = x == 1 or y == 1 or x == 14 or y == 14
                if border:
                    put(x, y, ac_dark)
                elif inner:
                    put(x, y, (main_c[0], main_c[1], main_c[2], 210))
                elif (x + y) in (7, 22):
                    put(x, y, (255, 255, 255, 130))
                else:
                    put(x, y, (main_c[0], main_c[1], main_c[2], 65))
    return px


def add_hmod(
    file_slug: str,
    mod_id: str,
    name: str,
    ru_desc: str,
    tab_title: str,
    icon_item: str,
    items: list[dict],
    blocks: list[dict],
    throwables: list[dict],
    recipes: list[dict],
) -> None:
    HMODS.append(
        {
            "slug": file_slug,
            "mod_id": mod_id,
            "name": name,
            "description": ru_desc,
            "file_name": f"{file_slug}.hmod",
            "tab_title": tab_title,
            "icon_item": icon_item,
            "items": items,
            "blocks": blocks,
            "throwables": throwables,
            "recipes": recipes,
        }
    )


def shaped_recipe(result_id: str, count: int, pattern: list[str], key: dict[str, str]) -> dict:
    return {
        "name": result_id.split(":")[-1],
        "body": {
            "type": "minecraft:crafting_shaped",
            "pattern": pattern,
            "key": key,
            "result": {"id": result_id, "count": count},
        },
    }


def shapeless_recipe(result_id: str, count: int, ingredients: list[str]) -> dict:
    return {
        "name": result_id.split(":")[-1],
        "body": {
            "type": "minecraft:crafting_shapeless",
            "ingredients": ingredients,
            "result": {"id": result_id, "count": count},
        },
    }


# 1. Ruby Arsenal
add_hmod(
    "ruby-arsenal",
    "ruby_arsenal",
    "Ruby Arsenal",
    "Добавляет рубин, рубиновый меч, топор, кирку, рубиновый блок и яркий рубиновый фонарь с крафтами.",
    "Ruby Arsenal",
    "ruby_arsenal:ruby_sword",
    items=[
        {"id": "ruby", "ru": "Рубин", "en": "Ruby", "template": "minecraft:emerald", "rarity": "rare", "stack": 64, "sprite": "gem", "c1": (235, 36, 78), "c2": (255, 148, 178), "handheld": False},
        {"id": "ruby_sword", "ru": "Рубиновый меч", "en": "Ruby Sword", "template": "minecraft:netherite_sword", "rarity": "epic", "stack": 1, "sprite": "sword", "c1": (235, 36, 78), "c2": (255, 198, 92), "handheld": True},
        {"id": "ruby_pickaxe", "ru": "Рубиновая кирка", "en": "Ruby Pickaxe", "template": "minecraft:netherite_pickaxe", "rarity": "rare", "stack": 1, "sprite": "pickaxe", "c1": (235, 36, 78), "c2": (255, 176, 120), "handheld": True},
        {"id": "ruby_axe", "ru": "Рубиновый топор", "en": "Ruby Axe", "template": "minecraft:netherite_axe", "rarity": "rare", "stack": 1, "sprite": "axe", "c1": (235, 36, 78), "c2": (255, 176, 120), "handheld": True},
    ],
    blocks=[
        {"id": "ruby_block", "ru": "Рубиновый блок", "en": "Block of Ruby", "template": "minecraft:diamond_block", "props": {"hardness": 5.0, "explosion_resistance": 8.0, "light": 4}, "sprite": "block", "c1": (222, 32, 72), "c2": (132, 16, 42)},
        {"id": "ruby_lamp", "ru": "Рубиновый фонарь", "en": "Ruby Lamp", "template": "minecraft:glowstone", "props": {"hardness": 1.8, "light": 15}, "sprite": "lamp", "c1": (255, 62, 108), "c2": (255, 210, 140)},
    ],
    throwables=[],
    recipes=[
        shapeless_recipe("ruby_arsenal:ruby", 2, ["minecraft:diamond", "minecraft:redstone", "minecraft:redstone"]),
        shaped_recipe("ruby_arsenal:ruby_sword", 1, ["R", "R", "S"], {"R": "ruby_arsenal:ruby", "S": "minecraft:stick"}),
        shaped_recipe("ruby_arsenal:ruby_pickaxe", 1, ["RRR", " S ", " S "], {"R": "ruby_arsenal:ruby", "S": "minecraft:stick"}),
        shaped_recipe("ruby_arsenal:ruby_axe", 1, ["RR", "RS", " S"], {"R": "ruby_arsenal:ruby", "S": "minecraft:stick"}),
        shaped_recipe("ruby_arsenal:ruby_block", 1, ["RRR", "RRR", "RRR"], {"R": "ruby_arsenal:ruby"}),
        shaped_recipe("ruby_arsenal:ruby_lamp", 2, [" R ", "RGR", " R "], {"R": "ruby_arsenal:ruby", "G": "minecraft:glowstone"}),
    ],
)

# 2. Ninja Shurikens
add_hmod(
    "ninja-shurikens",
    "ninja_shurikens",
    "Ninja Shurikens",
    "Оружие ниндзя: метательные железные и алмазные сюрикены, огненный кунай с реальным уроном и катана тени.",
    "Ninja Shurikens",
    "ninja_shurikens:diamond_shuriken",
    items=[
        {"id": "iron_shuriken", "ru": "Железный сюрикен", "en": "Iron Shuriken", "template": "minecraft:snowball", "rarity": "uncommon", "stack": 32, "sprite": "shuriken", "c1": (210, 220, 232), "c2": (110, 128, 148), "handheld": False},
        {"id": "diamond_shuriken", "ru": "Алмазный сюрикен", "en": "Diamond Shuriken", "template": "minecraft:snowball", "rarity": "rare", "stack": 32, "sprite": "shuriken", "c1": (64, 235, 255), "c2": (38, 138, 220), "handheld": False},
        {"id": "flame_kunai", "ru": "Огненный кунай", "en": "Flame Kunai", "template": "minecraft:snowball", "rarity": "epic", "stack": 16, "sprite": "shuriken", "c1": (255, 118, 42), "c2": (255, 224, 88), "handheld": False},
        {"id": "shadow_katana", "ru": "Катана тени", "en": "Shadow Katana", "template": "minecraft:netherite_sword", "rarity": "epic", "stack": 1, "sprite": "sword", "c1": (72, 64, 118), "c2": (182, 92, 255), "handheld": True},
    ],
    blocks=[],
    throwables=[
        {"id": "iron_shuriken", "item": "ninja_shurikens:iron_shuriken", "damage": 4.0},
        {"id": "diamond_shuriken", "item": "ninja_shurikens:diamond_shuriken", "damage": 6.5},
        {"id": "flame_kunai", "item": "ninja_shurikens:flame_kunai", "damage": 7.5},
    ],
    recipes=[
        shaped_recipe("ninja_shurikens:iron_shuriken", 8, [" I ", "I I", " I "], {"I": "minecraft:iron_ingot"}),
        shaped_recipe("ninja_shurikens:diamond_shuriken", 8, [" D ", "DID", " D "], {"D": "minecraft:diamond", "I": "minecraft:iron_ingot"}),
        shaped_recipe("ninja_shurikens:flame_kunai", 4, [" B ", "BDB", " B "], {"B": "minecraft:blaze_powder", "D": "minecraft:diamond"}),
        shaped_recipe("ninja_shurikens:shadow_katana", 1, ["  O", " D ", "S  "], {"O": "minecraft:obsidian", "D": "minecraft:diamond", "S": "minecraft:stick"}),
    ],
)

# 3. Emerald Tools & Weapons
add_hmod(
    "emerald-gear",
    "emerald_gear",
    "Emerald Gear",
    "Полный набор изумрудного снаряжения (меч, кирка, топор) и светящийся изумрудный светильник.",
    "Emerald Gear",
    "emerald_gear:emerald_sword",
    items=[
        {"id": "emerald_sword", "ru": "Изумрудный меч", "en": "Emerald Sword", "template": "minecraft:diamond_sword", "rarity": "rare", "stack": 1, "sprite": "sword", "c1": (36, 224, 108), "c2": (255, 224, 88), "handheld": True},
        {"id": "emerald_pickaxe", "ru": "Изумрудная кирка", "en": "Emerald Pickaxe", "template": "minecraft:diamond_pickaxe", "rarity": "rare", "stack": 1, "sprite": "pickaxe", "c1": (36, 224, 108), "c2": (180, 255, 198), "handheld": True},
        {"id": "emerald_axe", "ru": "Изумрудный топор", "en": "Emerald Axe", "template": "minecraft:diamond_axe", "rarity": "rare", "stack": 1, "sprite": "axe", "c1": (36, 224, 108), "c2": (180, 255, 198), "handheld": True},
    ],
    blocks=[
        {"id": "emerald_lamp", "ru": "Изумрудный светильник", "en": "Emerald Lamp", "template": "minecraft:sea_lantern", "props": {"hardness": 2.0, "light": 15}, "sprite": "lamp", "c1": (48, 242, 128), "c2": (20, 128, 64)},
    ],
    throwables=[],
    recipes=[
        shaped_recipe("emerald_gear:emerald_sword", 1, ["E", "E", "S"], {"E": "minecraft:emerald", "S": "minecraft:stick"}),
        shaped_recipe("emerald_gear:emerald_pickaxe", 1, ["EEE", " S ", " S "], {"E": "minecraft:emerald", "S": "minecraft:stick"}),
        shaped_recipe("emerald_gear:emerald_axe", 1, ["EE", "ES", " S"], {"E": "minecraft:emerald", "S": "minecraft:stick"}),
        shaped_recipe("emerald_gear:emerald_lamp", 2, [" E ", "EGE", " E "], {"E": "minecraft:emerald", "G": "minecraft:glowstone"}),
    ],
)

# 4. Neon Lamps
add_hmod(
    "neon-lamps",
    "neon_lamps",
    "Neon Lamps",
    "8 ярких неоновых светильников (циан, маджента, лайм, янтарь, алый, фиолетовый, синий, ледяной) для декора баз.",
    "Neon Lamps",
    "neon_lamps:cyan_neon_lamp",
    items=[],
    blocks=[
        {"id": "cyan_neon_lamp", "ru": "Неоновая лампа (Циан)", "en": "Cyan Neon Lamp", "template": "minecraft:sea_lantern", "props": {"hardness": 1.2, "light": 15}, "sprite": "lamp", "c1": (42, 238, 255), "c2": (18, 92, 148)},
        {"id": "magenta_neon_lamp", "ru": "Неоновая лампа (Маджента)", "en": "Magenta Neon Lamp", "template": "minecraft:sea_lantern", "props": {"hardness": 1.2, "light": 15}, "sprite": "lamp", "c1": (255, 58, 204), "c2": (128, 18, 112)},
        {"id": "lime_neon_lamp", "ru": "Неоновая лампа (Лайм)", "en": "Lime Neon Lamp", "template": "minecraft:sea_lantern", "props": {"hardness": 1.2, "light": 15}, "sprite": "lamp", "c1": (96, 255, 72), "c2": (28, 128, 36)},
        {"id": "amber_neon_lamp", "ru": "Неоновая лампа (Янтарь)", "en": "Amber Neon Lamp", "template": "minecraft:glowstone", "props": {"hardness": 1.2, "light": 15}, "sprite": "lamp", "c1": (255, 178, 42), "c2": (148, 72, 16)},
        {"id": "crimson_neon_lamp", "ru": "Неоновая лампа (Алая)", "en": "Crimson Neon Lamp", "template": "minecraft:glowstone", "props": {"hardness": 1.2, "light": 15}, "sprite": "lamp", "c1": (255, 48, 64), "c2": (128, 16, 28)},
        {"id": "violet_neon_lamp", "ru": "Неоновая лампа (Фиолетовая)", "en": "Violet Neon Lamp", "template": "minecraft:sea_lantern", "props": {"hardness": 1.2, "light": 15}, "sprite": "lamp", "c1": (168, 78, 255), "c2": (68, 24, 142)},
        {"id": "cobalt_neon_lamp", "ru": "Неоновая лампа (Синяя)", "en": "Cobalt Neon Lamp", "template": "minecraft:sea_lantern", "props": {"hardness": 1.2, "light": 15}, "sprite": "lamp", "c1": (58, 132, 255), "c2": (22, 48, 138)},
        {"id": "ice_neon_lamp", "ru": "Неоновая лампа (Ледяная)", "en": "Ice Neon Lamp", "template": "minecraft:sea_lantern", "props": {"hardness": 1.2, "light": 15}, "sprite": "lamp", "c1": (210, 248, 255), "c2": (92, 158, 198)},
    ],
    throwables=[],
    recipes=[
        shapeless_recipe("neon_lamps:cyan_neon_lamp", 4, ["minecraft:glowstone", "minecraft:cyan_dye"]),
        shapeless_recipe("neon_lamps:magenta_neon_lamp", 4, ["minecraft:glowstone", "minecraft:magenta_dye"]),
        shapeless_recipe("neon_lamps:lime_neon_lamp", 4, ["minecraft:glowstone", "minecraft:lime_dye"]),
        shapeless_recipe("neon_lamps:amber_neon_lamp", 4, ["minecraft:glowstone", "minecraft:orange_dye"]),
        shapeless_recipe("neon_lamps:crimson_neon_lamp", 4, ["minecraft:glowstone", "minecraft:red_dye"]),
        shapeless_recipe("neon_lamps:violet_neon_lamp", 4, ["minecraft:glowstone", "minecraft:purple_dye"]),
        shapeless_recipe("neon_lamps:cobalt_neon_lamp", 4, ["minecraft:glowstone", "minecraft:blue_dye"]),
        shapeless_recipe("neon_lamps:ice_neon_lamp", 4, ["minecraft:glowstone", "minecraft:white_dye"]),
    ],
)

# 5. Super Foods
add_hmod(
    "super-foods",
    "super_foods",
    "Super Foods",
    "Новые питательные блюда и энергетики: Ягодный энергетик, Королевский стейк, Шоколадный маффин и Золотой эликсир.",
    "Super Foods",
    "super_foods:berry_energy",
    items=[
        {"id": "berry_energy", "ru": "Ягодный энергетик", "en": "Berry Energy", "template": "minecraft:golden_apple", "rarity": "uncommon", "stack": 16, "sprite": "orb", "c1": (255, 58, 118), "c2": (128, 248, 255), "handheld": False},
        {"id": "royal_steak", "ru": "Королевский стейк", "en": "Royal Steak", "template": "minecraft:cooked_beef", "rarity": "rare", "stack": 64, "sprite": "food", "c1": (198, 92, 48), "c2": (255, 214, 72), "handheld": False},
        {"id": "choco_muffin", "ru": "Шоколадный маффин", "en": "Chocolate Muffin", "template": "minecraft:golden_carrot", "rarity": "uncommon", "stack": 64, "sprite": "food", "c1": (118, 68, 38), "c2": (235, 198, 132), "handheld": False},
        {"id": "miner_elixir", "ru": "Эликсир шахтёра", "en": "Miner Elixir", "template": "minecraft:enchanted_golden_apple", "rarity": "epic", "stack": 16, "sprite": "orb", "c1": (255, 208, 48), "c2": (255, 255, 220), "handheld": False},
    ],
    blocks=[],
    throwables=[],
    recipes=[
        shapeless_recipe("super_foods:berry_energy", 2, ["minecraft:sweet_berries", "minecraft:sugar", "minecraft:honey_bottle"]),
        shapeless_recipe("super_foods:royal_steak", 2, ["minecraft:cooked_beef", "minecraft:gold_nugget", "minecraft:gold_nugget"]),
        shapeless_recipe("super_foods:choco_muffin", 4, ["minecraft:wheat", "minecraft:cocoa_beans", "minecraft:sugar"]),
        shaped_recipe("super_foods:miner_elixir", 1, ["GGG", "GAG", "GGG"], {"G": "minecraft:gold_ingot", "A": "minecraft:golden_apple"}),
    ],
)

# 6. Obsidian Gear
add_hmod(
    "obsidian-tools",
    "obsidian_tools",
    "Obsidian Gear",
    "Сверхпрочное обсидиановое оружие, кирка, топор и укреплённый обсидиановый кирпич с огромной взрывоустойчивостью.",
    "Obsidian Gear",
    "obsidian_tools:obsidian_blade",
    items=[
        {"id": "obsidian_blade", "ru": "Обсидиановый клинок", "en": "Obsidian Blade", "template": "minecraft:netherite_sword", "rarity": "epic", "stack": 1, "sprite": "sword", "c1": (88, 52, 138), "c2": (198, 118, 255), "handheld": True},
        {"id": "obsidian_pickaxe", "ru": "Обсидиановая кирка", "en": "Obsidian Pickaxe", "template": "minecraft:netherite_pickaxe", "rarity": "rare", "stack": 1, "sprite": "pickaxe", "c1": (88, 52, 138), "c2": (176, 98, 245), "handheld": True},
        {"id": "obsidian_axe", "ru": "Обсидиановый молот-топор", "en": "Obsidian Battleaxe", "template": "minecraft:netherite_axe", "rarity": "rare", "stack": 1, "sprite": "axe", "c1": (88, 52, 138), "c2": (176, 98, 245), "handheld": True},
    ],
    blocks=[
        {"id": "obsidian_bricks", "ru": "Обсидиановый кирпич", "en": "Obsidian Bricks", "template": "minecraft:obsidian", "props": {"hardness": 25.0, "explosion_resistance": 1200.0}, "sprite": "block", "c1": (48, 32, 74), "c2": (132, 68, 210)},
    ],
    throwables=[],
    recipes=[
        shaped_recipe("obsidian_tools:obsidian_blade", 1, ["O", "O", "S"], {"O": "minecraft:obsidian", "S": "minecraft:blaze_rod"}),
        shaped_recipe("obsidian_tools:obsidian_pickaxe", 1, ["OOO", " S ", " S "], {"O": "minecraft:obsidian", "S": "minecraft:blaze_rod"}),
        shaped_recipe("obsidian_tools:obsidian_axe", 1, ["OO", "OS", " S"], {"O": "minecraft:obsidian", "S": "minecraft:blaze_rod"}),
        shaped_recipe("obsidian_tools:obsidian_bricks", 4, ["OO", "OO"], {"O": "minecraft:obsidian"}),
    ],
)

# 7. Battle Throwables
add_hmod(
    "throwable-bombs",
    "throwable_bombs",
    "Battle Throwables",
    "Боевые метательные снаряды с уроном: метательный камень, магмовая сфера, ледяной осколок и эндер-кинжал.",
    "Battle Throwables",
    "throwable_bombs:magma_orb",
    items=[
        {"id": "pebble", "ru": "Боевой камень", "en": "Battle Pebble", "template": "minecraft:snowball", "rarity": "common", "stack": 64, "sprite": "orb", "c1": (148, 154, 162), "c2": (212, 218, 224), "handheld": False},
        {"id": "magma_orb", "ru": "Магмовая сфера", "en": "Magma Orb", "template": "minecraft:snowball", "rarity": "rare", "stack": 16, "sprite": "orb", "c1": (255, 86, 28), "c2": (255, 232, 92), "handheld": False},
        {"id": "frost_shard", "ru": "Ледяной осколок", "en": "Frost Shard", "template": "minecraft:snowball", "rarity": "uncommon", "stack": 32, "sprite": "gem", "c1": (118, 232, 255), "c2": (235, 252, 255), "handheld": False},
        {"id": "ender_dagger", "ru": "Эндер-кинжал", "en": "Ender Dagger", "template": "minecraft:snowball", "rarity": "epic", "stack": 16, "sprite": "shuriken", "c1": (32, 212, 186), "c2": (186, 72, 255), "handheld": False},
    ],
    blocks=[],
    throwables=[
        {"id": "pebble", "item": "throwable_bombs:pebble", "damage": 3.0},
        {"id": "magma_orb", "item": "throwable_bombs:magma_orb", "damage": 6.5},
        {"id": "frost_shard", "item": "throwable_bombs:frost_shard", "damage": 5.0},
        {"id": "ender_dagger", "item": "throwable_bombs:ender_dagger", "damage": 8.0},
    ],
    recipes=[
        shapeless_recipe("throwable_bombs:pebble", 8, ["minecraft:cobblestone"]),
        shapeless_recipe("throwable_bombs:magma_orb", 4, ["minecraft:magma_cream", "minecraft:fire_charge"]),
        shapeless_recipe("throwable_bombs:frost_shard", 8, ["minecraft:packed_ice", "minecraft:iron_nugget"]),
        shaped_recipe("throwable_bombs:ender_dagger", 4, [" E ", "EDE", " E "], {"E": "minecraft:ender_pearl", "D": "minecraft:diamond"}),
    ],
)

# 8. Amethyst Magic
add_hmod(
    "amethyst-magic",
    "amethyst_magic",
    "Amethyst Magic",
    "Аметистовая магия: кристальный клинок, метательный аметистовый заряд, аметистовое яблоко и светящийся кристалл.",
    "Amethyst Magic",
    "amethyst_magic:amethyst_blade",
    items=[
        {"id": "amethyst_blade", "ru": "Аметистовый клинок", "en": "Amethyst Blade", "template": "minecraft:diamond_sword", "rarity": "epic", "stack": 1, "sprite": "sword", "c1": (182, 92, 255), "c2": (245, 198, 255), "handheld": True},
        {"id": "crystal_bolt", "ru": "Аметистовый заряд", "en": "Crystal Bolt", "template": "minecraft:snowball", "rarity": "rare", "stack": 32, "sprite": "gem", "c1": (198, 108, 255), "c2": (255, 220, 255), "handheld": False},
        {"id": "amethyst_apple", "ru": "Аметистовое яблоко", "en": "Amethyst Apple", "template": "minecraft:golden_apple", "rarity": "rare", "stack": 32, "sprite": "food", "c1": (172, 78, 245), "c2": (255, 196, 255), "handheld": False},
    ],
    blocks=[
        {"id": "glowing_amethyst", "ru": "Светящийся аметист", "en": "Glowing Amethyst", "template": "minecraft:amethyst_block", "props": {"hardness": 2.0, "light": 14}, "sprite": "lamp", "c1": (192, 96, 255), "c2": (88, 32, 148)},
    ],
    throwables=[
        {"id": "crystal_bolt", "item": "amethyst_magic:crystal_bolt", "damage": 5.5},
    ],
    recipes=[
        shaped_recipe("amethyst_magic:amethyst_blade", 1, ["A", "A", "S"], {"A": "minecraft:amethyst_shard", "S": "minecraft:stick"}),
        shapeless_recipe("amethyst_magic:crystal_bolt", 6, ["minecraft:amethyst_shard", "minecraft:amethyst_shard"]),
        shaped_recipe("amethyst_magic:amethyst_apple", 1, ["AAA", "APA", "AAA"], {"A": "minecraft:amethyst_shard", "P": "minecraft:apple"}),
        shaped_recipe("amethyst_magic:glowing_amethyst", 2, [" A ", "AGA", " A "], {"A": "minecraft:amethyst_shard", "G": "minecraft:glowstone"}),
    ],
)

# 9. Copper Expansion
add_hmod(
    "copper-plus",
    "copper_plus",
    "Copper Expansion",
    "Расширение меди: улучшенная медная кирка, боевой медный топор, энергоядро и светящийся медный блок.",
    "Copper Expansion",
    "copper_plus:copper_energy_block",
    items=[
        {"id": "copper_pickaxe_plus", "ru": "Усиленная медная кирка", "en": "Reinforced Copper Pickaxe", "template": "minecraft:iron_pickaxe", "rarity": "uncommon", "stack": 1, "sprite": "pickaxe", "c1": (232, 122, 68), "c2": (72, 224, 186), "handheld": True},
        {"id": "copper_battleaxe", "ru": "Медный боевой топор", "en": "Copper Battleaxe", "template": "minecraft:iron_axe", "rarity": "uncommon", "stack": 1, "sprite": "axe", "c1": (232, 122, 68), "c2": (72, 224, 186), "handheld": True},
        {"id": "copper_core", "ru": "Медное энергоядро", "en": "Copper Energy Core", "template": "minecraft:emerald", "rarity": "rare", "stack": 64, "sprite": "orb", "c1": (68, 228, 192), "c2": (245, 138, 72), "handheld": False},
    ],
    blocks=[
        {"id": "copper_energy_block", "ru": "Медный энергоблок", "en": "Copper Energy Block", "template": "minecraft:copper_block", "props": {"hardness": 3.5, "light": 15}, "sprite": "lamp", "c1": (72, 232, 196), "c2": (198, 92, 46)},
    ],
    throwables=[],
    recipes=[
        shaped_recipe("copper_plus:copper_core", 2, [" C ", "CRC", " C "], {"C": "minecraft:copper_ingot", "R": "minecraft:redstone"}),
        shaped_recipe("copper_plus:copper_pickaxe_plus", 1, ["CCC", " S ", " S "], {"C": "minecraft:copper_ingot", "S": "minecraft:stick"}),
        shaped_recipe("copper_plus:copper_battleaxe", 1, ["CC", "CS", " S"], {"C": "minecraft:copper_ingot", "S": "minecraft:stick"}),
        shaped_recipe("copper_plus:copper_energy_block", 2, [" C ", "CEC", " C "], {"C": "minecraft:copper_ingot", "E": "copper_plus:copper_core"}),
    ],
)

# 10. Reinforced Base Blocks
add_hmod(
    "reinforced-base",
    "reinforced_base",
    "Reinforced Base",
    "Блоки для неприступной базы: бронированный бетон, титановые плиты, защитное стекло и бункерная лампа.",
    "Reinforced Base",
    "reinforced_base:titanium_plate",
    items=[],
    blocks=[
        {"id": "armored_concrete", "ru": "Бронированный бетон", "en": "Armored Concrete", "template": "minecraft:obsidian", "props": {"hardness": 18.0, "explosion_resistance": 800.0}, "sprite": "block", "c1": (72, 78, 88), "c2": (36, 40, 48)},
        {"id": "titanium_plate", "ru": "Титановая плита", "en": "Titanium Plate", "template": "minecraft:iron_block", "props": {"hardness": 14.0, "explosion_resistance": 600.0}, "sprite": "block", "c1": (162, 178, 198), "c2": (82, 96, 118)},
        {"id": "blast_glass", "ru": "Бронированное стекло", "en": "Blast-Proof Glass", "template": "minecraft:tinted_glass", "props": {"hardness": 10.0, "explosion_resistance": 600.0}, "sprite": "glass", "c1": (132, 212, 245), "c2": (52, 78, 108)},
        {"id": "bunker_lamp", "ru": "Бункерная лампа", "en": "Bunker Lamp", "template": "minecraft:iron_block", "props": {"hardness": 10.0, "explosion_resistance": 400.0, "light": 15}, "sprite": "lamp", "c1": (245, 232, 186), "c2": (68, 76, 88)},
    ],
    throwables=[],
    recipes=[
        shaped_recipe("reinforced_base:armored_concrete", 4, ["SIS", "ISI", "SIS"], {"S": "minecraft:stone", "I": "minecraft:iron_ingot"}),
        shaped_recipe("reinforced_base:titanium_plate", 4, ["III", "I I", "III"], {"I": "minecraft:iron_ingot"}),
        shaped_recipe("reinforced_base:blast_glass", 4, [" G ", "GIG", " G "], {"G": "minecraft:glass", "I": "minecraft:iron_ingot"}),
        shaped_recipe("reinforced_base:bunker_lamp", 2, [" I ", "IGI", " I "], {"I": "minecraft:iron_ingot", "G": "minecraft:glowstone"}),
    ],
)

# 11. Frost & Ice Arsenal
add_hmod(
    "ice-kingdom",
    "ice_kingdom",
    "Frost Arsenal",
    "Ледяной арсенал: клинок мороза, ледяной топор, метательная ледяная звезда и светящийся кристальный лёд.",
    "Frost Arsenal",
    "ice_kingdom:frost_blade",
    items=[
        {"id": "frost_blade", "ru": "Клинок мороза", "en": "Frost Blade", "template": "minecraft:diamond_sword", "rarity": "epic", "stack": 1, "sprite": "sword", "c1": (108, 228, 255), "c2": (232, 250, 255), "handheld": True},
        {"id": "frost_axe", "ru": "Морозный топор", "en": "Frost Axe", "template": "minecraft:diamond_axe", "rarity": "rare", "stack": 1, "sprite": "axe", "c1": (108, 228, 255), "c2": (210, 245, 255), "handheld": True},
        {"id": "ice_star", "ru": "Ледяная звезда", "en": "Ice Star", "template": "minecraft:snowball", "rarity": "rare", "stack": 32, "sprite": "shuriken", "c1": (132, 238, 255), "c2": (255, 255, 255), "handheld": False},
    ],
    blocks=[
        {"id": "crystal_ice", "ru": "Кристальный лёд", "en": "Crystal Ice", "template": "minecraft:blue_ice", "props": {"hardness": 2.2, "friction": 0.98, "light": 13}, "sprite": "lamp", "c1": (148, 242, 255), "c2": (58, 138, 235)},
    ],
    throwables=[
        {"id": "ice_star", "item": "ice_kingdom:ice_star", "damage": 5.5},
    ],
    recipes=[
        shaped_recipe("ice_kingdom:frost_blade", 1, ["I", "D", "S"], {"I": "minecraft:blue_ice", "D": "minecraft:diamond", "S": "minecraft:stick"}),
        shaped_recipe("ice_kingdom:frost_axe", 1, ["ID", "IS", " S"], {"I": "minecraft:blue_ice", "D": "minecraft:diamond", "S": "minecraft:stick"}),
        shaped_recipe("ice_kingdom:ice_star", 8, [" I ", "I I", " I "], {"I": "minecraft:packed_ice"}),
        shaped_recipe("ice_kingdom:crystal_ice", 4, [" I ", "IGI", " I "], {"I": "minecraft:packed_ice", "G": "minecraft:glowstone"}),
    ],
)

# 12. Golden Artifacts
add_hmod(
    "golden-artifacts",
    "golden_artifacts",
    "Golden Artifacts",
    "Золотые артефакты: позолоченный меч, священный метательный диск, солнечное яблоко и сияющий солнечный блок.",
    "Golden Artifacts",
    "golden_artifacts:gilded_blade",
    items=[
        {"id": "gilded_blade", "ru": "Позолоченный клинок", "en": "Gilded Blade", "template": "minecraft:netherite_sword", "rarity": "epic", "stack": 1, "sprite": "sword", "c1": (255, 208, 52), "c2": (255, 250, 198), "handheld": True},
        {"id": "solar_disc", "ru": "Солнечный диск", "en": "Solar Disc", "template": "minecraft:snowball", "rarity": "epic", "stack": 16, "sprite": "shuriken", "c1": (255, 218, 58), "c2": (255, 128, 32), "handheld": False},
        {"id": "sun_apple", "ru": "Солнечное яблоко", "en": "Sun Apple", "template": "minecraft:enchanted_golden_apple", "rarity": "epic", "stack": 16, "sprite": "food", "c1": (255, 198, 42), "c2": (255, 252, 180), "handheld": False},
    ],
    blocks=[
        {"id": "solar_block", "ru": "Солнечный блок", "en": "Solar Block", "template": "minecraft:gold_block", "props": {"hardness": 4.0, "light": 15}, "sprite": "lamp", "c1": (255, 224, 72), "c2": (218, 128, 22)},
    ],
    throwables=[
        {"id": "solar_disc", "item": "golden_artifacts:solar_disc", "damage": 7.0},
    ],
    recipes=[
        shaped_recipe("golden_artifacts:gilded_blade", 1, [" G ", "GDG", " S "], {"G": "minecraft:gold_ingot", "D": "minecraft:diamond_sword", "S": "minecraft:blaze_rod"}),
        shaped_recipe("golden_artifacts:solar_disc", 4, [" G ", "GDG", " G "], {"G": "minecraft:gold_ingot", "D": "minecraft:diamond"}),
        shaped_recipe("golden_artifacts:sun_apple", 1, ["GGG", "GAG", "GGG"], {"G": "minecraft:gold_block", "A": "minecraft:apple"}),
        shaped_recipe("golden_artifacts:solar_block", 2, [" G ", "GOG", " G "], {"G": "minecraft:gold_ingot", "O": "minecraft:glowstone"}),
    ],
)


def main() -> None:
    assert len(HMODS) == 12, f"Expected 12 hmods, got {len(HMODS)}"
    MODS_ROOT.mkdir(parents=True, exist_ok=True)

    for m in HMODS:
        ns = m["mod_id"]
        work = SRC_HMODS / m["slug"]
        if work.exists():
            shutil.rmtree(work)
        work.mkdir(parents=True, exist_ok=True)

        toml_txt = (
            f'id = "{ns}"\n'
            f'name = "{m["name"]}"\n'
            f'description = "{m["description"]}"\n'
            f'version = "1.0.0"\n'
            f'api = "0.2"\n'
            f'side = "both"\n'
            f'capabilities = ["registries"]\n'
            f'experimental = ["registries"]\n'
        )
        (work / "horizon-mod.toml").write_text(toml_txt, encoding="utf-8", newline="\n")

        lang_ru: dict[str, str] = {}
        lang_en: dict[str, str] = {}
        tab_items: list[str] = []

        # Items
        for it in m["items"]:
            iid = it["id"]
            tab_items.append(f"{ns}:{iid}")
            lang_ru[f"item.{ns}.{iid}"] = it["ru"]
            lang_en[f"item.{ns}.{iid}"] = it["en"]

            item_def = {
                "template": it["template"],
                "rarity": it["rarity"],
                "max_stack_size": it["stack"],
            }
            p_def = work / "data" / ns / "horizon" / "item" / f"{iid}.json"
            p_def.parent.mkdir(parents=True, exist_ok=True)
            p_def.write_text(json.dumps(item_def, indent=2), encoding="utf-8", newline="\n")

            # Texture + model + 26.3 client item def
            rgba = draw_sprite_16(it["sprite"], it["c1"], it["c2"])
            write_png_rgba(work / "assets" / ns / "textures" / "item" / f"{iid}.png", 16, 16, rgba)

            parent_m = "minecraft:item/handheld" if it.get("handheld") else "minecraft:item/generated"
            p_mod = work / "assets" / ns / "models" / "item" / f"{iid}.json"
            p_mod.parent.mkdir(parents=True, exist_ok=True)
            p_mod.write_text(
                json.dumps({"parent": parent_m, "textures": {"layer0": f"{ns}:item/{iid}"}}, indent=2),
                encoding="utf-8",
                newline="\n",
            )

            p_ci = work / "assets" / ns / "items" / f"{iid}.json"
            p_ci.parent.mkdir(parents=True, exist_ok=True)
            p_ci.write_text(
                json.dumps({"model": {"type": "minecraft:model", "model": f"{ns}:item/{iid}"}}, indent=2),
                encoding="utf-8",
                newline="\n",
            )

        # Blocks
        for bl in m["blocks"]:
            bid = bl["id"]
            tab_items.append(f"{ns}:{bid}")
            lang_ru[f"block.{ns}.{bid}"] = bl["ru"]
            lang_en[f"block.{ns}.{bid}"] = bl["en"]
            lang_ru[f"item.{ns}.{bid}"] = bl["ru"]
            lang_en[f"item.{ns}.{bid}"] = bl["en"]

            bl_def = {"template": bl["template"], "properties": bl["props"]}
            p_def = work / "data" / ns / "horizon" / "block" / f"{bid}.json"
            p_def.parent.mkdir(parents=True, exist_ok=True)
            p_def.write_text(json.dumps(bl_def, indent=2), encoding="utf-8", newline="\n")

            rgba = draw_sprite_16(bl["sprite"], bl["c1"], bl["c2"])
            write_png_rgba(work / "assets" / ns / "textures" / "block" / f"{bid}.png", 16, 16, rgba)

            p_bs = work / "assets" / ns / "blockstates" / f"{bid}.json"
            p_bs.parent.mkdir(parents=True, exist_ok=True)
            p_bs.write_text(
                json.dumps({"variants": {"": {"model": f"{ns}:block/{bid}"}}}, indent=2),
                encoding="utf-8",
                newline="\n",
            )

            p_bm = work / "assets" / ns / "models" / "block" / f"{bid}.json"
            p_bm.parent.mkdir(parents=True, exist_ok=True)
            p_bm.write_text(
                json.dumps({"parent": "minecraft:block/cube_all", "textures": {"all": f"{ns}:block/{bid}"}}, indent=2),
                encoding="utf-8",
                newline="\n",
            )

            p_im = work / "assets" / ns / "models" / "item" / f"{bid}.json"
            p_im.parent.mkdir(parents=True, exist_ok=True)
            p_im.write_text(json.dumps({"parent": f"{ns}:block/{bid}"}, indent=2), encoding="utf-8", newline="\n")

            p_ci = work / "assets" / ns / "items" / f"{bid}.json"
            p_ci.parent.mkdir(parents=True, exist_ok=True)
            p_ci.write_text(
                json.dumps({"model": {"type": "minecraft:model", "model": f"{ns}:block/{bid}"}}, indent=2),
                encoding="utf-8",
                newline="\n",
            )

        # Throwable entity types
        for th in m["throwables"]:
            p_et = work / "data" / ns / "horizon" / "entity_type" / f"{th['id']}.json"
            p_et.parent.mkdir(parents=True, exist_ok=True)
            p_et.write_text(
                json.dumps({"template": "minecraft:snowball", "item": th["item"], "damage": th["damage"]}, indent=2),
                encoding="utf-8",
                newline="\n",
            )

        # Creative tab
        p_ct = work / "data" / ns / "horizon" / "creative_tab" / "main.json"
        p_ct.parent.mkdir(parents=True, exist_ok=True)
        p_ct.write_text(
            json.dumps({"title": m["tab_title"], "icon": m["icon_item"], "items": tab_items}, indent=2),
            encoding="utf-8",
            newline="\n",
        )

        # Recipes
        for rec in m["recipes"]:
            p_r = work / "data" / ns / "recipe" / f"{rec['name']}.json"
            p_r.parent.mkdir(parents=True, exist_ok=True)
            p_r.write_text(json.dumps(rec["body"], indent=2), encoding="utf-8", newline="\n")

        # Languages
        p_lang = work / "assets" / ns / "lang"
        p_lang.mkdir(parents=True, exist_ok=True)
        (p_lang / "ru_ru.json").write_text(json.dumps(lang_ru, ensure_ascii=False, indent=2), encoding="utf-8", newline="\n")
        (p_lang / "en_us.json").write_text(json.dumps(lang_en, ensure_ascii=False, indent=2), encoding="utf-8", newline="\n")

        # Zip into mods/<slug>.hmod
        out_hmod = MODS_ROOT / m["file_name"]
        with zipfile.ZipFile(out_hmod, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
            for f in sorted(work.rglob("*")):
                if f.is_file():
                    zf.writestr(f.relative_to(work).as_posix(), f.read_bytes())

        print(f"[OK] Built {m['file_name']} ({out_hmod.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
