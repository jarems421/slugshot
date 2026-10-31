"""Build the private, TEMPORARY slug-shooting target range place (a test space only).

Rojo cannot map a lone init.server.luau, so the unchanged movement server is copied
into an ignored generated folder (as the Rocklock places do); the range's Arena module
is mapped beside it in combat-range.private.project.json.
"""
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / "experiments/movement/server/init.server.luau"
GENERATED = ROOT / "build/combat-range/generated/server"


def generate():
    GENERATED.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(SERVER, GENERATED / "init.server.luau")


def main():
    generate()
    if "--generate-only" in sys.argv:
        return
    subprocess.run(["rojo", "build", "combat-range.private.project.json", "--output", "build/SlugshotTempRange.rbxlx"], cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
