--!strict
-- Server-authoritative destruction for Rocklock v2. Only chunks registered under the map's
-- Destructibles folder and the Terrain inside TerrainZones ever change: requests can never
-- delete arbitrary instances. Structures have structural health; crossing a stage threshold
-- breaks that stage's chunks (small ones vanish, large ones fall and settle as anchored
-- rubble). Suspended formations warn, fall, damage players inside a predictable radius and
-- stay as cover. Everything is restored exactly by reset() from a pristine copy.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Config = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("RocklockV2")
		:WaitForChild("DestructionConfig")
)

export type Structure = {
	id: string,
	model: Model,
	category: string,
	kind: string,
	material: string,
	maxHealth: number,
	health: number,
	stages: number,
	broken: number,
	collapsing: boolean,
	hazardRadius: number,
	hazardDamage: number,
	hazardWarning: number,
	chunks: { BasePart },
	temporary: boolean,
	owner: Player?,
}

local Destruction = {}

local map: Model? = nil
local fx: RemoteEvent? = nil
local pristine: Folder? = nil
local rubble: Folder? = nil
local structures: { [string]: Structure } = {}
local byPart: { [BasePart]: Structure } = {}
local zones: { { id: string, kind: string, cframe: CFrame, size: Vector3 } } = {}
local largeRubble = 0
local generation = 0 -- bumps on reset so in-flight falls and collapses stop
local carveWindow, carveCount = 0, 0
local tempCount = 0

local function number(model: Instance, name: string, default: number): number
	local value = model:GetAttribute(name)
	return tonumber(value) or default
end

local function send(kind: string, data: { [string]: any })
	if fx then
		data.kind = kind
		fx:FireAllClients(data)
	end
end

local function characters(): { Instance }
	local list: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	return list
end

local function register(model: Model, temporary: boolean?, owner: Player?): Structure
	local s: Structure = {
		id = tostring(model:GetAttribute("Id") or model.Name),
		model = model,
		category = tostring(model:GetAttribute("Category") or "Full"),
		kind = tostring(model:GetAttribute("Kind") or "Cover"),
		material = tostring(model:GetAttribute("Material") or "Stone"),
		maxHealth = number(model, "Health", 100),
		health = number(model, "Health", 100),
		stages = math.max(1, number(model, "Stages", 1)),
		broken = 0,
		collapsing = false,
		hazardRadius = number(model, "HazardRadius", 0),
		hazardDamage = number(model, "HazardDamage", 0),
		hazardWarning = number(model, "HazardWarning", Config.Hazard.DefaultWarning),
		chunks = {},
		temporary = temporary == true,
		owner = owner,
	}
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			table.insert(s.chunks, item)
			byPart[item] = s
		end
	end
	model:SetAttribute("HealthNow", s.health)
	structures[s.id] = s
	return s
end

local function asInstances(parts: { BasePart }): { Instance }
	local list: { Instance } = {}
	for _, part in parts do
		table.insert(list, part)
	end
	return list
end

local function unregister(part: BasePart)
	byPart[part] = nil
end

-- Lowest free surface under a point, ignoring characters and the given instances.
local function ground(position: Vector3, ignore: { Instance }): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = characters()
	for _, item in ignore do
		table.insert(list, item)
	end
	params.FilterDescendantsInstances = list
	local hit = Workspace:Raycast(position, Vector3.new(0, -400, 0), params)
	return if hit then hit.Position else position - Vector3.new(0, 60, 0)
end

-- Settled rubble never appears solid inside a player: it stays non-colliding until clear.
local function settle(parts: { BasePart }, stamp: number)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	task.spawn(function()
		for _ = 1, 40 do
			if generation ~= stamp then
				return
			end
			overlap.FilterDescendantsInstances = characters()
			local blocked = false
			for _, part in parts do
				if part.Parent and #Workspace:GetPartsInPart(part, overlap) > 0 then
					blocked = true
					break
				end
			end
			if not blocked then
				for _, part in parts do
					if part.Parent then
						part.CanCollide = true
						part.CanQuery = true
					end
				end
				return
			end
			task.wait(Config.Rubble.ClearCheck)
		end
		for _, part in parts do
			if part.Parent then
				part.CanCollide, part.CanQuery = true, true
			end
		end
	end)
end

-- Animate a rigid group falling (anchored, server-driven) onto the surface below; true lands.
local function fall(
	parts: { BasePart },
	pivot: CFrame,
	stamp: number,
	onLanded: (Vector3) -> (),
	push: Vector3?,
	ignore: { Instance }?
)
	for _, part in parts do
		part.CanCollide, part.CanQuery = false, false
	end
	local lowest = math.huge
	for _, part in parts do
		lowest = math.min(lowest, part.Position.Y - part.Size.Y / 2)
	end
	local shift = push or Vector3.zero
	local skip = asInstances(parts)
	if ignore then
		for _, item in ignore do
			table.insert(skip, item)
		end
	end
	local landing = ground(
		Vector3.new(pivot.Position.X + shift.X, lowest - 0.05, pivot.Position.Z + shift.Z),
		skip
	)
	local drop = math.max(0, lowest - landing.Y)
	local gravity = math.max(Config.Rubble.Gravity, 2 * drop / Config.Rubble.MaxFallTime ^ 2)
	local duration = math.sqrt(2 * drop / gravity)
	local offsets = {}
	for i, part in parts do
		offsets[i] = pivot:ToObjectSpace(part.CFrame)
	end
	local tilt = CFrame.Angles(
		math.rad(math.random(-12, 12)),
		math.rad(math.random(-40, 40)),
		math.rad(math.random(-12, 12))
	)
	local start = os.clock()
	while true do
		if generation ~= stamp then
			return
		end
		local t = math.min(os.clock() - start, duration)
		local alpha = t / math.max(duration, 1e-3)
		local frame = pivot.Rotation:Lerp(tilt * pivot.Rotation, alpha)
			+ pivot.Position
			+ shift * alpha
			- Vector3.new(0, 0.5 * gravity * t * t, 0)
		for i, part in parts do
			if part.Parent then
				part.CFrame = frame * offsets[i]
			end
		end
		if t >= duration then
			break
		end
		RunService.Heartbeat:Wait()
	end
	onLanded(landing)
end

local function toRubble(parts: { BasePart }, stamp: number)
	for _, part in parts do
		unregister(part)
		part:SetAttribute("Rubble", "Settled")
		part.Parent = rubble
	end
	settle(parts, stamp)
end

local function breakChunk(s: Structure, part: BasePart, siblings: { Instance }?)
	unregister(part)
	send("Break", { position = part.Position, size = part.Size, color = part.Color })
	if part:GetAttribute("Rubble") == "Large" and largeRubble < Config.Rubble.LargeLimit then
		largeRubble += 1
		local stamp = generation
		-- Topple outward from the structure's centre so pieces spread into new cover.
		local centre = s.model:GetPivot().Position
		local away = Vector3.new(part.Position.X - centre.X, 0, part.Position.Z - centre.Z)
		if away.Magnitude < 0.5 then
			away = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
		end
		local push = away.Unit * (1.5 + part.Size.Magnitude * 0.25)
		task.spawn(fall, { part }, part.CFrame, stamp, function()
			toRubble({ part }, stamp)
		end, push, siblings)
	else
		part:Destroy()
	end
end

local function damageStructures(
	center: Vector3,
	radius: number,
	amount: number,
	archetype: string,
	skip: Structure?
)
	-- Collected first: damaging edits the part registry.
	local nearest: { [Structure]: number } = {}
	local where: { [Structure]: Vector3 } = {}
	for part, s in byPart do
		if s ~= skip and part.Parent then
			local distance =
				math.max(0, (part.Position - center).Magnitude - part.Size.Magnitude / 2)
			if distance <= radius and distance < (nearest[s] or math.huge) then
				nearest[s], where[s] = distance, part.Position
			end
		end
	end
	for s, distance in nearest do
		local scale = 1 - (1 - Config.Explosive.Falloff) * math.clamp(distance / radius, 0, 1)
		Destruction.damage(s, amount * scale, archetype, where[s])
	end
end

local function collapse(s: Structure)
	if s.collapsing then
		return
	end
	s.collapsing = true
	local stamp = generation
	local model = s.model
	local parts = table.clone(s.chunks)
	local pivot = model:GetPivot()
	local lowest = math.huge
	for _, part in parts do
		lowest = math.min(lowest, part.Position.Y - part.Size.Y / 2)
	end
	local target =
		ground(Vector3.new(pivot.Position.X, lowest - 0.05, pivot.Position.Z), asInstances(parts))
	send("Warn", {
		position = target,
		top = pivot.Position,
		radius = s.hazardRadius,
		duration = s.hazardWarning,
		id = s.id,
	})
	-- Warning: the formation shakes in place before it lets go.
	local start = os.clock()
	while os.clock() - start < s.hazardWarning do
		if generation ~= stamp then
			return
		end
		local a = Config.Hazard.Shake
		model:PivotTo(pivot * CFrame.new(math.random() * a - a / 2, 0, math.random() * a - a / 2))
		task.wait(1 / 15)
	end
	model:PivotTo(pivot)
	fall(parts, pivot, stamp, function(landing)
		if generation ~= stamp then
			return
		end
		-- Server-validated impact: players inside the warned radius at impact time.
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if humanoid and root and humanoid.Health > 0 then
				local offset = root.Position - landing
				if
					Vector3.new(offset.X, 0, offset.Z).Magnitude <= s.hazardRadius
					and math.abs(offset.Y) < 12
				then
					humanoid:TakeDamage(s.hazardDamage)
				end
			end
		end
		send("Impact", { position = landing, radius = s.hazardRadius, id = s.id })
		structures[s.id] = nil
		toRubble(parts, stamp)
		model:Destroy()
		damageStructures(landing, s.hazardRadius, Config.Hazard.StructuralDamage, "Blunt", s)
	end)
end

local function breakStage(s: Structure, stage: number)
	if s.kind == "Hanging" then
		return
	end
	local group: { BasePart } = {}
	for _, part in s.chunks do
		if part.Parent and byPart[part] == s and tonumber(part:GetAttribute("Stage")) == stage then
			table.insert(group, part)
		end
	end
	for _, part in group do
		breakChunk(s, part, asInstances(group))
	end
end

function Destruction.multiplier(material: string, archetype: string): number
	local row = (Config.Materials :: any)[material] or Config.Materials.Stone
	local value = row[archetype]
	return math.max(Config.MinMultiplier, if typeof(value) == "number" then value else 1)
end

-- Applies structural damage; returns the damage actually dealt.
function Destruction.damage(
	s: Structure,
	amount: number,
	archetype: string,
	point: Vector3?
): number
	local category = (Config.Categories :: any)[s.category]
	if not category or not category.Breakable or s.health <= 0 or s.collapsing then
		return 0
	end
	local dealt = math.max(0, amount) * Destruction.multiplier(s.material, archetype)
	s.health = math.max(0, s.health - dealt)
	s.model:SetAttribute("HealthNow", s.health)
	send("Hit", { position = point or s.model:GetPivot().Position, strength = dealt, id = s.id })
	local target = if s.health <= 0
		then s.stages
		else math.floor((1 - s.health / s.maxHealth) * s.stages + 1e-6)
	while s.broken < target do
		s.broken += 1
		breakStage(s, s.broken)
	end
	if s.health <= 0 then
		if s.kind == "Hanging" then
			task.spawn(collapse, s)
		else
			structures[s.id] = nil
			if s.temporary then
				tempCount = math.max(0, tempCount - 1)
			end
			local group: { BasePart } = {}
			for _, part in s.chunks do
				if
					part.Parent
					and byPart[part] == s
					and tonumber(part:GetAttribute("Stage")) ~= 0
				then
					table.insert(group, part)
				end
			end
			for _, part in group do
				breakChunk(s, part, asInstances(group))
			end
			if not s.model:FindFirstChildWhichIsA("BasePart", true) then
				s.model:Destroy()
			end
		end
	end
	return dealt
end

function Destruction.structureOf(part: Instance): Structure?
	return if part:IsA("BasePart") then byPart[part] else nil
end

function Destruction.get(id: string): Structure?
	return structures[id]
end

function Destruction.all(): { [string]: Structure }
	return structures
end

local function inZone(point: Vector3, radius: number): boolean
	for _, zone in zones do
		local p = zone.cframe:PointToObjectSpace(point)
		local h = zone.size / 2 + Vector3.new(radius, radius, radius)
		if math.abs(p.X) <= h.X and math.abs(p.Y) <= h.Y and math.abs(p.Z) <= h.Z then
			return true
		end
	end
	return false
end

-- Digs a crater/tunnel in excavatable earth. Only Terrain inside zones exists, and zones
-- sit on protected bedrock, so this can never open a bottomless hole or breach the arena.
function Destruction.excavate(point: Vector3, radius: number): boolean
	local now = os.clock()
	if now - carveWindow >= 1 then
		carveWindow, carveCount = now, 0
	end
	if carveCount >= Config.Excavation.MaxPerSecond or not inZone(point, radius) then
		return false
	end
	carveCount += 1
	Workspace.Terrain:FillBall(
		point,
		math.min(radius, Config.Excavation.MaxRadius),
		Enum.Material.Air
	)
	send("Dig", { position = point, radius = radius })
	return true
end

local function fillZones()
	local terrain = Workspace.Terrain
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(122, 98, 74))
	for _, zone in zones do
		terrain:FillBlock(zone.cframe, zone.size + Vector3.new(4, 4, 4), Enum.Material.Air)
		terrain:FillBlock(zone.cframe, zone.size, Enum.Material.Ground)
	end
end

-- One request's result, for the attacker's HUD.
export type Result = { target: string, dealt: number, health: number?, maxHealth: number? }

-- The shared entry point for any future slug: origin/direction are server-known values.
function Destruction.attack(
	origin: Vector3,
	direction: Vector3,
	amount: number,
	archetype: string,
	tier: string,
	ignore: { Instance }
): Result
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(origin, direction.Unit * Config.Requests.Range, params)
	if not hit then
		return { target = "nothing", dealt = 0 }
	end
	local result: Result = { target = "essential rock", dealt = 0 }
	if archetype == "Explosive" then
		damageStructures(hit.Position, Config.Explosive.Radius, amount, archetype, nil)
	end
	local s = byPart[hit.Instance :: BasePart]
	if hit.Instance == Workspace.Terrain then
		local radius = ((Config.Excavation.Radius :: any)[tier] or 3)
			* ((Config.Excavation.Archetype :: any)[archetype] or 1)
		result.target = if Destruction.excavate(hit.Position, radius)
			then "earth (dug)"
			else "earth (limit)"
	elseif s then
		if archetype ~= "Explosive" then
			result.dealt = Destruction.damage(s, amount, archetype, hit.Position)
		end
		result.target, result.health, result.maxHealth = s.id, s.health, s.maxHealth
	else
		send("Hit", { position = hit.Position, strength = amount * 0.2, essential = true })
	end
	if archetype == "Explosive" and hit.Instance ~= Workspace.Terrain then
		Destruction.excavate(hit.Position, (Config.Excavation.Radius :: any)[tier] or 3)
	end
	return result
end

-- Constructive earth: a temporary destructible slab wall in front of the caster.
function Destruction.raise(player: Player, origin: Vector3, look: Vector3): boolean
	if
		tempCount >= Config.Constructive.MaxActive * math.max(1, #Players:GetPlayers()) or not map
	then
		return false
	end
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then
		return false
	end
	flat = flat.Unit
	local base =
		ground(origin + flat * Config.Constructive.Distance + Vector3.new(0, 4, 0), characters())
	local model = Instance.new("Model")
	tempCount += 1
	model.Name = "RaisedSlab" .. tempCount
	model:SetAttribute(
		"Id",
		model.Name .. "_" .. player.UserId .. "_" .. math.floor(os.clock() * 10)
	)
	model:SetAttribute("Category", "Full")
	model:SetAttribute("Kind", "Raised")
	model:SetAttribute("Material", "Stone")
	model:SetAttribute("Health", tostring(Config.Constructive.Health))
	model:SetAttribute("Stages", "2")
	local frame = CFrame.lookAt(base, base + flat)
	for i, offset in { -3.2, 0, 3.2 } do
		local part = Instance.new("Part")
		part.Name = "Slab" .. i
		part.Anchored = true
		part.Material = Enum.Material.Slate
		part.Color = Color3.fromRGB(166, 144, 116)
		part.Size = Vector3.new(3.2, 6 - math.abs(offset) * 0.3, 1.6)
		part.CFrame = frame
			* CFrame.new(offset, part.Size.Y / 2, 0)
			* CFrame.Angles(math.rad(math.random(-6, 6)), 0, math.rad(math.random(-5, 5)))
		part:SetAttribute("Stage", tostring(if i == 2 then 2 else 1))
		part:SetAttribute("Rubble", "Small")
		part.Parent = model
	end
	model.Parent = map:FindFirstChild("Destructibles") or map
	local s = register(model, true, player)
	send("Raise", { position = base, id = s.id })
	local stamp = generation
	task.delay(Config.Constructive.Lifetime, function()
		if generation == stamp and structures[s.id] == s then
			Destruction.damage(s, s.health * 4 + 1, "Blunt", base)
		end
	end)
	return true
end

-- Restores geometry, health, collision, cover, hazards and Terrain exactly.
function Destruction.reset()
	assert(map and pristine and rubble, "Destruction.init must run first")
	generation += 1
	largeRubble, tempCount = 0, 0
	local live = map:FindFirstChild("Destructibles")
	if live then
		live:Destroy()
	end
	rubble:ClearAllChildren()
	structures, byPart = {}, {}
	local fresh = pristine:Clone()
	fresh.Name = "Destructibles"
	fresh.Parent = map
	for _, model in fresh:GetChildren() do
		if model:IsA("Model") then
			register(model)
		end
	end
	fillZones()
	send("Reset", {})
end

function Destruction.init(target: Model, remote: RemoteEvent)
	map, fx = target, remote
	local live = target:WaitForChild("Destructibles") :: Folder
	local copy = live:Clone()
	copy.Name = "RocklockV2Pristine"
	copy.Parent = ServerStorage
	pristine = copy
	local folder = Instance.new("Folder")
	folder.Name = "Rubble"
	folder.Parent = target
	rubble = folder
	local markers = target:FindFirstChild("TerrainZones")
	if markers then
		for _, marker in markers:GetChildren() do
			if marker:IsA("BasePart") then
				table.insert(zones, {
					id = tostring(marker:GetAttribute("Id") or marker.Name),
					kind = tostring(marker:GetAttribute("Kind") or "Crater"),
					cframe = marker.CFrame,
					size = marker.Size,
				})
			end
		end
	end
	Destruction.reset()
end

function Destruction.counts(): (number, number, number)
	local chunks, rubbleCount = 0, 0
	for _ in byPart do
		chunks += 1
	end
	if rubble then
		rubbleCount = #rubble:GetChildren()
	end
	local pristineChunks = 0
	if pristine then
		for _, item in pristine:GetDescendants() do
			if item:IsA("BasePart") then
				pristineChunks += 1
			end
		end
	end
	return chunks, rubbleCount, pristineChunks
end

function Destruction.zones()
	return zones
end

return Destruction
