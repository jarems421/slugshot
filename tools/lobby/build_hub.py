"""Build the lobby hub place: the approved block-out plus the final hub art (docs/art/lobby-hub.md).

Reuses the scale place's movement adapter, then runs Rojo on the private hub project.
Output: build/SlugshotLobbyHub.rbxlx. With --check it also builds build/SlugshotLobbyHubCheck.rbxlx, which adds the
performance probe and camera tour from experiments/lobby/hub/check. Those stay out of the normal place.
"""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).parent))
from build_scale import GENERATED, PATCHES, rebase  # noqa: E402

PROJECT = ROOT/"lobby-hub.private.project.json"
PLACE = ROOT/"build/SlugshotLobbyHub.rbxlx"
CHECK_PROJECT = ROOT/"build/lobby-scale/hub-check.project.json"
CHECK_PLACE = ROOT/"build/SlugshotLobbyHubCheck.rbxlx"


def rojo_build(project, place):
    subprocess.run(["rojo", "build", str(project), "--output", str(place)], cwd=ROOT, check=True)
    print(f"Built {place}")


def main():
    server = (ROOT/"experiments/movement/server/init.server.luau").read_text(encoding="utf-8")
    for upstream, adapter in PATCHES.items():
        assert server.count(upstream) == 1, f"Upstream changed, review the adapter: {upstream}"
        server = server.replace(upstream, adapter)
    GENERATED.mkdir(parents=True, exist_ok=True)
    (GENERATED/"init.server.luau").write_text(server, encoding="utf-8")
    rojo_build(PROJECT, PLACE)
    if "--check" in sys.argv:
        project = json.loads(PROJECT.read_text(encoding="utf-8"))
        project["name"] = "SlugshotLobbyHubCheck"
        tree = project["tree"]
        rebase(tree)
        check = "../../experiments/lobby/hub/check"
        tree["StarterPlayer"]["StarterPlayerScripts"]["HubCheck"] = {"$path": f"{check}/HubCheck.client.luau"}
        # The same true-speed walker as the block-out, so the new outlines are walked rather than assumed.
        tree["ServerScriptService"]["LobbyScaleCheck"] = {"$path": "../../experiments/lobby/scale/check/ScaleCheck.server.luau"}
        CHECK_PROJECT.write_text(json.dumps(project, indent=2), encoding="utf-8")
        rojo_build(CHECK_PROJECT, CHECK_PLACE)


if __name__ == "__main__":
    main()
