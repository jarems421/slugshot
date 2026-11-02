--!strict
-- Development-only LocalScript for the disposable 900 x 100-stud wall fixture.
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
	local samples, focusResets = 0, 0
	local recoverUntil = 0
	repeat
		RS.Heartbeat:Wait()
		local s = state()
		assert(s.acro == "WallRun", "Long hold detached: " .. s.acro)
		if not s.jumpHeld then
			-- Editor focus loss releases real keys; restore the scripted hold for this fixture.
			focusResets += 1
			probe:Invoke("JumpHeld", true)
			recoverUntil = os.clock() + 0.4
		end
		assert(
			s.velocity.Y > 0 or os.clock() < recoverUntil,
			`Long hold descended: held={s.jumpHeld}, speed={s.wallSpeed}`
		)
		samples += 1
	until os.clock() > untilAt
	local rise = state().position.Y - startY
	print(
		"[WallRunSpace] sustained",
		samples,
		"samples, rise",
		rise,
		"editor focus resets",
		focusResets
	)
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

	-- The lip is within mantle reach: an along-wall tap must remain a height adjustment.
	probe:Invoke("Move", { direction = Vector3.xAxis, duration = 20 })
	probe:Invoke("JumpHeld", true)
	waitFor(function()
		local s = state()
		if s.acro == "WallRun" and not s.jumpHeld then
			probe:Invoke("JumpHeld", true)
		end
		return s.wallAtTop
	end, 16, "Did not reach wall lip")
	probe:Invoke("JumpHeld", false)
	probe:Invoke("JumpHeld", true)
	assert(state().acro == "WallRun", "Along-wall tap at lip accidentally mantled")
	probe:Invoke("JumpHeld", false)
	local away = state().wallNormal
	probe:Invoke("Move", { direction = (Vector3.xAxis + away).Unit, duration = 1 })
	-- No render-frame wait: the same-frame outward diagonal must win over a mantle.
	probe:Invoke("JumpHeld", true)
	assert(state().acro == "WallHop", "Same-frame diagonal at lip did not kick")
	assert(state().velocity:Dot(away) > 8, "Kick did not follow outward input")
	local untilAt = os.clock() + 0.45
	repeat
		RS.Heartbeat:Wait()
		assert(state().acro ~= "Mantle", "Held kick was stolen by automatic mantle")
	until os.clock() > untilAt
	print("[WallRunSpace] PASS: same-frame diagonal at lip, correct launch, no automatic mantle")
	local function reattach()
		probe:Invoke("JumpHeld", false)
		local old = player.Character
		task.wait(3.1) -- respect the existing server respawn cooldown between cases
		probe:Invoke("Respawn")
		waitFor(function()
			return player.Character ~= old and state().ready
		end, 15, "Respawn not ready")
		task.wait(1.2)
		probe:Invoke("Move", { direction = Vector3.xAxis, duration = 20 })
		task.wait(0.7)
		probe:Invoke("Jump")
		probe:Invoke("JumpHeld", true)
		waitFor(function()
			return state().acro == "WallRun"
		end, 3, "No reattachment")
	end
	for _, along in { -1, 1 } do
		reattach()
		probe:Invoke("JumpHeld", false)
		local outward = state().wallNormal
		probe:Invoke("Move", { direction = (Vector3.xAxis * along + outward).Unit, duration = 1 })
		probe:Invoke("JumpHeld", true)
		assert(state().acro == "WallHop", "Outward/backward diagonal did not kick immediately")
		assert(state().velocity.X * along > 8, "Kick kept the smoothed old travel direction")
	end
	reattach()
	waitFor(function()
		local s = state()
		if s.acro == "WallRun" and not s.jumpHeld then
			probe:Invoke("JumpHeld", true)
		end
		return s.wallAtTop
	end, 18, "Did not reach lip for deliberate mantle")
	probe:Invoke("JumpHeld", false)
	probe:Invoke("Move", { direction = -state().wallNormal, duration = 1 })
	probe:Invoke("JumpHeld", true)
	assert(state().acro == "Mantle", "Deliberate into-wall press must retain mantle")
	print(
		"[WallRunSpace] PASS: held climb, taps, reversal, immediate outward diagonals, lip priority, deliberate mantle"
	)
end)
if probe then
	probe:Invoke("JumpHeld", false)
	probe:Invoke("Move", { direction = Vector3.zero, duration = 0.2 })
end
if not ok then
	warn("[WallRunSpace] FAIL", err)
end
