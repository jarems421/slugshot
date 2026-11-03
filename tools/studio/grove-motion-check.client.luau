--!strict
-- Native integration review: actual resident models, support and render cadence.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local function waitFor(check: () -> boolean, seconds: number)
	local deadline = os.clock() + seconds
	while not check() do
		assert(os.clock() < deadline, "grove readiness timed out")
		task.wait(0.1)
	end
end
local ok, problem = pcall(function()
	waitFor(function()
		return workspace:GetAttribute("HubSolid") == true
	end, 160)
	local group = workspace:WaitForChild("HubArt"):WaitForChild("GroveSlugs")
	task.wait(3)
	local models: { Model } = {}
	local counts = { Floppy = 0, Inferno = 0 }
	for _, item in group:GetChildren() do
		if item:IsA("Model") then
			assert(item:GetAttribute("GroveReady") == true, "resident was not grounded")
			assert(item:GetAttribute("WorldSlugSize") == 2, "resident size mismatch")
			local species = item:GetAttribute("Slug") :: string
			counts[species] = (counts[species] or 0) + 1
			table.insert(models, item)
		end
	end
	assert(#models >= 12 and #models <= 15, "resident count out of budget: " .. tostring(#models))
	local character = Players.LocalPlayer.Character or Players.LocalPlayer.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local subject = models[1]
	local camera = workspace.CurrentCamera :: Camera
	root.Anchored = true
	root.CFrame = CFrame.new(subject:GetPivot().Position + Vector3.new(0, 3, 7))
	local view = subject:GetPivot().Position
	camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep("GroveCheckCamera", Enum.RenderPriority.Last.Value + 5, function()
		camera.CFrame = CFrame.lookAt(view + Vector3.new(6, 3, 8), view + Vector3.yAxis)
	end)
	local frames, changed, previous = 0, 0, subject:GetPivot()
	local phases: { [string]: boolean } = {}
	local lookSeen = false
	local headLift = { Floppy = 0, Inferno = 0 }
	local minPress, maxPress = 0, 0
	local landingPeak = { Floppy = 0, Inferno = 0 }
	local supportSamples = 0
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, group }
	print("GROVECHECK focus")
	task.wait(1.5)
	local start = os.clock()
	local visitChanged = false
	local before = workspace:GetAttribute("GroveRenderedFrames") :: number
	local maxDt, totalDt = 0, 0
	while os.clock() - start < 26 do
		local dt = RunService.RenderStepped:Wait()
		if not visitChanged and os.clock() - start > 12 then
			for _, candidate in models do
				if candidate:GetAttribute("Slug") ~= subject:GetAttribute("Slug") then
					subject = candidate
					view = subject:GetPivot().Position
					root.CFrame = CFrame.new(view + Vector3.new(0, 3, 7))
					visitChanged = true
					break
				end
			end
		end
		frames += 1
		totalDt += dt
		maxDt = math.max(maxDt, dt)
		local pivot = subject:GetPivot()
		if
			(pivot.Position - previous.Position).Magnitude > 0.0001
			or (pivot.LookVector - previous.LookVector).Magnitude > 0.0001
		then
			changed += 1
		end
		previous = pivot
		for _, model in models do
			local phase = model:GetAttribute("GrovePhase") :: string
			if phase and not phases[phase] then
				phases[phase] = true
				print("GROVECHECK shot " .. phase)
			end
			local press = (model:GetAttribute("GrovePress") or 0) :: number
			minPress, maxPress = math.min(minPress, press), math.max(maxPress, press)
			if model:GetAttribute("GroveStage") == "landing" then
				local species = model:GetAttribute("Slug") :: string
				landingPeak[species] = math.max(landingPeak[species] or 0, press)
			end
			lookSeen = lookSeen or ((model:GetAttribute("GroveLook") or 0) :: number) > 0.5
			if
				((model:GetAttribute("GroveLook") or 0) :: number) > 0.9
				and model:GetAttribute("GroveStage") == "rest"
			then
				local head = model:FindFirstChild("head", true) :: Bone
				local residentFrame = model:GetPivot()
				local localFacing = head.WorldCFrame:VectorToObjectSpace(residentFrame.LookVector)
				local facing = head.TransformedWorldCFrame:VectorToWorldSpace(localFacing)
				local species = model:GetAttribute("Slug") :: string
				headLift[species] =
					math.max(headLift[species] or 0, facing:Dot(residentFrame.UpVector))
			end
			assert(
				((model:GetAttribute("GroveHomeDistance") or 0) :: number) < 7.7,
				"resident escaped home region"
			)
			if phase == "rest" and frames % 30 == 0 then
				local at = model:GetPivot().Position
				local hit = workspace:Raycast(at + Vector3.yAxis, -Vector3.yAxis * 2, params)
				assert(
					hit and (hit.Position - at).Magnitude < 0.12,
					"resident floating or embedded at rest"
				)
				supportSamples += 1
			end
		end
	end
	local renders = (workspace:GetAttribute("GroveRenderedFrames") :: number) - before
	assert(renders >= frames - 2, "motion skipped display frames")
	assert(minPress < -0.04 and maxPress > 0.2, "takeoff has no squash/stretch")
	assert(
		landingPeak.Floppy > 0.44 and landingPeak.Inferno > 0.44,
		"landing did not visibly compress both species"
	)
	assert(lookSeen, "no passing-player reaction")
	assert(
		headLift.Floppy > 0.08 and headLift.Inferno > 0.08,
		"a resident did not tilt its actual head up at the player"
	)
	assert(supportSamples > 0, "no ground contact samples")
	print("GROVECHECK result " .. HttpService:JSONEncode({
		residents = counts,
		renderFrames = frames,
		animationFrames = renders,
		changedFrames = changed,
		meanDt = totalDt / frames,
		maxDt = maxDt,
		press = { minPress, maxPress },
		lookSeen = lookSeen,
		landingPeak = landingPeak,
		headLift = headLift,
		supportSamples = supportSamples,
	}))
	RunService:UnbindFromRenderStep("GroveCheckCamera")
	root.Anchored = false
end)
print("GROVECHECK " .. (if ok then "PASS" else "FAIL " .. tostring(problem)))
