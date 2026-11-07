--!strict
-- Brings the final hub designs into the lobby: spawn rock, runestone gateways, rope bridges, Maelstrom and Sky Well.
-- Stone, rock and ground are solid exactly as drawn (see SOLID); ink, glow, water and anything that moves stay passable.
-- The block-out parts these designs replace turn invisible or are removed (docs/art/lobby-hub.md). Asset ids live in
-- private-assets/lobby. Motion runs on the client in HubMotion.client.
local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local layout = require(ReplicatedStorage:WaitForChild("LobbyScale"):WaitForChild("layout")) :: any
local rimShape =
	require(ReplicatedStorage:WaitForChild("LobbyScale"):WaitForChild("rim_shape")) :: any
local groveStream =
	require(ReplicatedStorage:WaitForChild("LobbyScale"):WaitForChild("grove_stream")) :: any
local groveFlora =
	require(ReplicatedStorage:WaitForChild("LobbyScale"):WaitForChild("grove_flora")) :: any
local groveCrystals =
	require(ReplicatedStorage:WaitForChild("LobbyScale"):WaitForChild("grove_crystals")) :: any
local groveTrees =
	require(ReplicatedStorage:WaitForChild("LobbyScale"):WaitForChild("grove_trees")) :: any
local groveSlugs =
	require(ReplicatedStorage:WaitForChild("LobbyScale"):WaitForChild("grove_slugs")) :: any
-- The gun side's knoll and canopy hole, in world studs (tools/lobby/gun_side_sites.py).
local gunSide =
	require(ReplicatedStorage:WaitForChild("LobbyScale"):WaitForChild("gun_side")) :: any
-- The cavern wall's and far side cave's dressing, in world studs (tools/lobby/far_side_sites.py).
local farSide =
	require(ReplicatedStorage:WaitForChild("LobbyScale"):WaitForChild("far_side")) :: any
local LookPack = require(ReplicatedStorage:WaitForChild("LookPack"))
local FloppyAppearance = require(script.Parent:WaitForChild("FloppyAppearance")) :: any
local InfernoAppearance = require(script.Parent:WaitForChild("InfernoAppearance")) :: any

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
-- The overflow spills over a shallow front arc of its basin as one sheet (owner, 2026-11-07: the falls looked weird; spilling
-- over 144 degrees of the round basin, from -72 to 72, made each a half-cylinder, a pipe of water seen from above).
local FALL_SPACING = 20 -- degrees between strips of the overflow
local FALL_FAN = { -40, -20, 0, 20, 40 }

-- Pieces that glow more than the painted brightness suits under Roblox's bloom.
local GLOW: { [string]: number } = {
	["hub-portal-pvp"] = 0.75,
	["hub-portal-training"] = 0.75,
	["hub-portal-veylume"] = 0.75,
	["hub-storm"] = 1.4, -- HubMotion's STORM_GLOW
	-- Mushroom caps in the whirlpool and on the spawn rock glow more (owner).
	["hub-pit-flora"] = 1.8,
	-- Their colour goes pale at any more.
	["hub-flora-star"] = 0.4,
	["hub-flora-bell"] = 0.4,
	["hub-flora-lantern"] = 0.5,
	["hub-flora-plant"] = 0.5,
	["hub-flora-grass"] = 0.5,
	["hub-rock-dress"] = 1.4,
	-- The shop's velvet ground glows purple, spores and all (owner, 2026-11-07: too dim, bring its glow back; then the cushions
	-- themselves, not only the specks: their glow map covers them now).
	["hub-gun-ground"] = 1.6,
	-- The runes round the storm (owner, 2026-11-07: the ring round the storm too plain and dark).
	["hub-well-rock"] = 1.6,
}
-- Caps alone, on top of that: the side mushrooms sprouting from the rock and the cave's spires and curving up (owner,
-- 2026-11-06: their tops need a good glow, like the mushroom trees'), from 0.93 to about the trees' 4.
local CAP_ONLY_GLOW: { [string]: number } = {
	["hub-gun-sideshroom-a"] = 4,
	["hub-gun-sideshroom-b"] = 4,
	-- The shop's great cap (owner, 2026-11-07: it should glow like the other mushrooms).
	["hub-gun-shop"] = 3,
}

-- Pieces whose ink a phone can skip: far away or small on screen (HubMotion.client decides).
local DISTANT = {
	"hub-portal-pvp",
	"hub-portal-training",
	"hub-portal-veylume",
	"hub-well-rock",
	"hub-well-glow",
	"hub-ceiling-vines",
	"hub-arch",
	"hub-volcano",
	"hub-grove-mountain",
	"hub-grove-rocks",
	"hub-grove-dress",
	"hub-well-isles",
	"hub-well-bits",
	"hub-rock-debris",
	"hub-pit-flora",
	"hub-cliff",
	"hub-rock",
	"hub-cavern-00",
	"hub-cavern-01",
	"hub-cavern-02",
	"hub-cavern-03",
	"hub-cavern-04",
	"hub-cavern-05",
	"hub-cavern-06",
	"hub-cavern-07",
	"hub-cavern-08",
	"hub-cavern-09",
	"hub-cavern-10",
	"hub-cavern-11",
	"hub-roof-00",
	"hub-roof-01",
	"hub-roof-02",
	"hub-roof-03",
	"hub-roof-04",
	"hub-roof-05",
	"hub-roof-06",
	"hub-roof-07",
	"hub-roof-08",
	"hub-roof-09",
	"hub-roof-10",
	"hub-roof-11",
	"hub-cave-spires",
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

-- What blocks light (owner, 2026-11-06: shader-style light from somewhere): rock with its runes, wood, stems and stone; never
-- an ink shell or what holds or is a light, as a crystal or glowing cap would shut in the light set inside it.
local GLOWING_PARTS = {
	"Lantern",
	"Energy",
	"Pool",
	"Flows",
	"Lava",
	"Falls",
	"Pond",
	"Juice",
	"Glow",
	"Storm",
	"Cap",
	"Gem",
	"Key",
	"Glass",
	"Sprouts",
	"Minis",
}
local function castsShadow(key: string, part: MeshPart): boolean
	if string.sub(key, 1, 9) == "crystals-" or string.sub(part.Name, -4) == "_Ink" then
		return false
	end
	-- Mushroom caps shade the ground under them in the storm's light (owner, 2026-11-07: shadows of everything that makes
	-- sense); a tree's own light hangs below its cap. The canopy's lights sit inside theirs (buildGunSide turns those off).
	if
		part.Name == "Cap"
		and (string.sub(key, 1, 9) == "mushroom-" or string.sub(key, 1, 18) == "hub-gun-sideshroom")
	then
		return true
	end
	for _, word in GLOWING_PARTS do
		if string.find(part.Name, word, 1, true) then
			return false
		end
	end
	return true
end

-- One of the asset library's pieces (LobbyAssets), styled in the look pack and pivoted at the middle of its foot. Look
-- only: anchored, with no collision; it casts shadows as castsShadow says (the mushrooms' stems, owner, 2026-11-06: no
-- shadows to be seen). nil if it doesn't load.
local function libraryPiece(key: string, glow: number): Model?
	local lobby = require(ServerStorage:WaitForChild("LobbyAssets")) :: any
	local info = lobby.assets[key]
	local ok, container = pcall(function()
		return InsertService:LoadAsset(info.model)
	end)
	if not ok then
		warn(`HubArt: {key} failed to load: {container}`)
		workspace:SetAttribute("HubArtFailed", (workspace:GetAttribute("HubArtFailed") or 0) + 1)
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
	LookPack.styleModel(model, key, info.groups, ServerStorage:WaitForChild("LobbyMaterials"), glow)
	for _, part in model:GetDescendants() do
		if part:IsA("MeshPart") then
			part.Anchored = true
			part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
			part.CastShadow = castsShadow(key, part)
		end
	end
	local lo, hi = paintedBounds(model)
	-- Crystals keep the tip lights and twinkles they have in the look test (owner: the grove's had none).
	-- As there, scale to the concept's height, then measure the import's axis flip so each point lands on
	-- its tip; planting scales the effects with the crystal.
	if string.sub(key, 1, 9) == "crystals-" and hi.Y > lo.Y then
		model:ScaleTo(model:GetScale() * info.height / (hi.Y - lo.Y))
		lo, hi = paintedBounds(model)
		local centre = (lo + hi) / 2
		local scale = (hi.Y - lo.Y) / info.height
		local best, bestError = Vector3.one, math.huge
		for _, flip in
			{
				Vector3.new(1, 1, 1),
				Vector3.new(-1, 1, -1),
				Vector3.new(-1, 1, 1),
				Vector3.new(1, 1, -1),
			}
		do
			local err = 0
			for name, spec in info.groups do
				local part = model:FindFirstChild(name)
				if part and part:IsA("MeshPart") then
					err += ((part.Position - centre) - (spec.center - info.center) * flip * scale).Magnitude
				end
			end
			if err < bestError then
				best, bestError = flip, err
			end
		end
		LookPack.addEffects(model, info, lobby.fx, function(p: Vector3): Vector3
			return centre + (p - info.center) * best * scale
		end)
	end
	model.WorldPivot = CFrame.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)
	return model
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
		workspace:SetAttribute("HubArtFailed", (workspace:GetAttribute("HubArtFailed") or 0) + 1)
		return nil
	end
	local ok, container = pcall(function()
		return InsertService:LoadAsset(info.model)
	end)
	if not ok then
		warn(`HubArt: {key} failed to load: {container}`)
		workspace:SetAttribute("HubArtFailed", (workspace:GetAttribute("HubArtFailed") or 0) + 1)
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
	local capGlow = CAP_ONLY_GLOW[key]
	if capGlow then
		for _, part in model:GetDescendants() do
			local surface = part:FindFirstChild("SlugshotMaterial")
			if part:IsA("MeshPart") and part.Name == "Cap" and surface then
				(surface :: SurfaceAppearance).EmissiveStrength *= capGlow
			end
		end
	end
	for _, part in model:GetDescendants() do
		if part:IsA("MeshPart") then
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = castsShadow(key, part)
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
	local conceptSize, importedSize = conceptHi - conceptLo, hi - lo
	local scale = math.max(conceptSize.X, conceptSize.Y, conceptSize.Z)
		/ math.max(importedSize.X, importedSize.Y, importedSize.Z)
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

-- What is solid, exactly as drawn: players stand on it and wall-run it, and the camera stops at it because it is
-- visible and queryable. Ink, glow, water, lava pools, foliage and anything that moves stay passable.
local CLIFF = { "Cliff0", "Cliff1", "Cliff2", "Cliff3", "Cliff4", "Cliff5", "Cliff6", "Cliff7" }
local GATE, PORTAL = { "StoneA", "StoneB", "Lintel", "Key" }, { "Stone", "Iron" }
local SOLID: { [string]: { string } } = {
	["hub-rock"] = { "Top", "Upper", "Lower", "Cracks" },
	["hub-rock-dress"] = { "Roots" },
	["hub-gate-0"] = GATE,
	["hub-gate-1"] = GATE,
	["hub-gate-2"] = GATE,
	["hub-gate-3"] = GATE,
	["hub-cliff"] = CLIFF,
	["hub-portal-pvp"] = PORTAL,
	["hub-portal-training"] = PORTAL,
	["hub-portal-veylume"] = PORTAL,
	["hub-arch"] = { "Pylons", "ArchL", "ArchR", "Pillars", "Base" },
	["hub-plaza-floor"] = { "Floor" },
	["hub-volcano"] = { "Pool", "Flows", "VolcanoFront", "VolcanoBack" },
	["hub-grove-ground"] = { "Ground", "Bed" },
	["hub-grove-rocks"] = { "Stones", "Runes" },
	-- The shop's pods and trunk are solid, so its closed door can't be walked through; the cap stays passable.
	["hub-gun-shop"] = { "Pods", "Trunk" },
	-- The cavern wall, as high as anyone can reach; the block-out's wall stays behind it.
	["hub-cavern-00"] = { "Low", "Mid" },
	["hub-cavern-01"] = { "Low", "Mid" },
	["hub-cavern-02"] = { "Low", "Mid" },
	["hub-cavern-03"] = { "Low", "Mid" },
	["hub-cavern-04"] = { "Low", "Mid" },
	["hub-cavern-05"] = { "Low", "Mid" },
	["hub-cavern-06"] = { "Low", "Mid" },
	["hub-cavern-07"] = { "Low", "Mid" },
	["hub-cavern-08"] = { "Low", "Mid" },
	["hub-cavern-09"] = { "Low", "Mid" },
	["hub-cavern-10"] = { "Low", "Mid" },
	["hub-cavern-11"] = { "Low", "Mid" },
	["hub-far-ground"] = {
		"FloorNearL",
		"FloorNearM",
		"FloorNearR",
		"FloorMidL",
		"FloorMidM",
		"FloorMidR",
		"FloorFarL",
		"FloorFarM",
		"FloorFarR",
		"Rubble",
		"Pools",
		"Shards",
	},
	["hub-lantern-post"] = { "Post" },
	-- The cave mouth's frame (owner, 2026-11-06): its low slabs stand on the floor beside the mouth.
	["hub-mouth-slabs"] = { "LowL", "LowR", "HighL", "HighR", "Top" },
	-- The rocks beside the cobble path (owner, 2026-11-07), walked round.
	["hub-path-rocks"] = { "RocksL", "RocksR" },
}

-- Collision builds beside the art, a few at a time, so a server start isn't held up; the block-out holds the ground
-- until it finishes. Building them one by one took over a minute.
local solidQueue: { MeshPart } = {}
local function makeSolid(model: Model, key: string)
	local names = SOLID[key]
	if names or key == "hub-grove-solid" then
		for _, part in model:GetDescendants() do
			if part:IsA("MeshPart") and (not names or table.find(names, part.Name)) then
				table.insert(solidQueue, part)
			end
		end
	end
end

local function buildCollision(whenDone: () -> ())
	local started = os.clock()
	local remaining, failed = #solidQueue, 0
	local nextIndex = 1
	for _ = 1, 8 do
		task.spawn(function()
			while nextIndex <= #solidQueue do
				local part = solidQueue[nextIndex]
				nextIndex += 1
				local ok, shaped = pcall(function()
					return AssetService:CreateMeshPartAsync(Content.fromUri(part.MeshId), {
						CollisionFidelity = Enum.CollisionFidelity.PreciseConvexDecomposition,
						RenderFidelity = part.RenderFidelity,
					})
				end)
				if ok then
					part:ApplyMesh(shaped)
					shaped:Destroy()
					part.CanCollide = not part:HasTag("HubCameraOnly")
					part.CanQuery = true
				else
					failed += 1
					warn(`HubArt: {part:GetFullName()} stays passable: {shaped}`)
				end
				remaining -= 1
				if remaining == 0 then
					print(
						string.format(
							"HubArt: solid art built, %d parts, %d failed, %.1fs",
							#solidQueue,
							failed,
							os.clock() - started
						)
					)
					workspace:SetAttribute("HubSolidParts", #solidQueue)
					workspace:SetAttribute("HubSolidFailed", failed)
					workspace:SetAttribute(
						"HubArtFailed",
						workspace:GetAttribute("HubArtFailed") or 0
					)
					whenDone()
				end
			end
		end)
	end
end

local function place(key: string): Model?
	local model = loadPiece(key)
	if model then
		model.Parent = art
		makeSolid(model, key)
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

-- Lamps and glows light pools round them (owner, 2026-11-06: light from somewhere, not from nowhere). With less ambient
-- light and Future lighting, every placed light is brighter and reaches further than it was first set at.
local LIGHT_GAIN, LIGHT_REACH = 1.8, 1.5

local function pointLight(
	position: Vector3,
	color: Color3,
	brightness: number,
	range: number
): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness * LIGHT_GAIN
	light.Range = math.min(range * LIGHT_REACH, 60)
	light.Shadows = false
	light.Parent = holder("Light", position, Vector3.one)
	return light
end

-- A soft pool of coloured light on the rock round something that glows (owner, 2026-11-07: crystals high on the walls glowed
-- but lit nothing round them, and it should be smooth, not choppy or blocky): no shadows, so it falls off evenly over every
-- facet, and shadeLights leaves it as it is.
local function softGlow(
	position: Vector3,
	color: Color3,
	brightness: number,
	range: number
): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = math.min(range, 120)
	light.Shadows = false
	light:SetAttribute("Soft", true)
	light.Parent = holder("SoftGlow", position, Vector3.one)
	return light
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
-- Where a point stands round the hub, in the layout's degrees: 0 is PvP and 90 the slug side.
local function zoneAngle(at: Vector3): number
	return math.deg(math.atan2(at.X, -at.Z))
end

local function onSlugSide(at: Vector3): boolean
	local angle = zoneAngle(at)
	return angle >= 40 and angle <= 135
end

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
	-- So do the grove's pond and mountain. The overgrowth's sketched mushrooms went too, one of them reaching over the volcano's side.
	for _, name in { "SlugPond", "WaterfallMountain", "VeylumeOvergrowth" } do
		local old = root:FindFirstChild(name)
		if old then
			old:Destroy()
		end
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
		-- The cavern wall's art replaces the block-out's wall all round. The mountain's back passes through it from 52 to 128,
		-- where players can climb over; the art's wall stands back in an alcove there from 53 to 126 (owner, 2026-11-05), so
		-- the block-out's would be an invisible wall in front of it.
		for _, item in cavern:GetChildren() do
			if item:IsA("BasePart") and item.Name == "Wall" then
				local angle = zoneAngle(item.Position)
				item.Transparency = 1
				item.CanQuery = false
				if angle > 52 and angle < 128 then
					item.CanCollide = angle <= 53 or angle >= 126
				end
			end
		end
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
	local gunBlockOut = root:FindFirstChild("GunSide")
	if gunBlockOut then
		for _, item in gunBlockOut:GetDescendants() do
			if item:IsA("BasePart") then
				item.Transparency = 1
			elseif item:IsA("BillboardGui") then
				item.Enabled = false
			end
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
		local portalColor, growthColor = layout.zones[1].color, layout.overgrowth.color
		local portalGround = Color3.fromRGB(portalColor[1], portalColor[2], portalColor[3])
		local growthGround = Color3.fromRGB(growthColor[1], growthColor[2], growthColor[3])
		for _, item in shore:GetChildren() do
			if item:IsA("BasePart") and item.Name == "Surface" then
				local at = item.Position
				local angle = math.abs(math.deg(math.atan2(at.X, -at.Z)))
				-- The far side's art replaces its ground too, which also stays to walk on.
				if
					item.Color == portalGround
					or (item.Color == growthGround and angle < 39)
					or onSlugSide(at)
					or angle > 134
				then
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

-- The look of shader packs (owner, 2026-11-06: like Minecraft shaders, light from somewhere, scenic, everything popping;
-- docs/art/lobby-hub.md, round 7): real shadows, light pouring in through the one opening and nowhere else, lamps and glows
-- lighting the rock round them in their own colours with the air glowing round them, a wide soft bloom, and colour from the
-- lights rather than a grade that lifts or darkens anything.
local function lighting()
	LookPack.applyBase()
	-- Real shadows from every lamp and glow: their light stops at the rock instead of passing through it.
	Lighting.GlobalShadows = true
	-- As dark as the cavern. Roblox stops drawing far parts at lower graphics levels, and the bright default sky then
	-- showed through wherever the far wall dropped out (phones especially).
	local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	for _, face in { "SkyboxBk", "SkyboxDn", "SkyboxFt", "SkyboxLf", "SkyboxRt", "SkyboxUp" } do
		(sky :: any)[face] = fxTexture("cavernsky")
	end
	sky.CelestialBodiesShown = false
	sky.StarCount = 0
	sky.Parent = Lighting
	-- The storm's light from overhead, a little off straight down, with shadows (owner, 2026-11-07: too dark and gloomy
	-- everywhere; no shadows of the rocks above or of the character; no mist to be seen). The roof and walls are shells facing
	-- in, which Roblox's shadows don't take from behind, so it reaches every floor at every graphics level alike (round 7's
	-- flood at level 1 came from a cover shutting it out at full graphics only); what it adds is shadows under everything
	-- that stands in it, the rubble's on the island among them, and light for the mist, which Roblox lights by the sun (with
	-- none in round 7 and 8 the mist went black and out of sight). At latitude 12 it stands 11.5 degrees off overhead
	-- (measured), so the rubble's shadows land on the island and a character's falls just behind it.
	Lighting.ClockTime = 12
	Lighting.GeographicLatitude = 12
	Lighting.Brightness = 1.2
	Lighting.ColorShift_Top = Color3.fromRGB(175, 180, 255)
	Lighting.ShadowSoftness = 0.2
	-- Saturation only (owner, 2026-11-06: make everything pop). No contrast or brightness (owner, 2026-11-05: looking up lit
	-- the cavern up): Roblox's automatic graphics level falls on heavy views such as the ceiling and can drop post effects,
	-- and the old grade's contrast went with it, lifting every dark wall. Losing this only greys the colours a little.
	local grade = Lighting:FindFirstChild("SlugshotGrade") :: ColorCorrectionEffect?
	if grade then
		grade.Enabled = true
		grade.Brightness, grade.Contrast, grade.Saturation = 0, 0, 0.22
		grade.TintColor = Color3.new(1, 1, 1)
	end
	-- Little light from nowhere: dark blue-violet where no lamp reaches. The same indoors and out, as where Roblox reckons
	-- the sky shows changes with the graphics level. The darkness is in the light itself, so it holds at every level.
	Lighting.Ambient = Color3.fromRGB(82, 78, 110)
	Lighting.OutdoorAmbient = Color3.fromRGB(82, 78, 110)
	Lighting.EnvironmentDiffuseScale = 0.3
	Lighting.EnvironmentSpecularScale = 0.7
	Lighting.ExposureCompensation = 0
	-- A wide soft glow round everything that glows: lanterns, lava, crystals, caps and runes. Only what glows: at 0.9 a
	-- character lit by a lamp bloomed too and looked blurred (owner, 2026-11-06: the character too glowy).
	local bloom = Lighting:FindFirstChild("SlugshotBloom") :: BloomEffect?
	if bloom then
		bloom.Intensity, bloom.Size, bloom.Threshold = 1.3, 50, 1.15
	end
	-- A light violet mist through the whole cavern (owner, 2026-11-06; 2026-11-07: a small hint of it, visible, not
	-- overpowering, not the main feature as in the far cave): the far walls fade into it.
	local atmosphere = Lighting:FindFirstChild("SlugshotAtmosphere") :: Atmosphere?
	if atmosphere then
		atmosphere.Density = 0.32
		atmosphere.Haze = 2
		atmosphere.Color = Color3.fromRGB(118, 106, 178)
		atmosphere.Decay = Color3.fromRGB(62, 54, 112)
	end
end

-- Light where the eye goes (owner, 2026-11-07: walls, mountain and the ring round the storm too dark; walls well lit, the
-- mountain well visible): broad coloured washes up the cavern wall from its foot, the grove mountain lit from the grove and
-- the stone ring round the storm lit from below. The volcano and portals keep their colouring (owner); the plaza in front of
-- them is lit by the portals and the lava cracks (buildPortals, buildArch). No shadows from these: they reach far, and the
-- sun and the lamps carry the shadows.
local WASH_COLOURS = {
	Color3.fromRGB(150, 120, 255),
	Color3.fromRGB(90, 200, 230),
	Color3.fromRGB(120, 150, 255),
}
local function spotAt(
	name: string,
	from: Vector3,
	aim: Vector3,
	colour: Color3,
	brightness: number,
	angle: number,
	range: number
)
	local source = holder(name, from, Vector3.one)
	source.CFrame = CFrame.lookAt(from, aim)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Angle = angle
	light.Range = range
	light.Brightness = brightness
	light.Color = colour
	light.Shadows = false
	light:SetAttribute("Shadowed", false)
	light.Parent = source
	CollectionService:AddTag(light, "HubLamp")
end

local function sceneLights()
	-- Round the wall every 15 degrees, from the floor at its foot up its face; not across the cave's mouth, which has its own
	-- slabs lit below, nor behind the mountain, which is lit instead.
	local index = 0
	for degrees = 0, 345, 15 do
		local mouth = degrees >= 160 and degrees <= 200
		local mountain = degrees >= 60 and degrees <= 120
		if not mouth and not mountain then
			index += 1
			local a = math.rad(degrees)
			local out = Vector3.new(math.sin(a), 0, -math.cos(a))
			spotAt(
				"WallWash",
				out * 262 + Vector3.new(0, 4, 0),
				out * 300 + Vector3.new(0, 75, 0),
				WASH_COLOURS[index % 3 + 1],
				1.5,
				80,
				120
			)
		end
	end
	-- The wall's upper half and the roof's underside, which those can't reach (owner, 2026-11-07: the lower wall lit nicely,
	-- the upper area too dark; the whole top of the map too dark). The wall stands at about 295 studs out up to 150, then the
	-- roof curves in to about 200 studs out at 235 (measured from its meshes). Two more rings: one from 95 studs up lighting
	-- the wall from 105 to 165, over the mouth and the edges of the mountain's alcove too; one from 168, close under the
	-- roof, lighting its underside, over the mountain too. Brighter than the foot's, as the mist dims what is high and far.
	index = 0
	for degrees = 0, 345, 15 do
		if degrees >= 75 and degrees <= 105 then
			continue
		end
		index += 1
		local a = math.rad(degrees + 7.5)
		local out = Vector3.new(math.sin(a), 0, -math.cos(a))
		spotAt(
			"WallWashHigh",
			out * 250 + Vector3.new(0, 95, 0),
			out * 300 + Vector3.new(0, 165, 0),
			WASH_COLOURS[(index + 1) % 3 + 1],
			2.4,
			80,
			120
		)
	end
	index = 0
	for degrees = 0, 340, 20 do
		index += 1
		local a = math.rad(degrees)
		local out = Vector3.new(math.sin(a), 0, -math.cos(a))
		spotAt(
			"RoofWash",
			out * 240 + Vector3.new(0, 168, 0),
			out * 272 + Vector3.new(0, 218, 0),
			WASH_COLOURS[(index + 2) % 3 + 1],
			2.6,
			95,
			100
		)
	end
	-- The mouth's slabs, from either side of the path.
	for _, side in { -1, 1 } do
		spotAt(
			"MouthWash",
			Vector3.new(side * 60, 6, 235),
			Vector3.new(side * 40, 110, 290),
			Color3.fromRGB(170, 150, 255),
			1.6,
			75,
			120
		)
	end
	-- The grove mountain, from the grove in front of it: its faces, ledges and peaks.
	for _, at in
		{ { 175, 8, -70, 285, 70, -30 }, { 175, 8, 70, 285, 70, 40 }, { 205, 30, 0, 300, 120, 0 } }
	do
		spotAt(
			"MountainWash",
			Vector3.new(at[1], at[2], at[3]),
			Vector3.new(at[4], at[5], at[6]),
			Color3.fromRGB(120, 230, 200),
			1.6,
			70,
			120
		)
	end
	-- Its peaks (owner, 2026-11-07: the top of the mountain darker): the summit stands at (299, 165, 0), 164 studs from the
	-- washes in the grove, past a light's 120-stud reach. Two more from in front of it, within reach of every peak.
	for _, z in { -32, 32 } do
		spotAt(
			"PeakWash",
			Vector3.new(225, 105, z),
			Vector3.new(300, 150, z * 0.4),
			Color3.fromRGB(120, 230, 200),
			1.5,
			75,
			120
		)
	end
	-- The alcove's wall above and behind the mountain, which the washes round the foot leave out. Within reach of it
	-- (lights reach 120 studs); without shadows, a light inside the mountain's peaks still lights the wall.
	for _, z in { -55, 55 } do
		spotAt(
			"AlcoveWash",
			Vector3.new(320, 175, z),
			Vector3.new(400, 190, z * 1.6),
			Color3.fromRGB(140, 130, 255),
			1.6,
			80,
			120
		)
	end
	-- The alcove's back wall above the mountain and its ceiling (owner, 2026-11-07: from the island the lighting only
	-- lasts half the screen). Between 60 and 120 degrees the wall stands about 400 studs out, a hundred behind the rest, up
	-- to 180, under a ceiling from 250 to 410 studs out (measured from its meshes); the rings round the wall pass in front
	-- of it and the alcove's two washes light its sides. A light inside the mountain's back still lights the wall.
	for k, degrees in { 68, 84, 100, 116 } do
		local a = math.rad(degrees)
		local out = Vector3.new(math.sin(a), 0, -math.cos(a))
		local colour = WASH_COLOURS[k % 3 + 1]
		spotAt(
			"AlcoveBack",
			out * 330 + Vector3.new(0, 135, 0),
			out * 405 + Vector3.new(0, 175, 0),
			colour,
			2.4,
			85,
			120
		)
		spotAt(
			"AlcoveRoof",
			out * 320 + Vector3.new(0, 170, 0),
			out * 345 + Vector3.new(0, 235, 0),
			colour,
			2.4,
			90,
			100
		)
	end
	-- The stone ring round the storm, from below.
	for k = 0, 7 do
		local a = k * math.pi / 4 + 0.2
		local at = Vector3.new(math.cos(a) * 135, 150, math.sin(a) * 135)
		spotAt(
			"RingWash",
			at,
			at + Vector3.new(math.cos(a) * 25, 100, math.sin(a) * 25),
			Color3.fromRGB(185, 175, 255),
			1.8,
			100,
			110
		)
	end
	-- The storm, from inside its funnel below the clouds (owner, 2026-11-07: even the storm very dark). With its own glow
	-- raised (HubMotion's STORM_GLOW), this lights the clouds' undersides so their swirl reads.
	for k = 0, 3 do
		local a = k * math.pi / 2 + 0.6
		local at = Vector3.new(math.cos(a) * 45, 175, math.sin(a) * 45)
		spotAt(
			"StormWash",
			at,
			Vector3.new(-math.cos(a) * 25, 260, -math.sin(a) * 25),
			Color3.fromRGB(175, 160, 255),
			1.3,
			100,
			110
		)
	end
end

-- Every lamp and glow, once placed: warm ones brighter still, all casting shadows, and the air round each glowing in its
-- colour as the mist would scatter it. Low detail drops the glow and the lamps' shadows (HubMotion). Not too bright up
-- close (owner, 2026-11-06: a character walking past a lamp lit up until it looked blurred): 1.3 and 1.2 times, from 1.6
-- and 1.4, and the glow drawn behind whatever stands at the lamp, so it surrounds a character instead of covering it.
local function shadeLights()
	local halos = Instance.new("Folder")
	halos.Name = "Halos"
	halos.Parent = art
	for _, light in art:GetDescendants() do
		if not light:IsA("PointLight") or light:GetAttribute("Soft") then
			continue
		end
		local warm = light.Color.R > light.Color.G + 0.2
		light.Brightness *= if warm then 1.3 else 1.2
		light.Shadows = true
		CollectionService:AddTag(light, "HubLamp")
		local at = light.Parent
		if light.Range >= 12 and at and (at:IsA("BasePart") or at:IsA("Attachment")) then
			local position = if at:IsA("BasePart")
				then at.Position
				else (at :: Attachment).WorldPosition
			local glow = holder("Halo", position, Vector3.one)
			glow.Parent = halos
			local e = Instance.new("ParticleEmitter")
			e.Texture = fxTexture("flash")
			e.Color = ColorSequence.new(light.Color)
			e.LightEmission = 1
			e.LightInfluence = 0
			e.Size = NumberSequence.new(light.Range * 0.75)
			local strength = if warm then 0.84 else 0.9
			e.Transparency = fade({ { 0, 1 }, { 0.3, strength }, { 0.7, strength }, { 1, 1 } })
			e.Lifetime = NumberRange.new(5, 6)
			e.Rate = 0.5
			e.Speed = NumberRange.new(0)
			e.Rotation = NumberRange.new(0, 360)
			e.ZOffset = -light.Range * 0.45
			e.Parent = glow
			CollectionService:AddTag(e, "HubHalo")
		end
	end
end

-- A star twinkle at each crystal's tip (look-pack.md), scaled to how far away they're seen.
local function addTwinkles(key: string, size: number, drop: number?)
	for index, point in private.assets[key].points do
		local source =
			holder("Twinkle", point.p - Vector3.new(0, drop or 0, 0), Vector3.one * size * 0.4)
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
	-- Its old crystals' twinkles went with them (owner, 2026-11-07: old designs); the approved ones under the rock are
	-- far_side.json's.
	place("hub-rock-dress")
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
-- The bridge's three hanging lanterns' cores, in its own studs (the library's lanternAt: 2.55 studs a unit, x along the
-- bridge, its rails' sag from railY).
local BRIDGE_LANTERNS = {
	Vector3.new(-13.77, -0.23, 6.04),
	Vector3.new(1.79, -1.21, -6.04),
	Vector3.new(14.28, -0.16, 6.04),
}
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
		for _, part in bridge:GetDescendants() do
			if part:IsA("MeshPart") and part.Name == "Deck" then
				part:AddTag("HubCameraOnly")
				table.insert(solidQueue, part)
			end
		end
		bridge.Name = `Bridge{dir}`
		bridge:PivotTo(frame * bridge:GetPivot())
		bridge:SetAttribute("Frame", frame)
		bridge.Parent = art
		CollectionService:AddTag(bridge, "HubBridge")
		-- Each hanging lantern lights the planks and ropes round it, as the path's lanterns do (owner, 2026-11-07: the
		-- bridges' lanterns didn't glow like those).
		for _, core in BRIDGE_LANTERNS do
			pointLight(frame * core, Color3.fromRGB(255, 168, 86), 0.7, 17)
		end
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
	-- It spreads a little as it falls; narrowing made a tapered pipe.
	b.Width0, b.Width1 = width, width * 1.25
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
	-- A little see-through, more at the sheet's two edges, melting into the foam at the foot.
	local melt = fade({ { 0, 0.05 }, { 0.5, 0.18 }, { 0.82, 0.25 }, { 1, 1 } })
	local edge = fade({ { 0, 0.3 }, { 0.5, 0.45 }, { 0.8, 0.55 }, { 1, 1 } })
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
			if math.abs(side) >= 40 then edge else melt,
			46,
			0.42 + index * 0.015,
			0
		)
		-- Faster, brighter bands over the top, so it never reads as one solid surface.
		if index % 2 == 0 then
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
	-- Spray where it tips over the lip, so the top reads as water going over an edge.
	local lipAt = centre + inward * (radius + 0.5) + Vector3.new(0, BASIN_Y * UNIT + 1, 0)
	local lip = holder("FallLip", lipAt, Vector3.new(10, 0.5, 1.5))
	lip.CFrame = CFrame.lookAt(lipAt, lipAt + inward)
	local spray = Instance.new("ParticleEmitter")
	spray.Name = "Spray"
	spray.Texture = fxTexture("mist")
	spray.EmissionDirection = Enum.NormalId.Front
	spray.Color = ColorSequence.new(Color3.fromRGB(215, 255, 250))
	spray.LightEmission = 0.4
	spray.LightInfluence = 0
	spray.Size = NumberSequence.new(1.6, 4.5)
	spray.Transparency = fade({ { 0, 1 }, { 0.15, 0.45 }, { 1, 1 } })
	spray.Lifetime = NumberRange.new(0.6, 1.1)
	spray.Rate = 9
	spray.Speed = NumberRange.new(2.5, 4.5)
	spray.SpreadAngle = Vector2.new(25, 35)
	spray.Acceleration = Vector3.new(0, -9, 0)
	spray.Parent = lip
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

-- The owner lowered the ceiling from where the concept has it, and everything fixed to it comes down too.
local CEILING_DROP = 250 - layout.cavern.ceilingY

local function placeUnderCeiling(key: string): Model?
	local model = place(key)
	if model then
		model:PivotTo(model:GetPivot() - Vector3.new(0, CEILING_DROP, 0))
	end
	return model
end

local function buildSkyWell()
	placeUnderCeiling("hub-well-rock")
	-- The opening's own crystals, the ceiling's, and the vines of the inner circle are gone (owner, 2026-11-05: packed,
	-- unlit, not our designs; the old ceiling's poked through the roof's ring; no vines there). A ring of the library's
	-- crystals hangs round the storm instead (far_side.json), and the green vines went to the walls.
	local isles = placeUnderCeiling("hub-well-isles")
	if isles then
		for index = 0, 4 do
			setMotion(isles, `Isle{index}`, -ORBIT, 6, ORBIT * (4 + index), index * 1.0)
		end
	end
	local bits = placeUnderCeiling("hub-well-bits")
	if bits then
		for index = 0, 5 do
			local spin = if index < 3 then -ORBIT * 2 else -ORBIT
			setMotion(bits, `Bits{index}`, spin, 6, ORBIT * (4 + index % 3 * 2), index * 1.9)
		end
	end
	local storm = placeUnderCeiling("hub-storm")
	if storm then
		-- One swirl: its body, and a thin veil of cloud turning a little faster over it for depth.
		local sheets: { [string]: number } = { StormBody = 1.8, StormVeil = 2.4 }
		for name, rate in sheets do
			setMotion(storm, name, ORBIT * rate, 0, 0, 0)
			local sheet = storm:FindFirstChild(name, true)
			local surface = sheet and sheet:FindFirstChildWhichIsA("SurfaceAppearance")
			if surface then
				CollectionService:AddTag(surface, "HubStormCloud")
			end
		end
	end
	-- Light falling from the mouth, spreading and fading with no edge: a few soft camera-facing sheets, strong enough to
	-- read as the storm's light in the mist (owner, 2026-11-06: shader-style light).
	for index = 0, 3 do
		local angle = index * math.pi / 2 + 0.4
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * 16
		beam(
			"LightShaft",
			offset + Vector3.new(0, 262 - CEILING_DROP, 0),
			offset * 2.4 + Vector3.new(0, 18, 0),
			80,
			170,
			fxTexture("softbeam"),
			Color3.fromRGB(150, 190, 225),
			fade({ { 0, 1 }, { 0.2, 0.66 }, { 0.6, 0.8 }, { 1, 1 } }),
			0,
			1
		)
	end
	-- A soft round glow well under the storm. A sprite that crosses the storm's surface is cut along it, which read as
	-- a box in the sky (owner), so none may reach it.
	local mouth = holder("MouthGlow", Vector3.new(0, 118 - CEILING_DROP, 0), Vector3.one)
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
	-- Diffuse lightning inside the storm: cloud illumination and a soft bloom only.
	local flash = holder("StormFlash", Vector3.new(0, 300 - CEILING_DROP, 0), Vector3.one)
	-- A wide, faint glow dissipates without drawing a solid bolt silhouette.
	local bloom = Instance.new("ParticleEmitter")
	bloom.Name = "Bloom"
	bloom.Texture = fxTexture("flash")
	bloom.Color = ColorSequence.new(Color3.fromRGB(190, 180, 255))
	bloom.LightEmission = 1
	bloom.LightInfluence = 0
	bloom.Size = NumberSequence.new(80, 100)
	bloom.Transparency = fade({ { 0, 1 }, { 0.15, 0.62 }, { 0.5, 0.8 }, { 1, 1 } })
	bloom.Lifetime = NumberRange.new(1.2, 1.6)
	bloom.Rate = 0
	bloom.Speed = NumberRange.new(0)
	bloom.Parent = flash
	-- The veil's height at the middle of the storm, for placing blooms below it.
	flash:SetAttribute("VeilY", 256 - CEILING_DROP)
end

local function buildPortals()
	local glow = {
		PvP = { key = "hub-portal-pvp", scale = 2.5, color = Color3.fromRGB(255, 158, 64) },
		Training = {
			key = "hub-portal-training",
			scale = 1.6,
			color = Color3.fromRGB(107, 255, 115),
		},
		Veylume = { key = "hub-portal-veylume", scale = 1.6, color = Color3.fromRGB(199, 128, 255) },
	} :: { [string]: { key: string, scale: number, color: Color3 } }
	for _, entry in layout.portals do
		local spec = glow[entry.name]
		local model = place(spec.key)
		if model then
			local rad = math.rad(entry.angle)
			local base =
				Vector3.new(entry.radius * math.sin(rad), entry.rise, -entry.radius * math.cos(rad))
			local frame = CFrame.lookAt(base, Vector3.new(0, base.Y, 0))
			model:PivotTo(frame * model:GetPivot())
			pointLight(
				base + frame.LookVector * 4 + Vector3.new(0, 5 * spec.scale, 0),
				spec.color,
				1.4,
				11 * spec.scale
			)
			-- Its colour spilling onto the plaza in front of it (owner, 2026-11-07: the area in front of the portals too dark;
			-- then a little too glowy, from 0.9).
			spotAt(
				"PortalSpill",
				base + frame.LookVector * 3 + Vector3.new(0, 9 * spec.scale, 0),
				base + frame.LookVector * 40,
				spec.color,
				0.7,
				80,
				70
			)
			-- The opening's true width: the middle one of the sheet's thickness, width and height.
			local energy = model:FindFirstChild("Energy", true) :: MeshPart
			local sizes = { energy.Size.X, energy.Size.Y, energy.Size.Z }
			table.sort(sizes)
			local across = sizes[2]
			local middle = energy.Position
			-- A solid colour with an exact glow. Neon glowed by itself, but it renders so far past full brightness that
			-- nothing drawn over it shows, so it couldn't carry a swirl.
			local field = energy:FindFirstChildOfClass("SurfaceAppearance")
			if field then
				field.EmissiveStrength = 2.4
			end
			energy:SetAttribute("PulseRate", 0.35)
			energy:SetAttribute("PulseDepth", 0.08)
			energy:SetAttribute("Phase", entry.angle)
			CollectionService:AddTag(energy, "HubPulse")
			local bright = spec.color:Lerp(Color3.new(1, 1, 1), 0.3)
			for _, side in { 1, -1 } do
				local face = CFrame.lookAt(middle, middle + frame.LookVector * side)
				local surface = holder(`PortalSurface{side}`, middle, Vector3.new(0.2, 0.2, 0.2))
				surface.CFrame = face + face.LookVector * 0.5
				-- Flat on the surface and adding light. Each fades out as the next fades in, and a new one starts exactly
				-- as the last has turned by one arm (120 degrees), so together they read as one swirl turning steadily,
				-- with nothing appearing or vanishing.
				local function layer(
					name: string,
					texture: string,
					size: number,
					strength: number,
					turn: number
				)
					local period = if turn > 0 then 120 / turn else 6
					local e = Instance.new("ParticleEmitter")
					e.Name = name
					e.Texture = fxTexture(texture)
					e.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
					e.EmissionDirection = Enum.NormalId.Front
					e.Speed = NumberRange.new(0.02)
					e.LightEmission = 1
					e.LightInfluence = 0
					e.Color = ColorSequence.new(spec.color)
					e.Size = NumberSequence.new(size * across)
					e.Transparency = fade({ { 0, 1 }, { 0.5, 1 - strength }, { 1, 1 } })
					e.Lifetime = NumberRange.new(period * 2)
					e.Rate = 0 -- HubMotion emits on the beat, and starts it already mid-turn
					e.Rotation = NumberRange.new(0)
					e.RotSpeed = NumberRange.new(turn)
					e:SetAttribute("SwirlPeriod", period)
					e.Parent = surface
					-- One already at its brightest and fading, so the join looks like any other moment of the cycle.
					local start = e:Clone()
					start.Name = name .. "Start"
					start.Lifetime = NumberRange.new(period)
					start.Transparency = fade({ { 0, 1 - strength }, { 1, 1 } })
					start.Parent = surface
					CollectionService:AddTag(e, "HubPortalSwirl")
					if side < 0 then
						CollectionService:AddTag(e, "HubSpareTwinkle")
					end
				end
				layer("SwirlWide", "swirl", 1.05, 0.22, 12)
				layer("SwirlDrift", "swirl", 0.9, 0.12, 16)
			end
			-- Sparks flying off the energy and floating up.
			local source =
				holder("PortalEmbers", middle, Vector3.new(across * 0.8, across * 1.1, 0.5))
			source.CFrame = CFrame.lookAt(middle, middle + frame.LookVector)
				+ frame.LookVector * 0.8
			local embers = Instance.new("ParticleEmitter")
			embers.Texture = fxTexture("spore")
			embers.Color = ColorSequence.new(bright)
			embers.LightEmission = 1
			embers.LightInfluence = 0
			embers.Brightness = 1.6
			embers.Size = NumberSequence.new(0.7, 0.12)
			embers.Transparency = fade({ { 0, 1 }, { 0.15, 0 }, { 1, 1 } })
			embers.Lifetime = NumberRange.new(5, 8)
			embers.Rate = 4
			embers.Speed = NumberRange.new(0.4, 1)
			embers.SpreadAngle = Vector2.new(35, 35)
			embers.Acceleration = Vector3.new(0, 0.3, 0)
			embers.EmissionDirection = Enum.NormalId.Front
			embers.Shape = Enum.ParticleEmitterShape.Box
			embers.Parent = source
		end
	end
end

-- The portal side: Titan's Arch, with Codex's Ember Crown volcano behind it. These were modelled facing away from the hub.
local PLAZA = CFrame.new(0, 0, -157) * CFrame.Angles(0, math.pi, 0)
local VOLCANO_Z = 111 -- studs behind the plaza's origin
local VOLCANO_SCALE = 1.15
-- Lava gloop layers: tile size in studs across and along the flow, and speed in studs a second (the waterfall runs at
-- about 19, so this is a slow ooze). Textures from tools/lobby/hub_mesh.py fx. Warm streaks only: dark crust plates
-- cut the lava up with black lines (owner, 2026-11-03), and strong contrast showed the joins between projections.
local LAVA_GLOOP = {
	{
		name = "Skin",
		image = "lavaskin",
		colour = Color3.fromRGB(200, 72, 12),
		transparency = 0.35,
		across = 14,
		along = 26,
		speed = 2.2,
	},
	{
		name = "Swell",
		image = "lavaskin",
		colour = Color3.fromRGB(235, 110, 20),
		transparency = 0.55,
		across = 30,
		along = 54,
		speed = 1.3,
	},
}
-- Every side the streams face, and the top for where they flatten out at the foot.
local GLOOP_FACES = {
	Enum.NormalId.Front,
	Enum.NormalId.Back,
	Enum.NormalId.Left,
	Enum.NormalId.Right,
	Enum.NormalId.Top,
}
local PLAZA_HEIGHT = 0.85 -- the volcano and the gate stand this share of their modelled height (owner: too near the ceiling)

-- Squashes a piece toward the ground, keeping its width.
local function shorten(model: Model)
	for _, part in model:GetDescendants() do
		if part:IsA("MeshPart") then
			local at = part.Position
			part.Size = Vector3.new(part.Size.X, part.Size.Y * PLAZA_HEIGHT, part.Size.Z)
			part.Position = Vector3.new(at.X, at.Y * PLAZA_HEIGHT, at.Z)
		end
	end
end

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

local function volcWall(a: number, y: number, offset: number): Vector3
	local cx, cz = volcCentre(y)
	local r = volcRadius(a, y) + offset
	return PLAZA
		* Vector3.new(
			(cx + math.cos(a) * r) * VOLCANO_SCALE,
			y * VOLCANO_SCALE * PLAZA_HEIGHT,
			(cz + math.sin(a) * r) * VOLCANO_SCALE + VOLCANO_Z
		)
end

local function buildVolcano()
	local volcano = placeInPlaza("hub-volcano")
	if volcano then
		shorten(volcano)
		-- Retain the crater pool's original slow glow; downhill lava keeps its authored material.
		for _, part in volcano:GetDescendants() do
			if part:IsA("MeshPart") and part.Name == "Pool" then
				part:SetAttribute("PulseRate", 0.55)
				part:SetAttribute("PulseDepth", 0.32)
				CollectionService:AddTag(part, "HubPulse")
			end
		end
		-- The slow gloop (owner, 2026-11-03: like the waterfall, slower, part of the lava, not on top of it). Textures on
		-- the lava's own part are drawn on its surface, projected from each side, so they follow every stream exactly and
		-- slide straight down it. They can't glow, so they are what cools on molten rock: long dark wrinkles and rafts of
		-- crust with glowing cracks, the crust slower than the skin under it. HubMotion.client scrolls them.
		local flows = volcano:FindFirstChild("Flows", true)
		if flows and flows:IsA("MeshPart") then
			for _, layer in LAVA_GLOOP do
				for _, face in GLOOP_FACES do
					local texture = Instance.new("Texture")
					texture.Name = `Gloop{layer.name}`
					texture.Face = face
					texture.Texture = fxTexture(layer.image)
					texture.Color3 = layer.colour
					texture.Transparency = layer.transparency
					texture.StudsPerTileU, texture.StudsPerTileV = layer.across, layer.along
					-- Seen from above, the texture runs the other way, so it still flows toward the plaza.
					texture:SetAttribute(
						"Speed",
						if face == Enum.NormalId.Top then -layer.speed else layer.speed
					)
					texture.Parent = flows
					CollectionService:AddTag(texture, "HubLavaGloop")
				end
			end
		end
	end
	-- Original crater-pool glints; no flow overlay is added to the downhill lava.
	for k = 0, 6 do
		local angle = -1.18 + k * 0.897598
		local from = volcWall(angle, 128.6, 5 - volcRadius(angle, 128))
		local to = volcWall(angle, 128.6, 0)
		local direction = (to - from).Unit
		local tangent = direction:Cross(Vector3.yAxis).Unit
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		local turn = CFrame.fromMatrix(Vector3.zero, direction, tangent, direction:Cross(tangent))
		a0.CFrame, a1.CFrame = turn, turn
		a0.Parent = holder("PoolGlint", from, Vector3.one)
		a1.Parent = holder("PoolGlint", to, Vector3.one)
		local glint = Instance.new("Beam")
		glint.Attachment0, glint.Attachment1 = a0, a1
		glint.FaceCamera = false
		glint.Segments = 1
		glint.Width0, glint.Width1 = 6, 13 * VOLCANO_SCALE
		glint.Texture = fxTexture("lavaflow")
		glint.TextureLength = 1
		glint.TextureMode = Enum.TextureMode.Stretch
		glint.TextureSpeed = 0.11
		glint.LightEmission = 1
		glint.LightInfluence = 0
		glint.Transparency = fade({ { 0, 1 }, { 0.4, 0.3 }, { 0.85, 0.3 }, { 1, 1 } })
		glint.Parent = a0.Parent
	end
	-- The crater: what erupts is run by HubMotion.client.
	local cx, cz = volcCentre(130)
	local top = PLAZA
		* Vector3.new(cx * VOLCANO_SCALE, 147 * PLAZA_HEIGHT, cz * VOLCANO_SCALE + VOLCANO_Z)
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
	plume.Color = ColorSequence.new(Color3.fromRGB(205, 205, 208), Color3.fromRGB(165, 165, 170))
	plume.LightEmission = 0.1
	plume.Size = fade({ { 0, 16 }, { 1, 58 } })
	plume.Transparency = fade({ { 0, 1 }, { 0.2, 0.62 }, { 1, 1 } })
	plume.Lifetime = NumberRange.new(9, 13)
	plume.Rate = 1.9
	plume:SetAttribute("HighRate", 1.9)
	plume.Speed = NumberRange.new(7, 11)
	plume.SpreadAngle = Vector2.new(10, 10)
	CollectionService:AddTag(plume, "HubMist")
	-- Slow and wide, so it hangs around the crater: rising straight up, the ceiling hid it from the spawn rock.
	local steam = emitter("SteamLight")
	steam.Texture = fxTexture("mist")
	steam.Color = ColorSequence.new(Color3.fromRGB(232, 232, 235), Color3.fromRGB(178, 178, 184))
	steam.LightEmission = 0.05
	steam.Size = fade({ { 0, 20 }, { 1, 85 } })
	steam.Transparency = fade({ { 0, 1 }, { 0.12, 1 }, { 0.3, 0.68 }, { 1, 1 } })
	steam.Lifetime = NumberRange.new(12, 18)
	steam.Rate = 3.8
	steam:SetAttribute("HighRate", 3.8)
	steam.Speed = NumberRange.new(4, 8)
	steam.SpreadAngle = Vector2.new(38, 38)
	CollectionService:AddTag(steam, "HubMist")
	local smoke = emitter("SteamGrey")
	smoke.Texture = fxTexture("mist")
	smoke.Color = ColorSequence.new(Color3.fromRGB(198, 198, 203), Color3.fromRGB(150, 150, 156))
	smoke.Size = fade({ { 0, 24 }, { 1, 95 } })
	smoke.Transparency = fade({ { 0, 1 }, { 0.3, 1 }, { 0.5, 0.72 }, { 1, 1 } })
	smoke.Lifetime = NumberRange.new(12, 18)
	smoke.Rate = 3.2
	smoke:SetAttribute("HighRate", 3.2)
	smoke.Speed = NumberRange.new(3, 6)
	smoke.SpreadAngle = Vector2.new(30, 30)
	CollectionService:AddTag(smoke, "HubMist")
	pointLight(top + Vector3.new(0, 6, 0), Color3.fromRGB(255, 120, 50), 1.2, 45)
	-- Over the volcano no crags hang (owner, 2026-11-05), and the roof looked blank there (owner, 2026-11-06): the lava lights
	-- it from below, warm and slowly breathing with the crater's pool, round the ring of warm crystals hanging from it
	-- (far_side.json), and the smoke spreads out flat under it.
	for k = 0, 2 do
		local a = k * math.pi * 2 / 3 + 0.5
		local glow = pointLight(
			Vector3.new(top.X + math.cos(a) * 30, 192, top.Z + math.sin(a) * 30),
			Color3.fromRGB(255, 104, 36),
			1.4,
			40
		)
		glow:SetAttribute("PulseRate", 0.55)
		glow:SetAttribute("PulseDepth", 0.25)
		glow:SetAttribute("Phase", k * 0.7)
		CollectionService:AddTag(glow, "HubPulse")
	end
	local pall = holder("SmokePall", Vector3.new(top.X, 214, top.Z), Vector3.new(70, 6, 70))
	local spread = Instance.new("ParticleEmitter")
	spread.Name = "Pall"
	spread.Texture = fxTexture("mist")
	spread.Color = ColorSequence.new(Color3.fromRGB(122, 74, 58), Color3.fromRGB(66, 52, 66))
	spread.LightEmission = 0.15
	spread.LightInfluence = 0.4
	spread.Size = fade({ { 0, 36 }, { 1, 80 } })
	spread.Transparency = fade({ { 0, 1 }, { 0.25, 0.78 }, { 0.7, 0.82 }, { 1, 1 } })
	spread.Lifetime = NumberRange.new(16, 22)
	spread.Rate = 0.9
	spread:SetAttribute("HighRate", 0.9)
	spread.Speed = NumberRange.new(1.5, 3)
	spread.SpreadAngle = Vector2.new(180, 6)
	spread.EmissionDirection = Enum.NormalId.Right
	spread.Rotation = NumberRange.new(0, 360)
	spread.RotSpeed = NumberRange.new(-4, 4)
	spread.Shape = Enum.ParticleEmitterShape.Box
	spread.Parent = pall
	CollectionService:AddTag(spread, "HubMist")
end

local function buildArch()
	local floor = placeInPlaza("hub-plaza-floor")
	if floor then
		floor:PivotTo(floor:GetPivot() + Vector3.new(0, 0.08, 0))
	end
	if floor then
		local lava = floor:FindFirstChild("Lava", true)
		if lava then
			lava:SetAttribute("PulseRate", 0.55)
			lava:SetAttribute("PulseDepth", 0.25)
			CollectionService:AddTag(lava, "HubPulse")
		end
	end
	-- A slight glow standing over the cracks, in plaza units. Each stops at the pit's edge.
	for index, crack in
		{
			{ 3.0, -3.8, 13.0, -14.0, 0.42, 0.04 },
			{ 1.2, -3.8, 3.87, -11.36, 0.42, 0.15 },
			{ 8.0, -8.8, 14.0, -7.0, 0.2, 0.03 },
			{ 3.4, -9.0, 2.3, -11.1, 0.18, 0.1 },
			{ 5.0, -3.0, 16.5, -3.6, 0.34, 0.05 },
		}
	do
		for _, side in { -1, 1 } do
			local halo = beam(
				"CrackGlow",
				PLAZA * Vector3.new(side * crack[1] * 5, 1, crack[2] * 5),
				PLAZA * Vector3.new(side * crack[3] * 5, 1, crack[4] * 5),
				math.max(crack[5] * 26, 3),
				math.max(crack[6] * 26, 3),
				fxTexture("softbeam"),
				Color3.fromRGB(255, 96, 24),
				fade({ { 0, 1 }, { 0.5, 0.75 }, { 1, 1 } }),
				0,
				1
			)
			halo:SetAttribute("Phase", index * 1.9)
			CollectionService:AddTag(halo, "HubLavaGlow")
			-- A warm pool on the plaza round each crack (owner, 2026-11-07: the area in front of the portals too dark; then a
			-- little too glowy to the eye): soft, without a lamp's glow in the air over it, a quarter less light.
			local from = PLAZA * Vector3.new(side * crack[1] * 5, 1, crack[2] * 5)
			local to = PLAZA * Vector3.new(side * crack[3] * 5, 1, crack[4] * 5)
			softGlow((from + to) / 2 + Vector3.new(0, 4, 0), Color3.fromRGB(255, 110, 40), 0.6, 30)
		end
	end
	local arch = placeInPlaza("hub-arch")
	if arch then
		shorten(arch)
		setMotion(arch, "ArchBits", 0, 1.3, 0.55, 0)
		-- The runes carved on the arch's stones and round its pillars light the stone round them, as the other runes do
		-- (owner, 2026-11-07). In the concept's units (5 studs): the stones' centres on the arch (radius 21 from its
		-- springing at 12), four on one side and three on the other, just in front of their faces toward the hub; and two
		-- round each pillar's front, either side of its molten slot.
		local runeGlow = Color3.fromRGB(255, 140, 50)
		local function archGlow(x: number, y: number, z: number, range: number)
			-- 1.15, from 1.4 (owner, 2026-11-07: the area in front of the portals a little too glowy).
			softGlow(PLAZA * Vector3.new(x * 5, y * 5 * PLAZA_HEIGHT, z * 5), runeGlow, 1.15, range)
		end
		for _, side in { -1, 1 } do
			local last = if side < 0 then 3 else 2
			for k = 0, last do
				local mid = (k + 0.5) * math.pi / 14
				archGlow(side * 21 * math.cos(mid), 12 + 21 * math.sin(mid), -3.2, 32)
			end
			for _, turn in { -0.9, 0.9 } do
				local a = -math.pi / 2 + turn
				archGlow(side * 21 + math.cos(a) * 5.5, 6.5, 0.8 + math.sin(a) * 5.5, 26)
			end
		end
	end
	-- The pylons' tops stay bare (owner, 2026-11-04: the crystals there, like the fires before them, didn't suit them).
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
-- The hidden block-out shapes the solid art replaces, so nothing invisible stands proud of it.
-- The slug side: Slug Grove (docs/art/lobby-hub.md). Its concept's space is shader units, with the pond at the origin, +Z
-- toward the wall and the hub behind -Z.
local GROVE = CFrame.new(layout.pond.radius, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
local GROVE_KEYS = {
	"hub-grove-ground",
	"hub-grove-mountain",
	"hub-grove-solid",
	"hub-grove-water",
	"hub-grove-falls",
	"hub-grove-rocks",
	"hub-grove-dress",
}
local GROVE_FOOT = Vector3.new(0.4, 0.1, 8.4)
local GROVE_TINT = Color3.fromRGB(150, 245, 225)
-- Shared outside-gun size (owner, 2026-11-03).
local SLUG_STUDS = (require :: any)(ReplicatedStorage:WaitForChild("Combat")).WorldSlugSize
-- The source Floppy's length between root and antenna, as in the combat flight model.
local SLUG_SOURCE = 2.72
-- Inferno's base form is exported at Floppy's height, so 0.34 x that length is his reference length (CombatServer).
local INFERNO_SOURCE = 0.34 * SLUG_SOURCE
-- 14 supported habitats: nine Floppies and five Infernos. Site 6 is a pond rock
-- too narrow to support a two-stud resident; retain all source sites for the concept.
local GROVE_SITES = { 1, 3, 10, 11, 12, 13, 15, 16, 18, 19, 23, 25, 27, 30 }
local GROVE_INFERNOS = { [1] = true, [11] = true, [13] = true, [18] = true, [19] = true }

local function groveAt(x: number, y: number, z: number): Vector3
	return GROVE * Vector3.new(x * UNIT, y * UNIT, z * UNIT)
end

-- Flowing water along the stream's own path, node to node, so it follows the mountain. Each segment is one repeat of the texture
-- and all move at one speed, so the pattern runs on across the joins.
local function groveFlow(
	lift: number,
	texture: string,
	color: Color3,
	transparency: number,
	speed: number,
	emission: number
)
	local nodes: { Attachment } = {}
	local count = #groveStream
	for index, row in groveStream do
		local before = groveStream[math.max(index - 1, 1)]
		local after = groveStream[math.min(index + 1, count)]
		local along = (groveAt(after[1], after[2], after[3]) - groveAt(
			before[1],
			before[2],
			before[3]
		)).Unit
		local across = GROVE.XVector
		local out = along:Cross(across).Unit
		if out:Dot(Vector3.yAxis - GROVE.ZVector) < 0 then
			out = -out
		end
		local node = holder("FallFlow", groveAt(row[1], row[2], row[3]) + out * lift, Vector3.one)
		local a = Instance.new("Attachment")
		-- The width runs along each attachment's Y.
		a.CFrame = CFrame.fromMatrix(Vector3.zero, along, across, along:Cross(across))
		a.Parent = node
		table.insert(nodes, a)
	end
	for index = 1, count - 1 do
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = nodes[index], nodes[index + 1]
		b.Width0, b.Width1 = groveStream[index][4] * 2 * UNIT, groveStream[index + 1][4] * 2 * UNIT
		b.FaceCamera = false
		b.Segments = 1
		b.Texture = texture
		b.TextureMode = Enum.TextureMode.Wrap
		b.TextureLength = (nodes[index].WorldPosition - nodes[index + 1].WorldPosition).Magnitude
		b.TextureSpeed = speed
		b.LightEmission = emission
		b.LightInfluence = 0
		b.Color = ColorSequence.new(color)
		local from = if index == 1 then 1 else transparency
		local to = if index == count - 1 then 1 else transparency
		b.Transparency = NumberSequence.new(from, to)
		b.Parent = nodes[index]
	end
end

-- A band of water drifting flat across the pond, from where the falls land, fading out before the banks.
local function pondCurrent(
	fromX: number,
	fromZ: number,
	toX: number,
	toZ: number,
	width: number,
	speed: number
)
	local from, to = groveAt(fromX, -0.07, fromZ), groveAt(toX, -0.07, toZ)
	local along = (to - from).Unit
	local across = along:Cross(Vector3.yAxis).Unit
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	local axes = CFrame.fromMatrix(Vector3.zero, along, across, along:Cross(across))
	a0.CFrame, a1.CFrame = axes, axes
	a0.Parent = holder("PondCurrent", from, Vector3.one)
	a1.Parent = holder("PondCurrent", to, Vector3.one)
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.Width0, b.Width1 = width * 0.45, width
	b.FaceCamera = false
	b.Segments = 1
	b.Texture = fxTexture("streak")
	b.TextureMode = Enum.TextureMode.Wrap
	b.TextureLength = 26
	b.TextureSpeed = speed
	b.LightEmission = 0.7
	b.LightInfluence = 0
	b.Color = ColorSequence.new(Color3.fromRGB(160, 250, 235))
	b.Transparency = fade({ { 0, 1 }, { 0.2, 0.62 }, { 0.75, 0.68 }, { 1, 1 } })
	b.Parent = a0.Parent
end

-- The pond moving by itself: currents from the falls, rings, glints, slow light under the surface, and pads on the swell.
local function pondLife()
	local water = art:FindFirstChild("hub-grove-water")
	local pond = water and water:FindFirstChild("Pond", true)
	if pond and pond:IsA("MeshPart") then
		-- See-through, so the deeper bed shows.
		pond.Transparency = 0.2
		pond:SetAttribute("PulseRate", 0.45)
		pond:SetAttribute("PulseDepth", 0.16)
		CollectionService:AddTag(pond, "HubPulse")
	end
	local dress = art:FindFirstChild("hub-grove-dress")
	if dress then
		setMotion(dress :: Model, "Pads", 0, 0.14, 0.5, 0)
	end
	for _, band in
		{
			{ -4.2, -1.6, 0.42 },
			{ -1.6, -4.6, 0.3 },
			{ 1.4, -5.0, 0.36 },
			{ 4.4, -2.6, 0.48 },
			{ -5.0, 2.2, 0.34 },
			{ 5.2, 2.0, 0.4 },
		}
	do
		pondCurrent(0.4, 6.6, band[1], band[2], 34, band[3])
	end
	local surface = holder("GroveSurface", groveAt(0, -0.09, 0.4), Vector3.new(64, 0.2, 66))
	local rings = Instance.new("ParticleEmitter")
	rings.Name = "Rings"
	rings.Texture = fxTexture("ripple")
	rings.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	rings.EmissionDirection = Enum.NormalId.Top
	rings.Speed = NumberRange.new(0.05)
	rings.Color = ColorSequence.new(GROVE_TINT)
	rings.LightEmission = 0.5
	rings.LightInfluence = 0
	rings.Size = NumberSequence.new(1.5, 13)
	rings.Transparency = fade({ { 0, 0.7 }, { 0.15, 0.35 }, { 1, 1 } })
	rings.Lifetime = NumberRange.new(2, 3.4)
	rings.Rate = 2.4
	rings.Parent = surface
	local glints = Instance.new("ParticleEmitter")
	glints.Name = "Glints"
	glints.Texture = fxTexture("twinkle")
	glints.EmissionDirection = Enum.NormalId.Top
	glints.Speed = NumberRange.new(0.05, 0.2)
	glints.Color = ColorSequence.new(Color3.fromRGB(205, 255, 245))
	glints.LightEmission = 1
	glints.LightInfluence = 0
	glints.Size = fade({ { 0, 0 }, { 0.4, 1.3 }, { 1, 0 } })
	glints.Lifetime = NumberRange.new(0.8, 1.6)
	glints.Rate = 14
	CollectionService:AddTag(glints, "HubSpareTwinkle")
	glints.Parent = surface
	-- What players' steps use (GroveWater.client).
	local splash = holder("GroveSplash", groveAt(0, -0.07, 0), Vector3.one)
	local stepRings = rings:Clone()
	stepRings.Rate = 0
	stepRings.Size = NumberSequence.new(1.5, 11)
	stepRings.Lifetime = NumberRange.new(1, 1.7)
	stepRings.Transparency = fade({ { 0, 0.15 }, { 1, 1 } })
	stepRings.Parent = splash
	local drops = Instance.new("ParticleEmitter")
	drops.Name = "Drops"
	drops.Texture = fxTexture("droplet")
	drops.EmissionDirection = Enum.NormalId.Top
	drops.Speed = NumberRange.new(9, 19)
	drops.SpreadAngle = Vector2.new(34, 34)
	drops.Acceleration = Vector3.new(0, -62, 0)
	drops.Color = ColorSequence.new(Color3.fromRGB(205, 255, 245))
	drops.LightEmission = 0.5
	drops.LightInfluence = 0
	drops.Size = fade({ { 0, 0.7 }, { 1, 0.25 } })
	drops.Lifetime = NumberRange.new(0.4, 0.75)
	drops.Rate = 0
	drops.Parent = splash
	local foam = Instance.new("ParticleEmitter")
	foam.Name = "Foam"
	foam.Texture = fxTexture("mist")
	foam.EmissionDirection = Enum.NormalId.Top
	foam.Speed = NumberRange.new(2, 5)
	foam.SpreadAngle = Vector2.new(50, 50)
	foam.Color = ColorSequence.new(Color3.fromRGB(215, 250, 245))
	foam.LightEmission = 0.3
	foam.LightInfluence = 0
	foam.Size = NumberSequence.new(2.5, 8)
	foam.Transparency = fade({ { 0, 0.55 }, { 1, 1 } })
	foam.Lifetime = NumberRange.new(0.5, 0.9)
	foam.Rate = 0
	foam.Parent = splash
end

local function groveWater()
	groveFlow(1.6, fxTexture("flow"), Color3.fromRGB(205, 255, 248), 0.45, 1.5, 0.3)
	groveFlow(1.75, fxTexture("streak"), GROVE_TINT, 0.4, 2.3, 0.6)
	-- A soft light in the cave's mouth, as if the water glows back into it.
	pointLight(groveAt(0.4, 20.5, 21.5), GROVE_TINT, 0.5, 22)
	local foot = groveAt(GROVE_FOOT.X, GROVE_FOOT.Y, GROVE_FOOT.Z)
	local landing = holder("GroveFoot", foot, Vector3.new(26, 0.5, 14))
	local ripples = Instance.new("ParticleEmitter")
	ripples.Name = "Ripples"
	ripples.Texture = fxTexture("ripple")
	ripples.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	ripples.EmissionDirection = Enum.NormalId.Top
	ripples.Speed = NumberRange.new(0.05)
	ripples.Color = ColorSequence.new(GROVE_TINT)
	ripples.LightEmission = 0.5
	ripples.LightInfluence = 0
	ripples.Size = NumberSequence.new(5, 26)
	ripples.Transparency = fade({ { 0, 0.5 }, { 0.15, 0.2 }, { 1, 1 } })
	ripples.Lifetime = NumberRange.new(2.2, 3)
	ripples.Rate = 1.4
	ripples.Parent = landing
	local mist = Instance.new("ParticleEmitter")
	mist.Name = "Mist"
	mist.Texture = fxTexture("mist")
	mist.EmissionDirection = Enum.NormalId.Top
	mist.Speed = NumberRange.new(2, 5)
	mist.SpreadAngle = Vector2.new(30, 30)
	mist.Color = ColorSequence.new(Color3.fromRGB(215, 245, 240))
	mist.LightEmission = 0.25
	mist.LightInfluence = 0
	mist.Size = NumberSequence.new(9, 26)
	mist.Transparency = fade({ { 0, 1 }, { 0.2, 0.72 }, { 1, 1 } })
	mist.Lifetime = NumberRange.new(3, 5)
	mist.Rotation = NumberRange.new(0, 360)
	mist.RotSpeed = NumberRange.new(-12, 12)
	mist.Rate = 4
	mist.Parent = landing
	pointLight(foot + Vector3.new(0, 6, 0), GROVE_TINT, 0.6, 32)
	-- Rings spreading across the pond now and then, and spores drifting through the clearing.
	local pond = holder("GrovePond", groveAt(0, -0.05, 0), Vector3.new(58, 0.5, 58))
	local rings = ripples:Clone()
	rings.Size = NumberSequence.new(2, 11)
	rings.Rate = 0.9
	rings.Parent = pond
	local air = holder("GroveAir", groveAt(0, 3, -2), Vector3.new(190, 26, 190))
	local spores = Instance.new("ParticleEmitter")
	spores.Name = "Spores"
	spores.Texture = fxTexture("spore")
	spores.EmissionDirection = Enum.NormalId.Top
	spores.Speed = NumberRange.new(0.3, 1.1)
	spores.SpreadAngle = Vector2.new(180, 180)
	spores.Color = ColorSequence.new(Color3.fromRGB(190, 255, 220))
	spores.LightEmission = 1
	spores.LightInfluence = 0
	spores.Size = NumberSequence.new(0.5, 0.25)
	spores.Transparency = fade({ { 0, 1 }, { 0.2, 0.15 }, { 0.8, 0.15 }, { 1, 1 } })
	spores.Lifetime = NumberRange.new(7, 12)
	spores.Rate = 10
	spores.Parent = air
end

-- Inferno's base form at a slug's height, in the same slug space as the Floppies, with his outline.
local function groveInferno(): Model?
	local module = ServerStorage:FindFirstChild("InfernoAsset")
	local materials = ServerStorage:FindFirstChild("InfernoMaterials")
	if not (module and materials) then
		warn("HubArt: no Inferno asset in this build, the grove has only Floppies")
		return nil
	end
	local asset = require(module) :: any
	local ok, container = pcall(function()
		return InsertService:LoadAsset(asset.base.model)
	end)
	if not ok then
		warn(`HubArt: the grove's Inferno failed to load: {container}`)
		workspace:SetAttribute("HubArtFailed", (workspace:GetAttribute("HubArtFailed") or 0) + 1)
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "GroveSlug"
	model:SetAttribute("Slug", "Inferno")
	for _, child in (container :: Instance):GetChildren() do
		child.Parent = model
	end
	(container :: Instance):Destroy()
	InfernoAppearance.dress(model, materials, SLUG_STUDS)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide, item.CanQuery, item.CanTouch = false, false, false
			item.CastShadow = false
			-- The import's RootPart is a block that isn't part of him.
			if not item:IsA("MeshPart") then
				item.Transparency = 1
			end
		elseif item:IsA("Bone") then
			item.Transform = CFrame.identity
		end
	end
	model:ScaleTo(model:GetScale() * SLUG_STUDS / INFERNO_SOURCE)
	local left = model:FindFirstChild("antenna_L", true) :: Bone
	local right = model:FindFirstChild("antenna_R", true) :: Bone
	local root = model:FindFirstChild("root", true) :: Bone
	local head = model:FindFirstChild("head", true) :: Bone
	local up = (head.WorldPosition - root.WorldPosition).Unit
	local front = (right.WorldPosition - left.WorldPosition):Cross(up).Unit
	model.WorldPivot = CFrame.fromMatrix(root.WorldPosition, up:Cross(-front), up, -front)
	InfernoAppearance.outline(model)
	return model
end

local function groveSlugModels()
	local asset = require(ServerStorage:WaitForChild("FloppyAsset")) :: any
	local ok, container = pcall(function()
		return InsertService:LoadAsset(asset.model)
	end)
	if not ok then
		warn(`HubArt: the grove's Floppy failed to load: {container}`)
		workspace:SetAttribute("HubArtFailed", (workspace:GetAttribute("HubArtFailed") or 0) + 1)
		return
	end
	local template = Instance.new("Model")
	template.Name = "GroveSlug"
	for _, child in (container :: Instance):GetChildren() do
		child.Parent = template
	end
	(container :: Instance):Destroy()
	FloppyAppearance.apply(template, 0.08)
	for _, item in template:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide, item.CanQuery, item.CanTouch = false, false, false
			item.CastShadow = false
		elseif item:IsA("Bone") then
			item.Transform = CFrame.identity
		end
	end
	local eyeL = template:FindFirstChild("eye_L", true) :: Bone
	local eyeR = template:FindFirstChild("eye_R", true) :: Bone
	local root = template:FindFirstChild("root", true) :: Bone
	local head = template:FindFirstChild("head", true) :: Bone
	local sourceScale = (eyeR.WorldPosition - eyeL.WorldPosition).Magnitude / 0.74
	template:ScaleTo(template:GetScale() * SLUG_STUDS / (SLUG_SOURCE * sourceScale))
	local up = (head.WorldPosition - root.WorldPosition).Unit
	local face = (eyeL.WorldPosition + eyeR.WorldPosition) / 2 - head.WorldPosition
	local front = (face - up * face:Dot(up)).Unit
	-- Slug space: its root on the ground, +Y up out of its back, -Z the way its face points.
	template.WorldPivot = CFrame.fromMatrix(root.WorldPosition, up:Cross(-front), up, -front)
	-- Floppies stand in at Inferno's sites if he can't load.
	local inferno = groveInferno() or template
	local group = Instance.new("Folder")
	group.Name = "GroveSlugs"
	group.Parent = art
	for _, index in GROVE_SITES do
		local site = groveSlugs[index]
		local slug = (if GROVE_INFERNOS[index] then inferno else template):Clone()
		slug.Name = `GroveSlug{index}`
		slug:SetAttribute(
			"Slug",
			if GROVE_INFERNOS[index] and inferno ~= template then "Inferno" else "Floppy"
		)
		slug:SetAttribute("GroveResident", true)
		slug:SetAttribute("WorldSlugSize", SLUG_STUDS)
		slug:SetAttribute("GroveOrigin", GROVE.Position)
		slug:PivotTo(
			CFrame.new(GROVE * Vector3.new(site.x, site.y, site.z))
				* CFrame.Angles(0, site.heading, 0)
		)
		slug.Parent = group
	end
	if inferno ~= template then
		inferno:Destroy()
	end
	template:Destroy()
end

-- The mushrooms are the approved giant mushroom at every size, with its roots, mound and sprouts, in the colours nearest the concept's.
-- Under 20 studs tall they use a much lighter copy, as a small one is only a little of the screen.
local TREE_COLOURS =
	{ [0] = "mushroom-13", [1] = "mushroom-12", [2] = "mushroom-5", [3] = "mushroom-3" }
local TREE_LIGHTS = {
	[0] = Color3.fromRGB(90, 240, 225),
	[1] = Color3.fromRGB(110, 245, 150),
	[2] = Color3.fromRGB(190, 120, 255),
	[3] = Color3.fromRGB(110, 165, 255),
}
local TREE_GLOW = 0.3 -- caps are far bigger on screen here than in the look test, and blow out to white at full strength
-- The caps' own glow on top of that (owner, 2026-11-06: the tops of the mushroom trees very dim, they need a good glow);
-- the stems stay as they were.
-- Round 9: their cap paint has its own glowing ring now, which blooms white at more than this.
local CAP_GLOW = 1.6
local SMALL_TREE = 20
local FLORA_KEYS: { [number]: string } = {
	[0] = "hub-flora-star",
	[1] = "hub-flora-bell",
	[2] = "hub-flora-lantern",
	[3] = "hub-flora-plant",
	[4] = "hub-flora-grass",
	-- The gun side's own star flowers, magenta and cyan.
	[5] = "hub-flora-gunstar-a",
	[6] = "hub-flora-gunstar-b",
}

local function groveProps()
	local cache: { [string]: Model } = {}
	local function template(key: string, glow: number): Model?
		local model = cache[key]
		if not model then
			model = libraryPiece(key, glow)
			if model and string.sub(key, 1, 9) == "mushroom-" then
				for _, part in model:GetDescendants() do
					local surface = part:FindFirstChild("SlugshotMaterial")
					if
						part:IsA("MeshPart")
						and (part.Name == "Cap" or part.Name == "GlowCap")
						and surface
					then
						(surface :: SurfaceAppearance).EmissiveStrength *= CAP_GLOW
					end
				end
			end
		end
		if model then
			cache[key] = model
		end
		return model
	end
	local function plant(
		source: Model,
		parent: Instance,
		x: number,
		y: number,
		z: number,
		turn: number,
		tall: number,
		frame: CFrame?
	): Model
		local copy = source:Clone()
		local lo, hi = paintedBounds(copy)
		copy:ScaleTo(copy:GetScale() * tall / (hi.Y - lo.Y))
		copy:PivotTo(
			CFrame.new((frame or GROVE) * Vector3.new(x, y, z)) * CFrame.Angles(0, turn, 0)
		)
		copy.Parent = parent
		return copy
	end
	local trees = Instance.new("Model")
	trees.Name = "GroveTrees"
	trees.Parent = art
	-- The mountain bare but for the mushrooms curving out of its faces (owner, 2026-11-07: plain, with only the mushrooms
	-- that come out and go up; far_side.json places those): nothing standing on its ledges, which start 10 studs up, while
	-- the grove's floor and banks lie below 6.
	local ON_MOUNTAIN = 10
	for index, site in groveTrees do
		if site.y > ON_MOUNTAIN then
			continue
		end
		local small = site.height < SMALL_TREE
		local colour = site.colour
		local source = template(TREE_COLOURS[colour] .. (if small then "-s" else ""), TREE_GLOW)
		if source then
			local tree =
				plant(source, trees, site.x, site.y, site.z, site.turn or index * 1.9, site.height)
			if not small then
				for _, part in tree:GetDescendants() do
					if part:IsA("MeshPart") and part.Name == "Stem" then
						table.insert(solidQueue, part)
					end
				end
				if site.height > 20 then
					pointLight(
						GROVE * Vector3.new(site.x, site.y + site.height * 0.62, site.z),
						TREE_LIGHTS[colour],
						0.22,
						site.height * 0.8
					)
				end
			end
		end
	end
	local crystals = Instance.new("Model")
	crystals.Name = "GroveCrystals"
	crystals.Parent = art
	for index, site in groveCrystals do
		if site.y > ON_MOUNTAIN then
			continue
		end
		local source = template(site.key, 1)
		if source then
			plant(source, crystals, site.x, site.y, site.z, index * 2.3, site.height)
		end
	end
	-- The gun side: the knoll's forest, and the canopy rising out of the hole from its floor far below. Only the
	-- knoll's big stems are solid; nobody can reach the canopy.
	local knoll = Instance.new("Model")
	knoll.Name = "KnollTrees"
	knoll.Parent = art
	for index, site in gunSide.trees do
		local small = site.height < SMALL_TREE
		local source =
			template(TREE_COLOURS[site.colour] .. (if small then "-s" else ""), TREE_GLOW)
		if source then
			local tree = plant(
				source,
				knoll,
				site.x,
				site.y,
				site.z,
				index * 2.7,
				site.height,
				CFrame.identity
			)
			if not small then
				for _, part in tree:GetDescendants() do
					if part:IsA("MeshPart") and part.Name == "Stem" then
						table.insert(solidQueue, part)
					end
				end
				if site.height > 30 then
					pointLight(
						Vector3.new(site.x, site.y + site.height * 0.62, site.z),
						TREE_LIGHTS[site.colour],
						0.22,
						site.height * 0.8
					)
				end
			end
		end
	end
	local canopy = Instance.new("Model")
	canopy.Name = "HoleCanopy"
	canopy.Parent = art
	for index, site in gunSide.canopy do
		local source = template(TREE_COLOURS[site.colour], TREE_GLOW)
		if source then
			local tree = plant(
				source,
				canopy,
				site.x,
				site.y,
				site.z,
				index * 1.7,
				site.height,
				CFrame.identity
			)
			for _, part in tree:GetDescendants() do
				if part:IsA("MeshPart") and part.Name == "Cap" then
					part.CastShadow = false
				end
			end
			-- Only the top layer of caps carries a light, so the hole glows without a crowd of lights.
			if site.height > 70 then
				pointLight(
					Vector3.new(site.x, site.y + site.height * 0.9, site.z),
					TREE_LIGHTS[site.colour],
					0.3,
					site.height * 0.6
				)
			end
		end
	end
	-- The cavern's crystals (owner, 2026-11-04: our own designs), leaning out from the wall, spire or floor they grow on.
	local crystalSites = table.clone(gunSide.crystals)
	table.move(farSide.crystals, 1, #farSide.crystals, #crystalSites + 1, crystalSites)
	local shapes: { [string]: number } = {}
	local wallGlows = 0
	for index, site in crystalSites do
		local source = template(site.key, 1)
		if source then
			-- How tall the design is for its widest side: a wide one is made smaller, so no side runs past the site's size
			-- by more than a tenth.
			local share = shapes[site.key]
			if not share then
				local lo, hi = paintedBounds(source)
				local size = hi - lo
				share = math.min(1, size.Y * 1.1 / math.max(size.X, size.Z))
				shapes[site.key] = share
			end
			local copy = plant(
				source,
				crystals,
				site.x,
				site.y,
				site.z,
				index * 1.9,
				site.height * share,
				CFrame.identity
			)
			local lean = Vector3.new(site.lx, 0, site.lz)
			if site.tilt > 0 and lean.Magnitude > 0 then
				local axis = Vector3.yAxis:Cross(lean.Unit)
				copy:PivotTo(
					CFrame.new(site.x, site.y, site.z)
						* CFrame.fromAxisAngle(axis, site.tilt)
						* CFrame.Angles(0, index * 1.9, 0)
				)
			end
			-- On walls, ceilings and high up, a soft pool of its colour on the rock round it: its own light sits at its tip,
			-- 20 or 30 studs out from the rock, and reaches 14 at most. Those on the floor have the floor's light round them.
			-- A site may ask for less where many grow close together (glow, a share of the usual).
			local glow = if site.glow ~= nil then site.glow else 1
			if (site.tilt > 0.5 or site.y > 15) and glow > 0 then
				local size = site.height * share
				local grows = if lean.Magnitude > 0
					then Vector3.yAxis * math.cos(site.tilt) + lean.Unit * math.sin(site.tilt)
					else Vector3.yAxis
				local brightest: PointLight? = nil
				for _, light in copy:GetDescendants() do
					if
						light:IsA("PointLight")
						and (not brightest or light.Brightness > brightest.Brightness)
					then
						brightest = light
					end
				end
				if brightest then
					softGlow(
						Vector3.new(site.x, site.y, site.z) + grows * size * 0.3,
						brightest.Color,
						1.5 * glow,
						math.clamp(size * 1.6, 20, 50)
					)
					wallGlows += 1
				end
			end
		end
	end
	print(`HubArt: {wallGlows} crystals light the rock round them`)
	for _, model in cache do
		model:Destroy()
	end
	-- The plants: one of each loaded, then copies. Each is modelled round its root at the ground.
	local flora = Instance.new("Model")
	flora.Name = "GroveFlora"
	flora.Parent = art
	local plants: { [number]: Model } = {}
	for kind, key in FLORA_KEYS do
		local model = loadPiece(key)
		if model then
			model.WorldPivot = CFrame.identity
			plants[kind] = model
		end
	end
	local function placePlant(site: { number }, frame: CFrame)
		local source = plants[site[1]]
		if source then
			local copy = source:Clone()
			copy:ScaleTo(copy:GetScale() * site[5])
			copy:PivotTo(
				CFrame.new(frame * Vector3.new(site[2], site[3], site[4]))
					* CFrame.Angles(0, site[6], 0)
			)
			copy.Parent = flora
			for _, part in copy:GetDescendants() do
				if part:IsA("MeshPart") and isInk(part) then
					CollectionService:AddTag(part, "HubDistantInk")
				end
			end
		end
	end
	for _, site in groveFlora do
		placePlant(site, GROVE)
	end
	for _, site in gunSide.flora do
		placePlant(site, CFrame.identity)
	end
	for _, model in plants do
		model:Destroy()
	end
end

-- The gun side's art (docs/art/general-shop.md): concept units are 5 studs round the canopy hole's centre, with the hub
-- toward the concept's -z, which is the world's +x from the hole.
local GUN = CFrame.new(gunSide.hole.centre[1], 0, gunSide.hole.centre[2])
	* CFrame.Angles(0, -math.pi / 2, 0)
local GUN_KEYS = {
	"hub-gun-ground",
	"hub-gun-path",
	"hub-gun-mat",
	"hub-gun-spire",
	"hub-gun-stones",
	"hub-gun-shop",
	"hub-gun-trim",
	"hub-gun-sign",
}

-- The cavern's pieces (owner, 2026-11-04): roots, shelves, side mushrooms and hanging vines, each modelled once and placed
-- round the hole's wall from gun_side.json, facing out of the rock (each piece's +z runs into it).
local function placeOnRock(name: string, sites: { any })
	local folder = Instance.new("Model")
	folder.Name = name
	folder.Parent = art
	local sources: { [string]: Model } = {}
	for _, site in sites do
		local source = sources[site.key]
		if source == nil then
			local loaded = loadPiece(site.key)
			if not loaded then
				continue
			end
			loaded.WorldPivot = CFrame.identity
			sources[site.key] = loaded
			source = loaded
		end
		local copy = (source :: Model):Clone()
		copy:ScaleTo(copy:GetScale() * site.s)
		local at = Vector3.new(site.x, site.y, site.z)
		copy:PivotTo(CFrame.lookAt(at, at - Vector3.new(site.ox, 0, site.oz)))
		copy.Parent = folder
		for _, part in copy:GetDescendants() do
			if part:IsA("MeshPart") and isInk(part) then
				CollectionService:AddTag(part, "HubDistantInk")
			end
		end
	end
	for _, source in sources do
		source:Destroy()
	end
end

local function gunCavern()
	placeOnRock("HoleWall", gunSide.wall)
end

-- The hole's mist (owner): layers at five depths, thick but see-through, drifting; and purple spores rising off the velvet.
local function gunSideEffects()
	local hole = gunSide.hole
	local centre = Vector3.new(hole.centre[1], 0, hole.centre[2])
	local folder = Instance.new("Folder")
	folder.Name = "GunSideEffects"
	folder.Parent = art
	local count = #hole.radii
	for layer = 0, 4 do
		local y = (-3 - layer * 4.3) * 5
		for k = 0, 7 do
			local t = (k + 0.5) / 8 * 2 * math.pi + layer * 0.4
			local r = hole.radii[math.floor(t / (2 * math.pi) * count) % count + 1]
				* (0.35 + 0.25 * (k % 3) / 2)
			local at = centre + Vector3.new(math.cos(t), 0, math.sin(t)) * r + Vector3.new(0, y, 0)
			local source = holder("Mist", at, Vector3.new(36, 2, 36))
			source.Parent = folder
			local e = Instance.new("ParticleEmitter")
			e.Texture = fxTexture("mist")
			e.Rate = 0.8
			e.Lifetime = NumberRange.new(14, 20)
			e.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 26),
				NumberSequenceKeypoint.new(1, 44),
			})
			e.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.3, 0.82),
				NumberSequenceKeypoint.new(0.7, 0.85),
				NumberSequenceKeypoint.new(1, 1),
			})
			e.Color =
				ColorSequence.new(Color3.fromRGB(150, 120, 210), Color3.fromRGB(110, 100, 180))
			e.LightEmission = 0.25
			e.Speed = NumberRange.new(0.6, 1.4)
			e.SpreadAngle = Vector2.new(180, 8)
			e.EmissionDirection = Enum.NormalId.Right
			e.Rotation = NumberRange.new(0, 360)
			e.RotSpeed = NumberRange.new(-3, 3)
			e.Parent = source
		end
	end
	-- Spores over the whole velvet, not just round the hole (owner, 2026-11-04: too few).
	for angle = gunSide.from + 5, gunSide.to - 5, 8 do
		for radius = 112, 292, 22 do
			local rad = math.rad(angle)
			local at = Vector3.new(math.sin(rad) * radius, 1, -math.cos(rad) * radius)
			local offset = Vector3.new(at.X - centre.X, 0, at.Z - centre.Z)
			local t = math.atan2(offset.Z, offset.X) % (2 * math.pi)
			if
				offset.Magnitude
				< hole.radii[math.floor(t / (2 * math.pi) * count) % count + 1] + 8
			then
				continue
			end
			local source = holder("Spores", at, Vector3.new(22, 1, 22))
			source.Parent = folder
			local e = Instance.new("ParticleEmitter")
			e.Texture = fxTexture("spore")
			e.Rate = 5
			e.Lifetime = NumberRange.new(6, 9)
			e.Size = NumberSequence.new(0.45)
			e.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.15, 0.2),
				NumberSequenceKeypoint.new(0.75, 0.3),
				NumberSequenceKeypoint.new(1, 1),
			})
			e.Color = ColorSequence.new(Color3.fromRGB(190, 90, 255))
			e.LightEmission = 1
			e.Speed = NumberRange.new(1.5, 2.6)
			e.SpreadAngle = Vector2.new(12, 12)
			e.EmissionDirection = Enum.NormalId.Top
			e.Parent = source
		end
	end
end

local function buildGunSide()
	for _, key in GUN_KEYS do
		local model = place(key)
		if model then
			model:PivotTo(GUN * model:GetPivot())
		end
	end
	gunCavern()
	gunSideEffects()
	-- The velvet's purple light over its cobbles (owner, 2026-11-07: the cobble stone too dark in the shop area): the path
	-- and the shop's mat stand in the hole's shade with no lamp, while the velvet round them glows by itself. Soft, high
	-- enough over the path that a character walking under it isn't lit up. Concept units: the path runs from -23.6 to the
	-- hole's rim at -14.4, the mat lies in front of the door.
	for _, at in { Vector3.new(0, 2.4, -21.5), Vector3.new(0, 2.4, -16.8), Vector3.new(0, 2.4, -4.4) } do
		softGlow(GUN * (at * UNIT), Color3.fromRGB(190, 150, 255), 1.1, 32)
	end
end

-- The far side (owner, 2026-11-04): the cavern wall round the whole circle, one great mouth in it, and a look-only cave beyond.
local FAR_KEYS = {
	"hub-cavern-00",
	"hub-cavern-01",
	"hub-cavern-02",
	"hub-cavern-03",
	"hub-cavern-04",
	"hub-cavern-05",
	"hub-cavern-06",
	"hub-cavern-07",
	"hub-cavern-08",
	"hub-cavern-09",
	"hub-cavern-10",
	"hub-cavern-11",
	"hub-roof-00",
	"hub-roof-01",
	"hub-roof-02",
	"hub-roof-03",
	"hub-roof-04",
	"hub-roof-05",
	"hub-roof-06",
	"hub-roof-07",
	"hub-roof-08",
	"hub-roof-09",
	"hub-roof-10",
	"hub-roof-11",
	"hub-cave-hall",
	"hub-cave-spires",
	"hub-far-ground",
	"hub-far-path",
	"hub-mouth-slabs",
	"hub-path-rocks",
}

-- The canopy hole's mist (owner): the same drifting see-through layers, under the cliff and thinner higher up in the cave.
local function farCaveMist()
	local folder = Instance.new("Folder")
	folder.Name = "FarCaveMist"
	folder.Parent = art
	local function layer(y: number, count: number, faint: boolean, seed: number)
		for k = 1, count do
			local across = ((k * 0.618 + seed * 0.37) % 1 - 0.5) * 400
			local depth = 300 + ((k * 0.381 + seed * 0.53) % 1) * 340
			local width = math.min(145 + (depth - 310) * 0.6, 250)
			local at = Vector3.new(math.clamp(across, -width, width), y, depth)
			local source = holder("Mist", at, Vector3.new(80, 3, 80))
			source.Parent = folder
			local e = Instance.new("ParticleEmitter")
			e.Texture = fxTexture("mist")
			e.Rate = if faint then 0.35 else 0.7
			e.Lifetime = NumberRange.new(16, 24)
			e.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 55),
				NumberSequenceKeypoint.new(1, 100),
			})
			local peak = if faint then 0.9 else 0.8
			e.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.3, peak),
				NumberSequenceKeypoint.new(0.7, peak + 0.03),
				NumberSequenceKeypoint.new(1, 1),
			})
			e.Color =
				ColorSequence.new(Color3.fromRGB(150, 120, 210), Color3.fromRGB(110, 100, 180))
			e.LightEmission = 0.25
			e.Speed = NumberRange.new(0.8, 1.8)
			e.SpreadAngle = Vector2.new(180, 8)
			e.EmissionDirection = Enum.NormalId.Right
			e.Rotation = NumberRange.new(0, 360)
			e.RotSpeed = NumberRange.new(-3, 3)
			e.Parent = source
			CollectionService:AddTag(e, "HubMist")
		end
	end
	for k = 0, 4 do
		layer((-2.5 - k * 5) * 5, 11, false, k)
	end
	layer(35, 6, true, 7)
	layer(80, 5, true, 11)
	-- Below the drifting layers, sheets of mist, thickening downward to a solid one in the colour the rock is painted
	-- fading into, well above the cave's floor. They run into the rock all round, so no edge shows.
	for _, sheet in
		{
			{ -128, 0.55, Color3.fromRGB(92, 78, 156) },
			{ -146, 0.3, Color3.fromRGB(74, 64, 130) },
			{ -165, 0, Color3.fromRGB(56, 51, 107) },
		}
	do
		local part = Instance.new("Part")
		part.Name = "MistSheet"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.Size = Vector3.new(560, 1, 430)
		part.Position = Vector3.new(0, sheet[1], 500)
		part.Transparency = sheet[2]
		part.Color = sheet[3]
		part.Parent = folder
	end
	layer(-125, 9, false, 13)
	layer(-142, 9, false, 17)
end

-- A lantern post either side of the far side's cobble path (owner, 2026-11-05), each with a warm light in its lantern.
-- hub-lantern-post's arm reaches over its +x, and the lantern's core hangs at (3.6, 9.9, -0.1) studs from its foot.
local LANTERN_CORE = Vector3.new(3.6, 9.9, -0.1)
local function farLanterns()
	local source = loadPiece("hub-lantern-post")
	if not source then
		return
	end
	source.WorldPivot = CFrame.identity
	local folder = Instance.new("Model")
	folder.Name = "FarLanterns"
	folder.Parent = art
	for _, site in farSide.lanterns do
		local frame = CFrame.new(site.x, site.y, site.z) * CFrame.Angles(0, site.yaw, 0)
		local copy = source:Clone()
		copy:PivotTo(frame)
		copy.Parent = folder
		makeSolid(copy, "hub-lantern-post")
		-- A warm pool on the path round each lantern.
		pointLight(frame * LANTERN_CORE, Color3.fromRGB(255, 168, 86), 0.7, 17)
	end
	source:Destroy()
end

-- A light mist over the whole hub (owner, 2026-11-06: just a light mist, nothing crazy; 2026-11-07: a small hint that you can
-- see, not overpowering), lit by the storm's light now it is back: a few big faint sprites drifting
-- low round the ring of floor between the island and the wall, and over the island. Half as many in Low detail (HubMotion).
local MIST_RATE = 0.15
local function hubMist()
	local folder = Instance.new("Folder")
	folder.Name = "HubMist"
	folder.Parent = art
	for k = 0, 39 do
		local angle = (k + 0.5) * math.pi * 2 / 40
		local island = k % 10 == 4
		local radius = if island then 55 elseif k % 2 == 0 then 150 else 235
		local source = holder(
			"Mist",
			Vector3.new(
				math.sin(angle) * radius,
				if island then 14 else 5,
				-math.cos(angle) * radius
			),
			Vector3.new(60, 4, 60)
		)
		source.Parent = folder
		local e = Instance.new("ParticleEmitter")
		e.Texture = fxTexture("mist")
		e.Rate = MIST_RATE
		e.Lifetime = NumberRange.new(22, 30)
		e.Size = NumberSequence.new(40, 70)
		e.Transparency = fade({ { 0, 1 }, { 0.3, 0.86 }, { 0.7, 0.87 }, { 1, 1 } })
		e.Color = ColorSequence.new(Color3.fromRGB(190, 175, 235), Color3.fromRGB(150, 138, 215))
		e.LightEmission = 0.25
		e.Speed = NumberRange.new(0.5, 1)
		e.SpreadAngle = Vector2.new(180, 8)
		e.EmissionDirection = Enum.NormalId.Right
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-3, 3)
		e:SetAttribute("HighRate", MIST_RATE)
		e.Parent = source
		CollectionService:AddTag(e, "HubMist")
	end
end

local function buildFarSide()
	for _, key in FAR_KEYS do
		place(key)
	end
	placeOnRock("FarDressing", farSide.wall)
	farLanterns()
	farCaveMist()
end

-- A strip of dark stone slabs on each line between lobby zones (owner, 2026-11-04: clean and connected, lying on the
-- boundary itself rather than on one zone). Each line is where the two grounds meet: the gun side's velvet stops at
-- -40.8 and -135.25 degrees (chWedge), the grove at 41.05 (the middle of its overlap with the portal floor) and 135.
-- Each copy of hub-zone-slab is a row of four slabs, laid end to end from where the zones start to the cavern wall.
-- Low enough to walk straight over.
local ZONE_LINES = { 41.05, -40.8, 135, -135.25 }
local ZONE_FROM, ZONE_TO = 104.5, 300 -- from where the hub's rim art ends to the cavern wall
local ZONE_ROW = 24.75 -- studs per row of four, joint included (ZS_PITCH in the concept)
local ZONE_TOP = 0.3 -- studs the slabs' tops stand above the floor
local function zoneSlabs()
	local source = loadPiece("hub-zone-slab")
	if not source then
		return
	end
	local folder = Instance.new("Model")
	folder.Name = "ZoneSlabs"
	folder.Parent = art
	local lo, hi = paintedBounds(source)
	source.WorldPivot = CFrame.new((lo.X + hi.X) / 2, hi.Y - ZONE_TOP, (lo.Z + hi.Z) / 2)
	-- The row runs along its longer side; turn it so that lies along the line.
	local turn = if hi.X - lo.X > hi.Z - lo.Z
		then CFrame.Angles(0, math.pi / 2, 0)
		else CFrame.identity
	local rows = math.ceil((ZONE_TO - ZONE_FROM) / ZONE_ROW)
	for _, angle in ZONE_LINES do
		local rad = math.rad(angle)
		local along = Vector3.new(math.sin(rad), 0, -math.cos(rad))
		for row = 1, rows do
			local at = along * (ZONE_FROM + ZONE_ROW * (row - 0.5))
			local copy = source:Clone()
			-- Every other row end for end, so the four slabs' shades don't repeat down the line.
			copy:PivotTo(CFrame.lookAt(at, at + along * (if row % 2 == 0 then -1 else 1)) * turn)
			copy.Parent = folder
			for _, part in copy:GetDescendants() do
				if part:IsA("MeshPart") and not isInk(part) then
					part.CanCollide = true
					part.CanQuery = true
				end
			end
		end
	end
	source:Destroy()
end

local function buildGrove()
	for _, key in GROVE_KEYS do
		local model = place(key)
		if model then
			model:PivotTo(GROVE * model:GetPivot())
		end
	end
	-- The dressing's bushes and vines all sit on the mountain, which is bare now (groveProps); its lily pads stay.
	local dress = art:FindFirstChild("hub-grove-dress")
	if dress then
		for _, part in dress:GetDescendants() do
			if part:IsA("MeshPart") and (string.find(part.Name, "^Bushes") or string.find(part.Name, "^Vines")) then
				part:Destroy()
			end
		end
	end
	groveProps()
	groveWater()
	pondLife()
	groveSlugModels()
end

local function retireBlockOut()
	local root = workspace:WaitForChild("LobbyScale") :: Model
	local function retire(container: Instance?)
		if container then
			for _, item in container:GetDescendants() do
				if item:IsA("BasePart") and item.Transparency >= 1 then
					item:Destroy()
				end
			end
		end
	end
	retire(root:FindFirstChild("SpawnRock"))
	retire(root:FindFirstChild("Portals"))
	local shore = root:FindFirstChild("Shore")
	if shore then
		for _, item in shore:GetDescendants() do
			if item.Name == "Lip" and item:IsA("BasePart") then
				item:Destroy()
			end
		end
		-- The grove's ground is solid as drawn, with a basin for the pond, so the flat one can't stay.
		for _, item in shore:GetChildren() do
			if item:IsA("BasePart") and item.Name == "Surface" and onSlugSide(item.Position) then
				item:Destroy()
			end
		end
	end
	-- The plunge's old walls stood in front of the cliff, which is solid now.
	local maelstrom = root:FindFirstChild("Maelstrom")
	if maelstrom then
		for _, item in maelstrom:GetDescendants() do
			if item:IsA("BasePart") and item.Transparency >= 1 then
				item.CanCollide = false
				item.CanQuery = false
			end
		end
	end
end

lighting()
hideBlockOut()
buildRock()
buildBridges()
buildMaelstrom()
buildSkyWell()
buildPortals()
buildVolcano()
buildArch()
buildGrove()
buildGunSide()
buildFarSide()
hubMist()
zoneSlabs()
sceneLights()
shadeLights()
buildCollision(function()
	retireBlockOut()
	workspace:SetAttribute("HubSolid", true)
end)
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
-- The veil is see-through cloud across most of the screen when looking up, so low detail drops it.
local storm = art:FindFirstChild("hub-storm")
if storm then
	local veil = storm:FindFirstChild("StormVeil", true)
	if veil then
		CollectionService:AddTag(veil, "HubSpareCloud")
	end
end
print("HubArt: built")
