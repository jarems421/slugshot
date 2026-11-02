"""Native shot diagnostics using the actual controller, server and movement probes."""
import json
from pathlib import Path
import subprocess
from build_combat_range import generate

ROOT = Path(__file__).resolve().parents[1]


def main():
    generate()
    out = ROOT / "build/shot-consistency"
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
    fixture = out / "fixture.server.luau"
    fixture.write_text(
        (ROOT / "tools/studio/shooting-feel-fixture.server.luau")
        .read_text(encoding="utf-8")
        .replace("distance <= 150", "distance <= 250"),
        encoding="utf-8",
    )
    project["name"] = "SlugshotShootingFeelCheck"
    project["tree"]["StarterPlayer"]["StarterPlayerScripts"]["ShotConsistencyCheck"] = {
        "$path": str(ROOT / "tools/studio/shot-consistency-check.client.luau")
    }
    project["tree"]["ServerScriptService"]["ShootingFeelFixture"] = {
        "$path": str(fixture)
    }
    project["tree"]["ServerScriptService"]["ShotConsistencyPhysics"] = {
        "$path": str(ROOT / "tools/studio/shot-consistency-physics.server.luau")
    }
    path = out / "check.private.project.json"
    path.write_text(json.dumps(project, indent=2), encoding="utf-8")
    subprocess.run(
        ["rojo", "build", str(path), "--output", "build/SlugshotShootingFeelCheck.rbxlx"],
        cwd=ROOT,
        check=True,
    )


if __name__ == "__main__":
    main()
