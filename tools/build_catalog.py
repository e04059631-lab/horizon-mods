"""Generates catalog.json and README.md for 27 native WGSL shaders + 30 curated Modrinth PvP resource packs."""

import json
import math
from pathlib import Path

from build_shaders import SHADERS

ROOT = Path(__file__).resolve().parent.parent
MODS_ROOT = ROOT / "mods"
ICONS_ROOT = ROOT / "icons"
MODRINTH_PACKS_FILE = Path(__file__).resolve().parent / "modrinth_pvp_packs.json"


def main() -> None:
    entries: list[dict] = []

    # 1: Flagship Motion Blur shader
    mb_path = MODS_ROOT / "motion-blur.hshader"
    entries.append(
        {
            "id": "motion-blur",
            "name": "Motion Blur",
            "description": "Плавное размытие в движении для Horizon 26.3 с адаптацией под 144 Гц и настройками силы и качества в игре.",
            "version": "1.0.0",
            "kind": "shader",
            "file_name": "motion-blur.hshader",
            "download_url": "mods/motion-blur.hshader",
            "icon_url": "icons/motion-blur.png?v=3",
            "size_kb": max(1, math.ceil(mb_path.stat().st_size / 1024)),
        }
    )

    # 2..27: Native WGSL Shaders
    for sh in SHADERS:
        fpath = MODS_ROOT / sh["file_name"]
        ipath = ICONS_ROOT / f"{sh['id']}.png"
        assert fpath.exists(), f"Missing {fpath}"
        assert ipath.exists(), f"Missing icon {ipath}"
        entries.append(
            {
                "id": sh["id"],
                "name": sh["name"],
                "description": sh["description"],
                "version": "1.0.0",
                "kind": "shader",
                "file_name": sh["file_name"],
                "download_url": f"mods/{sh['file_name']}",
                "icon_url": f"icons/{sh['id']}.png?v=3",
                "size_kb": max(1, math.ceil(fpath.stat().st_size / 1024)),
            }
        )

    # 28..57: 30 Curated Modrinth PvP & Combat Resource Packs (direct cdn.modrinth.com downloads)
    mr_packs = json.loads(MODRINTH_PACKS_FILE.read_text(encoding="utf-8"))
    for p in mr_packs:
        if not p["icon_url"].startswith("http"):
            ipath = ROOT / p["icon_url"].split("?", 1)[0]
            assert ipath.exists(), f"Missing converted Modrinth icon {ipath}"
        entries.append(
            {
                "id": p["id"],
                "name": p["name"],
                "description": p["description"],
                "version": p["version"],
                "kind": "resourcepack",
                "file_name": p["file_name"],
                "download_url": p["download_url"],
                "icon_url": p["icon_url"],
                "size_kb": p["size_kb"],
            }
        )

    shader_count = sum(1 for e in entries if e["kind"] == "shader")
    rp_count = sum(1 for e in entries if e["kind"] == "resourcepack")
    assert shader_count == 27 and rp_count >= 100, f"Unexpected counts: {shader_count} shaders, {rp_count} packs"

    catalog = {"version": 1, "mods": entries}
    (ROOT / "catalog.json").write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )

    lines = [
        "# Horizon Mods & Shaders Catalog (26.3)",
        "",
        "Официальный онлайн-каталог для **Horizon Offline Launcher (Minecraft 26.3)**:",
        f"**{shader_count} нативных WGSL-шейдеров** (`.hshader`) и **{rp_count} популярных PvP/Combat ресурс-паков с Modrinth** (`.zip`, прямая загрузка с `cdn.modrinth.com`).",
        "Все дополнения работают **на 100% на стороне клиента** — и в одиночном мире, и на любом сервере.",
        "",
        f"## Нативные WGSL-шейдеры ({shader_count})",
        "",
        "| Превью | Название | Файл | Описание |",
        "| :---: | :--- | :--- | :--- |",
    ]
    for e in entries:
        if e["kind"] == "shader":
            clean_icon = e["icon_url"].split("?", 1)[0]
            lines.append(
                f'| <img src="{clean_icon}" width="40" height="40" /> | **{e["name"]}** | `{e["file_name"]}` | {e["description"]} |'
            )

    lines += [
        "",
        f"## Ресурс-паки с Modrinth ({rp_count} шт. — топ-100 показаны ниже, все {rp_count} доступны в лаунчере и `catalog.json`)",
        "",
        "| Иконка | Название | Modrinth | Описание |",
        "| :---: | :--- | :--- | :--- |",
    ]
    rp_shown = 0
    for e in entries:
        if e["kind"] == "resourcepack":
            if rp_shown >= 100:
                continue
            clean_icon = e["icon_url"].split("?", 1)[0]
            mr_link = f"https://modrinth.com/resourcepack/{e['id']}"
            lines.append(
                f'| <img src="{clean_icon}" width="40" height="40" /> | **{e["name"]}** | [{e["id"]}]({mr_link}) | {e["description"]} |'
            )
            rp_shown += 1
    if rp_count > rp_shown:
        lines.append("")
        lines.append(f"*…и ещё **{rp_count - rp_shown}** проверенных ресурс-паков с Modrinth доступны напрямую во вкладке «Моды» лаунчера (см. [`catalog.json`](catalog.json)).*")

    lines.append("")
    (ROOT / "README.md").write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"[OK] Wrote catalog.json and README.md with {len(entries)} entries ({shader_count} shaders + {rp_count} Modrinth PvP packs)!")


if __name__ == "__main__":
    main()
