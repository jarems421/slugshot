--!strict
-- Firing slugs: hold LMB (or R2) with the blaster out to charge, release to fire. A
-- tap still fires at a decent speed; a full charge is faster and droops less. The
-- shot flies on this screen at once and is sent to the server, which judges it.
-- One slug for now (Floppy); the slug bar shows its cooldown.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HapticService = game:GetService("HapticService")
local Combat = require(ReplicatedStorage:WaitForChild("Combat"))
local Visuals = require(script.Parent:WaitForChild("SlugVisuals"))
local Viewmodel = require(script.Parent:WaitForChild("Viewmodel"))
local Hud = require(script.Parent:WaitForChild("PvpHud"))
Viewmodel.start()

local player = Players.LocalPlayer
local movement = player.PlayerScripts:WaitForChild("MovementSandbox")
local AimCursor = (require :: any)(movement:WaitForChild("AimCursor"))
local Tuning = (require :: any)(movement:WaitForChild("Tuning"))
local Recoil = (require :: any)(movement:WaitForChild("BlasterRecoil"))
local Ads = (require :: any)(movement:WaitForChild("Ads"))
local FirstPerson = (require :: any)(movement:WaitForChild("FirstPerson"))
local Reticle = (require :: any)(movement:WaitForChild("Reticle"))
local Keybinds = (require :: any)(movement:WaitForChild("Keybinds"))
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
local lastAccepted, lastRejected = 0, ""
local lastRejectedId = 0

-- HUD -------------------------------------------------------------------------------
Hud.create()
local markerLayer = Instance.new("ScreenGui") -- above the menus, like the crosshair it marks
markerLayer.Name = "HitMarker"
markerLayer.ResetOnSpawn = false
markerLayer.IgnoreGuiInset = true
markerLayer.DisplayOrder = 100
markerLayer.Parent = player:WaitForChild("PlayerGui")

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
marker.Parent = markerLayer

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
-- At full charge (scaled down for lower levels): how far a surface can be for shots to land on it,
-- and where they cross the crosshair's line when nothing is in range.
local TRUE_RANGE, OPEN_AIM = 62, 45

local function aim(charge: number): (Vector3?, Vector3?, Vector3?)
	-- Shots leave the actual gun's muzzle, in every view.
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
		return nil, nil, nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, camera }
	local cursor = AimCursor.point(camera)
	local ray = camera:ViewportPointToRay(cursor.X, cursor.Y)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	local point = if hit then hit.Position else ray.Origin + ray.Direction * 300
	local muzzle = Viewmodel.muzzle()
	if muzzle then
		-- A point behind the muzzle (a wall between camera and gun) keeps the camera's line.
		local toward = point - muzzle
		if toward.Magnitude <= 0.5 or toward.Unit:Dot(ray.Direction) <= 0 then
			return muzzle, ray.Direction, ray.Direction
		end
		-- Slugs droop and leave from the gun, off to one side, so a straight shot lands low and
		-- on the gun's side. A full charge launches along the arc that ends on the crosshair's
		-- point; lower levels only part-correct it, so they land low and fall short.
		local share = Combat.speed(slug, charge) / Combat.speed(slug, 1)
		local target: Vector3
		if hit and (point - muzzle).Magnitude <= TRUE_RANGE * share then
			-- The slug's edge touches first, so its centre aims one radius off the surface.
			target = point + hit.Normal * slug.Radius
		else
			-- Nothing in range behind the crosshair: a gentle arc crossing its line at a set
			-- distance. Using the far surface's real distance is a big lob over anything nearer,
			-- which overshot as soon as the crosshair slipped off a close target.
			local along = ray.Direction:Dot(muzzle - ray.Origin) + OPEN_AIM * share
			target = ray.Origin + ray.Direction * along
		end
		local straight = (target - muzzle).Unit
		local arc = Combat.aimedDirection(muzzle, target, slug, charge) or straight
		local level = Combat.level(charge)
		local correction = if level == 1
			then Tuning.values.shotArcOne
			elseif level == 2 then Tuning.values.shotArcTwo
			else Tuning.values.aimArc
		-- The gun points along the crosshair, not the arc, so it never jumps with the distance.
		return muzzle, straight:Lerp(arc, correction).Unit, ray.Direction
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
		if final.Magnitude > 0.5 and final.Unit:Dot(direction) > 0 then final.Unit else direction,
		ray.Direction
end

local function fire()
	charging = false
	local tool = blaster()
	local now = os.clock()
	local charge = math.clamp((now - chargeStart) / Tuning.values.chargeTime, 0, 1)
	local origin, direction, gunAim = aim(charge)
	if not tool or not origin or not direction then
		return
	end
	nextId += 1
	readyAt = now + Combat.Cooldown
	aimDirection, pointUntil = gunAim or direction, now + POINT_HOLD
	local recoilStyle = if player:GetAttribute("RecoilAnimation") == "Flip" then "Flip" else "Kick"
	local character = player.Character
	if character then
		character:SetAttribute("BlasterRecoilStyle", recoilStyle)
		character:SetAttribute("BlasterRecoilCharge", charge)
		character:SetAttribute("BlasterRecoilAt", now)
	end
	Visuals.launch({
		id = nextId,
		shooter = player,
		slugId = slugId,
		origin = origin,
		velocity = direction * Combat.speed(slug, charge),
		readyAt = readyAt,
	})
	remote:FireServer("Fire", {
		recoil = recoilStyle,
		id = nextId,
		slot = SLOT,
		origin = origin,
		direction = direction,
		charge = charge,
	})
end

-- The light inside the charger spiral sweeps round faster as the charge builds, holds top
-- speed at full charge and coasts down after the shot. The spiral mechanism never moves.
-- Only welds move, so the first-person gun copies follow.
type SpinPart = { weld: Weld, base: CFrame, part: BasePart }
type Spiral = { lights: { SpinPart }, angle: number, speed: number, lit: boolean }
local spirals: { [Tool]: Spiral } = setmetatable({}, { __mode = "k" }) :: any
local SPIRAL_LIGHT = { 0.05, 0.45, 0.68, 0.84 } -- transparency: the leading bar, then its trail
local SPIRAL_TRAIL = 0.016 -- seconds behind the leader per trailing bar
local SPIRAL_COAST = 2.2 -- 1/s; how quickly it winds down after the shot

local function spiralOf(tool: Tool): Spiral?
	local spiral = spirals[tool]
	if not spiral then
		local lights: { SpinPart } = {}
		for index = 1, #SPIRAL_LIGHT do
			local part = tool:FindFirstChild(`ChargerLight{index}`)
			local weld = part and part:FindFirstChildOfClass("Weld")
			if part and part:IsA("BasePart") and weld then
				table.insert(lights, { weld = weld, base = weld.C0, part = part })
			end
		end
		if #lights == 0 then
			return nil
		end
		spiral = { lights = lights, angle = 0, speed = 0, lit = false }
		spirals[tool] = spiral
	end
	return spiral
end

local function stepSpiral(tool: Tool, charge: number?, dt: number)
	local spiral = spiralOf(tool)
	if not spiral then
		return
	end
	local top = Tuning.values.spiralSpeed * 2 * math.pi
	if charge then
		-- The light steps up with each clunk, starting slow so tap fire stays calm.
		local wanted = top * (0.2 + 0.8 * Recoil.stage() / 3)
		spiral.speed += (wanted - spiral.speed) * (1 - math.exp(-14 * dt))
	else
		spiral.speed *= math.exp(-SPIRAL_COAST * dt)
		if spiral.speed < 0.3 then
			spiral.speed = 0
		end
	end
	if spiral.speed == 0 and not spiral.lit then
		return
	end
	spiral.lit = spiral.speed > 0
	spiral.angle = (spiral.angle + spiral.speed * dt) % (2 * math.pi)
	-- Brightens quickly, so a tap still flickers and a charge clearly glows.
	local shown = math.clamp(spiral.speed / math.max(top, 1e-3) * 2.5, 0, 1)
	for index, light in spiral.lights do
		local angle = spiral.angle - spiral.speed * SPIRAL_TRAIL * (index - 1)
		light.weld.C0 = light.base * CFrame.Angles(angle, 0, 0)
		local solid = 1 - (1 - SPIRAL_LIGHT[index]) * math.clamp(Tuning.values.spiralLight, 0, 1)
		light.part.Transparency = 1 - (1 - solid) * shown
	end
end

local function beginCharge(): boolean
	if not AimCursor.menuOpen() and blaster() and os.clock() >= readyAt then
		charging, chargeStart = true, os.clock()
		return true
	end
	return false
end

local function releaseCharge()
	if charging then
		fire()
	end
end

-- Hold to aim down sights, first person only. Otherwise the button keeps its camera use.
local function aimPressed(held: boolean)
	if held then
		if blaster() and FirstPerson.active() and not AimCursor.menuOpen() then
			Ads.set(true)
		end
	else
		Ads.set(false)
	end
end
Keybinds.on("aim", aimPressed)

Keybinds.on("fire", function(held: boolean)
	if held then
		beginCharge()
	else
		releaseCharge()
	end
end)

-- Controllers keep their triggers; they are not rebindable yet.
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.ButtonR2 then
		beginCharge()
	elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
		aimPressed(true)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.ButtonR2 then
		releaseCharge()
	elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
		aimPressed(false)
	end
end)

-- Server replies ---------------------------------------------------------------------
remote.OnClientEvent:Connect(function(kind: string, data: any)
	if kind == "Shot" and data.shooter == player then
		lastAccepted = data.id
	elseif kind == "Shot" and data.shooter ~= player then
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
			character:SetAttribute(
				"BlasterRecoilStyle",
				if data.recoil == "Flip" then "Flip" else "Kick"
			)
			character:SetAttribute("BlasterRecoilCharge", data.charge or 0)
			character:SetAttribute("BlasterRecoilAt", os.clock())
			pointing[character] = os.clock() + POINT_HOLD
			character:SetAttribute("BlasterPoint", data.velocity.Unit)
		end
	elseif kind == "Impact" and data.shooter == player and data.damage > 0 then
		Visuals.popup(data.position, data.damage, data.distance)
		marker.TextTransparency = 0
		TweenService:Create(marker, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
	elseif kind == "Rejected" then
		lastRejected = data.reason
		lastRejectedId = data.id
		Visuals.cancel(player, data.id)
		readyAt = 0
		warn(`[Combat] shot {data.id} rejected: {data.reason}`)
	end
end)

-- Studio inspection uses the same press/release path as input, including local
-- prediction and actual server acknowledgement. No firing bypass in published play.
if RunService:IsStudio() then
	local probe = Instance.new("BindableFunction")
	probe.Name = "CombatExperimentProbe"
	probe.OnInvoke = function(command: string)
		if command == "Press" then
			beginCharge()
		elseif command == "Release" then
			releaseCharge()
		end
		return {
			charging = charging,
			remaining = math.max(readyAt - os.clock(), 0),
			lastSent = nextId,
			lastAccepted = lastAccepted,
			lastRejected = lastRejected,
			lastRejectedId = lastRejectedId,
		}
	end
	probe.Parent = player.PlayerScripts
end

-- Per frame: charge meter, pointing arm, canister contents, ammo slot --------------
-- A blaster's canister shows the slug only while it is loaded: the server marks
-- SlugReady on the tool; this player's own gun follows the local prediction.
local shown: { [Tool]: boolean } = {}
local function setCanister(tool: Tool, visible: boolean)
	if shown[tool] == visible then
		return
	end
	local returned = visible and shown[tool] == false
	shown[tool] = visible
	if returned then
		Visuals.canisterPop(if tool.Parent == player.Character
			then Viewmodel.canister
			else function(): Vector3?
				local handle = tool:FindFirstChild("Handle")
				return if handle and handle:IsA("BasePart") then handle.Position else nil
			end)
	end
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

-- On a controller each clunk is also a rumble, strongest at full charge.
local RUMBLE = { 0.35, 0.55, 1 }
Recoil.onClunk(function(stage: number)
	local pad = Enum.UserInputType.Gamepad1
	local motor = Enum.VibrationMotor.Large
	if HapticService:IsVibrationSupported(pad) and HapticService:IsMotorSupported(pad, motor) then
		HapticService:SetMotor(pad, motor, RUMBLE[stage])
		task.delay(0.1, function()
			HapticService:SetMotor(pad, motor, 0)
		end)
	end
end)

local lastSpiralStep = os.clock()
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local spiralDt = now - lastSpiralStep
	lastSpiralStep = now
	local camera = workspace.CurrentCamera
	if camera then
		local cursor = AimCursor.point(camera)
		marker.Position = UDim2.fromOffset(cursor.X, cursor.Y)
	end
	local character = player.Character
	local tool = blaster()
	if charging and (not tool or AimCursor.menuOpen()) then
		charging = false
	end
	if Ads.wanted() and (not tool or not FirstPerson.active() or AimCursor.menuOpen()) then
		Ads.set(false)
	end
	local action = character and character:GetAttribute("FirstPersonAction")
	Ads.step(spiralDt, action == nil or action == "Slide")
	if Ads.wanted() and not charging then
		local _, _, gunAim = aim(0)
		if gunAim then
			aimDirection = gunAim
		end
	end
	if tool then
		stepSpiral(
			tool,
			if charging
				then math.clamp((now - chargeStart) / Tuning.values.chargeTime, 0, 1)
				else nil,
			spiralDt
		)
	end
	local body = character and character:FindFirstChild("HumanoidRootPart")
	local moveWeight = if body and body:IsA("BasePart")
		then Vector3.new(body.AssemblyLinearVelocity.X, 0, body.AssemblyLinearVelocity.Z).Magnitude / 16
		else 0
	if charging then
		local charge = math.clamp((now - chargeStart) / Tuning.values.chargeTime, 0, 1)
		Reticle.setCharge(charge)
		Recoil.setCharging(charge, moveWeight, spiralDt)
		local _, _, gunAim = aim(charge)
		if gunAim then
			aimDirection = gunAim
		end
	else
		Reticle.setCharge(nil)
		Recoil.setCharging(0, moveWeight, spiralDt)
	end
	if character then
		local point = if charging or Ads.wanted() or now < pointUntil then aimDirection else nil
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
	Hud.step(math.max(readyAt - now, 0), tool ~= nil)
end)
