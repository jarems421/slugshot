--!strict
-- Check build only: a short look at chosen views, logging real render costs at each. Output lines start with HUBCHECK.
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")

local STOPS: { { name: string, from: Vector3, at: Vector3 } } = {
	{ name = "gun", from = Vector3.new(-8, 9, 0), at = Vector3.new(-31, 12.6, 0) },
	{ name = "spawn", from = Vector3.new(0, 9, -12), at = Vector3.new(0, 90, -240) },
	{ name = "behind", from = Vector3.new(0, 40, 90), at = Vector3.new(0, 45, 290) },
	{ name = "poolNear", from = Vector3.new(24, 160, -238), at = Vector3.new(0, 148, -268) },
	{ name = "poolTop", from = Vector3.new(3, 215, -267), at = Vector3.new(0, 148, -268) },
	{ name = "lip", from = Vector3.new(-22, 156, -222), at = Vector3.new(-14, 140, -240) },
	{ name = "lipSide", from = Vector3.new(70, 155, -235), at = Vector3.new(18, 142, -250) },
	{ name = "shore", from = Vector3.new(-95, 75, -55), at = Vector3.new(0, 120, -265) },
}

-- Drops a block on the pool and on its edges, to prove you stand on the lava.
local DROPS: { Vector3 } = {
	Vector3.new(0, 165, -268),
	Vector3.new(-12, 165, -262),
	Vector3.new(14, 165, -280),
	Vector3.new(22, 165, -268),
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
	task.wait(3)
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
	local blocks = {}
	for index, at in DROPS do
		local block = Instance.new("Part")
		block.Size = Vector3.new(2, 4, 2)
		block.Position = at
		block.Parent = workspace
		blocks[index] = block
	end
	task.wait(6)
	for index, block in blocks do
		print(
			string.format(
				"HUBCHECK drop %d rests at y %.1f (x %.1f z %.1f)",
				index,
				block.Position.Y,
				block.Position.X,
				block.Position.Z
			)
		)
		block:Destroy()
	end
	print("HUBCHECK tour ends")
end)
