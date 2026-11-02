--!strict
-- Check build only: a short look at chosen views, logging real render costs at each. Output lines start with HUBCHECK.
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")

local STOPS: { { name: string, from: Vector3, at: Vector3 } } = {
	{ name = "spawn", from = Vector3.new(0, 9, -12), at = Vector3.new(0, 60, -220) },
	{ name = "shore", from = Vector3.new(0, 8, -118), at = Vector3.new(0, 60, -250) },
	{ name = "owner", from = Vector3.new(-95, 75, -55), at = Vector3.new(15, 40, -190) },
	{ name = "rim", from = Vector3.new(58, 34, -60), at = Vector3.new(50, 0, -105) },
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
	-- The eruption, from the spawn rock, at known moments.
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 9, -12), Vector3.new(0, 80, -240))
	task.wait(1)
	workspace:SetAttribute("HubErupt", true)
	for index = 1, 6 do
		task.wait(0.85)
		print(`HUBCHECK shot erupt{index}`)
	end
	task.wait(1)
	camera.CameraType = Enum.CameraType.Custom
	print("HUBCHECK tour ends")
end)
