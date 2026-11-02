--!strict
-- Check build only: a short look at chosen views, logging real render costs at each. Output lines start with HUBCHECK.
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")

local STOPS: { { name: string, from: Vector3, at: Vector3 } } = {
	{ name = "gun", from = Vector3.new(-8, 9, 0), at = Vector3.new(-31, 12.6, 0) },
	{ name = "spawn", from = Vector3.new(0, 9, -12), at = Vector3.new(0, 90, -240) },
	{ name = "pvp", from = Vector3.new(0, 14, -118), at = Vector3.new(0, 24, -161) },
	{ name = "training", from = Vector3.new(-45, 12, -122), at = Vector3.new(-63, 14, -153) },
	{ name = "veylume", from = Vector3.new(45, 12, -122), at = Vector3.new(63, 14, -153) },
	{ name = "pvp2", from = Vector3.new(0, 14, -118), at = Vector3.new(0, 24, -161) },
	{ name = "pvp3", from = Vector3.new(0, 14, -118), at = Vector3.new(0, 24, -161) },
	{ name = "side", from = Vector3.new(-85, 14, -125), at = Vector3.new(-63, 14, -153) },
	{ name = "lavaC", from = Vector3.new(-70, 45, -135), at = Vector3.new(-20, 60, -215) },
	{ name = "crater", from = Vector3.new(14, 190, -190), at = Vector3.new(0, 140, -265) },
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
	while not workspace:GetAttribute("HubSolid") do
		task.wait(0.5)
	end
	print("HUBCHECK solid ready")
	task.wait(24)
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
