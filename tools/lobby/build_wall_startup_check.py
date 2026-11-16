"""Build an isolated production upper-wall lighting and satchel check.

Uses the real wall loader, original materials and light rig.
Checks native camera focus through lobby/training transitions without a lobby tour.
Pass --baked-fill for the unaccepted material experiment; it never enters normal builds.
All test source and place output stay under ignored build/.
"""
import json
from pathlib import Path
import subprocess
import sys
from build_wall_materials import generate as wall_materials

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "build/lobby/wall-startup"

SERVER = '''
lighting()
sceneLights()
wallCrystalLights()
local calibration = loadPiece("hub-rock")
if calibration then calibration:Destroy() end
for _, key in { "hub-cavern-07", "hub-cavern-08", "hub-cavern-09" } do
    place(key)
end
workspace:SetAttribute("WallLightCheckReady", true)
'''

CLIENT = '''--!strict
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn, gui.IgnoreGuiInset = "SatchelReview", false, true
gui.Parent = player:WaitForChild("PlayerGui")
local image = Instance.new("ImageLabel")
image.Name = "Satchel"
image.Size, image.Position = UDim2.fromOffset(36, 36), UDim2.fromOffset(30, 80)
image.BackgroundTransparency = 1
local art = require(ReplicatedStorage:WaitForChild("GooArt")) :: any
image.Image = "rbxassetid://" .. tostring(art.iconInventory)
image.Parent = gui
local originalView = CFrame.lookAt(Vector3.new(0, 90, -55), Vector3.new(0, 105, -295))
local view = originalView
local kind = Enum.CameraType.Custom
local scriptedFocus: CFrame? = nil
RunService:BindToRenderStep("WallReviewCamera", Enum.RenderPriority.Camera.Value + 10, function()
    local camera = workspace.CurrentCamera
    if camera then
        camera.CameraType = kind
        camera.CFrame = view
        if scriptedFocus then camera.Focus = scriptedFocus end
    end
end)
local function check(ok: boolean, label: string)
    print("TRAINCHECK " .. (if ok then "PASS " else "FAIL ") .. label)
end
local began = os.clock()
while not workspace:GetAttribute("WallLightCheckReady") and os.clock() - began < 100 do task.wait(0.1) end
task.wait(12)
local camera = workspace.CurrentCamera :: Camera
check(workspace:GetAttribute("WallLightCheckReady") == true, "real wall setup completes")
check(image.IsLoaded, "uploaded satchel renders at HUD size")
check(workspace:GetAttribute("HubWallCrystalLightsReady") == true, "crystal pools exist before wall setup completes")
local baked = __BAKED__
local fills = 0
for _, instance in workspace:GetDescendants() do
    if instance:IsA("SurfaceAppearance") and instance:GetAttribute("CavernWallFill") then
        if math.abs(instance.EmissiveStrength - 0.35) < 0.001 and instance.EmissiveMaskContent.Uri ~= "" then fills += 1 end
    end
end
print("TRAINCHECK wall fill count " .. tostring(fills))
if baked then
    check(fills == 3, "all three real upper walls carry experimental fill")
else
    check(fills == 0, "baseline retains original wall materials")
end
check((camera.CFrame.Position - view.Position).Magnitude < 0.01, "wall check leaves view position unchanged")
check(math.abs(camera.Focus.Position.Y - 125) < 0.01, "upper view receives cavern lighting focus")
view = CFrame.lookAt(Vector3.new(0, 90, -55), Vector3.new(0, 25.7, -295))
task.wait(1)
check(math.abs(camera.Focus.Position.Y - 125) < 0.01, "default downward pitch warms upper wall")
view = originalView
task.wait(1)
print("TRAINCHECK capture production-focus")
task.wait(2)
player:SetAttribute("InTraining", true)
task.wait(1)
check(camera.Focus.Position.Y < 20, "training restores native focus")
player:SetAttribute("InTraining", false)
task.wait(2)
check(math.abs(camera.Focus.Position.Y - 125) < 0.01, "lobby return restores cavern focus")
print("TRAINCHECK capture lobby-return")
task.wait(2)
view = CFrame.lookAt(Vector3.new(0, 90, -55), Vector3.new(0, -70, -100))
task.wait(1)
check(camera.Focus.Position.Y < 20, "downward view retains lower lighting focus")
kind = Enum.CameraType.Scriptable
scriptedFocus = CFrame.new(0, 17, -140)
task.wait(1)
check(math.abs(camera.Focus.Position.Y - 17) < 0.01, "scriptable camera retains its own focus")
kind = Enum.CameraType.Custom
scriptedFocus = nil
view = originalView
task.wait(2)
print("TRAINCHECK capture final-source-focus")
task.wait(1)
print("TRAINCHECK done")
'''



def main():
    OUT.mkdir(parents=True, exist_ok=True)
    project = json.loads((ROOT / "build/training/game/game.project.json").read_text())
    tree = project["tree"]
    project["name"] = "SlugshotLobbyTrainingCheck"
    original = (ROOT / "experiments/lobby/hub/server/HubArt.server.luau").read_text(encoding="utf-8")
    prefix, _ = original.rsplit("\nlighting()\n", 1)
    server = OUT / "Wall.server.luau"
    client = OUT / "Wall.client.luau"
    baked = "--baked-fill" in sys.argv
    if baked:
        source = Path(tree["ServerStorage"]["HubMaterials"]["$path"])
        materials = OUT / "experimental-wall-materials.rbxmx"
        wall_materials(source, materials)
        tree["ServerStorage"]["HubMaterials"]["$path"] = str(materials)
        marker = "\tLookPack.styleModel(model, key, groups, templates, GLOW[key] or 1.0)\n"
        adapter = marker + '''
    if string.sub(key, 1, 11) == "hub-cavern-" then
        local high = model:FindFirstChild("High", true)
        local surface = high and high:FindFirstChildOfClass("SurfaceAppearance")
        if surface then
            surface.EmissiveStrength = 0.35
            surface.EmissiveTint = Color3.fromRGB(110, 150, 255)
            surface:SetAttribute("CavernWallFill", true)
        end
    end
'''
        assert prefix.count(marker) == 1
        prefix = prefix.replace(marker, adapter)
    server.write_text(prefix + "\n" + SERVER, encoding="utf-8")
    client.write_text(CLIENT.replace("__BAKED__", str(baked).lower()), encoding="utf-8")
    services = tree["ServerScriptService"]
    tree["ServerScriptService"] = {
        "$className": "ServerScriptService",
        "HubArt": {"$path": str(server)},
        "FloppyAppearance": services["FloppyAppearance"],
        "InfernoAppearance": services["InfernoAppearance"],
    }
    tree["StarterPlayer"]["StarterPlayerScripts"] = {
        "$className": "StarterPlayerScripts", "WallCheck": {"$path": str(client)},
        "HubMotion": {"$path": str(ROOT / "experiments/lobby/hub/client/HubMotion.client.luau")}}
    tree["Workspace"] = {
        "$className": "Workspace", "$properties": {"Gravity": 0},
        "Spawn": {"$className": "SpawnLocation", "$properties": {
            "Anchored": True, "Size": [20, 1, 20], "Transparency": 1}}}
    path = OUT / "wall.project.json"
    path.write_text(json.dumps(project, indent=2), encoding="utf-8")
    subprocess.run(["rojo", "build", str(path), "--output",
                    str(ROOT / "build/SlugshotLobbyTrainingCheck.rbxlx")], check=True, cwd=ROOT)


if __name__ == "__main__":
    main()
