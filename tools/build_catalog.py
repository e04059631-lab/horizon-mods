"""Generates catalog.json and README.md for all 56 client-side WGSL shaders and PvP/QoL packs."""

import json
import math
from pathlib import Path

from build_shaders import SHADERS
from build_resourcepacks import RESOURCEPACKS

ROOT = Path(__file__).resolve().parent.parent
MODS_ROOT = ROOT / "mods"
ICONS_ROOT = ROOT / "icons"


def main() -> None:
    entries: list[dict] = []

    # 1: Existing Motion Blur (#0 flagship shader)
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
            "icon_url": "icons/motion-blur.png",
            "size_kb": max(1, math.ceil(mb_path.stat().st_size / 1024)),
        }
    )

    # 2..27: WGSL Shaders
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
                "icon_url": f"icons/{sh['id']}.png",
                "size_kb": max(1, math.ceil(fpath.stat().st_size / 1024)),
            }
        )

    # 28..56: PvP & QoL Resourcepacks
    for rp in RESOURCEPACKS:
        fpath = MODS_ROOT / rp["file_name"]
        ipath = ICONS_ROOT / f"{rp['id']}.png"
        assert fpath.exists(), f"Missing {fpath}"
        assert ipath.exists(), f"Missing icon {ipath}"
        entries.append(
            {
                "id": rp["id"],
                "name": rp["name"],
                "description": rp["description"],
                "version": "1.0.0",
                "kind": "resourcepack",
                "file_name": rp["file_name"],
                "download_url": f"mods/{rp['file_name']}",
                "icon_url": f"icons/{rp['id']}.png",
                "size_kb": max(1, math.ceil(fpath.stat().st_size / 1024)),
            }
        )

    assert len(entries) == 56, f"Expected 56 catalog entries, got {len(entries)}"

    catalog = {"version": 1, "mods": entries}
    (ROOT / "catalog.json").write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )

    lines = [
        "# Horizon Mods Catalog (26.3)",
        "",
        "Официальный онлайн-каталог клиентских WGSL-шейдеров и PvP/QoL-паков для **Horizon Offline Launcher (Minecraft 26.3)**.",
        "Все дополнения работают **на 100% на стороне клиента** — и в одиночном мире, и на любом сервере.",
        "",
        f"**Всего в каталоге: {len(entries)} дополнений** (27 нативных `.hshader` WGSL-шейдеров + 29 клиентских `.zip` PvP/QoL-паков).",
        "",
        "## Нативные WGSL-шейдеры (`.hshader`)",
        "",
        "| Иконка | Название | Файл | Описание |",
        "| :---: | :--- | :--- | :--- |",
    ]
    for e in entries:
        if e["kind"] == "shader":
            lines.append(
                f'| <img src="{e["icon_url"]}" width="36" height="36" /> | **{e["name"]}** | `{e["file_name"]}` | {e["description"]} |'
            )

    lines += [
        "",
        "## Клиентские PvP и QoL паки (`.zip` для `resourcepacks/`)",
        "",
        "| Иконка | Название | Файл | Описание |",
        "| :---: | :--- | :--- | :--- |",
    ]
    for e in entries:
        if e["kind"] == "resourcepack":
            lines.append(
                f'| <img src="{e["icon_url"]}" width="36" height="36" /> | **{e["name"]}** | `{e["file_name"]}` | {e["description"]} |'
            )

    lines.append("")
    (ROOT / "README.md").write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"[OK] Wrote catalog.json and README.md with {len(entries)} pure client-side mods!")


if __name__ == "__main__":
    main()
