--!strict
-- Check build only: a short look at chosen views, logging real render costs at each. Output lines start with HUBCHECK.
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")

local STOPS: { { name: string, from: Vector3, at: Vector3 } } = {
	{ name = "spawn", from = Vector3.new(4, 7, 14), at = Vector3.new(0, 6, -40) },
	{ name = "crack", from = Vector3.new(-4, 8, 22), at = Vector3.new(-14, 0, 8) },
	{ name = "rope", from = Vector3.new(14, 6, -42), at = Vector3.new(9, 3, -33) },
	{ name = "gun", from = Vector3.new(-22, 10, 0), at = Vector3.new(-32, 12.5, 0) },
	{ name = "fall", from = Vector3.new(10, -18, 22), at = Vector3.new(54, -28, 62) },
	{ name = "foot", from = Vector3.new(40, -24, 40), at = Vector3.new(47, -56, 54) },
	{ name = "pit", from = Vector3.new(60, 18, -92), at = Vector3.new(0, -45, 0) },
	{ name = "up", from = Vector3.new(18, 6, 8), at = Vector3.new(6, 250, 2) },
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
		if stop.name == "fall" or stop.name == "foot" then
			task.wait(1)
			print(`HUBCHECK shot {stop.name}B`)
			task.wait(1)
		end
	end
	camera.CFrame = CFrame.lookAt(Vector3.new(34, 8, -60), Vector3.new(0, -3, -60))
	task.wait(1)
	print("HUBCHECK shot rest")
	task.wait(1)
	workspace:SetAttribute("HubTestRider", Vector3.new(0, -3, -60))
	task.wait(1.8)
	print("HUBCHECK shot rider")
	task.wait(1)
	workspace:SetAttribute("HubTestRider", nil)
	camera.CameraType = Enum.CameraType.Custom
	print("HUBCHECK tour ends")
end)
