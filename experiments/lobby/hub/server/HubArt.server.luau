--!strict
-- Brings the final hub designs into the lobby: spawn rock, runestone gateways, rope bridges, Maelstrom and Sky Well.
-- Everything is look-only on top of the block-out's simple colliders, so nothing here costs physics, and the parts of
-- the block-out these designs replace turn invisible (docs/art/lobby-hub.md). Asset ids live only in ignored
-- private-assets/lobby. Motion runs on the client in HubMotion.client.
local CollectionService = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local layout = require(ReplicatedStorage:WaitForChild("LobbyScale"):WaitForChild("layout")) :: any
local LookPack = require(ReplicatedStorage:WaitForChild("LookPack"))

type PartInfo = { ink: string?, emissive: number, min: Vector3, max: Vector3 }
type PieceInfo = { model: number, parts: { [string]: PartInfo } }

local private = require(ServerStorage:WaitForChild("HubAssets")) :: {
	fx: { [string]: number },
	assets: { [string]: PieceInfo },
}
local templates = ServerStorage:WaitForChild("HubMaterials")

local ORBIT = 0.12 -- the concepts' base rate, radians per second
local BRIDGE_S = 0.51 -- bridge units per spawn-rock unit
local UNIT = 5 -- studs per spawn-rock and Maelstrom unit
local CLIFF_LIFT = 0.12 -- keeps the cliff's ground above the block-out floor it covers

-- Pieces that glow more than the painted brightness suits under Roblox's bloom.
local GLOW: { [string]: number } = {
	["hub-portal-pvp"] = 0.45,
	["hub-portal-training"] = 0.45,
	["hub-portal-veylume"] = 0.45,
	["hub-storm"] = 0.7,
}

-- Pieces whose ink a phone can skip: far away or small on screen (HubMotion.client decides).
local DISTANT = {
	"hub-portal-pvp",
	"hub-portal-training",
	"hub-portal-veylume",
	"hub-well-rock",
	"hub-well-glow",
	"hub-well-isles",
	"hub-well-bits",
	"hub-rock-debris",
	"hub-pit-flora",
	"hub-cliff",
	"hub-rock",
	"Bridge0",
	"Bridge1",
	"Bridge2",
	"Bridge3",
}

-- Along the spawn rock's cracks, from tools/lobby/hub_mesh.py's crack geometry.
local CRACK_GLOW: { Vector3 } = {
	Vector3.new(-26.1, 0.6, -9.7),
	Vector3.new(-26.5, 0.6, -7.4),
	Vector3.new(-24.7, 0.6, -9.5),
	Vector3.new(-21.1, 0.6, -5.5),
	Vector3.new(-14.9, 0.6, -2.3),
	Vector3.new(-12.8, 0.6, 0.7),
	Vector3.new(-11.0, 0.6, 14.1),
	Vector3.new(-13.2, 0.6, 21.3),
	Vector3.new(-0.7, 0.6, -27.2),
	Vector3.new(0.7, 0.6, -26.7),
	Vector3.new(2.5, 0.6, -22.0),
	Vector3.new(5.9, 0.6, -14.6),
	Vector3.new(6.8, 0.6, 12.0),
	Vector3.new(13.3, 0.6, -21.8),
	Vector3.new(15.1, 0.6, -13.4),
	Vector3.new(13.4, 0.6, 11.0),
	Vector3.new(24.6, 0.6, -1.9),
	Vector3.new(22.0, 0.6, 5.4),
	Vector3.new(20.6, 0.6, 12.4),
	Vector3.new(26.5, 0.6, -5.0),
	Vector3.new(26.9, 0.6, 4.2),
}

local art = Instance.new("Model")
art.Name = "HubArt"
art.Parent = workspace

local function isInk(part: Instance): boolean
	return string.sub(part.Name, -4) == "_Ink"
end

local function paintedBounds(model: Model): (Vector3, Vector3)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, part in model:GetDescendants() do
		if part:IsA("MeshPart") and not isInk(part) then
			lo = lo:Min(part.Position - part.Size / 2)
			hi = hi:Max(part.Position + part.Size / 2)
		end
	end
	return lo, hi
end

-- glTF imports can arrive turned; measured on pieces with several parts and reused for those with one.
local importTurn: CFrame? = nil

local function measureTurn(model: Model, info: PieceInfo): CFrame?
	local count = 0
	local lo, hi = paintedBounds(model)
	local centre = (lo + hi) / 2
	local conceptLo, conceptHi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, part in info.parts do
		conceptLo = conceptLo:Min(part.min)
		conceptHi = conceptHi:Max(part.max)
		count += 1
	end
	if count < 2 then
		return nil
	end
	local conceptCentre = (conceptLo + conceptHi) / 2
	local best, bestError, bestName = CFrame.identity, math.huge, ""
	for name, turn in
		{ same = CFrame.identity, half = CFrame.Angles(0, math.pi, 0) } :: { [string]: CFrame }
	do
		local err = 0
		for partName, part in info.parts do
			local found = model:FindFirstChild(partName, true)
			if found and found:IsA("MeshPart") then
				local concept = (part.min + part.max) / 2 - conceptCentre
				err += (turn:VectorToWorldSpace(found.Position - centre) - concept).Magnitude
			end
		end
		if err < bestError then
			best, bestError, bestName = turn, err, name
		end
	end
	print(`HubArt: import turn {bestName} (fit error {string.format("%.2f", bestError)})`)
	return best
end

local function loadPiece(key: string): Model?
	local info = private.assets[key]
	if not info then
		warn(`HubArt: {key} is not uploaded`)
		return nil
	end
	local ok, container = pcall(function()
		return InsertService:LoadAsset(info.model)
	end)
	if not ok then
		warn(`HubArt: {key} failed to load: {container}`)
		return nil
	end
	local loaded = container :: Instance
	local model = Instance.new("Model")
	model.Name = key
	-- Keep the import's own tree where it holds bones; flatten everything else.
	local holdsBones = loaded:FindFirstChildWhichIsA("Bone", true) ~= nil
	if holdsBones then
		for _, child in loaded:GetChildren() do
			child.Parent = model
		end
	else
		for _, child in loaded:GetDescendants() do
			if child:IsA("MeshPart") then
				child.Parent = model
			end
		end
	end
	loaded:Destroy()
	local first = model:FindFirstChildWhichIsA("MeshPart", true)
	if first then
		print(`HubArt: {key} fidelity {first.RenderFidelity.Name}, bones {holdsBones}`)
	end
	local groups: { [string]: LookPack.GroupSpec } = {}
	for name, part in info.parts do
		groups[name] =
			{ ink = part.ink, emissive = part.emissive, center = (part.min + part.max) / 2 }
	end
	LookPack.styleModel(model, key, groups, templates, GLOW[key] or 1.0)
	for _, part in model:GetDescendants() do
		if part:IsA("MeshPart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Massless = true
		elseif part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Transparency = 1
		end
	end
	-- Fit to the concept in studs: true size, then turn, then position.
	local conceptLo, conceptHi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, part in info.parts do
		conceptLo = conceptLo:Min(part.min)
		conceptHi = conceptHi:Max(part.max)
	end
	local lo, hi = paintedBounds(model)
	local scale = (conceptHi.Y - conceptLo.Y) / (hi.Y - lo.Y)
	if math.abs(scale - 1) > 0.002 then
		print(`HubArt: {key} imported at {string.format("%.3f", 1 / scale)} of true size`)
		model:ScaleTo(model:GetScale() * scale)
	end
	importTurn = importTurn or measureTurn(model, info)
	model:PivotTo((importTurn or CFrame.identity) * model:GetPivot())
	lo, hi = paintedBounds(model)
	model:PivotTo(model:GetPivot() + ((conceptLo + conceptHi) / 2 - (lo + hi) / 2))
	return model
end

-- Client motion reads these: Spin about the world's vertical axis, and Bob up and down.
local function setMotion(
	model: Model,
	name: string,
	spin: number,
	bobHeight: number,
	bobRate: number,
	phase: number
)
	for _, part in model:GetDescendants() do
		if part:IsA("MeshPart") and (part.Name == name or part.Name == name .. "_Ink") then
			part:SetAttribute("Spin", spin)
			part:SetAttribute("BobHeight", bobHeight)
			part:SetAttribute("BobRate", bobRate)
			part:SetAttribute("Phase", phase)
			CollectionService:AddTag(part, "HubMover")
		end
	end
end

local function place(key: string): Model?
	local model = loadPiece(key)
	if model then
		model.Parent = art
	end
	return model
end

local function holder(name: string, position: Vector3, size: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = size
	part.Position = position
	part.Parent = art
	return part
end

local function pointLight(position: Vector3, color: Color3, brightness: number, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = holder("Light", position, Vector3.one)
end

local function fxTexture(name: string): string
	return "rbxassetid://" .. tostring(private.fx[name])
end

local function fade(points: { { number } }): NumberSequence
	local keys = {}
	for _, point in points do
		table.insert(keys, NumberSequenceKeypoint.new(point[1], point[2]))
	end
	return NumberSequence.new(keys)
end

local function beam(
	name: string,
	from: Vector3,
	to: Vector3,
	width0: number,
	width1: number,
	texture: string,
	color: Color3,
	transparency: NumberSequence,
	speed: number,
	repeats: number
): Beam
	local top = holder(name, from, Vector3.one)
	local bottom = holder(name, to, Vector3.one)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent, a1.Parent = top, bottom
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.Width0, b.Width1 = width0, width1
	b.FaceCamera = true
	b.Segments = 1
	b.Texture = texture
	b.TextureLength = repeats
	b.TextureMode = Enum.TextureMode.Stretch
	b.TextureSpeed = speed
	b.LightEmission = 1
	b.LightInfluence = 0
	b.Color = ColorSequence.new(color)
	b.Transparency = transparency
	b.Parent = top
	return b
end

-- The block-out's stand-ins for these designs turn invisible. Their collision stays, except what would snag a fall.
local function hideBlockOut()
	local root = workspace:WaitForChild("LobbyScale", 30) :: Model
	local function hide(container: Instance?)
		if not container then
			return
		end
		for _, item in container:GetDescendants() do
			if item:IsA("BasePart") then
				if item.CanCollide then
					item.Transparency = 1
				else
					item:Destroy()
				end
			end
		end
	end
	hide(root:FindFirstChild("SpawnRock"))
	hide(root:FindFirstChild("Bridges"))
	local rock = root:FindFirstChild("SpawnRock")
	local underside = rock and rock:FindFirstChild("Underside")
	if underside then
		underside:Destroy()
	end
	-- The real gates stand where the block-out's did.
	local portals = root:FindFirstChild("Portals")
	if portals then
		for _, entry in layout.portals do
			hide(portals:FindFirstChild(entry.name))
		end
	end
	local maelstrom = root:FindFirstChild("Maelstrom")
	if maelstrom then
		for _, item in maelstrom:GetChildren() do
			if item.Name == "WaterMarker" or item.Name == "Label" then
				item:Destroy()
			elseif item:IsA("BasePart") then
				-- The plunge's walls stood in front of the real cliff (owner: "the black base plate behind").
				item.Transparency = 1
			end
		end
	end
	local cavern = root:FindFirstChild("Cavern")
	if cavern then
		hide(cavern:FindFirstChild("Ceiling"))
		local sky = cavern:FindFirstChild("SkyWell")
		if sky then
			sky:Destroy()
		end
	end
	-- Labels only name the grey areas up close, so they don't float over the finished view.
	for _, item in root:GetDescendants() do
		if item:IsA("BillboardGui") then
			item.MaxDistance = 90
		end
	end
	local shore = root:FindFirstChild("Shore")
	if shore then
		for _, item in shore:GetChildren() do
			if item.Name == "DistanceTick" or item.Name == "Label" then
				item:Destroy()
			end
		end
		hide(shore:FindFirstChild("RimStrip"))
		-- The concept's mossy lip replaces the block-out's; its collider stays.
		for _, item in shore:GetDescendants() do
			if item.Name == "Lip" and item:IsA("BasePart") then
				item.Transparency = 1
			end
		end
	end
end

local function lighting()
	LookPack.applyBase()
	-- Phone first: no shadows and no voxel-heavy lamps, so every device gets the same look. The concepts' shading is
	-- painted in; a soft light from the Sky Well brings out the normal maps.
	Lighting.GlobalShadows = false
	Lighting.ClockTime = 12
	Lighting.GeographicLatitude = 35
	Lighting.Brightness = 0.9
	Lighting.Ambient = Color3.fromRGB(138, 136, 150)
	Lighting.OutdoorAmbient = Color3.fromRGB(138, 136, 150)
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0.2
	Lighting.ExposureCompensation = 0
	local atmosphere = Lighting:FindFirstChild("SlugshotAtmosphere") :: Atmosphere?
	if atmosphere then
		atmosphere.Density = 0.16
		atmosphere.Haze = 1
		atmosphere.Color = Color3.fromRGB(34, 36, 56)
		atmosphere.Decay = Color3.fromRGB(26, 26, 44)
	end
end

local function buildRock()
	place("hub-rock")
	place("hub-rock-dress")
	local debris = place("hub-rock-debris")
	if debris then
		for index = 0, 2 do
			setMotion(debris, `Debris{index}`, 0, 1.4, 0.3 + index * 0.09, index * 2.1)
		end
	end
	for _, point in CRACK_GLOW do
		local source = holder("CrackGlow", point, Vector3.new(5, 0.5, 5))
		local rising = Instance.new("ParticleEmitter")
		rising.Texture = fxTexture("mist")
		rising.Color = ColorSequence.new(Color3.fromRGB(70, 240, 215))
		rising.LightEmission = 1
		rising.LightInfluence = 0
		rising.Size = NumberSequence.new(3, 8)
		rising.Transparency = fade({ { 0, 1 }, { 0.25, 0.7 }, { 1, 1 } })
		rising.Lifetime = NumberRange.new(2, 3.2)
		rising.Rate = 0.5
		rising.Speed = NumberRange.new(1, 2)
		rising.EmissionDirection = Enum.NormalId.Top
		rising.Shape = Enum.ParticleEmitterShape.Box
		rising.Parent = source
	end
	local colors = {
		[0] = Color3.new(1, 0.62, 0.25),
		[1] = Color3.new(0.3, 1, 0.76),
		[2] = Color3.new(0.72, 0.87, 1),
		[3] = Color3.new(1, 0.82, 0.35),
	}
	for dir = 0, 3 do
		place(`hub-gate-{dir}`)
		local r = layout.bridges.gates[tostring(dir)] * UNIT
		local forward = ({
			[0] = Vector3.new(0, 0, -1),
			[1] = Vector3.new(1, 0, 0),
			[2] = Vector3.new(0, 0, 1),
			[3] = Vector3.new(-1, 0, 0),
		})[dir] :: Vector3
		pointLight(forward * r + Vector3.new(0, 12.6, 0), colors[dir], 0.5, 9)
	end
end

-- One bridge mesh shared by all four: its bones are moved per bridge on the client.
local function buildBridges()
	local source = loadPiece("hub-bridge")
	if not source then
		return
	end
	for dir = 0, 3 do
		local gate = layout.bridges.gates[tostring(dir)]
		local centre = (gate + 0.45 + 10 * BRIDGE_S) * UNIT
		local turn = (
				{ [0] = math.pi / 2, [1] = 0, [2] = -math.pi / 2, [3] = math.pi }
			)[dir] :: number
		local frame = CFrame.Angles(0, turn, 0) * CFrame.new(centre, 0, 0)
		local bridge = source:Clone()
		bridge.Name = `Bridge{dir}`
		bridge:PivotTo(frame * bridge:GetPivot())
		bridge:SetAttribute("Frame", frame)
		bridge.Parent = art
		CollectionService:AddTag(bridge, "HubBridge")
	end
	source:Destroy()
end

local function buildMaelstrom()
	local cliff = place("hub-cliff")
	if cliff then
		cliff:PivotTo(cliff:GetPivot() + Vector3.new(0, CLIFF_LIFT, 0))
	end
	place("hub-pit-flora")
	local juice = place("hub-juice")
	if juice then
		-- Rotating the whole surface is the concept's motion, since its folds all wind one way. Slower than the sped-up
		-- preview, because the owner wants it thick.
		setMotion(juice, "Juice", ORBIT * 2, 0, 0, 0)
	end
	local falls = place("hub-falls")
	if falls then
		CollectionService:AddTag(falls, "HubFalls")
	end
	-- Flowing light down each fall, on the same angles as the concept's falls.
	local hashes = { 0.7234, 0.3382, 0.0544, 0.5693 } -- hash1(i + 171) from the shader
	for index = 0, 3 do
		local angle = index * 1.5708 + 0.785 + 0.34 * (hashes[index + 1] - 0.5)
		local flat = Vector3.new(math.cos(angle), 0, math.sin(angle))
		beam(
			"FallFlow",
			flat * 85 + Vector3.new(0, 1, 0),
			flat * 73.6 + Vector3.new(0, -15, 0),
			6,
			8,
			fxTexture("streak"),
			Color3.fromRGB(70, 225, 205),
			fade({ { 0, 0.8 }, { 0.2, 0.55 }, { 1, 0.55 } }),
			0.45,
			1
		)
		beam(
			"FallFlow",
			flat * 73.6 + Vector3.new(0, -15, 0),
			flat * 73 + Vector3.new(0, -52, 0),
			8,
			10,
			fxTexture("streak"),
			Color3.fromRGB(70, 225, 205),
			fade({ { 0, 0.55 }, { 0.85, 0.55 }, { 1, 1 } }),
			0.45,
			2
		)
		-- Spray and a soft burst where it lands.
		local foot = holder("FallFoot", flat * 75 + Vector3.new(0, -53, 0), Vector3.new(12, 2, 12))
		local spray = Instance.new("ParticleEmitter")
		spray.Texture = fxTexture("mist")
		spray.Color = ColorSequence.new(Color3.fromRGB(130, 245, 225))
		spray.LightEmission = 1
		spray.LightInfluence = 0
		spray.Size = NumberSequence.new(5, 14)
		spray.Transparency = fade({ { 0, 1 }, { 0.3, 0.72 }, { 1, 1 } })
		spray.Lifetime = NumberRange.new(2.5, 4)
		spray.Rate = 1.2
		spray.Speed = NumberRange.new(2, 5)
		spray.EmissionDirection = Enum.NormalId.Top
		spray.Parent = foot
	end
	-- Mist and rising motes across the pit: a few big soft particles, which is what phones draw cheaply.
	local pit = holder("PitMist", Vector3.new(0, -46, 0), Vector3.new(130, 4, 130))
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = fxTexture("mist")
	mist.Color = ColorSequence.new(Color3.fromRGB(90, 225, 210))
	mist.LightEmission = 1
	mist.LightInfluence = 0
	mist.Size = NumberSequence.new(18, 34)
	mist.Transparency = fade({ { 0, 1 }, { 0.35, 0.8 }, { 1, 1 } })
	mist.Lifetime = NumberRange.new(7, 11)
	mist.Rate = 1.4
	mist.Speed = NumberRange.new(1.5, 3)
	mist.EmissionDirection = Enum.NormalId.Top
	mist.Shape = Enum.ParticleEmitterShape.Box
	mist.Parent = pit
	local motes = Instance.new("ParticleEmitter")
	motes.Texture = fxTexture("spore")
	motes.Color = ColorSequence.new(Color3.fromRGB(150, 255, 235))
	motes.LightEmission = 1
	motes.LightInfluence = 0
	motes.Brightness = 2
	motes.Size = NumberSequence.new(0.7, 0.3)
	motes.Transparency = fade({ { 0, 1 }, { 0.15, 0.1 }, { 0.8, 0.2 }, { 1, 1 } })
	motes.Lifetime = NumberRange.new(9, 14)
	motes.Rate = 3
	motes.Speed = NumberRange.new(3, 5)
	motes.EmissionDirection = Enum.NormalId.Top
	motes.Shape = Enum.ParticleEmitterShape.Box
	motes.Parent = pit
end

local function buildSkyWell()
	place("hub-well-rock")
	place("hub-well-glow")
	local isles = place("hub-well-isles")
	if isles then
		for index = 0, 4 do
			setMotion(isles, `Isle{index}`, -ORBIT, 6, ORBIT * (4 + index), index * 1.0)
		end
	end
	local bits = place("hub-well-bits")
	if bits then
		for index = 0, 5 do
			local spin = if index < 3 then -ORBIT * 2 else -ORBIT
			setMotion(bits, `Bits{index}`, spin, 6, ORBIT * (4 + index % 3 * 2), index * 1.9)
		end
	end
	local storm = place("hub-storm")
	if storm then
		for index = 0, 5 do
			-- Each layer winds a little faster toward the eye, which gives the cloud its depth.
			setMotion(storm, `Cloud{index}`, ORBIT * (1.7 + index * 0.16), 0, 0, 0)
		end
	end
	-- Light falling from the mouth, spreading and fading with no edge: a few soft camera-facing sheets.
	for index = 0, 3 do
		local angle = index * math.pi / 2 + 0.4
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 16
		beam(
			"LightShaft",
			offset + Vector3.new(0, 262, 0),
			offset * 2.4 + Vector3.new(0, 18, 0),
			80,
			170,
			fxTexture("softbeam"),
			Color3.fromRGB(150, 190, 225),
			fade({ { 0, 0.72 }, { 0.5, 0.87 }, { 1, 1 } }),
			0,
			1
		)
	end
	-- Lightning: the client moves this holder inside the storm and fires its two emitters.
	local flash = holder("StormFlash", Vector3.new(0, 300, 0), Vector3.one)
	local glow = Instance.new("ParticleEmitter")
	glow.Name = "Glow"
	glow.Texture = fxTexture("flash")
	glow.Color = ColorSequence.new(Color3.fromRGB(190, 180, 255))
	glow.LightEmission = 1
	glow.LightInfluence = 0
	glow.Size = NumberSequence.new(70, 95)
	glow.Transparency = fade({ { 0, 0.15 }, { 1, 1 } })
	glow.Lifetime = NumberRange.new(0.35, 0.5)
	glow.Rate = 0
	glow.Speed = NumberRange.new(0)
	glow.Parent = flash
	local zap = Instance.new("ParticleEmitter")
	zap.Name = "Zap"
	zap.Texture = fxTexture("zap")
	zap.Color = ColorSequence.new(Color3.fromRGB(235, 235, 255))
	zap.LightEmission = 1
	zap.LightInfluence = 0
	zap.Size = NumberSequence.new(26, 26)
	zap.Transparency = fade({ { 0, 0 }, { 0.6, 0.1 }, { 1, 1 } })
	zap.Lifetime = NumberRange.new(0.12, 0.22)
	zap.Rate = 0
	zap.Speed = NumberRange.new(0)
	zap.Rotation = NumberRange.new(0, 360)
	zap.Parent = flash
end

local function buildPortals()
	local glow = {
		PvP = { key = "hub-portal-pvp", color = Color3.fromRGB(255, 158, 64) },
		Training = { key = "hub-portal-training", color = Color3.fromRGB(107, 255, 115) },
		Veylume = { key = "hub-portal-veylume", color = Color3.fromRGB(199, 128, 255) },
	} :: { [string]: { key: string, color: Color3 } }
	for _, entry in layout.portals do
		local spec = glow[entry.name]
		local model = place(spec.key)
		if model then
			local rad = math.rad(entry.angle)
			local base =
				Vector3.new(entry.radius * math.sin(rad), entry.rise, -entry.radius * math.cos(rad))
			local frame = CFrame.lookAt(base, Vector3.new(0, base.Y, 0))
			model:PivotTo(frame * model:GetPivot())
			pointLight(base + frame.LookVector * 5 + Vector3.new(0, 8, 0), spec.color, 0.5, 14)
			-- Embers drifting off the energy, few and slow.
			local source = holder(
				"PortalEmbers",
				base + Vector3.new(0, 10, 0),
				Vector3.new(entry.width, entry.height, 1)
			)
			source.CFrame = frame + Vector3.new(0, 10, 0)
			local embers = Instance.new("ParticleEmitter")
			embers.Texture = fxTexture("spore")
			embers.Color = ColorSequence.new(spec.color)
			embers.LightEmission = 1
			embers.LightInfluence = 0
			embers.Brightness = 2
			embers.Size = NumberSequence.new(0.5, 0.15)
			embers.Transparency = fade({ { 0, 1 }, { 0.2, 0.1 }, { 1, 1 } })
			embers.Lifetime = NumberRange.new(2.5, 4.5)
			embers.Rate = 5
			embers.Speed = NumberRange.new(0.6, 1.6)
			embers.SpreadAngle = Vector2.new(30, 30)
			embers.EmissionDirection = Enum.NormalId.Top
			embers.Shape = Enum.ParticleEmitterShape.Box
			embers.Parent = source
		end
	end
end

-- Invisible blocks for the runestones, so players run into stone rather than through it.
local function gateColliders()
	local parent = Instance.new("Folder")
	parent.Name = "GateColliders"
	parent.Parent = art
	for dir = 0, 3 do
		local r = layout.bridges.gates[tostring(dir)] * UNIT
		local turn = (
				{ [0] = 0, [1] = -math.pi / 2, [2] = math.pi, [3] = math.pi / 2 }
			)[dir] :: number
		local frame = CFrame.Angles(0, turn, 0) * CFrame.new(0, 0, -r)
		local function solid(size: Vector3, offset: Vector3)
			local part = Instance.new("Part")
			part.Name = "GateCollider"
			part.Anchored = true
			part.CanTouch = false
			part.CastShadow = false
			part.Transparency = 1
			part.Size = size
			part.CFrame = frame * CFrame.new(offset)
			part.Parent = parent
		end
		for _, side in { 1, -1 } do
			solid(Vector3.new(4.2, 11.6, 3.6), Vector3.new(side * 9.2, 5.8, 0))
		end
		solid(Vector3.new(23, 2.6, 3.4), Vector3.new(0, 12.9, 0))
	end
end

lighting()
hideBlockOut()
gateColliders()
buildRock()
buildBridges()
buildMaelstrom()
buildSkyWell()
buildPortals()
for _, key in DISTANT do
	local model = art:FindFirstChild(key)
	if model then
		for _, part in model:GetDescendants() do
			if part:IsA("MeshPart") and isInk(part) then
				CollectionService:AddTag(part, "HubDistantInk")
			end
		end
	end
end
-- Stacked sheets of cloud are the most expensive thing to draw when looking up, so a phone drops every other one.
local storm = art:FindFirstChild("hub-storm")
if storm then
	for _, name in { "Cloud1", "Cloud3" } do
		local part = storm:FindFirstChild(name, true)
		if part then
			CollectionService:AddTag(part, "HubSpareCloud")
		end
	end
end
print("HubArt: built")
