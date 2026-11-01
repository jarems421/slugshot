--!strict
-- Development-only LocalScript. Walks to the range wall; never teleports the root.
local player: any = game:GetService("Players").LocalPlayer
local RunService = game:GetService("RunService")
local probe = player.PlayerScripts:WaitForChild("MovementExperimentProbe")
local first = require(player.PlayerScripts.MovementSandbox.FirstPerson)
local lab = require(player.PlayerScripts.MovementSandbox.AcrobaticCamera)
local shared = game:GetService("ReplicatedStorage"):WaitForChild("MovementExperiment")
local root = player.Character.HumanoidRootPart
local humanoid = player.Character.Humanoid
local camera = workspace.CurrentCamera :: Camera
local rejected: { string } = {}
local remote = shared:WaitForChild("MovementRequest") :: RemoteEvent
local ack = remote.OnClientEvent:Connect(function(_, accepted, reason)
	if not accepted then
		table.insert(rejected, reason)
	end
end)
local function emit(data: any)
	print("[FlipCameraWallLive]", game:GetService("HttpService"):JSONEncode(data))
end
local function walk(target: Vector3)
	local deadline = os.clock() + 16
	repeat
		local delta = target - root.Position
		delta = Vector3.new(delta.X, 0, delta.Z)
		if delta.Magnitude < 1.3 then
			break
		end
		probe:Invoke("Move", { direction = delta.Unit, duration = 0.3 })
		task.wait(0.08)
	until os.clock() > deadline
	probe:Invoke("Move", { direction = Vector3.zero, duration = 0.4 })
	task.wait(0.3)
	local delta = target - root.Position
	assert(Vector3.new(delta.X, 0, delta.Z).Magnitude < 3, "walk setup timeout")
end
task.spawn(function()
	local monitor: RBXScriptConnection? = nil
	local ok, err = pcall(function()
		first.setActive(true)
		for mode = 1, 3 do
			lab.select(mode)
			walk(Vector3.new(-48, 3, -74.5))
			local deadline = os.clock() + 4
			repeat
				task.wait(0.05)
			until humanoid.FloorMaterial ~= Enum.Material.Air or os.clock() > deadline
			assert(humanoid.FloorMaterial ~= Enum.Material.Air, "wall approach airborne")
			camera.CFrame =
				CFrame.lookAt(camera.CFrame.Position, camera.CFrame.Position + Vector3.xAxis)
			local corrections = player:GetAttribute("MotionCorrections") or 0
			local rejectStart = #rejected
			local actions, frames, missing = {}, 0, 0
			monitor = RunService.RenderStepped:Connect(function()
				frames += 1
				actions[probe:Invoke("State").acro] = true
				if not camera:FindFirstChild("FirstPersonBodyVisual") then
					missing += 1
				end
			end)
			probe:Invoke("Move", { direction = Vector3.new(1, 0, -0.04).Unit, duration = 1.8 })
			task.wait(0.8)
			probe:Invoke("Jump")
			task.wait(0.35)
			probe:Invoke("Move", { direction = Vector3.zAxis, duration = 0.7 })
			task.wait(0.08)
			probe:Invoke("JumpPress")
			task.wait(1.25)
			if monitor then
				monitor:Disconnect()
			end
			monitor = nil
			local record = {
				mode = mode,
				actions = actions,
				frames = frames,
				missingRigFrames = missing,
				rejections = #rejected - rejectStart,
				correctionDelta = (player:GetAttribute("MotionCorrections") or 0) - corrections,
			}
			emit(record)
			assert(
				actions.WallRun and actions.WallHop and missing == 0,
				"wall action/camera continuity failed"
			)
			assert(
				record.rejections == 0 and record.correctionDelta == 0,
				"server rejected live traversal"
			)
		end
		emit({ pass = true })
	end)
	if monitor then
		monitor:Disconnect()
	end
	ack:Disconnect()
	probe:Invoke("Move", { direction = Vector3.zero, duration = 0.3 })
	lab.select(1, true)
	first.setActive(false)
	if not ok then
		warn("[FlipCameraWallLive] FAIL", err)
	end
end)
