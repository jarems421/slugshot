--!strict
-- Check build only: a short look at chosen views, logging real render costs at each. Output lines start with HUBCHECK.
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")

local STOPS: { { name: string, from: Vector3, at: Vector3 } } = {
	{ name = "grovePath", from = Vector3.new(75, 9, 0), at = Vector3.new(285, 70, 0) },
	{ name = "grovePond", from = Vector3.new(112, 7, -24), at = Vector3.new(190, 14, 6) },
	{ name = "grovePeaks", from = Vector3.new(60, 34, 60), at = Vector3.new(285, 120, 0) },
	{ name = "groveTips", from = Vector3.new(100, 55, -80), at = Vector3.new(290, 150, 10) },
	{ name = "groveSlugs", from = Vector3.new(170, 3.4, -43), at = Vector3.new(174, 1, -46) },
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
	-- The slug side has no flat ground under its art, so it must be solid all over.
	local holes, tested = {}, 0
	for angle = 42, 133, 7 do
		for radius = 92, 296, 17 do
			local x, z = math.sin(math.rad(angle)) * radius, -math.cos(math.rad(angle)) * radius
			tested += 1
			if not workspace:Raycast(Vector3.new(x, 215, z), Vector3.new(0, -240, 0)) then
				table.insert(holes, string.format("%d/%d", angle, radius))
			end
		end
	end
	print(`HUBCHECK groveFloor tested={tested} holes={#holes} {table.concat(holes, " ")}`)
	local slugs = workspace:WaitForChild("HubArt"):FindFirstChild("GroveSlugs")
	print(`HUBCHECK groveSlugs count={if slugs then #slugs:GetChildren() else 0}`)
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
