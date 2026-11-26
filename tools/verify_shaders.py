"""Batch-verifies every .hshader in mods/ by compiling it inside the real Horizon 26.3 client."""

import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
MODS_ROOT = ROOT / "mods"

APPDATA = Path(os.environ["APPDATA"])
GAME_DIR = APPDATA / "horizon-offline-game"
RES_DIR = GAME_DIR / "client" / "26.3" / ".local" / "horizon-client" / "26.3"
CLIENT_EXE = GAME_DIR / "client" / "26.3" / "horizon-client.exe"
SHADER_DIR = GAME_DIR / "shaderpacks"
GFX_PATH = GAME_DIR / "horizon-graphics.txt"
LOG_PATH = GAME_DIR / "logs" / "latest.log"


def main() -> int:
    SHADER_DIR.mkdir(parents=True, exist_ok=True)
    orig_gfx = GFX_PATH.read_text(encoding="utf-8") if GFX_PATH.exists() else "pickedShaderPack:\n"

    shaders = sorted(MODS_ROOT.glob("*.hshader"))
    print(f"=== Verifying {len(shaders)} shader packs in Horizon 26.3 ===", flush=True)

    passed = 0
    failures: list[str] = []

    try:
        for sh in shaders:
            temp_name = f"_v_{sh.name}"
            dest = SHADER_DIR / temp_name
            shutil.copy2(sh, dest)

            if re.search(r"^pickedShaderPack:.*$", orig_gfx, flags=re.M):
                patched = re.sub(
                    r"^pickedShaderPack:.*$",
                    f"pickedShaderPack:{temp_name}",
                    orig_gfx,
                    flags=re.M,
                )
            else:
                patched = orig_gfx.rstrip() + f"\npickedShaderPack:{temp_name}\n"
            GFX_PATH.write_text(patched, encoding="utf-8", newline="\n")

            subprocess.run(
                [
                    str(CLIENT_EXE),
                    "--game-dir",
                    str(GAME_DIR),
                    "--home",
                    str(GAME_DIR),
                    "--resources",
                    str(RES_DIR),
                    "--test-terrain",
                    "--world",
                    "_sh_verify_world",
                    "--world-frames",
                    "18",
                    "--width",
                    "640",
                    "--height",
                    "360",
                ],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=45,
                check=False,
            )

            dest.unlink(missing_ok=True)
            log_text = LOG_PATH.read_text(encoding="utf-8", errors="replace") if LOG_PATH.exists() else ""

            if "refused:" in log_text:
                err = " | ".join(
                    line.strip()
                    for line in log_text.splitlines()
                    if ("refused" in line or "[CHAT]" in line)
                )
                print(f"[FAIL] {sh.name}: {err}", flush=True)
                failures.append(f"{sh.name}: {err}")
            else:
                m = re.findall(r"shader pack .* in \d+ ms", log_text)
                if m:
                    print(f"[PASS] {sh.name} -> {m[-1]}", flush=True)
                    passed += 1
                else:
                    print(f"[WARN] {sh.name}: compile message not found in log", flush=True)
                    failures.append(f"{sh.name}: compile message not found")
    finally:
        GFX_PATH.write_text(orig_gfx, encoding="utf-8", newline="\n")
        shutil.rmtree(GAME_DIR / "saves" / "_sh_verify_world", ignore_errors=True)

    print(f"\n=== RESULT: {passed}/{len(shaders)} PASSED ===", flush=True)
    if failures:
        print("=== FAILURES ===", flush=True)
        for f in failures:
            print(" -", f, flush=True)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
