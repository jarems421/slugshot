"""Build the private range with a disposable Inferno inspection review driver."""
import json
import subprocess
from pathlib import Path
from build_combat_range import generate

ROOT = Path(__file__).resolve().parents[1]


def main():
    generate()
    project = json.loads((ROOT / "combat-range.private.project.json").read_text())
    def absolute(node):
        if isinstance(node, dict):
            for key, value in node.items():
                if key == "$path":
                    node[key] = str(ROOT / value)
                else:
                    absolute(value)
    absolute(project)
    project["name"] = "SlugshotInfernoInspectCheck"
    project["tree"]["StarterPlayer"]["StarterPlayerScripts"]["InspectCheck"] = {
        "$path": str(ROOT / "tools/studio/inferno-inspect-check.client.luau")}
    out = ROOT / "build/inferno-inspect/check.private.project.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(project, indent=2))
    subprocess.run(["rojo", "build", str(out), "--output", "build/SlugshotInfernoInspectCheck.rbxlx"], cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
