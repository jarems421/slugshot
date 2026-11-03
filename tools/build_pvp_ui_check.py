"""Build the range with a small script that walks the PvP UI, so an agent can capture it without a mouse."""
import json
from pathlib import Path
import subprocess

from build_combat_range import generate

ROOT = Path(__file__).resolve().parents[1]


def main():
    generate()
    project = json.loads((ROOT / "combat-range.private.project.json").read_text(encoding="utf-8"))
    scripts = project["tree"]["StarterPlayer"]["StarterPlayerScripts"]
    scripts["UiCheck"] = {"$path": "tools/studio/pvp-ui-check.client.luau"}
    path = ROOT / "ui-check.generated.project.json"
    path.write_text(json.dumps(project, indent=2), encoding="utf-8")
    try:
        subprocess.run(["rojo", "build", path.name, "--output", "build/SlugshotUiCheck.rbxlx"], cwd=ROOT, check=True)
    finally:
        path.unlink()


if __name__ == "__main__":
    main()
