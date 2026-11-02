--!strict
-- Check build only: a short look at chosen views, logging real render costs at each. Output lines start with HUBCHECK.
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")

local STOPS: { { name: string, from: Vector3, at: Vector3 } } = {
	{ name = "crack", from = Vector3.new(-34, 9, -103), at = Vector3.new(-40, 0, -112) },
	{ name = "stormUp", from = Vector3.new(0, 9, 12), at = Vector3.new(0, 200, -10) },
	{ name = "ring", from = Vector3.new(-105, 12, -105), at = Vector3.new(-10, 200, -10) },
	{ name = "spawn", from = Vector3.new(0, 9, -12), at = Vector3.new(0, 90, -240) },
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
	-- The lightning, held long enough to see, at both ends of where it can strike.
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(Vector3.new(-30, 20, -30), Vector3.new(0, 280, 0))
	local holder = workspace:WaitForChild("HubArt"):WaitForChild("StormFlash") :: BasePart
	local bloom = holder:WaitForChild("Bloom") :: ParticleEmitter
	local zap = holder:WaitForChild("Zap") :: ParticleEmitter
	bloom.Lifetime, zap.Lifetime = NumberRange.new(4), NumberRange.new(4)
	for index, radius in { 30, 72 } do
		local base = holder:GetAttribute("VeilY") :: number
		holder.Position = Vector3.new(radius, base - 25 + 90 * (1 - radius / 96) ^ 1.7 - 40, 0)
		bloom:Emit(1)
		zap:Emit(1)
		task.wait(1)
		print(`HUBCHECK shot flash{index}`)
		task.wait(3.5)
	end
	camera.CameraType = Enum.CameraType.Custom
	print("HUBCHECK tour ends")
end)
