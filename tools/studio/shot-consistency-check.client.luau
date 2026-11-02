--!strict
-- Disposable baseline/regression diagnostics. Mapped only by the private builder.
local Players = game:GetService("Players")
local R = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local H = game:GetService("HttpService")
local P = Players.LocalPlayer
local scripts = P:WaitForChild("PlayerScripts")
local probe = scripts:WaitForChild("CombatExperimentProbe") :: BindableFunction
local motion = scripts:WaitForChild("MovementExperimentProbe") :: BindableFunction
local movement = scripts:WaitForChild("MovementSandbox")
local First = (require :: any)(movement:WaitForChild("FirstPerson"))
local Ads = (require :: any)(movement:WaitForChild("Ads"))
local Recoil = (require :: any)(movement:WaitForChild("BlasterRecoil"))
local Combat = (require :: any)(RS:WaitForChild("Combat"))
local T = ((require :: any)(movement:WaitForChild("Tuning"))).values
local fixture = RS:WaitForChild("ShootingFeelFixture") :: RemoteFunction
local remote = RS:WaitForChild("SlugshotCombat") :: RemoteEvent
local shots: { [number]: any } = {}
local impacts: { [number]: any } = {}
remote.OnClientEvent:Connect(function(kind, packet)
	if packet.shooter == P then
		if kind == "Shot" then
			shots[packet.id] = packet
		end
		if kind == "Impact" then
			impacts[packet.id] = packet
		end
	end
end)
local function waitFor(test: () -> boolean, seconds: number, label: string)
	local deadline = os.clock() + seconds
	repeat
		if test() then
			return
		end
		task.wait()
	until os.clock() > deadline
	error(label)
end
local function result(kind: string, data: any)
	print("SHOOTCHECK " .. kind .. " " .. H:JSONEncode(data))
end
local active = true
local ok, problem = pcall(function()
	local character = P.Character or P.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local backpack = P:WaitForChild("Backpack")
	waitFor(function()
		return backpack:FindFirstChildOfClass("Tool") ~= nil
			or character:FindFirstChildOfClass("Tool") ~= nil
	end, 25, "tool missing")
	humanoid:EquipTool(
		(character:FindFirstChildOfClass("Tool") or backpack:FindFirstChildOfClass("Tool")) :: Tool
	)
	First.setActive(true)
	task.wait(2)
	local camera = workspace.CurrentCamera :: Camera
	local target = fixture:InvokeServer(65, false)
	local frameCount, frameTotal, frameMax = 0, 0, 0
	R:BindToRenderStep("ConsistencyCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if active then
			camera.CameraType = Enum.CameraType.Scriptable
			local eye = root.Position + Vector3.new(0, 1.5, 0)
			camera.CFrame = CFrame.lookAt(eye, target)
			camera.Focus = CFrame.new(target)
			frameCount += 1
			frameTotal += dt
			frameMax = math.max(frameMax, dt)
		end
	end)
	Ads.set(true)
	task.wait(0.4)
	local last: { [number]: Vector3 } = {}
	local jumps = { 0, 0, 0 }
	local atDistance = { 0, 0, 0 }
	for i = 40, 320 do
		local distance = i / 2
		target = fixture:InvokeServer(distance, false)
		task.wait(0.025)
		for level = 1, 3 do
			local aim = probe:Invoke("Aim", level / 3)
			local prior = last[level]
			if prior then
				local jump = math.deg(math.acos(math.clamp(prior:Dot(aim.direction), -1, 1)))
				if jump > jumps[level] then
					jumps[level], atDistance[level] = jump, distance
				end
			end
			last[level] = aim.direction
		end
	end
	result("distance-sweep", { maxStepDegrees = jumps, atDistance = atDistance })
	for level = 1, 3 do
		assert(jumps[level] < 6, "camera/muzzle distance sweep has an angle cliff")
	end
	local visibleTarget: Vector3? = nil
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character, camera }
	R:BindToRenderStep("ConsistencyVisibleAim", Enum.RenderPriority.Last.Value + 70, function()
		local cursor = (if First.active() then camera.ViewportSize / 2 else camera.ViewportSize / 2)
		local ray = camera:ViewportPointToRay(cursor.X, cursor.Y)
		local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, rayParams)
		visibleTarget = if hit then hit.Position else ray.Origin + ray.Direction * 300
	end)
	local function expectedImpact(sample: any, charge: number): Vector3
		local velocity = sample.direction * Combat.speed(Combat.Slugs.Floppy, charge)
		local time = 0
		while time < Combat.MaxFlight do
			local hit = Combat.sweep(
				sample.origin,
				velocity,
				Combat.Slugs.Floppy,
				time,
				time + 1 / 120,
				rayParams
			)
			if hit then
				return hit.Position
			end
			time += 1 / 120
		end
		error("fixture shot has no predicted collision")
	end
	-- Real press/release requests at diagonal sprint onset, including an input-phase release.
	local pending: (() -> ())? = nil
	R:BindToRenderStep("ConsistencyRelease", Enum.RenderPriority.Input.Value + 5, function()
		if pending then
			local fire = pending
			pending = nil
			fire()
		end
	end)
	-- Repeat startup, sustained movement, hip fire, ADS and third-person shots.
	local cases = {
		{ view = "fp", sign = -1, delay = 0, level = 1, ads = true },
		{ view = "fp", sign = 1, delay = 0.04, level = 1, ads = true },
		{ view = "fp", sign = -1, delay = 0.12, level = 2, ads = true },
		{ view = "fp", sign = 1, delay = 0.02, level = 3, ads = true },
		{ view = "fp", sign = -1, delay = 0, level = 3, ads = false },
		{ view = "fp", sign = 1, delay = 0.4, level = 1, ads = false },
		{ view = "third", sign = -1, delay = 0, level = 1, ads = false },
		{ view = "third", sign = 1, delay = 0.12, level = 3, ads = false },
		{ view = "fp", sign = -1, delay = 0, level = 3, ads = true, perturb = true },
	}
	for _, case in cases do
		waitFor(function()
			return probe:Invoke("State").remaining <= 0
		end, 4, "cooldown")
		First.setActive(case.view == "fp")
		motion:Invoke("ShiftLock", case.view == "third")
		motion:Invoke("Move", { direction = Vector3.zero, duration = 2 })
		motion:Invoke("Sprint", false)
		Ads.set(false)
		task.wait(0.4)
		target = fixture:InvokeServer(45, false)
		task.wait(0.15)
		probe:Invoke("Press")
		if case.level > 1 then
			waitFor(function()
				return Recoil.stage() >= case.level
			end, 2, "visible kick missing")
		end
		motion:Invoke("Move", { direction = Vector3.new(-1, 0, case.sign).Unit, duration = 0.9 })
		motion:Invoke("Sprint", true)
		task.wait(case.delay)
		Ads.set(case.ads)
		local before = probe:Invoke("State").lastSent
		local sampled: any = nil
		local expected: Vector3? = nil
		local originOffset = 0
		local visibleError = 0
		pending = function()
			-- Model an in-frame camera write that is undone before drawing. The shot
			-- must keep the camera/muzzle pair actually shown in the previous frame.
			if case.perturb then
				camera.CFrame *= CFrame.Angles(0, math.rad(45), 0)
			end
			sampled = probe:Invoke("Aim", case.level / 3)
			if not sampled.target or not sampled.origin then
				result("missing-sample", {
					sameCharacter = P.Character == character,
					health = humanoid.Health,
					rootY = root.Position.Y,
					tool = character:FindFirstChildOfClass("Tool") ~= nil,
					view = case.view,
					level = case.level,
				})
				error("aim state unexpectedly missing")
			end
			visibleError = (sampled.target - (visibleTarget :: Vector3)).Magnitude
			assert(
				visibleError < 0.01,
				"input release aimed from a camera frame the player did not see"
			)
			originOffset = (sampled.origin - root.Position).Magnitude
			probe:Invoke("Release")
			expected = expectedImpact(sampled, case.level / 3)
		end
		waitFor(function()
			return probe:Invoke("State").lastSent > before
		end, 2, "release missing")
		local id = probe:Invoke("State").lastSent
		waitFor(function()
			return shots[id] ~= nil
		end, 3, "server did not accept moving shot")
		waitFor(function()
			return impacts[id] ~= nil
		end, 4, "impact missing")
		local packet, hit = shots[id], impacts[id]
		local agreement = (hit.position - (expected :: Vector3)).Magnitude
		if Combat.level(packet.charge) ~= case.level then
			result("power-mismatch", {
				expected = case.level,
				actual = Combat.level(packet.charge),
				charge = packet.charge,
				delay = case.delay,
			})
		end
		assert(Combat.level(packet.charge) == case.level, "visible kick/server power mismatch")
		assert(agreement < 0.08, "client/server collision disagree")
		if case.level == 3 and not sampled.obstructed then
			assert(
				(hit.position - sampled.target).Magnitude < 0.12,
				"full kick missed displayed crosshair"
			)
		end
		result("moving-shot", {
			view = case.view,
			sign = case.sign,
			delay = case.delay,
			level = case.level,
			ads = case.ads,
			perturb = case.perturb or false,
			speed = packet.velocity.Magnitude,
			error = {
				hit.position.X - sampled.target.X,
				hit.position.Y - sampled.target.Y,
				hit.position.Z - sampled.target.Z,
			},
			originOffset = originOffset,
			visibleError = visibleError,
			serverAgreement = agreement,
			obstructed = sampled.obstructed,
		})
	end
	-- Explicit close cover between eye and rendered barrel: shots must stop at
	-- this surface rather than starting beyond it and hitting a distant object.
	motion:Invoke("Move", { direction = Vector3.zero, duration = 10 })
	motion:Invoke("Sprint", false)
	Ads.set(true)
	task.wait(0.6)
	target = fixture:InvokeServer(45, false)
	task.wait(0.2)
	local clear = probe:Invoke("Aim", 1)
	local middle = camera.CFrame.Position:Lerp(clear.origin, 0.5)
	local coverPose = CFrame.lookAt(middle, middle + camera.CFrame.LookVector)
	local coverRemote = RS:WaitForChild("ShotConsistencyCover") :: RemoteFunction
	coverRemote:InvokeServer(coverPose)
	task.wait(0.3)
	for _, level in { 1, 3 } do
		waitFor(function()
			return probe:Invoke("State").remaining <= 0
		end, 4, "cover cooldown")
		probe:Invoke("Press")
		if level == 3 then
			waitFor(function()
				return Recoil.stage() == 3
			end, 2, "cover charge")
		end
		local sample = probe:Invoke("Aim", level / 3)
		assert(sample.obstructed and sample.origin, "barrel ignored nearby cover")
		probe:Invoke("Release")
		local id = probe:Invoke("State").lastSent
		waitFor(function()
			return shots[id] ~= nil and impacts[id] ~= nil
		end, 3, "cover impact missing")
		local localContact = coverPose:PointToObjectSpace(impacts[id].position)
		assert(math.abs(localContact.Z) < 0.1, "shot bypassed close cover")
		task.wait(0.05)
		local holder = camera:FindFirstChild("SlugShots")
		if holder then
			for _, model in holder:GetChildren() do
				if model:IsA("Model") and model:GetAttribute("ShotId") == id then
					assert(
						model:GetAttribute("RecoveryPhase") ~= nil,
						"visual flew past authoritative impact"
					)
				end
			end
		end
		result("cover-shot", {
			level = level,
			depth = localContact.Z,
			range = (impacts[id].position - sample.origin).Magnitude,
		})
	end
	coverRemote:InvokeServer(nil)
	-- The shoulder fallback follows the same close-cover policy if a freshly
	-- equipped first-person muzzle has not become available yet.
	local Viewmodel = (require :: any)(scripts:WaitForChild("Combat"):WaitForChild("Viewmodel"))
	local realMuzzle = Viewmodel.muzzle
	Viewmodel.muzzle = function()
		return nil
	end
	coverRemote:InvokeServer(coverPose)
	task.wait(0.1)
	waitFor(function()
		return probe:Invoke("State").remaining <= 0
	end, 4, "fallback cooldown")
	probe:Invoke("Press")
	local fallback = probe:Invoke("Aim", 0)
	assert(fallback.origin and fallback.obstructed, "shoulder fallback bypasses cover")
	probe:Invoke("Release")
	Viewmodel.muzzle = realMuzzle
	local fallbackId = probe:Invoke("State").lastSent
	waitFor(function()
		return impacts[fallbackId] ~= nil
	end, 3, "fallback impact missing")
	local fallbackContact = coverPose:PointToObjectSpace(impacts[fallbackId].position)
	assert(math.abs(fallbackContact.Z) < 0.1, "shoulder fallback shot passed through cover")
	result("cover-fallback", { depth = fallbackContact.Z })
	coverRemote:InvokeServer(nil)
	R:UnbindFromRenderStep("ConsistencyVisibleAim")
	waitFor(function()
		return RS:GetAttribute("ShotConsistencyPhysicsPass") ~= nil
	end, 20, "physics regressions missing")
	assert(RS:GetAttribute("ShotConsistencyPhysicsPass") == true, "physics regressions failed")
	result("timing", {
		frames = frameCount,
		meanDt = frameTotal / frameCount,
		maxDt = frameMax,
		arc = { T.shotArcOne, T.shotArcTwo },
	})
	R:UnbindFromRenderStep("ConsistencyRelease")
end)
active = false
R:UnbindFromRenderStep("ConsistencyCamera")
print("SHOOTCHECK " .. (if ok then "PASS shot consistency" else "FAIL " .. tostring(problem)))
