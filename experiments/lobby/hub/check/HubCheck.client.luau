--!strict
-- Check build only: a short look at chosen views, logging real render costs at each. Output lines start with HUBCHECK.
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")

local rimShape = require(
	game:GetService("ReplicatedStorage"):WaitForChild("LobbyScale"):WaitForChild("rim_shape")
) :: any
local STOPS: { { name: string, from: Vector3, at: Vector3 } } = {}
for index, angle in rimShape.falls do
	local flat = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local side = Vector3.new(-flat.Z, 0, flat.X)
	local basin = flat * 85 + Vector3.new(0, -11, 0)
	local mid = flat * 78 + Vector3.new(0, -32, 0)
	table.insert(STOPS, {
		name = `front{index}`,
		from = flat * 52 + side * 9 + Vector3.new(0, -9, 0),
		at = flat * 80 + Vector3.new(0, -22, 0),
	})
	if index == 1 then
		table.insert(
			STOPS,
			{ name = "side", from = flat * 58 + side * 42 + Vector3.new(0, -12, 0), at = mid }
		)
		table.insert(
			STOPS,
			{ name = "close", from = flat * 58 + side * 6 + Vector3.new(0, -2, 0), at = basin }
		)
		table.insert(
			STOPS,
			{ name = "rimview", from = flat * 104 + side * 14 + Vector3.new(0, 9, 0), at = basin }
		)
		table.insert(STOPS, {
			name = "foot",
			from = flat * 45 + side * 22 + Vector3.new(0, -32, 0),
			at = flat * 72 + Vector3.new(0, -50, 0),
		})
	end
end

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
