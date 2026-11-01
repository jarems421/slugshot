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
local rimShape =
	require(ReplicatedStorage:WaitForChild("LobbyScale"):WaitForChild("rim_shape")) :: any
local LookPack = require(ReplicatedStorage:WaitForChild("LookPack"))

type PartInfo = { ink: string?, emissive: number, min: Vector3, max: Vector3 }
type PieceInfo = {
	model: number,
	points: { { p: Vector3, c: Color3 } },
	parts: { [string]: PartInfo },
}

local private = require(ServerStorage:WaitForChild("HubAssets")) :: {
	fx: { [string]: number },
	assets: { [string]: PieceInfo },
}
local templates = ServerStorage:WaitForChild("HubMaterials")

local ORBIT = 0.12 -- the concepts' base rate, radians per second
local BRIDGE_S = 0.51 -- bridge units per spawn-rock unit
local UNIT = 5 -- studs per spawn-rock and Maelstrom unit
local CLIFF_LIFT = 0.12 -- keeps the cliff's ground above the block-out floor it covers
local DOWN = Vector3.new(0, -1, 0)
local FALL_FOOT_Y = -51 -- the juice's surface where the falls land
local BASIN_Y = -2.25 -- the pools' surface, in units
local BASIN_R = 1.7 -- the basin's radius, in units
local BASIN_CENTRE = -0.7 -- in units, from the cliff's edge
local FALL_SPACING = 24 -- degrees between strips of the overflow
local FALL_FAN = { -72, -48, -24, 0, 24, 48, 72 }

-- Pieces that glow more than the painted brightness suits under Roblox's bloom.
local GLOW: { [string]: number } = {
	["hub-portal-pvp"] = 0.75,
	["hub-portal-training"] = 0.75,
	["hub-portal-veylume"] = 0.75,
	["hub-storm"] = 0.7,
}

-- Pieces whose ink a phone can skip: far away or small on screen (HubMotion.client decides).
local DISTANT = {
	"hub-portal-pvp",
	"hub-portal-training",
	"hub-portal-veylume",
	"hub-well-rock",
	"hub-well-glow",
	"hub-ceiling-gems",
	"hub-ceiling-vines",
	"hub-arch",
	"hub-volcano",
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
	-- Titan's Arch and the real volcano replace the block-out's. The climb to the old rim goes with it.
	local oldVolcano = root:FindFirstChild("Volcano")
	if oldVolcano then
		oldVolcano:Destroy()
	end
	-- The real gates stand where the block-out's did.
	local portals = root:FindFirstChild("Portals")
	if portals then
		for _, item in portals:GetChildren() do
			if item:IsA("BasePart") and item.Name == "Surface" then
				item.Transparency = 1
			end
		end
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
		-- The portal side's ground art replaces its grey ground, which stays to walk on.
		for _, item in shore:GetChildren() do
			if item:IsA("BasePart") and item.Name == "Surface" then
				local at = item.Position
				if math.abs(math.deg(math.atan2(at.X, -at.Z))) < 40 then
					item.Transparency = 1
				end
			end
		end
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

-- A star twinkle at each crystal's tip (look-pack.md), scaled to how far away they're seen.
local function addTwinkles(key: string, size: number)
	for index, point in private.assets[key].points do
		local source = holder("Twinkle", point.p, Vector3.one * size * 0.4)
		local e = Instance.new("ParticleEmitter")
		e.Name = "Twinkle"
		e.Texture = fxTexture("twinkle")
		e.Color = ColorSequence.new(point.c:Lerp(Color3.new(1, 1, 1), 0.45))
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Brightness = 2.5
		e.Size = fade({ { 0, 0 }, { 0.4, size }, { 1, 0 } })
		e.Lifetime = NumberRange.new(0.5, 1.1)
		e.Rate = 1.2
		e.Speed = NumberRange.new(0.05, 0.25)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Rotation = NumberRange.new(0, 90)
		e.RotSpeed = NumberRange.new(-40, 40)
		e.Parent = source
		if index % 2 == 0 then
			CollectionService:AddTag(e, "HubSpareTwinkle")
		end
	end
end

local function buildRock()
	place("hub-rock")
	place("hub-rock-dress")
	addTwinkles("hub-rock-dress", 1.5)
	place("hub-gems")
	addTwinkles("hub-gems", 1.3)
	local debris = place("hub-rock-debris")
	if debris then
		for index = 0, 2 do
			setMotion(debris, `Debris{index}`, 0, 1.4, 0.3 + index * 0.09, index * 2.1)
		end
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

-- One strip of the overflow. Each stays flat against the basin it spills from, so it never turns to face the camera.
local function ribbon(
	from: Vector3,
	to: Vector3,
	outward: Vector3,
	tangent: Vector3,
	width: number,
	texture: string,
	color: Color3,
	transparency: NumberSequence,
	length: number,
	speed: number,
	emission: number
)
	local top, bottom = holder("FallFlow", from, Vector3.one), holder("FallFlow", to, Vector3.one)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	-- The curve leaves the top along +X of the first attachment and arrives along +X of the second; width runs along Y.
	a0.CFrame = CFrame.fromMatrix(Vector3.zero, outward, tangent, outward:Cross(tangent))
	a1.CFrame = CFrame.fromMatrix(Vector3.zero, DOWN, tangent, DOWN:Cross(tangent))
	a0.Parent, a1.Parent = top, bottom
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.CurveSize0, b.CurveSize1 = 4.5, 16
	b.Width0, b.Width1 = width, width * 0.85
	b.FaceCamera = false
	b.Segments = 14
	b.Texture = texture
	b.TextureMode = Enum.TextureMode.Wrap
	b.TextureLength = length
	b.TextureSpeed = speed
	b.LightEmission = emission
	b.LightInfluence = 0
	b.Color = ColorSequence.new(color)
	b.Transparency = transparency
	b.Parent = top
end

-- The basin overflows: water runs off the pool and over the whole front of the basin, then falls to the juice as one curtain.
local function buildFall(angle: number)
	local flat = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local across = Vector3.new(-flat.Z, 0, flat.X)
	local rim = UNIT * (17.6 + 0.45 * math.sin(angle * 5 + 1) + 0.3 * math.sin(angle * 11 + 2))
	local inward = -flat
	local radius = BASIN_R * UNIT
	local centre = flat * (rim + BASIN_CENTRE * UNIT)
	local melt = fade({ { 0, 0 }, { 0.82, 0 }, { 1, 1 } })
	for index, side in FALL_FAN do
		local turn = math.rad(side)
		local outward = inward * math.cos(turn) + across * math.sin(turn)
		local tangent = across * math.cos(turn) - inward * math.sin(turn)
		local from = centre + outward * (radius - 1) + Vector3.new(0, BASIN_Y * UNIT + 0.75, 0)
		local to = centre + outward * (radius - 1.2) + Vector3.new(0, FALL_FOOT_Y, 0)
		local width = radius * math.rad(FALL_SPACING) * 1.9
		ribbon(
			from,
			to,
			outward,
			tangent,
			width,
			fxTexture("flow"),
			Color3.new(1, 1, 1),
			melt,
			46,
			0.42 + index * 0.015,
			0
		)
		-- Faster, brighter bands over the top, so it never reads as one solid surface.
		if index % 3 == 1 then
			ribbon(
				from + Vector3.new(0, 0.05, 0),
				to,
				outward,
				tangent,
				width,
				fxTexture("streak"),
				Color3.fromRGB(165, 255, 240),
				fade({ { 0, 1 }, { 0.05, 0.55 }, { 0.8, 0.5 }, { 1, 1 } }),
				30,
				0.95,
				0.5
			)
		end
	end
	local foot = centre + inward * radius + Vector3.new(0, FALL_FOOT_Y, 0)
	-- Where it lands: ripples spreading over the juice, foam churning, and foam carried off along the swirl's own direction.
	local landing = holder("FallFoot", foot + Vector3.new(0, 1.4, 0), Vector3.new(11, 0.5, 11))
	local ripples = Instance.new("ParticleEmitter")
	ripples.Name = "Ripples"
	ripples.Texture = fxTexture("ripple")
	ripples.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	ripples.EmissionDirection = Enum.NormalId.Top
	ripples.Speed = NumberRange.new(0.05)
	ripples.Color = ColorSequence.new(Color3.fromRGB(190, 255, 245))
	ripples.LightEmission = 0.5
	ripples.LightInfluence = 0
	ripples.Size = NumberSequence.new(7, 34)
	ripples.Transparency = fade({ { 0, 0.5 }, { 0.15, 0.15 }, { 1, 1 } })
	ripples.Lifetime = NumberRange.new(2.2, 3)
	ripples.Rate = 1.3
	ripples.Parent = landing
	local foam = Instance.new("ParticleEmitter")
	foam.Name = "Foam"
	foam.Texture = fxTexture("mist")
	foam.EmissionDirection = Enum.NormalId.Top
	foam.Color = ColorSequence.new(Color3.fromRGB(170, 250, 238))
	foam.LightEmission = 0.2
	foam.LightInfluence = 0
	foam.Size = NumberSequence.new(7, 16)
	foam.Transparency = fade({ { 0, 1 }, { 0.2, 0.5 }, { 1, 1 } })
	foam.Lifetime = NumberRange.new(1.2, 2)
	foam.Rate = 6
	foam.Speed = NumberRange.new(2, 5)
	foam.SpreadAngle = Vector2.new(35, 35)
	foam.Parent = landing
	-- The juice turns from each point toward (z, -x) in world space, and winds inward.
	local swirl = (Vector3.new(flat.Z, 0, -flat.X) * 0.85 + inward * 0.5).Unit
	local trail = holder("FallTrail", foot + Vector3.new(0, 1.5, 0), Vector3.new(7, 0.5, 7))
	trail.CFrame = CFrame.lookAt(trail.Position, trail.Position + swirl)
	local carried = Instance.new("ParticleEmitter")
	carried.Name = "Carried"
	carried.Texture = fxTexture("mist")
	carried.EmissionDirection = Enum.NormalId.Front
	carried.Color = ColorSequence.new(Color3.fromRGB(150, 245, 230))
	carried.LightEmission = 0.2
	carried.LightInfluence = 0
	carried.Size = NumberSequence.new(5, 10)
	carried.Transparency = fade({ { 0, 1 }, { 0.15, 0.6 }, { 1, 1 } })
	carried.Lifetime = NumberRange.new(2.5, 4)
	carried.Rate = 2.5
	carried.Speed = NumberRange.new(5, 8)
	carried.SpreadAngle = Vector2.new(10, 10)
	carried.Acceleration = Vector3.new(0, -1.2, 0)
	carried.Parent = trail
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
	-- The pools turn in place, with ripples spreading over them, so the source is as alive as the fall.
	place("hub-bowl")
	local pools = place("hub-basin")
	if pools then
		for index = 0, 3 do
			local pool = pools:FindFirstChild(`Pool{index}`, true)
			if pool then
				pool:SetAttribute("LocalSpin", ORBIT * 2.5)
				CollectionService:AddTag(pool, "HubMover")
				local rings = Instance.new("ParticleEmitter")
				rings.Texture = fxTexture("ripple")
				rings.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
				rings.EmissionDirection = Enum.NormalId.Top
				rings.Speed = NumberRange.new(0.05)
				rings.Color = ColorSequence.new(Color3.fromRGB(190, 255, 245))
				rings.LightEmission = 0.4
				rings.LightInfluence = 0
				rings.Size = NumberSequence.new(1.5, 8)
				rings.Transparency = fade({ { 0, 0.6 }, { 0.2, 0.3 }, { 1, 1 } })
				rings.Lifetime = NumberRange.new(1.6, 2.4)
				rings.Rate = 1
				rings.Shape = Enum.ParticleEmitterShape.Disc
				rings.Parent = pool
			end
		end
	end
	-- The same fixed angles as the art's basins.
	for _, angle in rimShape.falls do
		buildFall(angle)
	end
	-- Mist rising off the juice: a few big soft particles, which is what phones draw cheaply.
	local pit = holder("PitMist", Vector3.new(0, -58, 0), Vector3.new(120, 4, 120))
	local mist = Instance.new("ParticleEmitter")
	mist.Name = "Mist"
	mist.Texture = fxTexture("mist")
	mist.Color = ColorSequence.new(Color3.fromRGB(95, 230, 215))
	mist.LightEmission = 0.6
	mist.LightInfluence = 0
	mist.Size = NumberSequence.new(24, 52)
	mist.Transparency = fade({ { 0, 1 }, { 0.3, 0.55 }, { 1, 1 } })
	mist.Lifetime = NumberRange.new(9, 13)
	mist.Rate = 3
	-- Stays in the pit: a big sprite that drifts up past the island draws a hard edge across the view.
	mist.Speed = NumberRange.new(2, 3.5)
	mist.EmissionDirection = Enum.NormalId.Top
	mist.Shape = Enum.ParticleEmitterShape.Box
	mist.Parent = pit
	CollectionService:AddTag(mist, "HubMist")
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
	addTwinkles("hub-well-glow", 6)
	place("hub-ceiling-vines")
	place("hub-ceiling-gems")
	addTwinkles("hub-ceiling-gems", 7)
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
			local sheet = storm:FindFirstChild(`Cloud{index}`, true)
			local surface = sheet and sheet:FindFirstChildWhichIsA("SurfaceAppearance")
			if surface then
				CollectionService:AddTag(surface, "HubStormCloud")
			end
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
			fade({ { 0, 1 }, { 0.22, 0.84 }, { 0.55, 0.9 }, { 1, 1 } }),
			0,
			1
		)
	end
	-- A soft round glow well under the storm. A sprite that crosses a flat cloud sheet is cut in a straight line there, which
	-- read as a box in the sky (owner), so none may reach the sheets (the lowest is at 200).
	local mouth = holder("MouthGlow", Vector3.new(0, 118, 0), Vector3.one)
	local haze = Instance.new("ParticleEmitter")
	haze.Texture = fxTexture("flash")
	haze.Color = ColorSequence.new(Color3.fromRGB(150, 180, 225))
	haze.LightEmission = 1
	haze.LightInfluence = 0
	haze.Size = NumberSequence.new(150, 165)
	haze.Transparency = fade({ { 0, 1 }, { 0.5, 0.78 }, { 1, 1 } })
	haze.Lifetime = NumberRange.new(7, 9)
	haze.Rate = 0.35
	haze.Speed = NumberRange.new(0)
	haze.Parent = mouth
	-- Lightning: the client moves this holder inside the storm and fires its two emitters.
	local flash = holder("StormFlash", Vector3.new(0, 300, 0), Vector3.one)
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

-- The portal side: Titan's Arch, with Codex's Ember Crown volcano behind it. These were modelled facing away from the hub.
local PLAZA = CFrame.new(0, 0, -157) * CFrame.Angles(0, math.pi, 0)
local VOLCANO_Z = 111 -- studs behind the plaza's origin
local VOLCANO_SCALE = 1.15
local DOWN_AXIS = Vector3.new(0, -1, 0)

local function placeInPlaza(key: string): Model?
	local model = place(key)
	if model then
		model:PivotTo(PLAZA * model:GetPivot())
	end
	return model
end

local function volcCentre(y: number): (number, number)
	local t = y / 130
	return 4 * math.sin(t * 2.4) - 2 * t, -4 * t + 2 * math.sin(t * 3)
end

local function volcRadius(a: number, y: number): number
	local t = math.clamp(y / 130, 0, 1)
	local base = 84 - 54 * t ^ 0.72
	local phase = a * 12 + 0.22 * math.sin(a * 3) + 0.13 * math.sin(t * 9 + a * 2)
	local ridge = (1 - math.abs(math.sin(phase * 0.5))) ^ 1.6
	return base
		+ (ridge - 0.36) * (15 - 5 * t)
		+ 1.15 * math.sin(t * math.pi * 6 + a * 2)
		+ 2 * math.sin(a * 3 + 0.5) * (1 - t)
end

-- A point on the volcano's wall, in world space, in the study's own units of angle and height.
local function volcWall(a: number, y: number, offset: number): Vector3
	local cx, cz = volcCentre(y)
	local r = volcRadius(a, y) + offset
	return PLAZA
		* Vector3.new(
			(cx + math.cos(a) * r) * VOLCANO_SCALE,
			y * VOLCANO_SCALE,
			(cz + math.sin(a) * r) * VOLCANO_SCALE + VOLCANO_Z
		)
end

local function buildVolcano()
	placeInPlaza("hub-volcano")
	-- Molten rivers, flowing, over the painted ones on the side facing the hub.
	local rivers = {
		{ -1.18, 5, 4.8, 0 },
		{ -0.28, 25, 3.6, 1 },
		{ 3.3106, 8, 4.5, 5 },
		{ 4.2081, 21, 3.8, 6 },
	}
	for _, river in rivers do
		local a0, lo, wide, k = river[1], river[2], river[3], river[4]
		local segments = 5
		for s = 0, segments - 1 do
			local function at(f: number): (Vector3, number)
				local t = f / segments
				local y = 129 + (lo - 129) * t
				local a = a0 + 0.08 * math.sin(y / 130 * 5 + k * 2)
				local w = wide
					* (0.72 + 0.23 * math.sin(t * 15 + k * 2))
					* (0.55 + 0.45 * math.sin(math.pi * t * 0.7 + 0.35))
				return volcWall(a, y, 1.6), w * 2.6 * VOLCANO_SCALE
			end
			local from, w0 = at(s)
			local to, w1 = at(s + 1)
			beam(
				"LavaRiver",
				from,
				to,
				w0,
				w1,
				fxTexture("lavaflow"),
				Color3.new(1, 1, 1),
				fade({ { 0, 0.12 }, { 1, 0.12 } }),
				0.32,
				2
			)
		end
	end
	-- The crater: what erupts is run by HubMotion.client.
	local cx, cz = volcCentre(130)
	local top = PLAZA * Vector3.new(cx * VOLCANO_SCALE, 147, cz * VOLCANO_SCALE + VOLCANO_Z)
	local crater = holder("Crater", top, Vector3.new(26, 1, 26))
	CollectionService:AddTag(crater, "HubCrater")
	local function emitter(name: string): ParticleEmitter
		local e = Instance.new("ParticleEmitter")
		e.Name = name
		e.Rate = 0
		e.LightInfluence = 0
		e.EmissionDirection = Enum.NormalId.Top
		e.Parent = crater
		return e
	end
	local molten = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 226, 150)),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 142, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 28, 8)),
	})
	-- Heavy blobs thrown high in long arcs, falling back on the slopes.
	local blobs = emitter("Blobs")
	blobs.Texture = fxTexture("droplet")
	blobs.Orientation = Enum.ParticleOrientation.VelocityParallel
	blobs.LightEmission = 1
	blobs.Color = molten
	blobs.Size = fade({ { 0, 6 }, { 0.15, 10 }, { 1, 5 } })
	blobs.Transparency = fade({ { 0, 0 }, { 0.85, 0 }, { 1, 1 } })
	blobs.Lifetime = NumberRange.new(3.2, 4.6)
	blobs.Speed = NumberRange.new(55, 98)
	blobs.SpreadAngle = Vector2.new(40, 40)
	blobs.Acceleration = Vector3.new(0, -62, 0)
	blobs.Drag = 0.12
	-- A spray of small hot spits, wider and quicker to die.
	local spits = emitter("Spits")
	spits.Texture = fxTexture("droplet")
	spits.Orientation = Enum.ParticleOrientation.VelocityParallel
	spits.LightEmission = 1
	spits.Color = molten
	spits.Size = fade({ { 0, 3.6 }, { 1, 1 } })
	spits.Lifetime = NumberRange.new(1.4, 2.6)
	spits.Speed = NumberRange.new(30, 78)
	spits.SpreadAngle = Vector2.new(55, 55)
	spits.Acceleration = Vector3.new(0, -62, 0)
	spits.Drag = 0.2
	-- Underlit smoke thrown up with each blast.
	local blast = emitter("Blast")
	blast.Texture = fxTexture("mist")
	blast.LightEmission = 0.35
	blast.Color = ColorSequence.new(Color3.fromRGB(255, 118, 48), Color3.fromRGB(58, 40, 50))
	blast.Size = fade({ { 0, 30 }, { 1, 95 } })
	blast.Transparency = fade({ { 0, 0.35 }, { 1, 1 } })
	blast.Lifetime = NumberRange.new(2.2, 3.6)
	blast.Speed = NumberRange.new(16, 34)
	blast.SpreadAngle = Vector2.new(18, 18)
	-- The flash in the crater.
	local flare = emitter("Flare")
	flare.Texture = fxTexture("flash")
	flare.LightEmission = 1
	flare.Color = ColorSequence.new(Color3.fromRGB(255, 170, 70))
	flare.Size = fade({ { 0, 80 }, { 1, 135 } })
	flare.Transparency = fade({ { 0, 0.25 }, { 1, 1 } })
	flare.Lifetime = NumberRange.new(0.45, 0.7)
	flare.Speed = NumberRange.new(0)
	-- The plume that's always rising.
	local plume = emitter("Plume")
	plume.Texture = fxTexture("mist")
	plume.Color = ColorSequence.new(Color3.fromRGB(150, 98, 84), Color3.fromRGB(46, 40, 54))
	plume.LightEmission = 0.1
	plume.Size = fade({ { 0, 16 }, { 1, 58 } })
	plume.Transparency = fade({ { 0, 1 }, { 0.2, 0.62 }, { 1, 1 } })
	plume.Lifetime = NumberRange.new(9, 13)
	plume.Rate = 1.5
	plume.Speed = NumberRange.new(7, 11)
	plume.SpreadAngle = Vector2.new(10, 10)
	CollectionService:AddTag(plume, "HubMist")
	pointLight(top + Vector3.new(0, 6, 0), Color3.fromRGB(255, 120, 50), 1.2, 45)
end

local function buildArch()
	placeInPlaza("hub-plaza-floor")
	placeInPlaza("hub-arch")
	-- Fires on the pylons.
	for _, spot in { { 6.2, -8.5, 8 }, { 14, -11, 10 } } do
		for _, side in { -1, 1 } do
			local position = PLAZA
				* Vector3.new(side * spot[1] * 5, (spot[3] + 0.42) * 5, spot[2] * 5)
			local source = holder("PylonFire", position, Vector3.new(4, 1, 4))
			local flames = Instance.new("ParticleEmitter")
			flames.Texture = fxTexture("flame")
			flames.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 196, 90)),
				ColorSequenceKeypoint.new(0.6, Color3.fromRGB(255, 96, 24)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 28, 8)),
			})
			flames.LightEmission = 1
			flames.LightInfluence = 0
			flames.Size = fade({ { 0, 6.5 }, { 1, 2 } })
			flames.Transparency = fade({ { 0, 0.2 }, { 0.7, 0.3 }, { 1, 1 } })
			flames.Lifetime = NumberRange.new(0.6, 1.1)
			flames.Rate = 12
			flames.Speed = NumberRange.new(7, 12)
			flames.SpreadAngle = Vector2.new(9, 9)
			flames.EmissionDirection = Enum.NormalId.Top
			flames.Parent = source
			pointLight(position + Vector3.new(0, 4, 0), Color3.fromRGB(255, 120, 45), 0.6, 18)
		end
	end
	-- The two lava falls beside the PvP gate, flat against the view from the hub.
	for _, side in { -1, 1 } do
		local top = PLAZA * Vector3.new(side * 34.5, 110, 4)
		local foot = PLAZA * Vector3.new(side * 34.5, -1, 4)
		ribbon(
			top,
			foot,
			DOWN_AXIS,
			Vector3.xAxis,
			9.5,
			fxTexture("lavaflow"),
			Color3.new(1, 1, 1),
			fade({ { 0, 0.06 }, { 1, 0.06 } }),
			60,
			0.55,
			0
		)
		ribbon(
			top,
			foot,
			DOWN_AXIS,
			Vector3.xAxis,
			8,
			fxTexture("streak"),
			Color3.fromRGB(255, 170, 70),
			fade({ { 0, 0.55 }, { 1, 0.55 } }),
			40,
			1.1,
			0.6
		)
		local base = holder("LavaFoot", foot + Vector3.new(0, 2, 0), Vector3.new(14, 0.5, 8))
		local steam = Instance.new("ParticleEmitter")
		steam.Texture = fxTexture("mist")
		steam.Color = ColorSequence.new(Color3.fromRGB(255, 110, 44))
		steam.LightEmission = 0.6
		steam.LightInfluence = 0
		steam.Size = fade({ { 0, 7 }, { 1, 18 } })
		steam.Transparency = fade({ { 0, 1 }, { 0.2, 0.6 }, { 1, 1 } })
		steam.Lifetime = NumberRange.new(1.4, 2.4)
		steam.Rate = 3
		steam.Speed = NumberRange.new(4, 9)
		steam.EmissionDirection = Enum.NormalId.Top
		steam.Shape = Enum.ParticleEmitterShape.Box
		steam.Parent = base
	end
	-- Embers across the whole area.
	local air = holder("PlazaEmbers", PLAZA * Vector3.new(0, 3, 30), Vector3.new(230, 4, 180))
	local embers = Instance.new("ParticleEmitter")
	embers.Texture = fxTexture("spore")
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 160, 70))
	embers.LightEmission = 1
	embers.LightInfluence = 0
	embers.Brightness = 2
	embers.Size = NumberSequence.new(0.7, 0.25)
	embers.Transparency = fade({ { 0, 1 }, { 0.15, 0.1 }, { 0.8, 0.2 }, { 1, 1 } })
	embers.Lifetime = NumberRange.new(7, 11)
	embers.Rate = 7
	embers.Speed = NumberRange.new(3, 6)
	embers.EmissionDirection = Enum.NormalId.Top
	embers.Shape = Enum.ParticleEmitterShape.Box
	embers.Parent = air
end

-- What players bump into: the arch's feet, the pylons, the columns and the volcano itself, all invisible and simple.
local function plazaColliders()
	local parent = Instance.new("Folder")
	parent.Name = "PlazaColliders"
	parent.Parent = art
	local function solid(size: Vector3, frame: CFrame, shape: Enum.PartType?)
		local part = Instance.new("Part")
		part.Name = "PlazaCollider"
		part.Anchored = true
		part.CanTouch = false
		part.CastShadow = false
		part.Transparency = 1
		if shape then
			part.Shape = shape
		end
		part.Size = size
		part.CFrame = frame
		part.Parent = parent
	end
	for _, side in { -1, 1 } do
		solid(Vector3.new(28, 62, 46), PLAZA * CFrame.new(side * 127, 31, 4))
		solid(Vector3.new(52, 60, 86), PLAZA * CFrame.new(side * 160, 30, -2))
		solid(Vector3.new(10, 40, 10), PLAZA * CFrame.new(side * 31, 20, -42.5))
		solid(Vector3.new(12, 50, 12), PLAZA * CFrame.new(side * 70, 25, -55))
	end
	for band = 0, 6 do
		local y = 10 + band * 20
		local r = (84 - 54 * math.clamp(y / 150, 0, 1) ^ 0.72) * VOLCANO_SCALE
		solid(
			Vector3.new(20, r * 2, r * 2),
			PLAZA * CFrame.new(0, y, VOLCANO_Z) * CFrame.Angles(0, 0, math.pi / 2),
			Enum.PartType.Cylinder
		)
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
buildVolcano()
buildArch()
plazaColliders()
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
