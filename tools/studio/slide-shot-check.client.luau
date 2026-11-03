--!strict
-- Regression: brief loss of a queried surface during slide recovery must not
-- choose a maximum-range lob. Visible surfaces retain full-charge accuracy.
-- Client-only query masking models the open-space window; server targets remain.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local R = game:GetService("RunService")
local H = game:GetService("HttpService")
local P = Players.LocalPlayer
local scripts = P:WaitForChild("PlayerScripts")
local probe = scripts:WaitForChild("CombatExperimentProbe") :: BindableFunction
local motion = scripts:WaitForChild("MovementExperimentProbe") :: BindableFunction
local movement = scripts:WaitForChild("MovementSandbox")
local First = (require :: any)(movement:WaitForChild("FirstPerson"))
local Ads = (require :: any)(movement:WaitForChild("Ads"))
local Recoil = (require :: any)(movement:WaitForChild("BlasterRecoil"))
local fixture = RS:WaitForChild("ShootingFeelFixture") :: RemoteFunction
local remote = RS:WaitForChild("SlugshotCombat") :: RemoteEvent
local shots: { [number]: any } = {}
local impacts: { [number]: any } = {}
remote.OnClientEvent:Connect(function(kind, data)
	if kind == "Rejected" then
		print("SHOOTCHECK rejected " .. H:JSONEncode(data))
	end
	if data.shooter == P then
		if kind == "Shot" then
			shots[data.id] = data
		end
		if kind == "Impact" then
			impacts[data.id] = data
		end
	end
end)
local function waitFor(test: () -> boolean, seconds: number, label: string)
	local deadline = os.clock() + seconds
	while not test() do
		assert(os.clock() < deadline, label)
		task.wait()
	end
end
local function result(kind: string, data: any)
	print("SHOOTCHECK " .. kind .. " " .. H:JSONEncode(data))
end
local pending: (() -> ())? = nil
R:BindToRenderStep("SlideShotRelease", Enum.RenderPriority.Input.Value + 5, function()
	if pending then
		local callback = pending
		pending = nil
		callback()
	end
end)
local ok, problem = pcall(function()
	local character = P.Character or P.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local backpack = P:WaitForChild("Backpack")
	waitFor(function()
		return backpack:FindFirstChildOfClass("Tool") ~= nil
			or character:FindFirstChildOfClass("Tool") ~= nil
	end, 30, "blaster missing")
	humanoid:EquipTool(
		(character:FindFirstChildOfClass("Tool") or backpack:FindFirstChildOfClass("Tool")) :: Tool
	)
	First.setActive(true)
	task.wait(2)
	local camera = workspace.CurrentCamera :: Camera
	R:BindToRenderStep("SlideShotFacing", Enum.RenderPriority.Camera.Value + 1, function()
		local eye = camera.CFrame.Position
		camera.CFrame = CFrame.lookAt(eye, eye + Vector3.xAxis * 100)
	end)
	for index, offset in
		{ 0, 0.05, 0.12, 0.3, 0, 0.05, 0.12, 0.3, 0, 0.05, 0.12, 0.3, 0, 0.05, 0.12, 0.3 }
	do
		waitFor(function()
			return probe:Invoke("State").remaining <= 0
		end, 5, "cooldown")
		motion:Invoke("Move", { direction = Vector3.zero, duration = 2 })
		motion:Invoke("Sprint", false)
		Ads.set(false)
		task.wait(0.4)
		fixture:InvokeServer("Reset")
		task.wait(0.4)
		character = P.Character or P.CharacterAdded:Wait()
		root = character:WaitForChild("HumanoidRootPart") :: BasePart
		humanoid = character:WaitForChild("Humanoid") :: Humanoid
		First.setActive(true)
		motion:Invoke("ShiftLock", true)
		task.wait(0.3)
		local target = fixture:InvokeServer(65, false)
		probe:Invoke("Press")
		waitFor(function()
			return Recoil.stage() == 3
		end, 2, "full charge missing")
		local directions =
			{ Vector3.xAxis, Vector3.new(1, 0, 1).Unit, Vector3.zAxis, -Vector3.xAxis }
		local travel = directions[math.floor((index - 1) / 4) + 1]
		motion:Invoke("Move", { direction = travel, duration = 1.6 })
		motion:Invoke("Sprint", true)
		task.wait(0.25)
		motion:Invoke("SlideKey", true)
		waitFor(function()
			return motion:Invoke("State").acro == "Slide"
		end, 1, "slide failed")
		task.wait(0.3)
		motion:Invoke("SlideKey", true)
		Ads.set(index % 2 == 0)
		local airWindow = index % 4 == 1
		local surface = workspace:WaitForChild("ShootingFeelTarget") :: BasePart
		if airWindow then
			surface.CanQuery = false
		end
		task.wait(if airWindow then 0.04 else offset)
		local sample: any = nil
		local before = probe:Invoke("State").lastSent
		pending = function()
			assert(First.active() and P.Character == character, "fixture character/view changed")
			sample = probe:Invoke("Aim", 1)
			probe:Invoke("Release")
		end
		waitFor(function()
			return probe:Invoke("State").lastSent > before
		end, 2, "shot missing")
		local id = probe:Invoke("State").lastSent
		result("release", {
			offset = offset,
			origin = { sample.origin.X, sample.origin.Y, sample.origin.Z },
			target = { sample.target.X, sample.target.Y, sample.target.Z },
			root = { root.Position.X, root.Position.Y, root.Position.Z },
			obstructed = sample.obstructed or false,
			charge = shots[id] and shots[id].charge,
			direction = { sample.direction.X, sample.direction.Y, sample.direction.Z },
		})
		waitFor(function()
			return shots[id] ~= nil
		end, 3, "server shot missing")
		if airWindow then
			assert(sample.direction.Y < 0.45, "empty-space aim selected a maximum-range lob")
		end
		waitFor(function()
			return impacts[id] ~= nil
		end, 4, "impact missing")
		local error = (impacts[id].position - sample.target).Magnitude
		result("slide-rise", {
			airWindow = airWindow,
			travel = { travel.X, travel.Z },
			ads = index % 2 == 0,
			offset = offset,
			targetX = target.X,
			sampleTarget = { sample.target.X, sample.target.Y, sample.target.Z },
			origin = { sample.origin.X, sample.origin.Y, sample.origin.Z },
			direction = { sample.direction.X, sample.direction.Y, sample.direction.Z },
			obstructed = sample.obstructed or false,
			error = error,
		})
		surface.CanQuery = true
		assert(not sample.obstructed, "slide recovery invented close cover")
		if airWindow then
			assert(
				sample.direction.Y < 0.45,
				"empty-space slide-rise aim selected a maximum-range lob"
			)
			assert(
				math.abs(impacts[id].position.X - target.X) < 0.35,
				"air zero overshot the nearby target plane"
			)
		else
			assert(error < 0.12, "full-charge slide-rise shot missed the aimed surface")
		end
	end
	R:UnbindFromRenderStep("SlideShotFacing")
end)
R:UnbindFromRenderStep("SlideShotRelease")
print("SHOOTCHECK " .. (if ok then "PASS slide-rise regression" else "FAIL " .. tostring(problem)))
