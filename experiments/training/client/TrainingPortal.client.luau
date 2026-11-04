--!strict
-- Wading through the training portal, either way, at any angle. The juice has depth: the further in you are, the greener
-- the view and the slower you go. Touching it drops the loading screen (owner, 2026-11-03: so someone who stops in the
-- portal still notices the move); the move happens under it, and you come out clear of the far portal with your speed
-- and heading kept. The arena's art is preloaded in the background from the moment the place starts.
local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local floorPlan = require(ReplicatedStorage:WaitForChild("TrainingFloor")) :: any
local lobbyLayout =
	require(ReplicatedStorage:WaitForChild("LobbyScale"):WaitForChild("layout")) :: any
local remote = ReplicatedStorage:WaitForChild("TrainingPortal") :: RemoteEvent
local LoadingScreen = (require :: any)(
	(script.Parent :: Instance).Parent:WaitForChild("Combat"):WaitForChild("LoadingScreen")
)

local ORIGIN = Vector3.new(floorPlan.origin[1], floorPlan.origin[2], floorPlan.origin[3])
local WASH = Color3.fromRGB(107, 255, 115)
local ARRIVAL_LIMIT = 2.5 -- never hold the view shut longer than this
local JUICE_DEPTH = 5 -- studs either side of the portal's middle where it starts to take hold
local TOUCH = 3 -- this close to the middle, the body is touching the juice
local OPENING = 10.4 -- half the opening's width
local OPENING_HEIGHT = 27
local DRAG = 0.35 -- share of walking speed lost at the very middle

local gui = Instance.new("ScreenGui")
gui.Name = "TrainingTransition"
gui.IgnoreGuiInset, gui.ResetOnSpawn, gui.DisplayOrder = true, false, 100
local veil = Instance.new("Frame")
veil.Size, veil.BorderSizePixel = UDim2.fromScale(1, 1), 0
veil.BackgroundColor3, veil.BackgroundTransparency = WASH, 1
veil.Parent = gui
local depth = Instance.new("UIGradient")
depth.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 60, 30)),
})
depth.Rotation = 90
depth.Parent = veil
gui.Parent = player:WaitForChild("PlayerGui")

local blur = Instance.new("BlurEffect")
blur.Name, blur.Size, blur.Parent = "TrainingBlur", 0, Lighting

-- The lobby's fog is remembered on the way in. The arena has the same light, with its fog near black for the void.
local atmosphere: Atmosphere? = nil
local saved: { [string]: any }? = nil
local function setArenaLight(inArena: boolean)
	atmosphere = atmosphere or Lighting:FindFirstChildOfClass("Atmosphere")
	local air = atmosphere
	if not air then
		return
	end
	if inArena then
		saved = saved
			or {
				color = air.Color,
				decay = air.Decay,
				density = air.Density,
				haze = air.Haze,
			}
		air.Color, air.Decay = Color3.fromRGB(5, 5, 8), Color3.fromRGB(3, 3, 5)
		air.Density, air.Haze = 0.22, 2
	elseif saved then
		air.Color, air.Decay = saved.color, saved.decay
		air.Density, air.Haze = saved.density, saved.haze
	end
end

local function root(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local busy = false
local function setHud()
	local inside = player:GetAttribute("InTraining") == true
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	local hud = playerGui and playerGui:FindFirstChild("CombatHUD")
	if hud and hud:IsA("ScreenGui") then
		hud.Enabled = inside
	end
end

local function lobbyLook(): Vector3
	for _, entry in lobbyLayout.portals do
		if entry.name == "Training" then
			local rad = math.rad(entry.angle)
			return Vector3.new(-math.sin(rad), 0, math.cos(rad))
		end
	end
	return Vector3.zAxis
end

local function lobbyPortal(): CFrame
	for _, entry in lobbyLayout.portals do
		if entry.name == "Training" then
			local rad = math.rad(entry.angle)
			local base =
				Vector3.new(entry.radius * math.sin(rad), entry.rise, -entry.radius * math.cos(rad))
			return CFrame.lookAt(base, Vector3.new(0, base.Y, 0))
		end
	end
	error("No Training portal in the lobby layout")
end
local lobbyFrame = lobbyPortal()
local arenaPosition = ORIGIN + Vector3.new(table.unpack(floorPlan.arrival.portal))
local arenaFrame = CFrame.lookAt(arenaPosition, arenaPosition + Vector3.new(0, 0, -1))

local function currentFrame(): CFrame
	return if player:GetAttribute("InTraining") == true then arenaFrame else lobbyFrame
end

-- How far into the juice this point is, from 0 outside to 1 at the middle. It eases off toward the frame's sides so
-- coming in at an angle near an edge doesn't pop.
local function juiceAt(frame: CFrame, position: Vector3): number
	local there = frame:PointToObjectSpace(position)
	if there.Y < -2 or there.Y > OPENING_HEIGHT then
		return 0
	end
	local along = math.clamp(1 - math.abs(there.Z) / JUICE_DEPTH, 0, 1)
	local across = math.clamp((OPENING - math.abs(there.X)) / 1.5, 0, 1)
	return along * along * (3 - 2 * along) * across
end

local holding = false -- full colour regardless of depth, while the move happens
local shown = 0
local function juiceHere(): number
	local body = root()
	return if body then juiceAt(currentFrame(), body.Position) else 0
end

RunService.RenderStepped:Connect(function(dt)
	local goal = if holding then 1 else juiceHere()
	shown += (goal - shown) * (1 - math.exp(-(if holding then 20 else 14) * dt))
	veil.BackgroundTransparency = 1 - shown
	blur.Size = 20 * shown
end)

-- Straight after the movement client sets the walking speed, every frame, so this never compounds.
RunService:BindToRenderStep("TrainingPortalDrag", Enum.RenderPriority.Input.Value + 2, function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed *= 1 - DRAG * juiceHere()
	end
end)

local armed = false -- starts false: spawning next to a portal must not use it

local function travel(action: string, frame: CFrame, side: number)
	busy = true
	holding = true
	local camera = workspace.CurrentCamera
	-- What you were doing, relative to the portal: travel straight on is this basis's forward.
	local going = CFrame.lookAt(Vector3.zero, frame.LookVector * side)
	local onward = if action == "Enter" then arenaFrame.LookVector else lobbyLook()
	local leaving = CFrame.lookAt(Vector3.zero, onward)
	-- Taken as the juice is touched, before the screen drops.
	local body = root()
	local look = camera.CFrame.LookVector
	local velocity = if body then body.AssemblyLinearVelocity else Vector3.zero
	local lateral = if body then going:VectorToObjectSpace(body.Position - frame.Position).X else 0
	local wasInside = player:GetAttribute("InTraining") == true
	local loading = LoadingScreen.show(if action == "Enter" then "Training" else "Lobby")
	loading.covered()
	remote:FireServer(action, lateral)
	local started = os.clock()
	while os.clock() - started < ARRIVAL_LIMIT do
		body = root()
		if (player:GetAttribute("InTraining") == true) ~= wasInside and body then
			local there = (body.Position - ORIGIN).Magnitude < 1000
			if there == not wasInside then
				break
			end
		end
		task.wait()
	end
	setArenaLight(player:GetAttribute("InTraining") == true)
	setHud()
	body = root()
	if body then
		local eye = body.Position + Vector3.new(0, 1.5, 0)
		camera.CFrame =
			CFrame.lookAt(eye, eye + leaving:VectorToWorldSpace(going:VectorToObjectSpace(look)))
		body.AssemblyLinearVelocity =
			leaving:VectorToWorldSpace(going:VectorToObjectSpace(velocity))
	end
	task.wait(0.08) -- one beat for the arrival frame to draw
	loading.finish()
	while LoadingScreen.isShowing() do
		task.wait()
	end
	holding = false
	busy = false
end

-- Touching the juice is enough: walk in, stop, and you still go. You come out clear of the far portal, and it can't
-- take you back until you've stepped out of its reach and come at it again.
RunService.Heartbeat:Connect(function()
	local body = root()
	if not body or busy then
		return
	end
	local frame = currentFrame()
	local there = frame:PointToObjectSpace(body.Position)
	local inReach = math.abs(there.X) < OPENING
		and math.abs(there.Z) < TOUCH
		and there.Y > -2
		and there.Y < OPENING_HEIGHT
	if not inReach then
		armed = true
	elseif armed and workspace:GetAttribute("TrainingReady") then
		armed = false
		-- Which way you were heading, from the side you came in on: coming from the front (-Z) means going
		-- against the frame's look, into the portal.
		task.spawn(
			travel,
			if player:GetAttribute("InTraining") == true then "Exit" else "Enter",
			frame,
			if there.Z >= 0 then 1 else -1
		)
	end
end)

-- A fall off the island passes under the same wash.
task.spawn(function()
	while true do
		task.wait(0.1)
		local body = root()
		if not busy and body and player:GetAttribute("InTraining") and body.Position.Y < -170 then
			busy, holding = true, true
			while root() and (root() :: BasePart).Position.Y < -20 do
				task.wait()
			end
			task.wait(0.08)
			busy, holding = false, false
		end
	end
end)

player:GetAttributeChangedSignal("InTraining"):Connect(setHud)
task.spawn(function()
	for _ = 1, 40 do
		setHud()
		task.wait(0.5)
	end
end)

-- Background preload, so the first walk through doesn't pop in.
task.spawn(function()
	while not workspace:GetAttribute("TrainingReady") do
		task.wait(0.5)
	end
	local arena = workspace:FindFirstChild("TrainingArena")
	if arena then
		local items = arena:GetDescendants()
		pcall(function()
			ContentProvider:PreloadAsync(items)
		end)
	end
end)
