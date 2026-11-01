--!strict
-- Look-test cavern: loads the privately uploaded final concept assets, styles them with the look pack,
-- adds their glow effects, lights them and lays out zone moods so the owner can judge the Slugshot look
-- in Roblox (docs/art/look-pack.md). Asset ids live only in ignored private-assets/lobby.
local InsertService = game:GetService("InsertService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local LookPack = require(ReplicatedStorage:WaitForChild("LookPack"))
local private = require(ServerStorage:WaitForChild("LobbyAssets")) :: {
	fx: { spore: number, twinkle: number },
	assets: { [string]: LookPack.AssetInfo },
}
local templates = ServerStorage:WaitForChild("LobbyMaterials")

-- One knob for every glow in the test, so it can be tuned in a single place.
local GLOW = 1.0
LookPack.applyBase()

local scene = Instance.new("Folder")
scene.Name = "LookTest"
scene.Parent = workspace

local floor = Instance.new("Part")
floor.Name = "CavernFloor"
floor.Anchored = true
floor.Size = Vector3.new(240, 2, 240)
floor.Position = Vector3.new(0, -1, 0)
floor.Color = Color3.fromRGB(30, 32, 44)
floor.Material = Enum.Material.SmoothPlastic
floor.Parent = scene

local loaded: { [string]: Model } = {}

local function isInk(part: Instance): boolean
	return string.sub(part.Name, -4) == "_Ink"
end

-- Axis-aligned bounds of the painted (non-ink) parts.
local function paintedBounds(model: Model): (Vector3, Vector3)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, part in model:GetChildren() do
		if part:IsA("MeshPart") and not isInk(part) then
			lo = lo:Min(part.Position - part.Size / 2)
			hi = hi:Max(part.Position + part.Size / 2)
		end
	end
	return lo, hi
end

local function load(key: string): Model?
	local cached = loaded[key]
	if cached then
		return cached:Clone()
	end
	local info = private.assets[key]
	local ok, container = pcall(InsertService.LoadAsset, InsertService, info.model)
	if not ok then
		warn(`LookTest: {key} failed to load: {container}`)
		return nil
	end
	local model = Instance.new("Model")
	model.Name = key
	for _, child in (container :: Instance):GetDescendants() do
		if child:IsA("MeshPart") then
			child.Parent = model
		end
	end
	(container :: Instance):Destroy()
	LookPack.styleModel(model, key, info.groups, templates, GLOW)
	-- Scale to the concept's true height, measured on the painted parts (ink shells add a sliver).
	local lo, hi = paintedBounds(model)
	if hi.Y > lo.Y then
		model:ScaleTo(model:GetScale() * info.height / (hi.Y - lo.Y))
	end
	-- Concept coordinates map onto the model through the centre of the painted bounds.
	lo, hi = paintedBounds(model)
	LookPack.addEffects(model, info, private.fx, (lo + hi) / 2 - info.center)
	loaded[key] = model
	return model:Clone()
end

-- Stand a model on the floor at (x, z), turned by yaw degrees (0 = its front faces -Z).
local function place(key: string, x: number, z: number, yaw: number): Model?
	local model = load(key)
	if not model then
		return nil
	end
	model.Parent = scene
	local lo, hi = paintedBounds(model)
	local centre = (lo + hi) / 2
	local pivotOffset = model:GetPivot().Position - centre
	model:PivotTo(
		CFrame.new(x, (hi.Y - lo.Y) / 2, z)
			* CFrame.Angles(0, math.rad(yaw), 0)
			* CFrame.new(pivotOffset)
	)
	return model
end

local function light(
	name: string,
	className: string,
	position: Vector3,
	color: Color3,
	brightness: number,
	range: number
): Light
	local holder = Instance.new("Part")
	holder.Name = name
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Position = position
	holder.Parent = scene
	local l = Instance.new(className) :: Light
	l.Color = color
	l.Brightness = brightness;
	(l :: any).Range = range
	l.Shadows = true
	l.Parent = holder
	return l
end

-- Cavern enclosure: the rock wall module reused in a ring, all facing the centre (modular kit test).
for i = 0, 7 do
	local angle = i * 45 + 22.5
	local a = math.rad(angle)
	place("rock-wall-1", math.sin(a) * 52, -math.cos(a) * 52, -angle)
end

-- Hub centre: PvP gate ahead of spawn, crystals either side, the mint mushroom on the left.
local gate = place("gate-pvp-1", 0, -26, 0)
place("crystals-1", -13, -9, 20)
place("crystals-11", 15, -6, -25)
place("crystals-1", 20, 14, 140)
place("mushroom-1", -26, 6, 30)

light("PortalGlow", "PointLight", Vector3.new(0, 8, -22), Color3.fromRGB(255, 150, 70), 1.4, 26)
light("CapGlow", "PointLight", Vector3.new(-25, 9, 6), Color3.fromRGB(80, 255, 190), 1.0, 20)
light("WarmPocket", "PointLight", Vector3.new(8, 7, 24), Color3.fromRGB(255, 170, 90), 1.1, 26)
local skyWell = light(
	"SkyWell",
	"SpotLight",
	Vector3.new(0, 70, 0),
	Color3.fromRGB(170, 195, 255),
	1.6,
	90
) :: SpotLight
skyWell.Face = Enum.NormalId.Bottom
skyWell.Angle = 70

-- Portal life: sparks swirling across the energy surface and embers drifting up from it. The pulse of
-- its glow and light runs on the client (LookFx.client).
local energy = gate and gate:FindFirstChild("Energy") :: MeshPart?
if energy then
	local core = Color3.fromRGB(255, 170, 80)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Texture = "rbxassetid://" .. private.fx.twinkle
	sparks.Color = ColorSequence.new(core, Color3.fromRGB(255, 235, 190))
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Brightness = 2.5
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Lifetime = NumberRange.new(1.2, 2.4)
	sparks.Rate = 22
	sparks.Speed = NumberRange.new(0.3, 1.2)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.RotSpeed = NumberRange.new(-120, 120)
	sparks.Shape = Enum.ParticleEmitterShape.Box
	sparks.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	sparks.Parent = energy
	local embers = Instance.new("ParticleEmitter")
	embers.Name = "Embers"
	embers.Texture = "rbxassetid://" .. private.fx.spore
	embers.Color = ColorSequence.new(core)
	embers.LightEmission = 1
	embers.LightInfluence = 0
	embers.Brightness = 3
	embers.Size = NumberSequence.new(0.16, 0.04)
	embers.Transparency = NumberSequence.new(0.1, 1)
	embers.Lifetime = NumberRange.new(2, 4)
	embers.Rate = 12
	embers.Speed = NumberRange.new(1, 2.2)
	embers.SpreadAngle = Vector2.new(25, 25)
	embers.EmissionDirection = Enum.NormalId.Top
	embers.Shape = Enum.ParticleEmitterShape.Box
	embers.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	embers.Parent = energy
	energy:AddTag("SlugshotPortalEnergy")
end

-- Zone moods: full strength inside each radius, fading out beyond (see LookZones.client).
local zones = Instance.new("Folder")
zones.Name = "LookZones"
zones.Parent = workspace
local function zone(mood: string, x: number, z: number, radius: number)
	local p = Instance.new("Part")
	p.Name = mood
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(radius * 2, 1, radius * 2)
	p.Position = Vector3.new(x, 0, z)
	p:SetAttribute("Mood", mood)
	p.Parent = zones
end
zone("PvP", 0, -24, 10)
zone("Training", 18, 0, 8)
zone("Veylume", -24, 4, 9)

-- Characters always get the Inked Cavern outline (style guide). Highlight draws a thin silhouette only;
-- Floppy and future slugs carry real ink shells in their meshes.
local function outline(character: Model)
	local h = Instance.new("Highlight")
	h.Name = "SlugshotInk"
	h.FillTransparency = 1
	h.OutlineColor = LookPack.INK
	h.OutlineTransparency = 0
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = character
end
local function watch(player: Player)
	player.CharacterAdded:Connect(outline)
	if player.Character then
		outline(player.Character)
	end
end
Players.PlayerAdded:Connect(watch)
for _, player in Players:GetPlayers() do
	watch(player)
end

print("LookTest: scene built", #scene:GetChildren(), "objects")
