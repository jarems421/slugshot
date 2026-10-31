"""Verify the slug-shooting experiment (offline: formatting, lint, strict types, builds).

Runtime behaviour is checked in Studio: the target range's CombatSelfTest writes
[CombatSelfTest] PASS/FAIL lines to the Studio log, and feel is the owner's playtest.
"""
from pathlib import Path
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from verify_movement import definitions  # noqa: E402
from build_combat_range import generate  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
PRIVATE = ROOT / "private-assets"


def run(*args):
    print("+ " + " ".join(args), flush=True)
    subprocess.run(args, cwd=ROOT, check=True)


def main():
    run(sys.executable, "tools/verify_movement.py")
    run("stylua", "--check", "experiments/combat")
    run("selene", "experiments/combat")
    generate()
    run("rojo", "sourcemap", "combat-range.private.project.json", "--output", "build/combat.sourcemap.json")
    run("luau-lsp", "analyze", f"--definitions=@roblox={definitions().relative_to(ROOT).as_posix()}",
        "--sourcemap=build/combat.sourcemap.json", "experiments/combat")
    if PRIVATE.exists():
        run("rojo", "build", "combat-range.private.project.json", "--output", "build/SlugshotTempRange.rbxlx")
        run("rojo", "build", "rocklock-unified.private.project.json", "--output", "build/SlugshotRocklockUnified.rbxlx")
    else:
        print("SKIP: private place builds need the ignored private-assets folder")
    print("PASS: combat formatting, lint, strict types and place builds")


if __name__ == "__main__":
    try:
        main()
    except (AssertionError, subprocess.CalledProcessError, OSError, ValueError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
