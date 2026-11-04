--!strict
-- Firing slugs: hold LMB (or R2) with the blaster out to charge, release to fire. A
-- tap still fires at a decent speed; a full charge is faster and droops less. The
-- shot flies on this screen at once and is sent to the server, which judges it.
-- Floppy and Inferno so far; the slug bar shows the selected slot's cooldown.
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
local selectedSlot = 1
local slugId = Combat.Loadout[selectedSlot]
local slug = Combat.Slugs[slugId]
local POINT_HOLD = 0.35 -- the arm keeps pointing this long after a shot

local charging, chargeStart = false, 0
local readyAt = 0 -- predicted; the server owns cooldowns
local cooldowns: { [number]: number } = {}
local pending: { [number]: { slot: number, ready: number } } = {}
local Inspect = (require :: any)(movement:WaitForChild("SlugInspect"))
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

local function cancelInspect()
	local character = player.Character
	if character and character:GetAttribute("SlugInspectAt") ~= nil then
		character:SetAttribute("SlugInspectAt", nil)
		remote:FireServer("CancelInspect")
	end
end

local function selectSlot(slot: number): boolean
	local id = Combat.Loadout[slot]
	if AimCursor.menuOpen() or not id or not Combat.Slugs[id] then
		return false
	end
	cancelInspect()
	charging = false
	Ads.set(false)
	selectedSlot, slugId, slug = slot, id, Combat.Slugs[id]
	readyAt = cooldowns[slot] or 0
	remote:FireServer("Select", slot)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if humanoid and humanoid.Health > 0 and not blaster() and backpack then
		for _, item in backpack:GetChildren() do
			if Combat.isBlaster(item) then
				humanoid:EquipTool(item :: Tool)
				break
			end
		end
	end
	return true
end

local function cycleSlot(direction: number)
	for offset = 1, Combat.SlotCount do
		local slot = (selectedSlot - 1 + direction * offset) % Combat.SlotCount + 1
		if Combat.Loadout[slot] then
			selectSlot(slot)
			return
		end
	end
end
for slot = 1, Combat.SlotCount do
	Keybinds.on(`slug{slot}`, function(pressed: boolean)
		if pressed then
			selectSlot(slot)
		end
	end)
end
Keybinds.on("nextSlug", function(pressed: boolean)
	if pressed then
		cycleSlot(1)
	end
end)
Keybinds.on("previousSlug", function(pressed: boolean)
	if pressed then
		cycleSlot(-1)
	end
end)

local function beginInspect(): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if
		not character
		or not humanoid
		or humanoid.Health <= 0
		or not blaster()
		or charging
		or Ads.wanted()
		or AimCursor.menuOpen()
		or os.clock() < readyAt
		or character:GetAttribute("FirstPersonAction") ~= nil
		or character:GetAttribute("BlasterFlourish") ~= nil
		or Inspect.elapsed(character)
	then
		return false
	end
	remote:FireServer("Inspect")
	return true
end
Keybinds.on("inspect", function(pressed: boolean)
	if pressed then
		beginInspect()
	end
end)

-- The shoulder, the aim point under the cursor (the crosshair when shift-locked) and
-- the muzzle a gun's reach along the line to it.
-- A firing sample belongs to one completed rendered frame. Input callbacks run
-- after the movement camera removes its temporary offset, but before its next
-- presentation pass; mixing that camera with the old world-space muzzle is wrong.
type AimFrame = {
	character: Model,
	camera: Camera,
	tool: Tool?,
	ray: Ray,
	muzzle: Vector3?,
	shoulder: Vector3,
}
local renderedAim: AimFrame? = nil
RunService:BindToRenderStep(
	"SlugshotRenderedAim",
	Enum.RenderPriority.Character.Value + 20,
	function()
		local character, camera = player.Character, workspace.CurrentCamera
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
			renderedAim = nil
			return
		end
		local cursor = AimCursor.point(camera)
		renderedAim = {
			character = character,
			camera = camera,
			tool = blaster(),
			ray = camera:ViewportPointToRay(cursor.X, cursor.Y),
			muzzle = Viewmodel.muzzle(),
			shoulder = torso.CFrame * shoulder.C0.Position,
		}
	end
)

local function aim(
	charge: number,
	presentationOnly: boolean?
): (Vector3?, Vector3?, Vector3?, Vector3?, boolean?)
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
	local frame = renderedAim
	local useFrame = not presentationOnly
		and frame
		and frame.character == character
		and frame.camera == camera
		and frame.tool == blaster()
	local ray = if useFrame
		then (frame :: AimFrame).ray
		else camera:ViewportPointToRay(cursor.X, cursor.Y)
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	local point = if hit then hit.Position else ray.Origin + ray.Direction * 300
	local muzzle = if useFrame then (frame :: AimFrame).muzzle else Viewmodel.muzzle()
	if presentationOnly then
		return muzzle, ray.Direction, ray.Direction, point
	end
	local from = if useFrame
		then (frame :: AimFrame).shoulder
		else torso.CFrame * shoulder.C0.Position
	if not muzzle then
		local toward = point - from
		local direction = if toward.Magnitude < Combat.MuzzleReach + 0.5
			then ray.Direction
			else toward.Unit
		muzzle = from + direction * Combat.MuzzleReach
	end
	-- Animated/viewmodel barrels can cross close cover before the camera does.
	-- Start on the shooter's side and hit that cover, never beyond its surface.
	local reach = muzzle - from
	local obstruction = if reach.Magnitude > 1e-4
		then workspace:Spherecast(from, slug.Radius, reach, params)
		else nil
	if obstruction then
		local origin = obstruction.Position + obstruction.Normal * (slug.Radius + 0.01)
		return origin, -obstruction.Normal, ray.Direction, point, true
	end
	local toward = point - muzzle
	if hit and (toward.Magnitude <= 0.5 or toward.Unit:Dot(ray.Direction) <= 0) then
		local origin = point + hit.Normal * (slug.Radius + 0.01)
		local root = character:FindFirstChild("HumanoidRootPart")
		if
			root
			and root:IsA("BasePart")
			and (origin - root.Position).Magnitude <= Combat.MaxOriginOffset
		then
			return origin, -hit.Normal, ray.Direction, point, true
		end
		return nil, nil, ray.Direction, point, true
	end
	local target = if hit then point + hit.Normal * slug.Radius else point
	local level = Combat.level(charge)
	local correction = if level == 1
		then Tuning.values.shotArcOne
		elseif level == 2 then Tuning.values.shotArcTwo
		else 1
	local direction = Combat.launchDirection(muzzle :: Vector3, target, slug, charge, correction)
	return muzzle, direction, ray.Direction, point
end

local function fire()
	charging = false
	local tool = blaster()
	local now = os.clock()
	local charge = if Recoil.stage() == 3
		then 1
		else math.clamp((now - chargeStart) / Tuning.values.chargeTime, 0, 1)
	local origin, direction, gunAim = aim(charge)
	if not tool or not origin or not direction then
		return
	end
	nextId += 1
	readyAt = now + Combat.Cooldown
	cooldowns[selectedSlot] = readyAt
	pending[nextId] = { slot = selectedSlot, ready = readyAt }
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
		slot = selectedSlot,
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
		cancelInspect()
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
			cancelInspect()
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
		pending[data.id] = nil
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
	elseif kind == "Impact" then
		Visuals.confirmImpact(data.shooter, data.id, data.position, data.normal, data.victim)
		if data.shooter == player and data.damage > 0 then
			Visuals.popup(data.position, data.damage, data.distance)
			marker.TextTransparency = 0
			TweenService:Create(marker, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		end
	elseif kind == "Rejected" then
		lastRejected = data.reason
		lastRejectedId = data.id
		Visuals.cancel(player, data.id)
		local request = pending[data.id]
		if request and cooldowns[request.slot] == request.ready then
			cooldowns[request.slot] = os.clock() + (data.remaining or 0)
			if selectedSlot == request.slot then
				readyAt = cooldowns[request.slot]
			end
		end
		pending[data.id] = nil
		warn(`[Combat] shot {data.id} rejected: {data.reason}`)
	end
end)

-- Studio inspection uses the same press/release path as input, including local
-- prediction and actual server acknowledgement. No firing bypass in published play.
if RunService:IsStudio() then
	local probe = Instance.new("BindableFunction")
	probe.Name = "CombatExperimentProbe"
	probe.OnInvoke = function(command: string, value: any)
		if command == "Aim" then
			local charge = if typeof(value) == "number" then math.clamp(value, 0, 1) else 1
			local origin, direction, gunAim, target, obstructed = aim(charge)
			return {
				origin = origin,
				direction = direction,
				gunAim = gunAim,
				target = target,
				level = Combat.level(charge),
				obstructed = obstructed == true,
			}
		elseif command == "Select" then
			selectSlot(value)
		elseif command == "Cycle" then
			cycleSlot(value)
		elseif command == "Inspect" then
			beginInspect()
		elseif command == "Press" then
			beginCharge()
		elseif command == "Release" then
			releaseCharge()
		end
		return {
			selectedSlot = selectedSlot,
			slugId = slugId,
			inspecting = player.Character ~= nil
				and Inspect.elapsed(player.Character :: Model) ~= nil,
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
local shownSlug: { [Tool]: string } = {}
-- Each slug's loaded model in the canister; only the selected one shows.
local LOADED_MODELS: { [string]: string } = { Floppy = "Floppy", Inferno = "InfernoLoaded" }
local contentWatch: { [Tool]: RBXScriptConnection } = {}
local function setCanister(tool: Tool, visible: boolean)
	if not contentWatch[tool] then
		contentWatch[tool] = tool.DescendantAdded:Connect(function(item: Instance)
			if item:IsA("BasePart") then
				shown[tool] = nil
			end
		end)
		tool.Destroying:Once(function()
			local connection = contentWatch[tool]
			if connection then
				connection:Disconnect()
			end
			contentWatch[tool], shown[tool], shownSlug[tool] = nil, nil, nil
		end)
	end
	local selected = tool:GetAttribute("SelectedSlugId")
	local selectedId = if typeof(selected) == "string" then selected else "Floppy"
	if shown[tool] == visible and shownSlug[tool] == selectedId then
		return
	end
	shownSlug[tool] = selectedId
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
	for id, name in LOADED_MODELS do
		local loaded = tool:FindFirstChild(name)
		if loaded then
			local show = visible and id == selectedId
			for _, item in loaded:GetDescendants() do
				if item:IsA("BasePart") then
					if item:GetAttribute("CanisterTransparency") == nil then
						item:SetAttribute("CanisterTransparency", item.Transparency)
					end
					item.Transparency = if show
						then item:GetAttribute("CanisterTransparency") :: number
						else 1
				end
			end
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
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if
		not tool
		or AimCursor.menuOpen()
		or action ~= nil
		or not humanoid
		or humanoid.Health <= 0
	then
		cancelInspect()
	end
	Ads.step(spiralDt, action == nil or action == "Slide")
	if Ads.wanted() and not charging then
		local _, _, gunAim = aim(0, true)
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
		local _, _, gunAim = aim(charge, true)
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
	Hud.step(cooldowns, selectedSlot, tool ~= nil, now)
end)
