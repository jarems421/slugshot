--!strict
-- Check build only: a short look at chosen views, logging real render costs at each. Output lines start with HUBCHECK.
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")

local STOPS: { { name: string, from: Vector3, at: Vector3 } } = {
	{ name = "top", from = Vector3.new(6, 42, 36), at = Vector3.new(0, 0, 4) },
	{ name = "player", from = Vector3.new(12, 11, -2), at = Vector3.new(14, 0, -18) },
	{ name = "low", from = Vector3.new(4, 7, 20), at = Vector3.new(16, 0, 8) },
	{ name = "close", from = Vector3.new(-14, 5, 8), at = Vector3.new(-18, 0, -1) },
}

local function read(name: string): number
	local ok, value = pcall(function()
		return (Stats :: any)[name]
	end)
	return if ok and typeof(value) == "number" then value else -1
end

task.spawn(function()
	local player = Players.LocalPlayer
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	while not workspace:FindFirstChild("HubArt") do
		task.wait(0.5)
	end
	task.wait(12)
	print("HUBCHECK tour starts")
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	for _, stop in STOPS do
		camera.CFrame = CFrame.lookAt(stop.from, stop.at)
		task.wait(2)
		print(
			string.format(
				"HUBCHECK %s tris=%d draws=%d texMB=%.0f meshMB=%.0f",
				stop.name,
				read("SceneTriangleCount"),
				read("SceneDrawcallCount"),
				Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsTexture),
				Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsMeshParts)
			)
		)
		print(`HUBCHECK shot {stop.name}`)
		task.wait(1)
	end
	camera.CameraType = Enum.CameraType.Custom
	print("HUBCHECK tour ends")
end)
