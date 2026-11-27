"""Generates catalog.json and README.md for all 27 native WGSL shaders."""

import json
import math
from pathlib import Path

from build_shaders import SHADERS

ROOT = Path(__file__).resolve().parent.parent
MODS_ROOT = ROOT / "mods"
ICONS_ROOT = ROOT / "icons"


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

    assert len(entries) == 27, f"Expected 27 shader entries, got {len(entries)}"

    catalog = {"version": 1, "mods": entries}
    (ROOT / "catalog.json").write_text(
        json.dumps(catalog, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )

    lines = [
        "# Horizon Shaders Catalog (26.3)",
        "",
        "Официальный онлайн-каталог нативных WGSL-шейдеров для **Horizon Offline Launcher (Minecraft 26.3)**.",
        "Все шейдеры работают **на 100% на стороне клиента** — и в одиночном мире, и на любом сервере, с поддержкой объединения нескольких шейдеров одновременно.",
        "",
        f"**Всего в каталоге: {len(entries)} нативных `.hshader` WGSL-шейдеров.**",
        "",
        "| Превью | Название | Файл | Описание |",
        "| :---: | :--- | :--- | :--- |",
    ]
    for e in entries:
        clean_icon = e["icon_url"].split("?", 1)[0]
        lines.append(
            f'| <img src="{clean_icon}" width="40" height="40" /> | **{e["name"]}** | `{e["file_name"]}` | {e["description"]} |'
        )

    lines.append("")
    (ROOT / "README.md").write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print(f"[OK] Wrote catalog.json and README.md with {len(entries)} native WGSL shaders!")


if __name__ == "__main__":
    main()
