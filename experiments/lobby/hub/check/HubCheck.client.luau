--!strict
-- Check build only: a camera tour of the hub that logs real render costs at each stop, so the phone budget is measured
-- rather than assumed. Output lines start with HUBCHECK.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")

local STOPS: { { name: string, from: Vector3, at: Vector3 } } = {
	{ name = "spawn", from = Vector3.new(4, 7, 14), at = Vector3.new(0, 6, -40) },
	{ name = "gateway", from = Vector3.new(16, 8, -12), at = Vector3.new(0, 6, -33) },
	{ name = "rope", from = Vector3.new(14, 6, -42), at = Vector3.new(9, 4, -33) },
	{ name = "bridge", from = Vector3.new(0, 7, -70), at = Vector3.new(0, 4, -33) },
	{ name = "pit", from = Vector3.new(60, 18, -92), at = Vector3.new(0, -45, 0) },
	{ name = "shore", from = Vector3.new(-96, 16, -60), at = Vector3.new(0, 0, 0) },
	{ name = "crack", from = Vector3.new(-4, 7, 22), at = Vector3.new(-14, 0, 8) },
	{ name = "sprout", from = Vector3.new(-13, 4, 9), at = Vector3.new(-20, 1, 2) },
	{ name = "root", from = Vector3.new(24, 2, 44), at = Vector3.new(12, -12, 26) },
	{ name = "rim", from = Vector3.new(60, 9, 70), at = Vector3.new(40, -22, 46) },
	{ name = "crystal", from = Vector3.new(-5, 4, 20), at = Vector3.new(-12, 1, 18) },
	{ name = "fall", from = Vector3.new(24, -18, 30), at = Vector3.new(52, -24, 60) },
	{ name = "juice", from = Vector3.new(46, -14, -46), at = Vector3.new(0, -60, 0) },
	{ name = "up", from = Vector3.new(18, 6, 8), at = Vector3.new(6, 250, 2) },
	{ name = "well", from = Vector3.new(-60, 60, 90), at = Vector3.new(0, 240, 0) },
	{ name = "under", from = Vector3.new(58, -30, 42), at = Vector3.new(0, -12, 0) },
	{ name = "above", from = Vector3.new(0, 150, 150), at = Vector3.new(0, -20, 0) },
}

local function read(name: string): number
	local ok, value = pcall(function()
		return (Stats :: any)[name]
	end)
	return if ok and typeof(value) == "number" then value else -1
end

local function report(stop: string, frames: number, seconds: number)
	print(
		string.format(
			"HUBCHECK %s fps=%.0f tris=%d draws=%d texMB=%.0f meshMB=%.0f mem=%.0fMB instances=%d parts=%d",
			stop,
			frames / seconds,
			read("SceneTriangleCount"),
			read("SceneDrawcallCount"),
			Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsTexture),
			Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsMeshParts),
			Stats:GetTotalMemoryUsageMb(),
			Stats.InstanceCount,
			Stats.PrimitivesCount
		)
	)
end

task.spawn(function()
	local player = Players.LocalPlayer
	player.CharacterAdded:Wait()
	while not workspace:FindFirstChild("HubArt") do
		task.wait(0.5)
	end
	task.wait(25)
	print("HUBCHECK tour starts")
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	for round = 1, 1 do
		for _, stop in STOPS do
			camera.CFrame = CFrame.lookAt(stop.from, stop.at)
			task.wait(if round == 1 then 3 else 1)
			local frames, started = 0, os.clock()
			local connection = RunService.RenderStepped:Connect(function()
				frames += 1
			end)
			task.wait(2)
			connection:Disconnect()
			report(`{stop.name}{round}`, frames, os.clock() - started)
			if round == 1 then
				print(`HUBCHECK shot {stop.name}`)
				task.wait(4)
			end
		end
	end
	-- Two views of each moving surface, a second and a half apart.
	for _, stop in STOPS do
		if stop.name == "fall" or stop.name == "juice" then
			camera.CFrame = CFrame.lookAt(stop.from, stop.at)
			task.wait(1)
			print(`HUBCHECK shot {stop.name}A`)
			task.wait(1.5)
			print(`HUBCHECK shot {stop.name}B`)
			task.wait(2)
		end
	end
	-- A test rider crosses the forward bridge: frames for judging the dip and the moving boards.
	camera.CFrame = CFrame.lookAt(Vector3.new(34, 8, -60), Vector3.new(0, -3, -60))
	task.wait(1)
	print("HUBCHECK shot rest")
	task.wait(4)
	for index, z in { -46, -60, -74 } do
		workspace:SetAttribute("HubTestRider", Vector3.new(0, -3, z))
		task.wait(1.5)
		print(`HUBCHECK shot rider{index}`)
		task.wait(3)
	end
	workspace:SetAttribute("HubTestRider", nil)
	-- What a phone gets: measured at the stops, with the same views as above.
	workspace:SetAttribute("HubReduceDetail", true)
	task.wait(1)
	for _, stop in STOPS do
		camera.CFrame = CFrame.lookAt(stop.from, stop.at)
		task.wait(1)
		local frames, started = 0, os.clock()
		local connection = RunService.RenderStepped:Connect(function()
			frames += 1
		end)
		task.wait(2)
		connection:Disconnect()
		report(`{stop.name}Phone`, frames, os.clock() - started)
	end
	print("HUBCHECK tour ends")
	camera.CameraType = Enum.CameraType.Custom
end)
