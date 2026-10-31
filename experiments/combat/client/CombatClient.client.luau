--!strict
-- Firing slugs: hold LMB (or R2) with the blaster out to charge, release to fire. A
-- tap still fires at a decent speed; a full charge is faster and droops less. The
-- shot flies on this screen at once and is sent to the server, which judges it.
-- One slot for now (Floppy); the ammo HUD shows its cooldown.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Combat = require(ReplicatedStorage:WaitForChild("Combat"))
local Visuals = require(script.Parent:WaitForChild("SlugVisuals"))
local Viewmodel = require(script.Parent:WaitForChild("Viewmodel"))
Viewmodel.start()

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("SlugshotCombat") :: RemoteEvent
local SLOT = 1
local slugId = Combat.Loadout[SLOT]
local slug = Combat.Slugs[slugId]
local POINT_HOLD = 0.35 -- the arm keeps pointing this long after a shot

local charging, chargeStart = false, 0
local readyAt = 0 -- predicted; the server's cooldown is the authority
local nextId = 0
local aimDirection = Vector3.new(0, 0, -1)
local pointUntil = 0
local pointing: { [Model]: number } = {} -- other shooters' arms, raised briefly

-- HUD -------------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "CombatHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true

local function corner(parent: Instance, radius: number)
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, radius)
	round.Parent = parent
end

local slotFrame = Instance.new("Frame")
slotFrame.Name = "Slot1"
slotFrame.AnchorPoint = Vector2.new(1, 1)
slotFrame.Position = UDim2.new(1, -24, 1, -24)
slotFrame.Size = UDim2.fromOffset(96, 112)
slotFrame.BackgroundColor3 = Color3.fromRGB(20, 26, 34)
slotFrame.BackgroundTransparency = 0.2
slotFrame.Parent = gui
corner(slotFrame, 10)
local view = Instance.new("ViewportFrame")
view.Size = UDim2.fromOffset(96, 88)
view.BackgroundTransparency = 1
view.Ambient = Color3.fromRGB(200, 200, 200)
view.LightColor = Color3.fromRGB(255, 250, 240)
view.Parent = slotFrame
local slotName = Instance.new("TextLabel")
slotName.Position = UDim2.fromOffset(0, 86)
slotName.Size = UDim2.fromOffset(96, 22)
slotName.BackgroundTransparency = 1
slotName.Font = Enum.Font.GothamBold
slotName.TextSize = 14
slotName.TextColor3 = Color3.fromRGB(229, 239, 248)
slotName.Text = `1  {string.upper(slug.Label)}`
slotName.Parent = slotFrame
local shade = Instance.new("Frame") -- drains downward as the cooldown runs out
shade.Size = UDim2.fromScale(1, 0)
shade.BackgroundColor3 = Color3.new(0, 0, 0)
shade.BackgroundTransparency = 0.35
shade.ZIndex = 3
shade.Parent = slotFrame
corner(shade, 10)
local countdown = Instance.new("TextLabel")
countdown.Size = UDim2.fromScale(1, 0.8)
countdown.BackgroundTransparency = 1
countdown.Font = Enum.Font.GothamBlack
countdown.TextSize = 30
countdown.TextColor3 = Color3.new(1, 1, 1)
countdown.TextStrokeTransparency = 0.4
countdown.ZIndex = 4
countdown.Parent = slotFrame

local chargeBar = Instance.new("Frame")
chargeBar.AnchorPoint = Vector2.new(0.5, 0)
chargeBar.Position = UDim2.new(0.5, 0, 0.5, 22)
chargeBar.Size = UDim2.fromOffset(96, 6)
chargeBar.BackgroundColor3 = Color3.fromRGB(20, 26, 34)
chargeBar.BackgroundTransparency = 0.3
chargeBar.Visible = false
chargeBar.Parent = gui
corner(chargeBar, 3)
local chargeFill = Instance.new("Frame")
chargeFill.Size = UDim2.fromScale(0, 1)
chargeFill.BackgroundColor3 = Color3.fromRGB(216, 211, 190)
chargeFill.Parent = chargeBar
corner(chargeFill, 3)

local marker = Instance.new("TextLabel") -- hit marker over the crosshair
marker.AnchorPoint = Vector2.new(0.5, 0.5)
marker.Position = UDim2.fromScale(0.5, 0.5)
marker.Size = UDim2.fromOffset(34, 34)
marker.BackgroundTransparency = 1
marker.Font = Enum.Font.GothamBlack
marker.TextSize = 30
marker.Text = "×"
marker.TextColor3 = Color3.fromRGB(255, 214, 92)
marker.TextTransparency = 1
marker.Parent = gui
gui.Parent = player:WaitForChild("PlayerGui")

-- The slot icon: the in-flight model, turning slowly.
task.spawn(function()
	local assets = ReplicatedStorage:WaitForChild("CombatAssets", 30)
	if not assets then
		return
	end
	local icon = Visuals.model(slugId)
	local world = Instance.new("WorldModel")
	icon.Parent = world
	world.Parent = view
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	view.CurrentCamera = camera
	camera.Parent = view
	local centre = icon:GetPivot().Position
	camera.CFrame =
		CFrame.lookAt(centre + Vector3.new(0.35, 0.45, -1.35) * (slug.Size / 0.55), centre)
	local turn = 0
	RunService.RenderStepped:Connect(function(dt: number)
		turn += dt * 0.8
		icon:PivotTo(CFrame.new(centre) * CFrame.Angles(0, turn, 0))
	end)
end)

-- Aim and fire -----------------------------------------------------------------------
local function blaster(): Tool?
	local character = player.Character
	if not character then
		return nil
	end
	for _, item in character:GetChildren() do
		if Combat.isBlaster(item) then
			return item :: Tool
		end
	end
	return nil
end

-- The shoulder, the aim point under the cursor (the crosshair when shift-locked) and
-- the muzzle a gun's reach along the line to it.
local function aim(): (Vector3?, Vector3?)
	local character = player.Character
	local camera = workspace.CurrentCamera
	local torso = character and character:FindFirstChild("Torso")
	local shoulder = torso and torso:FindFirstChild("Right Shoulder")
	if
		not character
		or not camera
		or not torso
		or not torso:IsA("BasePart")
		or not shoulder
		or not shoulder:IsA("Motor6D")
	then
		return nil, nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, camera }
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	local point = if hit then hit.Position else ray.Origin + ray.Direction * 300
	-- First person: shots leave the first-person gun's muzzle.
	local muzzle = Viewmodel.muzzle()
	if muzzle then
		local toward = point - muzzle
		return muzzle, if toward.Magnitude > 0.5 then toward.Unit else ray.Direction
	end
	local from = torso.CFrame * shoulder.C0.Position
	local toward = point - from
	if toward.Magnitude < Combat.MuzzleReach + 0.5 then
		toward = ray.Direction -- aiming at something touching the gun: fire straight on
	end
	local direction = toward.Unit
	local origin = from + direction * Combat.MuzzleReach
	local final = point - origin
	return origin,
		if final.Magnitude > 0.5 and final.Unit:Dot(direction) > 0 then final.Unit else direction
end

local function fire()
	charging = false
	local tool = blaster()
	local origin, direction = aim()
	if not tool or not origin or not direction then
		return
	end
	local now = os.clock()
	local charge = math.clamp((now - chargeStart) / Combat.ChargeTime, 0, 1)
	nextId += 1
	readyAt = now + Combat.Cooldown
	aimDirection, pointUntil = direction, now + POINT_HOLD
	Viewmodel.kick(charge)
	Visuals.launch({
		id = nextId,
		shooter = player,
		slugId = slugId,
		origin = origin,
		velocity = direction * Combat.speed(slug, charge),
		readyAt = readyAt,
	})
	remote:FireServer("Fire", {
		id = nextId,
		slot = SLOT,
		origin = origin,
		direction = direction,
		charge = charge,
	})
end

local function pressed(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.KeyCode == Enum.KeyCode.ButtonR2
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not pressed(input) then
		return
	end
	if blaster() and os.clock() >= readyAt then
		charging, chargeStart = true, os.clock()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if charging and pressed(input) then
		fire()
	end
end)

-- Server replies ---------------------------------------------------------------------
remote.OnClientEvent:Connect(function(kind: string, data: any)
	if kind == "Shot" and data.shooter ~= player then
		Visuals.launch({
			id = data.id,
			shooter = data.shooter,
			slugId = data.slug,
			origin = data.origin,
			velocity = data.velocity,
			readyAt = os.clock() + Combat.Cooldown,
		})
		local character = data.shooter.Character
		if character then
			pointing[character] = os.clock() + POINT_HOLD
			character:SetAttribute("BlasterPoint", data.velocity.Unit)
		end
	elseif kind == "Impact" and data.shooter == player and data.damage > 0 then
		Visuals.popup(data.position, data.damage, data.distance)
		marker.TextTransparency = 0
		TweenService:Create(marker, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
	elseif kind == "Rejected" then
		Visuals.cancel(player, data.id)
		readyAt = 0
		warn(`[Combat] shot {data.id} rejected: {data.reason}`)
	end
end)

-- Per frame: charge meter, pointing arm, canister contents, ammo slot --------------
-- A blaster's canister shows the slug only while it is loaded: the server marks
-- SlugReady on the tool; this player's own gun follows the local prediction.
local shown: { [Tool]: boolean } = {}
local function setCanister(tool: Tool, visible: boolean)
	if shown[tool] == visible then
		return
	end
	shown[tool] = visible
	local floppy = tool:FindFirstChild("Floppy")
	if not floppy then
		return
	end
	for _, item in floppy:GetDescendants() do
		if item:IsA("BasePart") then
			if item:GetAttribute("CanisterTransparency") == nil then
				item:SetAttribute("CanisterTransparency", item.Transparency)
			end
			item.Transparency = if visible
				then item:GetAttribute("CanisterTransparency") :: number
				else 1
		end
	end
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local character = player.Character
	local tool = blaster()
	if charging and not tool then
		charging = false
	end
	chargeBar.Visible = charging
	Viewmodel.setCharge(
		if charging then math.clamp((now - chargeStart) / Combat.ChargeTime, 0, 1) else 0
	)
	if charging then
		local charge = math.clamp((now - chargeStart) / Combat.ChargeTime, 0, 1)
		chargeFill.Size = UDim2.fromScale(charge, 1)
		chargeFill.BackgroundColor3 = Color3.fromRGB(216, 211, 190)
			:Lerp(Color3.fromRGB(255, 150, 60), charge)
		local _, direction = aim()
		if direction then
			aimDirection = direction
		end
	end
	if character then
		local point = if charging or now < pointUntil then aimDirection else nil
		if character:GetAttribute("BlasterPoint") ~= point then
			character:SetAttribute("BlasterPoint", point)
		end
	end
	for other, untilTime in pointing do
		if now >= untilTime or not other.Parent then
			other:SetAttribute("BlasterPoint", nil)
			pointing[other] = nil
		end
	end
	for _, other in Players:GetPlayers() do
		local otherCharacter = other.Character
		if otherCharacter then
			for _, item in otherCharacter:GetChildren() do
				if Combat.isBlaster(item) then
					local loaded = item:GetAttribute("SlugReady") ~= false
					if other == player then
						loaded = now >= readyAt
					end
					setCanister(item :: Tool, loaded)
				end
			end
		end
	end
	local remaining = math.max(readyAt - now, 0)
	shade.Size = UDim2.fromScale(1, remaining / Combat.Cooldown)
	countdown.Text = if remaining > 0 then string.format("%.1f", remaining) else ""
	slotFrame.BackgroundTransparency = if tool then 0.2 else 0.5
end)
