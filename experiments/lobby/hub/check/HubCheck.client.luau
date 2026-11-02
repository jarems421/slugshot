--!strict
-- Check build only: a short look at chosen views, logging real render costs at each. Output lines start with HUBCHECK.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local STOPS: { { name: string, from: Vector3, at: Vector3 } } = {
	{ name = "spawn", from = Vector3.new(0, 9, -12), at = Vector3.new(0, 100, -240) },
}

-- Walks the real character at each structure from open ground. Stopping short of the far point means it was blocked.
local WALKS: { { any } } = {
	{ "training plinth front", Vector3.new(-50, 0.9, -125), Vector3.new(-66, 0.9, -160) },
	{ "training plinth side", Vector3.new(-30, 0.9, -135), Vector3.new(-62, 0.9, -152) },
	{ "training plinth far side", Vector3.new(-95, 0.9, -130), Vector3.new(-62, 0.9, -152) },
	{ "veylume plinth front", Vector3.new(50, 0.9, -125), Vector3.new(66, 0.9, -160) },
	{ "veylume plinth side", Vector3.new(30, 0.9, -135), Vector3.new(62, 0.9, -152) },
	{ "pvp step", Vector3.new(0, 0.9, -125), Vector3.new(0, 0.9, -160) },
	{ "pvp step corner", Vector3.new(36, 0.9, -130), Vector3.new(0, 0.9, -160) },
	{ "stump plus x", Vector3.new(76, 133, -115), Vector3.new(76, 133, -190) },
	{ "stump minus x", Vector3.new(-86, 112, -115), Vector3.new(-86, 112, -190) },
	{ "pillar shaft", Vector3.new(105, 34, -115), Vector3.new(105, 34, -190) },
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
	task.wait(8)
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
	local character = player.Character :: Model
	for _, speed in { 24 } do
		for _, walk in WALKS do
			-- Character-sized, pushed flat at this speed with gravity off, spawned clear of anything.
			local body = Instance.new("Part")
			body.Size = Vector3.new(2, 1.2, 1.5)
			body.CFrame = CFrame.lookAt(walk[2], walk[3])
			body.CanTouch = false
			body.Parent = workspace
			local direction = (walk[3] - walk[2]).Unit
			local full = (walk[3] - walk[2]).Magnitude
			local connection = RunService.Heartbeat:Connect(function()
				body.AssemblyLinearVelocity = direction * speed
				body.AssemblyAngularVelocity = Vector3.zero
			end)
			task.wait(full / speed + 0.5)
			connection:Disconnect()
			local moved = (body.Position - walk[2]):Dot(direction)
			print(
				string.format(
					"HUBCHECK push %s at %d: went %.1f of %.1f, ends %.1f,%.1f,%.1f",
					walk[1],
					speed,
					moved,
					full,
					body.Position.X,
					body.Position.Y,
					body.Position.Z
				)
			)
			body:Destroy()
		end
	end
	character:PivotTo(CFrame.new(0, 6, 0))
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 9, -12), Vector3.new(0, 100, -240))
	task.wait(22)
	print("HUBCHECK shot steamSpawn")
	task.wait(1)
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 30, -115), Vector3.new(0, 190, -265))
	task.wait(1.5)
	print("HUBCHECK shot steamNear")
	task.wait(1)
	camera.CFrame = CFrame.lookAt(Vector3.new(-95, 75, -55), Vector3.new(0, 150, -265))
	task.wait(1.5)
	print("HUBCHECK shot steamSide")
	task.wait(1)
	camera.CameraType = Enum.CameraType.Custom
	print("HUBCHECK tour ends")
end)
