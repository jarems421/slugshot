--!strict
-- Development-only LocalScript for the disposable 900 x 180-stud wall fixture.
-- Build using tools/build_wallrun_space_test.py. Never mapped to playable places.
local Players = game:GetService("Players")
local RS = game:GetService("RunService")
local player = Players.LocalPlayer
local probe = player.PlayerScripts:WaitForChild("MovementExperimentProbe", 30) :: BindableFunction
local function state(): any
	return probe:Invoke("State")
end
local function waitFor(test: () -> boolean, seconds: number, label: string)
	local untilAt = os.clock() + seconds
	repeat
		task.wait(0.03)
		if test() then
			return
		end
	until os.clock() > untilAt
	error(label)
end
local ok, err = pcall(function()
	assert(probe, "No probe")
	waitFor(function()
		return state().ready
	end, 20, "Avatar not ready")
	task.wait(2)
	probe:Invoke("Move", { direction = Vector3.xAxis, duration = 20 })
	task.wait(0.8)
	probe:Invoke("Jump")
	probe:Invoke("JumpHeld", true)
	waitFor(function()
		return state().acro == "WallRun"
	end, 3, "No wall attachment")
	local startY = state().position.Y
	local untilAt = os.clock() + 6
	local samples = 0
	repeat
		RS.Heartbeat:Wait()
		local s = state()
		assert(s.acro == "WallRun", "Long hold detached: " .. s.acro)
		assert(s.velocity.Y > 0, "Long hold descended")
		samples += 1
	until os.clock() > untilAt
	local rise = state().position.Y - startY
	print("[WallRunSpace] sustained", samples, "samples, rise", rise)
	assert(rise > 45, "Insufficient climb")
	for _, duration in { 0.05, 0.15, 0.3, 0.8 } do
		probe:Invoke("JumpHeld", false)
		task.wait(0.18)
		assert(state().acro == "WallRun", "Release kicked off")
		probe:Invoke("JumpHeld", true)
		task.wait(duration)
		assert(state().acro == "WallRun", "Tap press kicked off")
		probe:Invoke("JumpHeld", false)
		task.wait(0.08)
		assert(state().acro == "WallRun", "Tap release kicked off")
	end
	probe:Invoke("Move", { direction = -Vector3.xAxis, duration = 2 })
	task.wait(0.05)
	probe:Invoke("JumpHeld", true)
	task.wait(0.15)
	probe:Invoke("JumpHeld", false)
	assert(state().acro == "WallRun", "Reversal height tap kicked off")
	task.wait(0.3)
	local away = state().wallNormal
	probe:Invoke("Move", { direction = away, duration = 1 })
	task.wait(0.25)
	probe:Invoke("JumpHeld", true)
	waitFor(function()
		return state().acro == "WallHop"
	end, 1, "Outward kick did not fire")
	print(
		"[WallRunSpace] PASS: sustained hold, short releases, four height taps, reversal, deliberate outward kick"
	)
end)
if probe then
	probe:Invoke("JumpHeld", false)
	probe:Invoke("Move", { direction = Vector3.zero, duration = 0.2 })
end
if not ok then
	warn("[WallRunSpace] FAIL", err)
end
