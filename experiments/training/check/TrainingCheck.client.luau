--!strict
-- Disposable check for the portal, the zone's gun and the dummy settings, with stops for window captures.
-- Added only by build_game.py --check.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local floorPlan = require(ReplicatedStorage:WaitForChild("TrainingFloor")) :: any
local layout = require(ReplicatedStorage:WaitForChild("LobbyScale"):WaitForChild("layout")) :: any
local ORIGIN = Vector3.new(floorPlan.origin[1], floorPlan.origin[2], floorPlan.origin[3])

local function say(text: string)
	print(`TRAINCHECK {text}`)
end
local function result(ok: boolean, text: string)
	say(`{if ok then "PASS" else "FAIL"} {text}`)
end
local function shot(name: string)
	task.wait(1.6)
	say(`capture {name}`)
	task.wait(1.4)
end
local function untilTrue(predicate: () -> boolean, limit: number): boolean
	local deadline = os.clock() + limit
	while os.clock() < deadline do
		if predicate() then
			return true
		end
		task.wait(0.05)
	end
	return false
end
local function armed(): boolean
	local character, backpack = player.Character, player:FindFirstChildOfClass("Backpack")
	return (character ~= nil and character:FindFirstChild("Blaster") ~= nil)
		or (backpack ~= nil and backpack:FindFirstChild("Blaster") ~= nil)
end

-- Holds W (check.ps1 presses it for real) and wades in at 35 degrees to the portal.
local function cross(frame: CFrame, wantInside: boolean, label: string)
	local character = player.Character :: Model
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	local heading = (-frame.LookVector * math.cos(math.rad(35)) + frame.RightVector * math.sin(
		math.rad(35)
	)).Unit
	local start = frame.Position - heading * 13 + Vector3.new(0, 5, 0)
	local place = ReplicatedStorage:WaitForChild("TrainingCheckPlace") :: RemoteEvent
	place:FireServer(CFrame.lookAt(start, start + heading))
	untilTrue(function()
		return (character:GetPivot().Position - start).Magnitude < 6
	end, 5)
	task.wait(1)
	local veil =
		player.PlayerGui:WaitForChild("TrainingTransition"):FindFirstChildOfClass("Frame") :: Frame
	local steer = true
	local worstAt, movedAt = "", 0
	local lastCover, biggestStep, worst, outside, slowest = 0, 0, 0, 0, math.huge
	local loadingFor, captured = 0, false
	local connection = RunService.RenderStepped:Connect(function(dt)
		local screen = player.PlayerGui:FindFirstChild("LoadingScreen") :: ScreenGui?
		if screen and screen.Enabled then
			loadingFor += dt
			if loadingFor > 0.6 and not captured then
				captured = true
				say(`capture loading-{string.gsub(label, " ", "-")}`)
				-- Mid-hold the sheet must cover the whole screen, not sit partly lifted.
				local sheet = screen:FindFirstChild("Sheet") :: Frame?
				local view = (workspace.CurrentCamera :: Camera).ViewportSize
				if sheet then
					-- AbsolutePosition is measured below the top bar, even in a gui that ignores it.
					local top = sheet.AbsolutePosition.Y + GuiService:GetGuiInset().Y
					local bottom = top + sheet.AbsoluteSize.Y
					say(
						`{label} sheet at rest from {math.round(top)} to {math.round(bottom)} of {math.round(
							view.Y
						)}`
					)
					result(
						math.abs(top) <= 2 and bottom >= view.Y - 2,
						`{label} sheet covers the screen`
					)
				end
			end
		end
		if dt > worst then
			worst = dt
			worstAt = if steer
				then "before the move"
				else `{string.format("%.2f", os.clock() - movedAt)}s after arrival`
		end
		-- The green wash only counts while it can be seen, not under the loading screen.
		local cover = 1 - veil.BackgroundTransparency
		if not (screen and screen.Enabled) then
			biggestStep = math.max(biggestStep, math.abs(cover - lastCover))
		end
		lastCover = cover
		if steer then
			local eye = root.Position + Vector3.new(0, 1.5, 0)
			workspace.CurrentCamera.CFrame = CFrame.lookAt(eye, eye + heading)
			local there = frame:PointToObjectSpace(root.Position)
			if math.abs(there.Z) > 8 then
				outside = math.max(outside, humanoid.WalkSpeed)
			elseif math.abs(there.Z) < 4 then
				slowest = math.min(slowest, humanoid.WalkSpeed)
			end
		end
	end)
	say("key down")
	local began = os.clock()
	local arrived = untilTrue(function()
		return (player:GetAttribute("InTraining") == true) == wantInside
	end, 8)
	steer, movedAt = false, os.clock()
	-- The attribute can arrive just before the body does.
	untilTrue(function()
		return ((root.Position - ORIGIN).Magnitude < 1000) == wantInside
	end, 3)
	local out = root.Position
	untilTrue(function()
		return veil.BackgroundTransparency > 0.5
	end, 3)
	task.wait(0.7)
	local carried = (root.Position - out).Magnitude
	say("key up")
	task.wait(0.6)
	untilTrue(function()
		return veil.BackgroundTransparency > 0.98
	end, 3)
	connection:Disconnect()
	local line =
		"%s %.2fs, walking %.1f, at the middle %.1f, biggest veil step %.2f, worst frame %.0fms, moved %.1f on the far side"
	say(
		line:format(label, os.clock() - began, outside, slowest, biggestStep, worst * 1000, carried)
	)
	say(`{label} worst frame came {worstAt}`)
	result(arrived, `{label} crossed at an angle`)
	result(slowest < outside * 0.85 and slowest > outside * 0.5, `{label} slowed slightly`)
	result(biggestStep < 0.4, `{label} view changes gradually`)
	say(`{label} loading screen up {string.format("%.2f", loadingFor)}s`)
	result(loadingFor > 1.9 and loadingFor < 2.9, `{label} loading screen shows briefly`)
	result(carried > 3 and carried < 100, `{label} kept walking out`)
	result(
		((root.Position - ORIGIN).Magnitude < 1000) == wantInside,
		`{label} stays on the far side`
	)
end

local function view(name: string, from: Vector3, at: Vector3)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(ORIGIN + from, ORIGIN + at)
	shot(name)
end

local function run()
	workspace:SetAttribute("LoadingScreenTiming", true) -- local only: the loading screen logs its slow frames
	local character = player.Character or player.CharacterAdded:Wait()
	character:WaitForChild("HumanoidRootPart")
	result(
		untilTrue(function()
			return workspace:GetAttribute("TrainingReady") == true
		end, 150),
		"arena built"
	)
	task.wait(3)
	result(not armed(), "no gun in the lobby")
	local gui = player.PlayerGui:FindFirstChild("CombatHUD")
	result(gui == nil or not (gui :: ScreenGui).Enabled, "no combat HUD in the lobby")

	local lobbyFrame: CFrame
	for _, entry in layout.portals do
		if entry.name == "Training" then
			local rad = math.rad(entry.angle)
			local base =
				Vector3.new(entry.radius * math.sin(rad), entry.rise, -entry.radius * math.cos(rad))
			lobbyFrame = CFrame.lookAt(base, Vector3.new(0, base.Y, 0))
		end
	end
	cross(lobbyFrame, true, "enter")
	local root = (player.Character :: Model):WaitForChild("HumanoidRootPart") :: BasePart
	local arrivedAt = root.Position - ORIGIN
	say(
		`enter arrived at {math.round(arrivedAt.X)}, {math.round(arrivedAt.Y)}, {math.round(
			arrivedAt.Z
		)}`
	)
	result(arrivedAt.Magnitude < 160 and arrivedAt.Y > -3, "standing on the island")
	result(untilTrue(armed, 3), "gun handed over")
	task.wait(2.5)
	result((root.Position - ORIGIN).Magnitude < 160, "the motion check left the player there")
	shot("arrival")

	local moving = workspace:FindFirstChild("Moving 28", true) :: Model
	local remote = ReplicatedStorage:WaitForChild("TrainingDummySettings") :: RemoteEvent
	local a = moving:GetPivot().Position
	task.wait(2)
	result((moving:GetPivot().Position - a).Magnitude > 1, "moving dummy moves")
	remote:FireServer("Speed", 0)
	task.wait(0.4)
	a = moving:GetPivot().Position
	task.wait(0.5)
	result((moving:GetPivot().Position - a).Magnitude < 0.01, "stop holds it")
	remote:FireServer("Speed", 99)
	task.wait(0.3)
	result(workspace:GetAttribute("TrainingDummySpeed") == 0, "forged speed refused")
	remote:FireServer("Health", 300)
	task.wait(0.3)
	local humanoid = moving:FindFirstChildOfClass("Humanoid") :: Humanoid
	result(humanoid.MaxHealth == 300, "HP setting applies")
	remote:FireServer("Speed", 7)
	task.wait(0.2)
	remote:FireServer("Health", 100)
	task.wait(0.3)

	-- Knocked out, a dummy falls back flat, then stands up again at full health.
	local still = workspace:FindFirstChild("Still 35", true) :: Model
	local upright = still:GetPivot()
	local stillHumanoid = still:FindFirstChildOfClass("Humanoid") :: Humanoid
	view("knockdown-before", Vector3.new(70, 6, 52), Vector3.new(58, 3, 35))
	local knock = ReplicatedStorage:WaitForChild("TrainingCheckKnock") :: RemoteEvent
	knock:FireServer(still)
	local lowest, back = 1, 0
	local deadline = os.clock() + 0.9
	-- Announced while it lies on the ground: the capture script polls the log every 0.3 s.
	task.delay(0.32, say, "capture knockdown-down")
	while os.clock() < deadline do
		local up = still:GetPivot().UpVector
		if up.Y < lowest then
			-- The firing line is toward +Z, so falling back sends the top toward -Z.
			lowest, back = up.Y, -up.Z
		end
		task.wait()
	end
	say(`knockdown lowest up {string.format("%.2f", lowest)}`)
	result(lowest < 0.3, "a knocked-out dummy falls flat")
	result(back > 0.9, "it falls backwards, away from the firing line")
	task.wait(1.2)
	result(
		(still:GetPivot().Position - upright.Position).Magnitude < 0.01
			and still:GetPivot().UpVector:Dot(upright.UpVector) > 0.9999,
		"it stands back up where it was"
	)
	result(stillHumanoid.Health == stillHumanoid.MaxHealth, "at full health")
	shot("knockdown-after")

	view("juice-side", Vector3.new(15, 7, 114), Vector3.new(0, 10, 128))
	view("juice-front", Vector3.new(0, 8, 102), Vector3.new(0, 11, 128))
	view("juice-corner", Vector3.new(-9, 3.5, 119), Vector3.new(-10, 2, 128))
	view("above", Vector3.new(230, 190, 250), Vector3.new(0, -14, 0))
	view("top", Vector3.new(0, 300, 1), Vector3.zero) -- under the void's lid
	view("firing-line", Vector3.new(40, 6, 80), Vector3.new(80, 4, -40))
	view("course", Vector3.new(-20, 9, 90), Vector3.new(-60, 4, -10))
	view("walls", Vector3.new(-80, 10, 46), Vector3.new(-112, 10, -10))
	view("runes", Vector3.new(0, 7, 124), Vector3.new(0, 6, 88))
	view("runes-move", Vector3.new(-24, 6, 106), Vector3.new(-26, 6.5, 89))
	view("runes-target", Vector3.new(24, 6, 106), Vector3.new(26, 6.5, 89))
	view("station", Vector3.new(52, 6, 92), Vector3.new(60, 3, 82))
	view("edge-down", Vector3.new(-100, 7, -70), Vector3.new(-190, -80, -130))
	view("void", Vector3.new(60, 8, -70), Vector3.new(300, 60, -500))
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	task.wait(0.5)
	local at_ = floorPlan.station.at
	local place_ = ReplicatedStorage:WaitForChild("TrainingCheckPlace") :: RemoteEvent
	place_:FireServer(
		CFrame.new(
			ORIGIN + Vector3.new(at_[1] - 6, 3.5, at_[2] + 4),
			ORIGIN + Vector3.new(at_[1], 3, at_[2])
		)
	)
	task.wait(1.5)
	shot("prompt")
	say("press F")
	task.wait(1)
	result(player:GetAttribute("PvpMenu") == "TrainingDummies", "F opens the dummy settings")
	shot("panel")
	player:SetAttribute("PvpMenu", "Settings")
	shot("settings-tab")
	player:SetAttribute("PvpMenu", "TrainingDummies")
	task.wait(0.4)
	say("press F")
	task.wait(0.8)
	result(player:GetAttribute("PvpMenu") == nil, "F closes them")

	local at = floorPlan.arrival.portal
	local position = ORIGIN + Vector3.new(at[1], at[2], at[3])
	cross(CFrame.lookAt(position, position + Vector3.new(0, 0, -1)), false, "exit")
	result(
		untilTrue(function()
			return not armed()
		end, 3),
		"gun gone again"
	)
	result(
		untilTrue(function()
			return (root.Position - ORIGIN).Magnitude > 1000
		end, 3),
		"back in the lobby"
	)
	task.wait(0.6)
	result(
		workspace.CurrentCamera.CFrame.LookVector:Dot(lobbyFrame.LookVector) > 0.3,
		"looking away from the portal"
	)
	task.wait(0.2)
	local lobbyCamera = workspace.CurrentCamera
	lobbyCamera.CameraType = Enum.CameraType.Scriptable
	lobbyCamera.CFrame = CFrame.lookAt(
		lobbyFrame.Position + lobbyFrame.LookVector * 26 + Vector3.new(0, 8, 0),
		lobbyFrame.Position + Vector3.new(0, 11, 0)
	)
	shot("lobby-portal")
	lobbyCamera.CameraType = Enum.CameraType.Custom
	cross(lobbyFrame, true, "enter again")
	say("done")
end

local ok: boolean, problem: any = pcall(run)
if not ok then
	result(false, `check stopped: {problem}`)
	say("done")
end
