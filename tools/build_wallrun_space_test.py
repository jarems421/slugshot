"""Build a disposable native wall-run regression place, without private assets.
Run Play in the generated place; the fixture drives the Studio-only input probe.
"""
import json
from pathlib import Path
import shutil
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build/wallrun-space"


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    arena = OUT / "Arena.luau"
    arena.write_text("""local Arena = {}
function Arena.create()
 local model = Instance.new("Model"); model.Name = "WallRunSpaceFixture"
 for _, d in {{"Floor", Vector3.new(900,2,80), Vector3.new(0,-1,20)},
              {"TallWall", Vector3.new(900,100,2), Vector3.new(0,50,26)}} do
  local p = Instance.new("Part"); p.Name=d[1]; p.Size=d[2]; p.Position=d[3]; p.Anchored=true; p.Parent=model
 end
 model.Parent=workspace; return model
end
return Arena
""")
    project = json.loads((ROOT / "movement.test.project.json").read_text())
    def absolute_paths(node):
        if isinstance(node, dict):
            for key, value in node.items():
                if key == "$path":
                    node[key] = str(ROOT / value)
                else:
                    absolute_paths(value)
    absolute_paths(project)
    server = OUT / "server"
    server.mkdir(exist_ok=True)
    shutil.copyfile(ROOT / "experiments/movement/server/init.server.luau", server / "init.server.luau")
    project["name"] = "SlugshotWallRunSpaceRegression"
    project["tree"]["ServerScriptService"]["MovementSandbox"] = {
        "$path": str(server), "Arena": {"$path": str(arena)}}
    driver = OUT / "Probe.client.luau"
    shutil.copyfile(ROOT / "tools/studio/wallrun-space-regression.luau", driver)
    project["tree"]["StarterPlayer"]["StarterPlayerScripts"]["WallRunSpaceProbe"] = {
        "$path": str(driver)}
    target = OUT / "test.project.json"
    target.write_text(json.dumps(project, indent=2))
    subprocess.run(["rojo", "build", str(target), "--output",
                    str(ROOT / "build/SlugshotWallRunSpaceRegression.rbxlx")], cwd=ROOT, check=True)
    tree = ET.parse(ROOT / "build/SlugshotWallRunSpaceRegression.rbxlx")
    drivers = [item for item in tree.iter("Item")
               if item.findtext("Properties/string[@name='Name']") == "WallRunSpaceProbe"]
    assert len(drivers) == 1 and drivers[0].get("class") == "LocalScript", "Regression driver must execute on the client"



if __name__ == "__main__":
    main()
