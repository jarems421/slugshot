--!strict
-- Q and E arm the selected slug's main or passive for the next shot (docs/slugs/ability-specs.md); pressing the
-- armed key again disarms. The server owns arming and cooldowns; this shows the ability chips beside the HUD's
-- canisters and the murk inside a Mistbank, a placeholder until production VFX.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CombatModule = ReplicatedStorage:WaitForChild("Combat")
local Combat = require(CombatModule)
local Abilities = require(CombatModule:WaitForChild("Abilities"))
local Theme = require(script.Parent:WaitForChild("PvpTheme"))

local player = Players.LocalPlayer
local movement = player.PlayerScripts:WaitForChild("MovementSandbox")
local Keybinds = (require :: any)(movement:WaitForChild("Keybinds"))
local AimCursor = (require :: any)(movement:WaitForChild("AimCursor"))
local remote = ReplicatedStorage:WaitForChild("SlugshotCombat") :: RemoteEvent

local KEYS: { [string]: string } = { main = "Q", passive = "E" }
local armed: Abilities.Kind? = nil
local ready: { [string]: number } = {}

local function selectedSlug(): string?
	local character = player.Character
	local slot = character and character:GetAttribute("SelectedSlugSlot")
	return Combat.Loadout[if typeof(slot) == "number" then slot else 1]
end

local function press(kind: Abilities.Kind)
	if not AimCursor.menuOpen() and Abilities.ability(selectedSlug(), kind) then
		remote:FireServer("Arm", if armed == kind then false else kind)
	end
end
local ACTIONS: { [string]: string } = { main = "armMain", passive = "armPassive" }
for kind, action in ACTIONS do
	Keybinds.on(action, function(pressed: boolean)
		if pressed then
			press(kind)
		end
	end)
end

remote.OnClientEvent:Connect(function(kind: string, data: any)
	if kind == "AbilityState" then
		armed, ready = data.armed, data.ready or {}
	end
end)

-- One chip for each of the selected slug's abilities, in the PvP UI's look: Q left of the HUD's
-- canisters and E right of them, so they share its scale and hide with it in the lobby.
local canisters = player
	:WaitForChild("PlayerGui")
	:WaitForChild("CombatHUD")
	:WaitForChild("SlugBar")
	:WaitForChild("Canisters") :: Frame

type Chip = { frame: Frame, key: TextLabel, name: TextLabel, edge: UIStroke }
local chips: { [string]: Chip } = {}
local SIDES: { [string]: number } = { main = -1, passive = 1 }
for kind, side in SIDES do
	local frame = Theme.new("Frame", {
		AnchorPoint = Vector2.new(if side < 0 then 1 else 0, 0.5),
		Position = UDim2.new(if side < 0 then 0 else 1, 14 * side, 0.5, 0),
		Size = UDim2.fromOffset(160, 34),
		BackgroundColor3 = Theme.Panel,
		Parent = canisters,
	})
	Theme.corner(frame, 8)
	local key = Theme.label(frame, KEYS[kind], Theme.TitleBold, 18, {
		Position = UDim2.fromOffset(10, 0),
		Size = UDim2.new(0, 18, 1, 0),
		TextColor3 = Theme.Muted,
	})
	local name = Theme.label(frame, "", Theme.Body, 15, {
		Position = UDim2.fromOffset(34, 0),
		Size = UDim2.new(1, -42, 1, 0),
	})
	chips[kind] = { frame = frame, key = key, name = name, edge = Theme.edge(frame, 2) }
end

local function drawBar(current: number)
	local slugId = selectedSlug()
	for kind, chip in chips do
		local ability = Abilities.ability(slugId, kind)
		chip.frame.Visible = ability ~= nil
		if ability then
			local left = (ready[`{slugId}:{kind}`] or 0) - current
			local isArmed = armed == kind
			chip.name.Text = if left > 0
				then string.format("%s  %.1fs", ability.Name, left)
				else ability.Name
			chip.name.TextColor3 = if left > 0 then Theme.Muted else Theme.Text
			chip.frame.BackgroundColor3 = if isArmed then Theme.Raised else Theme.Panel
			chip.edge.Color = if isArmed then Theme.Accent else Theme.Ink
			chip.key.TextColor3 = if isArmed then Theme.Accent else Theme.Muted
		end
	end
end

-- Mistbank murk: inside one the view closes in to a few studs. Placeholder: heavy atmosphere plus fog particles
-- round the camera. Name tags hide themselves (NameTags).
local fogPart = Theme.new("Part", {
	Name = "MistbankMurk",
	Size = Vector3.new(9, 9, 9),
	Transparency = 1,
	Anchored = true,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
})
local fog = Theme.new("ParticleEmitter", {
	Texture = "rbxasset://textures/particles/smoke_main.dds",
	Color = ColorSequence.new(Color3.fromRGB(222, 232, 238)),
	Size = NumberSequence.new(5),
	Transparency = NumberSequence.new(0.55),
	Lifetime = NumberRange.new(0.8, 1.2),
	Rate = 90,
	Speed = NumberRange.new(0),
	Shape = Enum.ParticleEmitterShape.Sphere,
	ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	LockedToPart = true,
	Enabled = false,
	Parent = fogPart,
})

type Air = { density: number, offset: number, haze: number, color: Color3 }
local saved: Air? = nil
local function setMurk(inside: boolean)
	local camera = workspace.CurrentCamera
	if inside and camera then
		fogPart.CFrame = camera.CFrame
		fogPart.Parent = camera
	end
	if fog.Enabled == inside then
		return
	end
	fog.Enabled = inside
	local air = Lighting:FindFirstChildOfClass("Atmosphere")
	if inside then
		if not air then
			air = Theme.new("Atmosphere", { Name = "MistbankAtmosphere", Parent = Lighting })
		end
		local atmosphere = air :: Atmosphere
		saved = {
			density = atmosphere.Density,
			offset = atmosphere.Offset,
			haze = atmosphere.Haze,
			color = atmosphere.Color,
		}
		atmosphere.Density, atmosphere.Offset, atmosphere.Haze = 0.92, 1, 3
		atmosphere.Color = Color3.fromRGB(222, 232, 238)
	elseif air and saved then
		local atmosphere = air :: Atmosphere
		if atmosphere.Name == "MistbankAtmosphere" then
			atmosphere:Destroy()
		else
			atmosphere.Density, atmosphere.Offset = saved.density, saved.offset
			atmosphere.Haze, atmosphere.Color = saved.haze, saved.color
		end
		saved = nil
	end
end

RunService.RenderStepped:Connect(function()
	drawBar(workspace:GetServerTimeNow())
	local camera = workspace.CurrentCamera
	setMurk(camera ~= nil and Abilities.insideMist(camera.CFrame.Position))
end)
