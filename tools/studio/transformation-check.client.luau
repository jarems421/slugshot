--!strict
-- Disposable transformation review, mapped only by tools/build_transformation_check.py. Freezes the sequence at set
-- moments for stills, flies the real code path past a side camera at real speed, then fires a real server shot in first
-- person and measures it.
local Players = game:GetService("Players")
local R = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local H = game:GetService("HttpService")
local P = Players.LocalPlayer
local scripts = P:WaitForChild("PlayerScripts")
local probe = scripts:WaitForChild("CombatExperimentProbe") :: BindableFunction
local movement = scripts:WaitForChild("MovementSandbox")
local First = (require :: any)(movement:WaitForChild("FirstPerson"))
local combatScripts = scripts:WaitForChild("Combat")
local Transformation = (require :: any)(combatScripts:WaitForChild("SlugTransformation"))
local Visuals = (require :: any)(combatScripts:WaitForChild("SlugVisuals"))
local Combat = (require :: any)(RS:WaitForChild("Combat"))
local fixture = RS:WaitForChild("ShootingFeelFixture") :: RemoteFunction
local remote = RS:WaitForChild("SlugshotCombat") :: RemoteEvent

local function say(text: string)
	print("TRANSCHECK " .. text)
end

local cameraAt: CFrame? = nil
local follow: (() -> CFrame?)? = nil
local camera = workspace.CurrentCamera :: Camera
R:BindToRenderStep("TransformationCheckCamera", Enum.RenderPriority.Last.Value, function()
	local placed = if follow then follow() else cameraAt
	if placed then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = placed
	end
end)

local ok, problem = pcall(function()
	local character = P.Character or P.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local backpack = P:WaitForChild("Backpack")
	local deadline = os.clock() + 25
	while
		not (backpack:FindFirstChildOfClass("Tool") or character:FindFirstChildOfClass("Tool"))
		and os.clock() < deadline
	do
		task.wait()
	end
	humanoid:EquipTool(
		(character:FindFirstChildOfClass("Tool") or backpack:FindFirstChildOfClass("Tool")) :: Tool
	)
	task.wait(2)
	local inferno = Combat.Slugs.Inferno
	local shape = inferno.Transformation
	local air = root.Position + Vector3.new(0, 40, 0)
	local folder = camera:WaitForChild("SlugShots")

	-- Frozen stills, three-quarters from the front, with long ribbons so their shape can be judged.
	do
		-- Slow motion, so the explosion and cinders are still there when each still is taken.
		Transformation.timeScale = 0.05
		local base = Visuals.model("Inferno")
		base:PivotTo(CFrame.new(air))
		base.Parent = folder
		local params = RaycastParams.new()
		local state = Transformation.new(
			"Inferno",
			base,
			{ origin = air, velocity = Vector3.new(0, 0, -500) },
			params,
			folder
		)
		assert(state, "no transformation state for Inferno")
		for _, trail in state.anchor:GetDescendants() do
			if trail:IsA("Trail") then
				trail.Lifetime = 8
			end
		end
		task.wait(0.3)
		local flightClock = 0
		local moments = { 0.05, 0.1, 0.14, 0.16, 0.18, 0.22, 0.3, 0.5 }
		for _, moment in moments do
			-- Run up to the moment slowly so ribbons draw, then hold.
			while flightClock < moment do
				flightClock = math.min(moment, flightClock + 1 / 240)
				local t = Combat.flightTime(inferno, flightClock)
				local position = Combat.at(air, Vector3.new(0, 0, -500), inferno, t)
				local placed = CFrame.lookAt(position, position + Vector3.new(0, 0, -1))
				Transformation.step(state, flightClock, placed)
				cameraAt = CFrame.lookAt(position + Vector3.new(6.5, 2, -8.5), position)
				R.RenderStepped:Wait()
			end
			task.wait(0.15)
			say(`shot still-{string.format("%.2f", moment)}`)
			task.wait(0.9)
		end
		-- From the shooter's side, close and at range, with the fire rippling.
		for _, view in
			{
				{ "back", Vector3.new(0, 1.6, 8) },
				{ "far", Vector3.new(0, 3, 30) },
				{ "quarter", Vector3.new(6, 2.5, 6.5) },
			}
		do
			local spot = state.form:GetPivot().Position
			cameraAt = CFrame.lookAt(spot + view[2], spot)
			task.wait(0.3)
			for index = 1, 3 do
				say(`shot {view[1]}-{index}`)
				task.wait(0.35)
			end
		end
		Transformation.finish(state, Vector3.new(0, -1000, 0), Vector3.yAxis)
		base:Destroy()
		Transformation.timeScale = 1
	end

	-- The aura close to a floor: it must stay soft instead of depth-clipping into a rectangular card.
	do
		local ground = Instance.new("Part")
		ground.Name = "AuraFloorFixture"
		ground.Anchored = true
		ground.Size = Vector3.new(60, 1, 60)
		ground.Position = air - Vector3.yAxis * 1.1
		ground.Color = Color3.fromRGB(75, 78, 85)
		ground.Parent = workspace
		local base = Visuals.model("Inferno")
		base:PivotTo(CFrame.new(air))
		base.Parent = folder
		local state = Transformation.new(
			"Inferno",
			base,
			{ origin = air, velocity = Vector3.new(0, 0, -500) },
			RaycastParams.new(),
			folder
		)
		assert(state, "no transformation state for Inferno")
		local placed = CFrame.new(air)
		for index, offset in
			{ Vector3.new(6, 2, 8), Vector3.new(0, 0.8, 12), Vector3.new(0, 7, 10) }
		do
			cameraAt = CFrame.lookAt(air + offset, air)
			camera.CFrame = cameraAt
			task.wait(0.15)
			Transformation.step(state, shape.Spin * 0.9, placed)
			local obstruction = workspace:Raycast(
				camera.CFrame.Position,
				air - camera.CFrame.Position,
				state.occlusion
			)
			say("aura visibility " .. H:JSONEncode({
				enabled = state.board.Enabled,
				wideLoaded = state.wide.IsLoaded,
				hotLoaded = state.hot.IsLoaded,
				fetch = tostring(
					game:GetService("ContentProvider"):GetAssetFetchStatus(state.wide.Image)
				),
				obstruction = if obstruction then obstruction.Instance.Name else "none",
			}))
			assert(
				state.board.AlwaysOnTop and state.board.Enabled,
				"loaded glow should be visible near floor"
			)
			say(`shot floor-{index}`)
			task.wait(0.6)
		end
		local blocker = Instance.new("Part")
		blocker.Anchored = true
		blocker.Size = Vector3.new(30, 30, 1)
		blocker.CFrame = CFrame.new(air + Vector3.new(0, 0, 5))
		blocker.Parent = workspace
		cameraAt = CFrame.lookAt(air + Vector3.new(0, 2, 12), air)
		camera.CFrame = cameraAt
		Transformation.step(state, shape.Spin * 0.95, placed)
		assert(not state.board.Enabled, "aura leaked through a solid wall")
		say("wall occlusion ok")
		blocker:Destroy()
		Transformation.step(state, shape.Spin, placed)
		assert(state.swapped, "swap missing")
		assert(state.form:GetScale() <= state.formScale, "reveal overshot final size")
		Transformation.step(state, shape.Spin + 0.3, placed)
		assert(not state.board.Enabled, "aura did not fade after reveal")
		assert(
			math.abs(state.form:GetScale() - state.formScale) < 1e-4,
			"form did not settle to final scale"
		)
		assert(state.form:GetAttribute("TransformFold") == 0, "wings did not unfold")
		Transformation.destroy(state)
		Transformation.destroy(state)
		assert(not state.anchor.Parent and not state.form.Parent, "cancellation leaked effects")
		base:Destroy()
		ground:Destroy()
		say("aura, reveal and cancellation ok")
	end

	-- An impact before the swap restores the base form without leaving a parked dragon or aura.
	do
		local base = Visuals.model("Inferno")
		base.Parent = folder
		local scale = base:GetScale()
		local state = Transformation.new(
			"Inferno",
			base,
			{ origin = air, velocity = Vector3.new(0, 0, -500) },
			RaycastParams.new(),
			folder
		)
		assert(state, "no early-impact fixture")
		Transformation.step(state, shape.Spin * 0.8, CFrame.new(air))
		Transformation.finish(state, air, Vector3.yAxis)
		assert(math.abs(base:GetScale() - scale) < 1e-4, "early impact kept shrunken base form")
		assert(not state.anchor.Parent and not state.form.Parent, "early impact leaked effects")
		base:Destroy()
		say("early impact ok")
	end

	-- Real speed past a side camera, all the way to a target wall.
	local target = fixture:InvokeServer(65, false)
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local way = (target - origin).Unit
	local sideways = way:Cross(Vector3.yAxis).Unit
	cameraAt =
		CFrame.lookAt(origin + way * 26 + sideways * 16 + Vector3.yAxis * 2, origin + way * 26)
	task.wait(0.5)
	say("record side")
	task.wait(0.6)
	for index = 1, 2 do
		Visuals.launch({
			id = -index,
			shooter = P,
			slugId = "Inferno",
			origin = origin,
			velocity = way * Combat.speed(inferno, 1),
			readyAt = 0,
		})
		task.wait(1.2)
	end
	task.wait(1)

	-- A shot at nothing disappears at its time limit.
	Visuals.launch({
		id = -3,
		shooter = P,
		slugId = "Inferno",
		origin = origin,
		velocity = (way + Vector3.yAxis * 0.5).Unit * Combat.speed(inferno, 1),
		readyAt = 0,
	})
	task.wait(inferno.Expires + 0.2)
	for _, item in folder:GetChildren() do
		assert(item:GetAttribute("ShotId") ~= -3, "unlanded shot did not disappear")
	end
	say("despawn ok")

	-- The real thing: real input path, server hit, first person.
	cameraAt = nil
	First.setActive(true)
	local shots: { [number]: number } = {}
	local measured = 0
	remote.OnClientEvent:Connect(function(kind, packet)
		if packet.shooter ~= P then
			return
		end
		if kind == "Shot" then
			shots[packet.id] = os.clock()
		elseif kind == "Impact" and shots[packet.id] then
			measured = os.clock() - shots[packet.id]
			say("impact " .. H:JSONEncode({
				seconds = measured,
				distance = packet.distance,
				damage = packet.damage,
			}))
		end
	end)
	probe:Invoke("Select", 2)
	task.wait(0.8)
	follow = function()
		return CFrame.lookAt(root.Position + Vector3.new(0, 1.5, 0), target)
	end
	task.wait(0.5)
	say("record first")
	task.wait(0.6)
	probe:Invoke("Press")
	task.wait(0.7)
	probe:Invoke("Release")
	task.wait(0.03)
	local saw = false
	local check = os.clock() + (shape.Spin + shape.Flash + 0.15)
	while os.clock() < check do
		for _, item in folder:GetChildren() do
			if item.Name == "InfernoTransformed" and (item :: Model):GetPivot().Y > -1000 then
				saw = true
			end
		end
		R.RenderStepped:Wait()
	end
	task.wait(2.5)
	assert(saw, "transformed form never appeared on a real shot")
	assert(measured > 0, "real shot produced no server impact")
	local left = 0
	for _, item in folder:GetChildren() do
		if item.Name == "InfernoTransformed" then
			left += 1
		end
	end
	assert(left == 0, "transformed form left behind after the hit")
end)
if ok then
	say("PASS")
else
	say("FAIL " .. tostring(problem))
end
