"""Native shot diagnostics using the actual controller, server and movement probes."""
import json
from pathlib import Path
import subprocess
import sys
from build_combat_range import generate

ROOT = Path(__file__).resolve().parents[1]


def main():
    generate()
    out = ROOT / "build/slide-shot"
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
    text = fixture.read_text(encoding="utf-8").replace(
        "target.Anchored = true", "target.Anchored = true\ntarget.CanCollide = false"
    )
    needle = "remote.OnServerInvoke = function(player: Player, distance: any, dark: any, height: any)"
    reset = """
    if distance == "Reset" then
        local root = (player.Character :: Model):WaitForChild("HumanoidRootPart") :: BasePart
        root.CFrame = CFrame.new(0, 3, 30)
        root.AssemblyLinearVelocity = Vector3.zero
        return Vector3.zero
    end"""
    assert needle in text, "fixture signature changed"
    fixture.write_text(text.replace(needle, needle + reset), encoding="utf-8")
    project["name"] = "SlugshotShootingFeelCheck"
    project["tree"]["StarterPlayer"]["StarterPlayerScripts"]["ShotConsistencyCheck"] = {
        "$path": str(ROOT / "tools/studio/slide-shot-check.client.luau")
    }
    project["tree"]["ServerScriptService"]["ShootingFeelFixture"] = {
        "$path": str(fixture)
    }
    project["tree"]["ServerScriptService"]["ShotConsistencyPhysics"] = {
        "$path": str(ROOT / "tools/studio/shot-consistency-physics.server.luau")
    }
    if "--baseline" in sys.argv:
        baseline = out / "baseline.client.luau"
        baseline.write_bytes(subprocess.check_output(
            ["git", "show", "9f99b67:experiments/combat/client/CombatClient.client.luau"], cwd=ROOT
        ))
        project["tree"]["StarterPlayer"]["StarterPlayerScripts"]["Combat"]["CombatClient"] = {
            "$path": str(baseline)
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
