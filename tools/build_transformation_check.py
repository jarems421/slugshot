"""Disposable transformation review place: the private combat range plus its review script and target fixture."""
import json
from pathlib import Path
import subprocess
from build_combat_range import generate

ROOT = Path(__file__).resolve().parents[1]


def main():
    generate()
    out = ROOT / "build/transformation-check"
    out.mkdir(parents=True, exist_ok=True)
    project = json.loads((ROOT / "combat-range.private.project.json").read_text(encoding="utf-8"))

    def absolute(node):
        if isinstance(node, dict):
            for key, value in node.items():
                if key == "$path":
                    node[key] = str(ROOT / value)
                else:
                    absolute(value)

    absolute(project)
    project["name"] = "SlugshotTransformationCheck"
    project["tree"]["StarterPlayer"]["StarterPlayerScripts"]["TransformationCheck"] = {
        "$path": str(ROOT / "tools/studio/transformation-check.client.luau")
    }
    project["tree"]["ServerScriptService"]["ShootingFeelFixture"] = {
        "$path": str(ROOT / "tools/studio/shooting-feel-fixture.server.luau")
    }
    path = out / "check.private.project.json"
    path.write_text(json.dumps(project, indent=2), encoding="utf-8")
    subprocess.run(
        ["rojo", "build", str(path), "--output", "build/SlugshotTransformationCheck.rbxlx"],
        cwd=ROOT,
        check=True,
    )


if __name__ == "__main__":
    main()
