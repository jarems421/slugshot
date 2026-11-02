"""Build the lobby scale block-out place (docs/art/lobby-roadmap.md).

The movement server stays unchanged: like the Rocklock build, this writes a generated copy whose spawn
line and fall height come from experiments/lobby/scale/server/LobbySpawns.luau, then runs Rojo.
Output: build/lobby-scale/generated/server and build/SlugshotLobbyScale.rbxlx.
With --check it also builds build/SlugshotLobbyScaleCheck.rbxlx, which adds the walking self-test and
camera tour from experiments/lobby/scale/check. Those stay out of the normal place.
"""
from pathlib import Path
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "build/lobby-scale"
GENERATED = BUILD / "generated/server"
PROJECT = ROOT / "lobby-scale.private.project.json"
PLACE = ROOT / "build/SlugshotLobbyScale.rbxlx"
CHECK_PROJECT = BUILD / "check.project.json"
CHECK_PLACE = ROOT / "build/SlugshotLobbyScaleCheck.rbxlx"
PATCHES = {
    "character:PivotTo(CFrame.new((player.UserId % 3) * 6 - 6, 5, 30))":
        "character:PivotTo(require(script.LobbySpawns).frameFor(player))",
    "if root.Position.Y < -40 and not state.spawning then":
        "if root.Position.Y < require(script.LobbySpawns).respawnY and not state.spawning then",
}


def rojo_build(project, place):
    subprocess.run(["rojo", "build", str(project), "--output", str(place)], cwd=ROOT, check=True)
    print(f"Built {place}")


def rebase(node):
    # The check project lives two folders below the repository root.
    for key, value in node.items():
        if key == "$path":
            node[key] = f"../../{value}"
        elif isinstance(value, dict) and not key.startswith("$"):
            rebase(value)


def write_check_project():
    project = json.loads(PROJECT.read_text(encoding="utf-8"))
    project["name"] = "SlugshotLobbyScaleCheck"
    tree = project["tree"]
    rebase(tree)
    check = "../../experiments/lobby/scale/check"
    tree["ServerScriptService"]["LobbyScaleCheck"] = {"$path": f"{check}/ScaleCheck.server.luau"}
    tree["StarterPlayer"]["StarterPlayerScripts"]["LobbyScaleTour"] = {"$path": f"{check}/ViewTour.client.luau"}
    CHECK_PROJECT.write_text(json.dumps(project, indent=2), encoding="utf-8")


def main():
    server = (ROOT / "experiments/movement/server/init.server.luau").read_text(encoding="utf-8")
    for upstream, adapter in PATCHES.items():
        assert server.count(upstream) == 1, f"Upstream changed, review the adapter: {upstream}"
        server = server.replace(upstream, adapter)
    GENERATED.mkdir(parents=True, exist_ok=True)
    (GENERATED / "init.server.luau").write_text(server, encoding="utf-8")
    rojo_build(PROJECT, PLACE)
    if "--check" in sys.argv:
        write_check_project()
        rojo_build(CHECK_PROJECT, CHECK_PLACE)


if __name__ == "__main__":
    main()
