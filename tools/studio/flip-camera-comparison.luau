--!strict
-- Development-only LocalScript probe. Inject into PlayerScripts during Studio Play.
-- Never mapped into a playable place. Uses the actual movement/firing entry points.
local player: any = game:GetService("Players").LocalPlayer
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local movement = player.PlayerScripts:WaitForChild("MovementExperimentProbe")
local combat = player.PlayerScripts:WaitForChild("CombatExperimentProbe")
local first = require(player.PlayerScripts.MovementSandbox.FirstPerson)
local lab = require(player.PlayerScripts.MovementSandbox.AcrobaticCamera)
local viewmodel = require(player.PlayerScripts.Combat.Viewmodel)
if player:GetAttribute("FlipCameraProbeRunning") then
	return
end
player:SetAttribute("FlipCameraProbeRunning", true)

local function emit(tag: string, data: any)
	print("[FlipCamera" .. tag .. "]", HttpService:JSONEncode(data))
end

local function angle(a: CFrame, b: CFrame): number
	local _, radians = a:ToObjectSpace(b):ToAxisAngle()
	return math.deg(math.abs(radians))
end

task.spawn(function()
	local connection: RBXScriptConnection? = nil
	local ok, err = pcall(function()
		local old = player.Character
		task.wait(3.1) -- respect the existing server respawn cooldown across probe runs
		movement:Invoke("Respawn")
		local deadline = os.clock() + 8
		repeat
			task.wait(0.1)
		until (player.Character and player.Character ~= old) or os.clock() > deadline
		assert(player.Character ~= old, "respawn timeout")
		task.wait(1)
		local character = player.Character
		local root = character:WaitForChild("HumanoidRootPart")
		local camera = workspace.CurrentCamera :: Camera
		local cases = 0
		local lastCaseRespawn = os.clock()
		local measuring: any = nil
		connection = RunService.RenderStepped:Connect(function(dt)
			if not measuring then
				return
			end
			if character:GetAttribute("FirstPersonAction") ~= "Flip" then
				return
			end
			measuring.frames += 1
			measuring.maxDt = math.max(measuring.maxDt, dt)
			measuring.maxRotation =
				math.max(measuring.maxRotation, angle(lab.base(), camera.CFrame))
			measuring.minRootUp = math.min(measuring.minRootUp, root.CFrame.UpVector.Y)
			measuring.maxLookDrift =
				math.max(measuring.maxLookDrift, angle(measuring.look, lab.base().Rotation))
			local visual = camera:FindFirstChild("FirstPersonBodyVisual")
			if not visual then
				measuring.missingRigFrames += 1
				return
			end
			for _, name in { "Left Arm", "Right Arm" } do
				local limb = visual:FindFirstChild(name)
				if limb and limb:IsA("BasePart") then
					local hand = camera.CFrame:PointToObjectSpace(
						limb.CFrame * Vector3.new(0, -limb.Size.Y / 2, 0)
					)
					local stats = measuring.hands[name]
					if stats.previous then
						stats.travel += (hand - stats.previous).Magnitude
					end
					stats.previous = hand
					local _, visible = camera:WorldToViewportPoint(camera.CFrame * hand)
					if visible and limb.LocalTransparencyModifier < 0.8 then
						stats.seen += 1
					end
				end
			end
			local arm, handle = visual:FindFirstChild("Right Arm"), visual:FindFirstChild("Handle")
			if arm and arm:IsA("BasePart") and handle and handle:IsA("BasePart") then
				local hand = arm.CFrame * Vector3.new(0, -arm.Size.Y / 2, 0)
				measuring.maxGunGap =
					math.max(measuring.maxGunGap, (handle.Position - hand).Magnitude)
			end
			local muzzle = viewmodel.muzzle()
			if muzzle then
				measuring.maxMuzzleDistance =
					math.max(measuring.maxMuzzleDistance, (muzzle - root.Position).Magnitude)
			end
		end)

		local function stage(index: number)
			if script:GetAttribute("FreshCharacter") then
				task.wait(math.max(0, 3.1 - (os.clock() - lastCaseRespawn)))
				local previous = player.Character
				movement:Invoke("Respawn")
				lastCaseRespawn = os.clock()
				local respawnDeadline = os.clock() + 8
				repeat
					task.wait(0.05)
				until (player.Character and player.Character ~= previous)
					or os.clock() > respawnDeadline
				assert(player.Character ~= previous, "case respawn timeout")
				character = player.Character
				root = character:WaitForChild("HumanoidRootPart")
				task.wait(0.65)
			end
			movement:Invoke("Move", { direction = Vector3.zero, duration = 0.5 })
			root.CFrame = CFrame.new(-70, 3, 10)
			root.AssemblyLinearVelocity = Vector3.zero
			character.Humanoid:ChangeState(Enum.HumanoidStateType.Running)
			lab.select(index)
			first.setActive(true)
			task.wait(0.55)
			camera.CFrame =
				CFrame.lookAt(camera.CFrame.Position, camera.CFrame.Position - Vector3.zAxis)
			task.wait(0.15)
			local groundDeadline = os.clock() + 2
			repeat
				task.wait()
			until character.Humanoid.FloorMaterial ~= Enum.Material.Air
				or os.clock() > groundDeadline
			assert(character.Humanoid.FloorMaterial ~= Enum.Material.Air, "case did not ground")
		end
		local function flip(direction: Vector3)
			movement:Invoke("Move", { direction = direction, duration = 1.05 })
			task.wait(0.1)
			movement:Invoke("Jump")
			task.wait(0.24)
			movement:Invoke("JumpPress")
			local renderDeadline = os.clock() + 0.35
			repeat
				RunService.RenderStepped:Wait()
			until character:GetAttribute("FirstPersonAction") == "Flip"
				or os.clock() > renderDeadline
			assert(character:GetAttribute("FirstPersonAction") == "Flip", "flip did not start")
		end
		for mode = 1, (script:GetAttribute("MaxMode") or 3) :: number do
			for sector = 0, 7 do
				local state = combat:Invoke("State")
				task.wait(state.remaining + 0.15)
				stage(mode)
				local held = sector % 2 == 1
				if held then
					assert(combat:Invoke("Press").charging, "charge did not start")
					task.wait(0.6)
				end
				local a = sector * math.pi / 4
				local record: any = {
					mode = mode,
					sector = sector,
					held = held,
					frames = 0,
					maxDt = 0,
					maxRotation = 0,
					minRootUp = 1,
					maxLookDrift = 0,
					maxGunGap = 0,
					maxMuzzleDistance = 0,
					look = lab.base().Rotation,
					missingRigFrames = 0,
					hands = {
						["Left Arm"] = { travel = 0, seen = 0 },
						["Right Arm"] = { travel = 0, seen = 0 },
					},
				}
				measuring = record
				flip(Vector3.new(math.sin(a), 0, -math.cos(a)))
				task.wait(0.15)
				if not held then
					assert(combat:Invoke("Press").charging, "tap did not start")
					task.wait(0.025)
				end
				record.variant = character:GetAttribute("MovementVariant")
				record.firedDuringFlip = character:GetAttribute("FirstPersonAction") == "Flip"
				local fired = combat:Invoke("Release")
				local untilAck = os.clock() + 0.9
				repeat
					task.wait(0.02)
					state = combat:Invoke("State")
				until state.lastAccepted == fired.lastSent
					or state.lastRejectedId == fired.lastSent
					or os.clock() > untilAck
				record.accepted = state.lastAccepted == fired.lastSent
				record.reject = if record.accepted then "" else state.lastRejected
				task.wait(0.9)
				measuring = nil
				movement:Invoke("Move", { direction = Vector3.zero, duration = 0.4 })
				record.finalRotation = angle(lab.base(), camera.CFrame)
				record.finalLookDrift = angle(record.look, lab.base().Rotation)
				record.look = nil
				for _, stats in record.hands do
					stats.previous = nil
				end
				emit("Case", record)
				assert(record.accepted and record.firedDuringFlip, "mid-flip shot failed")
				assert(
					record.frames >= 3 and record.minRootUp > 0.999 and record.missingRigFrames == 0,
					"missing frames or rotated physics root"
				)
				assert(
					record.maxGunGap < 0.5 and record.maxMuzzleDistance < 6,
					"gun detached or origin out of range"
				)
				assert(
					record.maxLookDrift < 0.15 and record.finalLookDrift < 0.15,
					"presentation leaked into player look"
				)
				assert(record.finalRotation < 0.25, "rotation failed to settle")
				assert(
					if mode == 1
						then record.maxRotation < 0.1
						elseif mode == 2 then record.maxRotation > 2 and record.maxRotation < 23
						else record.maxRotation > 130,
					"profiles not distinct"
				)
				cases += 1
			end
		end

		stage(3)
		flip(-Vector3.zAxis)
		lab.select(2)
		task.wait(0.08)
		local selected, requested = lab.status()
		assert(selected == 3 and requested == 2, "selection did not queue")
		task.wait(1)
		assert(lab.status() == 2, "queued mode not applied")
		emit("Lifecycle", { queue = true })
		stage(3)
		flip(-Vector3.zAxis)
		task.wait(0.14)
		lab.select(1, true)
		task.wait(0.35)
		assert(lab.status() == 1 and angle(lab.base(), camera.CFrame) < 1, "steady return failed")
		emit("Lifecycle", { steadyReturn = true })
		task.wait(0.8)
		stage(3)
		flip(-Vector3.zAxis)
		first.setActive(false)
		task.wait(0.15)
		assert(not camera:FindFirstChild("FirstPersonBodyVisual"), "first-person rig survived exit")
		assert(angle(lab.base(), camera.CFrame) < 0.01, "effect leaked to third person")
		emit("Lifecycle", { thirdPersonExit = true })
		local before = player.Character
		task.wait(math.max(0, 3.1 - (os.clock() - lastCaseRespawn)))
		movement:Invoke("Respawn")
		deadline = os.clock() + 8
		repeat
			task.wait(0.1)
		until (player.Character and player.Character ~= before) or os.clock() > deadline
		task.wait(1)
		assert(player.Character ~= before and not first.active(), "respawn state failed")
		local panels = 0
		for _, item in player.PlayerGui:GetChildren() do
			if item.Name == "Settings" then
				panels += 1
			end
		end
		assert(
			panels == 1 and not player.PlayerGui:FindFirstChild("FlipCameraComparison"),
			"settings duplicated or old comparison panel survived"
		)
		emit("Lifecycle", { respawn = true, panelCount = panels })
		emit("Result", {
			pass = true,
			cases = cases,
			coverage = if cases == 0 then "lifecycleOnly" else "directionalAndLifecycle",
		})
	end)
	if connection then
		connection:Disconnect()
	end
	lab.select(1, true)
	first.setActive(false)
	movement:Invoke("Move", { direction = Vector3.zero, duration = 0.2 })
	player:SetAttribute("FlipCameraProbeRunning", nil)
	if not ok then
		warn("[FlipCameraResult] FAIL", err)
	end
end)
