--!strict
-- Development-only LocalScript; run after flip-camera-comparison in Studio Play.
local player: any = game:GetService("Players").LocalPlayer
local RunService = game:GetService("RunService")
local first = require(player.PlayerScripts.MovementSandbox.FirstPerson)
local lab = require(player.PlayerScripts.MovementSandbox.AcrobaticCamera)
local probe = player.PlayerScripts:WaitForChild("MovementExperimentProbe")
local HttpService = game:GetService("HttpService")
local traversal = require(player.PlayerScripts.MovementSandbox.Traversal)
local config = (require :: any)(
	game:GetService("ReplicatedStorage"):WaitForChild("MovementExperiment"):WaitForChild("Config")
)
local function emit(data: any)
	print("[FlipCameraTransitions]", HttpService:JSONEncode(data))
end
local function angle(a: CFrame, b: CFrame): number
	local _, radians = a:ToObjectSpace(b):ToAxisAngle()
	return math.deg(math.abs(radians))
end
task.spawn(function()
	local monitor: RBXScriptConnection? = nil
	local ok, err = pcall(function()
		local character = player.Character
		local root = character:WaitForChild("HumanoidRootPart")
		local camera = workspace.CurrentCamera :: Camera
		local function stage(mode: number, position: Vector3, direction: Vector3)
			probe:Invoke("Move", { direction = Vector3.zero, duration = 0.3 })
			root.CFrame = CFrame.lookAt(position, position + direction)
			root.AssemblyLinearVelocity = Vector3.zero
			character:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Running)
			lab.select(mode)
			first.setActive(true)
			task.wait(0.6)
			camera.CFrame =
				CFrame.lookAt(camera.CFrame.Position, camera.CFrame.Position + direction)
			task.wait(0.2)
			local deadline = os.clock() + 2
			repeat
				task.wait()
			until character.Humanoid.FloorMaterial ~= Enum.Material.Air or os.clock() > deadline
			assert(character.Humanoid.FloorMaterial ~= Enum.Material.Air, "stage failed to ground")
		end
		for mode = 1, 3 do
			if script:GetAttribute("WallOnly") then
				continue
			end
			stage(mode, Vector3.new(-70, 3, 10), -Vector3.zAxis)
			probe:Invoke("Move", { direction = -Vector3.zAxis, duration = 1.1 })
			probe:Invoke("Jump")
			task.wait(0.24)
			probe:Invoke("JumpPress")
			task.wait(0.08)
			assert(character:GetAttribute("FirstPersonAction") == "Flip", "look test missing flip")
			local before = lab.base().Rotation
			local pulses, delta = 0, 0.015
			RunService:BindToRenderStep(
				"FlipCameraLookProbe",
				Enum.RenderPriority.Input.Value + 2,
				function()
					if pulses >= 8 then
						return
					end
					camera.CFrame = CFrame.new(camera.CFrame.Position)
						* CFrame.Angles(0, delta, 0)
						* camera.CFrame.Rotation
					pulses += 1
				end
			)
			task.wait(0.35)
			RunService:UnbindFromRenderStep("FlipCameraLookProbe")
			local errorDegrees =
				angle(CFrame.Angles(0, delta * pulses, 0) * before, lab.base().Rotation)
			assert(pulses == 8 and errorDegrees < 0.1, "live look was filtered or lost")
			local start = character:GetAttribute("MovementActionTime")
			local duration = character:GetAttribute("FirstPersonFlipDuration")
			local remaining = math.max(0, start + duration * 0.73 - workspace:GetServerTimeNow())
			task.wait(remaining)
			local lateAngle = angle(lab.base(), camera.CFrame)
			if mode == 2 then
				assert(lateAngle < 0.25, "Spot did not level early")
			end
			task.wait(0.8)
			local expectedFov = player:GetAttribute("FieldOfView") or 72
			local fovError = math.abs(camera.FieldOfView - expectedFov)
			assert(fovError < 0.1, "lens pulse accumulated")
			emit({
				test = "injectedLook",
				mode = mode,
				degrees = math.deg(delta * pulses),
				errorDegrees = errorDegrees,
				lateAngle = lateAngle,
				fovError = fovError,
			})
		end
		for mode = 1, 3 do
			stage(mode, Vector3.new(-28, 3, -85), Vector3.xAxis)
			local actions, frames, missing = {}, 0, 0
			local maxAngle = 0
			monitor = RunService.RenderStepped:Connect(function()
				frames += 1
				actions[probe:Invoke("State").acro] = true
				if not camera:FindFirstChild("FirstPersonBodyVisual") then
					missing += 1
				end
				maxAngle = math.max(maxAngle, angle(lab.base(), camera.CFrame))
			end)
			probe:Invoke("Move", { direction = Vector3.xAxis, duration = 1.3 })
			task.wait(0.35)
			probe:Invoke("Jump")
			task.wait(0.42)
			local rays = traversal.params(character)
			local wall =
				traversal.findWall(character.Humanoid, root, config.Traversal.WallRun, rays)
			assert(wall, "wall fixture lost contact")
			probe:Invoke("Move", { direction = wall.Normal, duration = 0.5 })
			task.wait(0.12)
			probe:Invoke("JumpPress")
			task.wait(1.3)
			if monitor then
				monitor:Disconnect()
			end
			monitor = nil
			emit({
				test = "wallRunKick",
				mode = mode,
				frames = frames,
				missingRigFrames = missing,
				actions = actions,
				maxAngle = maxAngle,
			})
			assert(
				actions.WallRun and actions.WallHop and missing == 0,
				"wall run/kick or rig continuity failed"
			)
		end
		stage(3, Vector3.new(-70, 3, 10), -Vector3.zAxis)
		player:SetAttribute("FirstPersonFlipCameraEnabled", false)
		probe:Invoke("Jump")
		task.wait(0.24)
		probe:Invoke("JumpPress")
		task.wait(0.2)
		assert(angle(lab.base(), camera.CFrame) < 0.1, "disabled experiment still rotating")
		emit({ test = "disabledFallback", pass = true })
		task.wait(1)
		player:SetAttribute("FirstPersonFlipCameraEnabled", true)
		emit({ pass = true })
	end)
	if monitor then
		monitor:Disconnect()
	end
	RunService:UnbindFromRenderStep("FlipCameraLookProbe")
	player:SetAttribute("FirstPersonFlipCameraEnabled", true)
	lab.select(1, true)
	first.setActive(false)
	probe:Invoke("Move", { direction = Vector3.zero, duration = 0.3 })
	if not ok then
		warn("[FlipCameraTransitions] FAIL", err)
	end
end)
