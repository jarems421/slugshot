--!strict
-- Disposable check for the portal, the zone's gun and the dummy settings, with stops for window captures.
-- Added only by build_game.py --check.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LogService = game:GetService("LogService")

local runtimeError = false
LogService.MessageOut:Connect(function(message: string, kind: Enum.MessageType)
	if
		kind == Enum.MessageType.MessageError
		and (
			string.find(message, "FloppyIdle", 1, true)
			or string.find(message, "Equipment", 1, true)
			or string.find(message, "Inventory", 1, true)
		)
	then
		runtimeError = true
	end
end)

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
	local character = player.Character
	return character ~= nil and character:FindFirstChild("Blaster") ~= nil
end

local function checkHolster(label: string, selectedId: string)
	local template = game:GetService("StarterPack"):WaitForChild("Blaster")
	local ghost: Model? = nil
	result(
		untilTrue(function()
			ghost = (workspace.CurrentCamera :: Camera):FindFirstChild(
					"BlasterHolsterVisual"
				) :: Model?
			return ghost ~= nil and (ghost :: Model):GetAttribute("HolsteredSlugId") == selectedId
		end, 5),
		`{label}: holster shows {selectedId}`
	)
	if not ghost then
		return
	end
	local model = ghost :: Model
	local handle = model:FindFirstChild("VisualHandle") :: BasePart
	local character = player.Character :: Model
	local leg = (
		character:FindFirstChild("Right Leg") or character:FindFirstChild("RightUpperLeg")
	) :: BasePart
	say(
		`{label} muzzle vertical {handle.CFrame.LookVector.Y}, relative to thigh {handle.CFrame.LookVector:Dot(
			leg.CFrame.UpVector
		)}`
	)
	result(
		handle.CFrame.LookVector:Dot(leg.CFrame.UpVector) < -0.9,
		`{label}: muzzle faces down along the thigh`
	)
	local scale = model:GetScale()
	local worst, checked = 0, 0
	for _, name in { "CanisterTeal", "FloppyBody", "InfernoBody" } do
		local source = template:FindFirstChild(name, true)
		local copy = model:FindFirstChild(name, true)
		local weld = source and source:FindFirstChildOfClass("Weld")
		if copy and copy:IsA("BasePart") and weld then
			local actual = handle.CFrame:ToObjectSpace(copy.CFrame)
			worst = math.max(worst, (actual.Position - weld.C0.Position * scale).Magnitude)
			checked += 1
		end
	end
	result(
		checked == 3 and worst < 0.02,
		`{label}: canister and slugs retain authored weld positions`
	)
	local hidden = model:FindFirstChild(
		if selectedId == "Floppy" then "InfernoBody" else "FloppyBody",
		true
	) :: BasePart?
	result(
		hidden ~= nil and (hidden :: BasePart).Transparency == 1,
		`{label}: other loaded slug hidden`
	)
	result(
		model:FindFirstChildWhichIsA("Motor6D", true) ~= nil,
		`{label}: skinned rig joints retained`
	)
end

local function checkLobby(label: string)
	local character = player.Character :: Model
	local movement = player.PlayerScripts:WaitForChild("MovementSandbox")
	local firstPerson = (require :: any)(movement:WaitForChild("FirstPerson"))
	firstPerson.setActive(false)
	local backpack = player:WaitForChild("Backpack")
	result(
		untilTrue(function()
			local tool = backpack:FindFirstChild("Blaster") :: Tool?
			return tool ~= nil and not tool.Enabled and not armed()
		end, 10),
		`{label}: gun carried but not equipped`
	)
	result(character:GetAttribute("LobbyHolstered") == true, `{label}: server requests hip holster`)
	result(
		untilTrue(function()
			return (workspace.CurrentCamera :: Camera):FindFirstChild("BlasterHolsterVisual") ~= nil
		end, 5),
		`{label}: hip visual exists`
	)
	local hud = player.PlayerGui:WaitForChild("CombatHUD") :: ScreenGui
	local bar = hud:WaitForChild("SlugBar")
	result(
		bar:WaitForChild("Health"):FindFirstChild("Sprint") == nil,
		`{label}: sprint label removed`
	)
	local bag = bar:WaitForChild("InventoryToggle") :: TextButton
	result(
		bag.Text == "" and bag:FindFirstChild("Bag") ~= nil and bag.Position.Y.Offset < 40,
		`{label}: bag icon beside health`
	)
	result(
		hud.Enabled and (bar:WaitForChild("Health") :: Frame).Visible,
		`{label}: health and hotbar visible`
	)
	say("press Two")
	result(
		untilTrue(function()
			return character:GetAttribute("SelectedSlugSlot") == 2
		end, 4),
		`{label}: number key selects a slug`
	)
	result(not armed(), `{label}: selecting does not draw the gun`)
	checkHolster(label, "Inferno")
	say("press F")
	local inventory = bar:WaitForChild("Inventory") :: Frame
	result(
		untilTrue(function()
			return player:GetAttribute("PvpMenu") == "Inventory" and inventory.Visible
		end, 4),
		`{label}: F opens inventory`
	)
	if label == "spawn" then
		task.wait(0.6) -- measure the tile after the inventory's opening animation
		local content = inventory:WaitForChild("Content")
		local tile = content:WaitForChild("Tile2"):WaitForChild("Inferno") :: TextButton
		local inset = GuiService:GetGuiInset()
		local centre = tile.AbsolutePosition + tile.AbsoluteSize / 2 + inset
		local viewport = (workspace.CurrentCamera :: Camera).ViewportSize
		say(
			`click {math.round(centre.X)} {math.round(centre.Y)} {math.round(viewport.X)} {math.round(
				viewport.Y
			)}`
		)
		local title = content:WaitForChild("Detail"):WaitForChild("SlugName") :: TextLabel
		result(
			untilTrue(function()
				return title.Text == "Inferno"
			end, 4),
			"inventory selection updates details"
		)
		say(`inventory details before capture: {title.Text}`)
	end
	shot(`{label}-inventory`)
	say("press F")
	untilTrue(function()
		return player:GetAttribute("PvpMenu") == nil
	end, 4)
	local remote = ReplicatedStorage:WaitForChild("SlugshotCombat") :: RemoteEvent
	local rejection = ""
	local response = remote.OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "Rejected" and data.id == 903113 then
			rejection = data.reason
		end
	end)
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	remote:FireServer("Fire", {
		id = 903113,
		slot = 2,
		origin = root.Position,
		direction = Vector3.zAxis,
		charge = 1,
	})
	result(
		untilTrue(function()
			return rejection == "lobby"
		end, 4),
		`{label}: server rejects a forged lobby shot`
	)
	response:Disconnect()
	local equip = ReplicatedStorage:WaitForChild("TrainingCheckEquip") :: RemoteFunction
	result(equip:InvokeServer(), `{label}: server reverses a forced draw`)
	say("press R")
	say("press E")
	task.wait(0.5)
	result(
		not armed() and character:GetAttribute("SlugInspectAt") == nil,
		`{label}: inspect and passive cannot draw`
	)
	shot(`{label}-holster`)
	if label == "spawn" then
		local camera = workspace.CurrentCamera :: Camera
		local savedFrame, savedType = camera.CFrame, camera.CameraType
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = CFrame.lookAt(
			root.CFrame:PointToWorldSpace(Vector3.new(3.4, 0.3, 2.4)),
			root.CFrame:PointToWorldSpace(Vector3.new(1, -0.6, 0))
		)
		shot("holster-close")
		camera.CFrame, camera.CameraType = savedFrame, savedType
	end
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

local function worldView(name: string, frame: CFrame)
	local camera = workspace.CurrentCamera :: Camera
	local previous, kind = camera.CFrame, camera.CameraType
	camera.CameraType, camera.CFrame = Enum.CameraType.Scriptable, frame
	shot(name)
	camera.CameraType, camera.CFrame = kind, previous
end

local function run()
	result(
		untilTrue(function()
			return workspace:GetAttribute("HubSceneLightsReady") == true
		end, 10),
		"complete wall lighting ready at startup"
	)
	local art = workspace:WaitForChild("HubArt")
	local function countLights(name: string): number
		local count = 0
		for _, item in art:GetChildren() do
			if item.Name == name and item:FindFirstChildOfClass("SpotLight") then
				count += 1
			end
		end
		return count
	end
	local lower, upper, roof =
		countLights("WallWash"), countLights("WallWashHigh"), countLights("RoofWash")
	result(lower > 0 and upper == 21 and roof == 18, "lower, upper and roof washes arrive together")
	workspace:SetAttribute("LoadingScreenTiming", true) -- local only: the loading screen logs its slow frames
	local character = player.Character or player.CharacterAdded:Wait()
	character:WaitForChild("HumanoidRootPart")
	checkLobby("spawn")
	local respawn = ReplicatedStorage:WaitForChild("TrainingCheckRespawn") :: RemoteFunction
	respawn:InvokeServer()
	result(
		untilTrue(function()
			return player.Character ~= nil
				and player.Character ~= character
				and (player.Character :: Model):FindFirstChild("HumanoidRootPart") ~= nil
		end, 15),
		"lobby respawn completes"
	)
	task.wait(1)
	checkLobby("respawn")
	local wallView = CFrame.lookAt(Vector3.new(0, 40, 0), Vector3.new(0, 155, -295))
	if untilTrue(function()
		return art:FindFirstChild("hub-cavern-00") ~= nil
	end, 60) then
		worldView("wall-startup", wallView)
	end
	result(
		untilTrue(function()
			return workspace:GetAttribute("TrainingReady") == true
		end, 300),
		"arena built"
	)
	task.wait(3)
	result(
		countLights("WallWash") == lower
			and countLights("WallWashHigh") == upper
			and countLights("RoofWash") == roof,
		"wall lighting count unchanged after scenery load"
	)
	local rims = 0
	for _, item in art:GetDescendants() do
		if item:GetAttribute("LuminousRim") and item:IsA("MeshPart") then
			rims += 1
			result(
				item.Material == Enum.Material.Neon
					and item.Color.R > 0.8
					and not item:HasTag("HubDistantInk"),
				"cavern cap rim pale, emissive and retained at low detail"
			)
		end
	end
	result(rims > 0, "cavern mushrooms have luminous rims")
	worldView("wall-settled", wallView)
	local closest: BasePart? = nil
	for _, item in art:GetDescendants() do
		if item:IsA("BasePart") and item:GetAttribute("LuminousRim") then
			if
				not closest
				or item.Position.Magnitude < (closest :: BasePart).Position.Magnitude
			then
				closest = item
			end
		end
	end
	if closest then
		local point = closest.Position
		local inward = (-point * Vector3.new(1, 0, 1)).Unit
		worldView("cavern-rim", CFrame.lookAt(point + inward * 25 + Vector3.new(0, 10, 0), point))
	end

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
	result(untilTrue(armed, 3), "gun drawn in training")
	task.wait(2.5)
	result((root.Position - ORIGIN).Magnitude < 160, "the motion check left the player there")
	shot("arrival")

	if not workspace:GetAttribute("TrainingUiOnly") then
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
	end

	do
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
		local stationPoint = ORIGIN + Vector3.new(at_[1], 4.2, at_[2])
		result(
			untilTrue(function()
				return (root.Position - stationPoint).Magnitude < 12
			end, 5),
			"standing beside the dummy station"
		)
		-- PromptShown depends on the station being in the gameplay view. The earlier
		-- third-person camera still faced away after teleporting the character.
		local stationCamera = workspace.CurrentCamera :: Camera
		stationCamera.CameraType = Enum.CameraType.Scriptable
		stationCamera.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 1.5, 0), stationPoint)
		result(
			untilTrue(function()
				local controls = player.PlayerGui:FindFirstChild("TrainingControls")
				return controls ~= nil and controls:FindFirstChild("TrainingPromptBoard") ~= nil
			end, 5),
			"dummy station prompt visible"
		)
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
		stationCamera.CameraType = Enum.CameraType.Custom
	end

	local at = floorPlan.arrival.portal
	local position = ORIGIN + Vector3.new(at[1], at[2], at[3])
	cross(CFrame.lookAt(position, position + Vector3.new(0, 0, -1)), false, "exit")
	result(
		untilTrue(function()
			return not armed()
		end, 3),
		"gun holstered again"
	)
	checkLobby("return")
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
	result(untilTrue(armed, 3), "gun drawn after re-entry")
	local combat = ReplicatedStorage:WaitForChild("SlugshotCombat") :: RemoteEvent
	local accepted = false
	local response = combat.OnClientEvent:Connect(function(kind: string, data: any)
		if kind == "Shot" and data.id == 903114 and data.shooter == player then
			accepted = true
		end
	end)
	root = (player.Character :: Model):WaitForChild("HumanoidRootPart") :: BasePart
	combat:FireServer("Fire", {
		id = 903114,
		slot = 2,
		origin = root.Position,
		direction = Vector3.xAxis,
		charge = 0.2,
	})
	result(
		untilTrue(function()
			return accepted
		end, 4),
		"server accepts a training shot"
	)
	response:Disconnect()
	if workspace:GetAttribute("TrainingUiOnly") then
		local previous = player.Character
		respawn:InvokeServer()
		result(
			untilTrue(function()
				local current = player.Character
				return current ~= nil
					and current ~= previous
					and current:GetAttribute("TrainingArrived") == true
					and armed()
			end, 15),
			"training respawn draws only after arrival"
		)
		root = (player.Character :: Model):WaitForChild("HumanoidRootPart") :: BasePart
		result((root.Position - ORIGIN).Magnitude < 160, "training respawn is inside the arena")
		shot("training-respawn")
	end
	result(not runtimeError, "no equipment, inventory or slug callback errors")
	say("done")
end

local ok: boolean, problem: any = pcall(run)
if not ok then
	result(false, `check stopped: {problem}`)
	say("done")
end
