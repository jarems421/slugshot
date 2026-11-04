"""Build SlugshotLobbyTraining.rbxlx: the lobby with the training arena, its portal, and the guns inside it only.

Starts from the lobby's project and adds the range's combat, so both stay as they are. Generated under ignored build/.
"""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/"tools/lobby"))
from build_scale import PATCHES  # noqa: E402

OUT = ROOT/"build/training/game"
PLACE = ROOT/"build/SlugshotLobbyTraining.rbxlx"
CHECK = ROOT/"build/SlugshotLobbyTrainingCheck.rbxlx"
PATH = "$path"
# The motion check sees the portal's move as a teleport. For a moment after one it just follows the body: the client
# owns its physics, so a sample can still show the old spot, and judging that would snap the player back.
WARP = (
    "local previous = state.position or root.Position",
    'if (player:GetAttribute("TrainingWarpUntil") or 0) > now then\n'
    "\t\tstate.position = root.Position\n"
    "\t\tstate.violations = 0\n"
    "\t\ttable.clear(state.suspects)\n"
    "\t\ttable.clear(state.history)\n"
    "\tend\n"
    "\tlocal previous = state.position or root.Position",
)


def absolute(node):
    for key, value in node.items():
        if key == PATH:
            node[key] = str((ROOT/value).resolve())
        elif isinstance(value, dict) and not key.startswith("$"):
            absolute(value)


def main():
    code = (ROOT/"experiments/movement/server/init.server.luau").read_text(encoding="utf-8")
    for upstream, adapter in [*PATCHES.items(), WARP]:
        assert code.count(upstream) == 1, f"Upstream changed, review the adapter: {upstream}"
        code = code.replace(upstream, adapter)
    server = OUT/"server"
    server.mkdir(parents=True, exist_ok=True)
    (server/"init.server.luau").write_text(code, encoding="utf-8")

    project = json.loads((ROOT/"lobby-hub.private.project.json").read_text(encoding="utf-8"))
    range_tree = json.loads((ROOT/"combat-range.private.project.json").read_text(encoding="utf-8"))["tree"]
    project["name"] = "SlugshotLobbyTraining"
    tree = project["tree"]
    tree["Workspace"]["$properties"]["FallenPartsDestroyHeight"] = -2000

    shared = tree["ReplicatedStorage"]
    for name in ("Combat", "GooArt", "FloppyAsset", "InfernoAsset"):
        shared[name] = range_tree["ReplicatedStorage"][name]
    shared["TrainingFloor"] = {PATH: "experiments/training/shared/floor.json"}

    services = tree["ServerScriptService"]
    services["MovementSandbox"][PATH] = str(server)
    integration = dict(range_tree["ServerScriptService"]["FloppyIntegration"])
    del integration["ReadyBlaster"]  # the arena hands the gun over instead
    services["FloppyIntegration"] = integration
    services["Combat"] = range_tree["ServerScriptService"]["Combat"]
    services["SettingsPersistence"] = range_tree["ServerScriptService"]["SettingsPersistence"]
    services["Training"] = {
        "$className": "Folder",
        "TrainingArena": {PATH: "experiments/training/server/TrainingArena.server.luau"},
        "Motion": {PATH: "experiments/training/server/Motion.luau"},
    }

    scripts = tree["StarterPlayer"]["StarterPlayerScripts"]
    for name in ("RocklockBlaster", "FloppyIdle", "Combat", "FloppyFace", "InfernoMotion"):
        scripts[name] = range_tree["StarterPlayer"]["StarterPlayerScripts"][name]
    scripts["Training"] = {PATH: "experiments/training/client"}

    storage = tree["ServerStorage"]
    for name in ("BlasterMesh", "FloppyMaterials", "InfernoMaterials"):
        storage[name] = range_tree["ServerStorage"][name]
    storage["TrainingLayout"] = {PATH: "build/training/floor/floor-layout.json"}
    storage["TrainingDraft"] = {PATH: "private-assets/training/TrainingDraft.luau"}
    storage["TrainingMaterials"] = {PATH: "private-assets/training/materials.rbxmx"}

    absolute(tree)
    path = OUT/"game.project.json"
    path.write_text(json.dumps(project, indent=2), encoding="utf-8")
    subprocess.run(["rojo", "build", str(path), "--output", str(PLACE)], cwd=ROOT, check=True)
    print(f"Built {PLACE}")
    if "--check" in sys.argv:
        project["name"] = "SlugshotLobbyTrainingCheck"
        scripts["TrainingCheck"] = {PATH: str(ROOT/"experiments/training/check/TrainingCheck.client.luau")}
        services["TrainingCheckHelper"] = {PATH: str(ROOT/"experiments/training/check/CheckHelper.server.luau")}
        path = OUT/"check.project.json"
        path.write_text(json.dumps(project, indent=2), encoding="utf-8")
        subprocess.run(["rojo", "build", str(path), "--output", str(CHECK)], cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
