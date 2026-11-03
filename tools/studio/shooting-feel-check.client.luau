--!strict
-- Disposable native controller/shot review; never part of the playable range.
local P = game:GetService("Players").LocalPlayer
local R = game:GetService("RunService")
local RS = game:GetService("ReplicatedStorage")
local H = game:GetService("HttpService")
local scripts = P:WaitForChild("PlayerScripts")
local probe = scripts:WaitForChild("CombatExperimentProbe") :: BindableFunction
local movement = scripts:WaitForChild("MovementSandbox")
local first = (require :: any)(movement:WaitForChild("FirstPerson"))
local ads = (require :: any)(movement:WaitForChild("Ads"))
local recoil = (require :: any)(movement:WaitForChild("BlasterRecoil"))
local combat = (require :: any)(RS:WaitForChild("Combat"))
local fixture = RS:WaitForChild("ShootingFeelFixture") :: RemoteFunction
local remote = RS:WaitForChild("SlugshotCombat") :: RemoteEvent
local shots: { [number]: any } = {}
local impacts: { [number]: any } = {}
local active = true
remote.OnClientEvent:Connect(function(kind: string, packet: any)
	if packet.shooter ~= P then
		return
	end
	if kind == "Shot" then
		shots[packet.id] = packet
	end
	if kind == "Impact" then
		impacts[packet.id] = packet
	end
end)
local function waitFor(test: () -> boolean, timeout: number, label: string)
	local endAt = os.clock() + timeout
	repeat
		if test() then
			return
		end
		task.wait()
	until os.clock() > endAt
	error(label)
end
local function capture(name: string)
	print("SHOOTCHECK shot " .. name)
	task.wait(1.3)
end
local flashSamples = 0
local ok, err = pcall(function()
	local character = P.Character or P.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local backpack = P:WaitForChild("Backpack")
	waitFor(function()
		return character:FindFirstChildOfClass("Tool") ~= nil
			or backpack:FindFirstChildOfClass("Tool") ~= nil
	end, 25, "gun missing")
	humanoid:EquipTool(
		(character:FindFirstChildOfClass("Tool") or backpack:FindFirstChildOfClass("Tool")) :: Tool
	)
	first.setActive(true)
	task.wait(2)
	local camera = workspace.CurrentCamera :: Camera
	local aimPoint = fixture:InvokeServer(25, false)
	camera.CameraType = Enum.CameraType.Scriptable
	R:BindToRenderStep("ShootingFeelReview", Enum.RenderPriority.Last.Value + 50, function()
		if not active then
			return
		end
		camera.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 1.5, 0), aimPoint)
		if recoil.stepHit(os.clock()) > 0.6 then
			local holo = camera:FindFirstChild("AdsHologram")
			if holo then
				for _, part in holo:GetChildren() do
					if
						part:IsA("BasePart")
						and part.Material == Enum.Material.Neon
						and part.Transparency < 0.5
					then
						assert(
							math.abs(part.Color.R - part.Color.G) < 0.04
								and math.abs(part.Color.G - part.Color.B) < 0.04,
							"charge flash has a colour cast"
						)
						flashSamples += 1
					end
				end
			end
		end
	end)
	print("SHOOTCHECK started")
	ads.set(true)
	task.wait(1)
	capture("ads-light")
	aimPoint = fixture:InvokeServer(25, true)
	task.wait(0.3)
	capture("ads-dark")
	local function shoot(distance: number, level: number)
		waitFor(function()
			return probe:Invoke("State").remaining <= 0
		end, 5, "cooldown did not end")
		task.wait(0.2)
		local state = probe:Invoke("State")
		local oldId = state.lastSent
		probe:Invoke("Press")
		waitFor(function()
			return recoil.stage() >= level
		end, 3, "charge kick missing")
		assert(recoil.stage() == level, "skipped requested kick")
		local sampled = probe:Invoke("Aim", level / 3)
		probe:Invoke("Release")
		waitFor(function()
			return probe:Invoke("State").lastSent > oldId
		end, 2, "no shot sent")
		local id = probe:Invoke("State").lastSent
		waitFor(function()
			return shots[id] ~= nil
		end, 3, "server did not accept shot")
		waitFor(function()
			return impacts[id] ~= nil
		end, 4, "no impact")
		local shot, hit = shots[id], impacts[id]
		assert(combat.level(shot.charge) == level, "visible kick and server charge disagree")
		local errorAt = hit.position - sampled.target
		assert(
			math.abs(errorAt.X) < 0.12 and math.abs(errorAt.Z) < 0.12,
			"shot missed target plane/crosshair horizontally"
		)
		if level == 3 then
			assert(errorAt.Magnitude < 0.12, "full charge did not hit crosshair")
		else
			assert(errorAt.Y < 0.05 and errorAt.Y > -4.1, "weak shot drop outside useful band")
		end
		print("SHOOTCHECK result " .. H:JSONEncode({
			distance = distance,
			level = level,
			charge = shot.charge,
			speed = shot.velocity.Magnitude,
			error = { errorAt.X, errorAt.Y, errorAt.Z },
		}))
	end
	for _, distance in { 25, 65, 85, 100, 120 } do
		aimPoint = fixture:InvokeServer(distance, true)
		task.wait(0.2)
		for _, level in (if distance <= 65 then { 1, 2, 3 } else { 3 }) do
			shoot(distance, level)
		end
	end
	ads.set(false)
	task.wait(0.5)
	aimPoint = fixture:InvokeServer(65, false)
	task.wait(0.2)
	shoot(65, 1)
	shoot(65, 3)
	for _, height in { -3, 5 } do
		aimPoint = fixture:InvokeServer(85, false, height)
		task.wait(0.2)
		shoot(85, 3)
	end
	assert(flashSamples > 0, "no white charge flash observed")
	print("SHOOTCHECK flash samples " .. flashSamples)
	ads.set(false)
	task.wait(0.5)
	local holo = camera:FindFirstChild("AdsHologram")
	if holo then
		for _, part in holo:GetChildren() do
			if part:IsA("BasePart") then
				assert(part.Transparency == 1, "ADS stroke remains visible after closing")
			end
		end
	end
end)
active = false
R:UnbindFromRenderStep("ShootingFeelReview")
print("SHOOTCHECK " .. (if ok then "PASS" else "FAIL " .. tostring(err)))
