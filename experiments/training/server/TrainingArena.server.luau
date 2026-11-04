--!strict
-- The training arena, built inside the lobby place so its portal needs no loading screen. The island, rubble, gems and
-- portal are clones of what HubArt already placed; the distant walls and dressing reuse lobby assets; the floor,
-- stations, runestones and dummy are the private authored model (tools/training/build_floor.py).
local CollectionService = game:GetService("CollectionService")
local InsertService = game:GetService("InsertService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local StarterPack = game:GetService("StarterPack")

local Combat = require(ReplicatedStorage:WaitForChild("Combat"))
local LookPack = require(ReplicatedStorage:WaitForChild("LookPack"))
local Motion = require(script.Parent.Motion)
local floorPlan = require(ReplicatedStorage:WaitForChild("TrainingFloor")) :: any
local lobbyLayout =
	require(ReplicatedStorage:WaitForChild("LobbyScale"):WaitForChild("layout")) :: any
local rim = require(ReplicatedStorage:WaitForChild("LobbyScale"):WaitForChild("rim_shape")) :: any
local authoredLayout = require(ServerStorage:WaitForChild("TrainingLayout")) :: any
local draft = require(ServerStorage:WaitForChild("TrainingDraft")) :: { model: number }

local GLYPH_GLOW = 0.9 -- the rune symbols' emissive strength; the lobby's gateway symbols use 1.3
local ORIGIN = Vector3.new(floorPlan.origin[1], floorPlan.origin[2], floorPlan.origin[3])
local SCALE = floorPlan.island.scale :: number
local FALL_Y = -190
local IDLE_RESET = 4
local WARP_GRACE = 1.5

local COLORS: { [string]: Color3 } = {
	iron = Color3.fromRGB(62, 62, 70),
	wood = Color3.fromRGB(112, 74, 44),
	sack = Color3.fromRGB(178, 150, 98),
	bone = Color3.fromRGB(232, 226, 204),
	goo = Color3.fromRGB(150, 196, 74),
	-- Soft mint and amber, painted and lit as the lobby's symbols are rather than neon (owner, 2026-11-03: "too neon").
	glowMove = Color3.fromRGB(140, 222, 200),
	glowTarget = Color3.fromRGB(240, 172, 96),
	-- The fine painted edge under each symbol, a deep shade of its glow.
	edgeMove = Color3.fromRGB(10, 70, 62),
	edgeTarget = Color3.fromRGB(110, 42, 8),
}

local arena = Instance.new("Model")
arena.Name = "TrainingArena"
arena.Parent = workspace

local function world(x: number, y: number, z: number): Vector3
	return ORIGIN + Vector3.new(x, y, z)
end

local function hostile(part: BasePart)
	part.Anchored, part.CanCollide, part.CanTouch = true, false, false
end

local function pointLight(position: Vector3, color: Color3, brightness: number, range: number)
	local holder = Instance.new("Part")
	holder.Name, holder.Size, holder.Transparency = "Light", Vector3.one, 1
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
	holder.Position, holder.Parent = position, arena
	local light = Instance.new("PointLight")
	light.Color, light.Brightness, light.Range, light.Shadows = color, brightness, range, false
	light.Parent = holder
end

-- Clones ------------------------------------------------------------------------------
local function waitForHub(): Instance
	while not workspace:GetAttribute("HubSolid") do
		task.wait(0.25)
	end
	local art: Instance? = nil
	for _, child in workspace:GetDescendants() do
		if child:IsA("Model") and child:FindFirstChild("hub-rock") then
			art = child
			break
		end
	end
	assert(art, "HubArt's model is missing")
	return art
end

-- Strips what the lobby's motion scripts would animate, and scales about the model's world origin.
local function cloneScaled(source: Instance, names: { string }?, transform: CFrame, scale: number)
	for _, item in source:GetDescendants() do
		if item:IsA("MeshPart") and (not names or table.find(names, item.Name)) then
			local part = item:Clone()
			for _, tag in part:GetTags() do
				part:RemoveTag(tag)
			end
			for name in part:GetAttributes() do
				part:SetAttribute(name, nil)
			end
			part.Size = item.Size * scale
			part.CFrame = transform * CFrame.new(item.Position * scale) * item.CFrame.Rotation
			hostile(part)
			part.CanQuery = false
			part.Parent = arena
		end
	end
end

local function buildIsland(art: Instance)
	local home = CFrame.new(ORIGIN)
	local rock = art:FindFirstChild("hub-rock") :: Instance
	cloneScaled(rock, { "Upper", "Lower", "Upper_Ink", "Lower_Ink" }, home, SCALE)
	-- Rubble spread out past the rim and down, so looking over any edge finds it. Bare rock only: the island is plain
	-- for practice, so the rubble's crystals, mushrooms and roots stay in the lobby (owner, 2026-11-03).
	local debris = art:FindFirstChild("hub-rock-debris")
	if debris then
		local random = Random.new(7)
		local rocks = {}
		for index = 0, 2 do
			table.insert(rocks, `Debris{index}`)
			table.insert(rocks, `Debris{index}_Ink`)
		end
		for index = 1, 14 do
			local angle = index * 2.39996
			local reach = (95 + (index % 4) * 32) * SCALE / 3.375
			local place = CFrame.new(
				ORIGIN
					+ Vector3.new(
						math.cos(angle) * reach,
						-20 - (index % 5) * 28,
						math.sin(angle) * reach
					)
			) * CFrame.Angles(0, angle, 0)
			cloneScaled(debris, rocks, place, random:NextNumber(1.2, 2))
		end
	end
end

-- A clone of the lobby's training portal: the way back, in the arena's own frame.
local function lobbyPortalFrame(): (CFrame, { [string]: any })
	for _, entry in lobbyLayout.portals do
		if entry.name == "Training" then
			local rad = math.rad(entry.angle)
			local base =
				Vector3.new(entry.radius * math.sin(rad), entry.rise, -entry.radius * math.cos(rad))
			return CFrame.lookAt(base, Vector3.new(0, base.Y, 0)), entry
		end
	end
	error("No Training portal in the lobby layout")
end

-- The energy is a thin sheet. Fainter, slightly smaller sheets either side make a bulge of juice, kept within the
-- pillars' depth and clear of the frame on every side so none of it shows outside the arch.
local function thicken(portal: Model, frame: CFrame)
	local energy = portal:FindFirstChild("Energy", true) :: MeshPart
	for index, offset in { 0.7, 1.4, 2.1 } do
		for _, side in { 1, -1 } do
			local sheet = energy:Clone()
			for _, tag in sheet:GetTags() do
				sheet:RemoveTag(tag)
			end
			for name in sheet:GetAttributes() do
				sheet:SetAttribute(name, nil)
			end
			sheet:ClearAllChildren()
			sheet.Name = "Juice"
			sheet.TextureID, sheet.Material = "", Enum.Material.Neon
			sheet.Color = Color3.fromRGB(44, 176, 72)
			sheet.Transparency = 0.7 + index * 0.06
			sheet.CanCollide, sheet.CanQuery, sheet.CanTouch, sheet.CastShadow =
				false, false, false, false
			sheet.Size = energy.Size * (1 - index * 0.022)
			sheet.CFrame = energy.CFrame + frame.LookVector * offset * side
			sheet.Parent = energy.Parent
		end
	end
end

-- Sparks that sit over the spiral rather than hide it.
local function quietEmbers(item: Instance)
	for _, embers in item:GetChildren() do
		if embers:IsA("ParticleEmitter") then
			embers.Rate, embers.Brightness = 1.5, 0.8
			embers.Size = NumberSequence.new(0.35, 0.08)
		end
	end
end

-- The spiral and embers sit beside the portal in HubArt's model, one set per portal.
local function portalEffects(art: Instance, energy: BasePart): { BasePart }
	local found = {}
	for _, item in art:GetChildren() do
		if
			item:IsA("BasePart")
			and (string.sub(item.Name, 1, 13) == "PortalSurface" or item.Name == "PortalEmbers")
			and (item.Position - energy.Position).Magnitude < 6
		then
			table.insert(found, item)
		end
	end
	return found
end

local function buildReturnPortal(art: Instance)
	local source = art:FindFirstChild("hub-portal-training") :: Model
	local lobbyFrame_ = lobbyPortalFrame()
	thicken(source, lobbyFrame_)
	local effects = portalEffects(art, source:FindFirstChild("Energy", true) :: BasePart)
	-- The spiral rides the bulge's outer face, or the juice would cover it.
	for _, item in effects do
		if string.sub(item.Name, 1, 13) == "PortalSurface" then
			item.CFrame += item.CFrame.LookVector * 2
		else
			quietEmbers(item)
		end
	end
	local copy = source:Clone()
	for _, item in copy:GetDescendants() do
		if item:IsA("BasePart") then
			for _, tag in item:GetTags() do
				if tag ~= "HubPulse" then
					item:RemoveTag(tag)
				end
			end
		end
	end
	local at = floorPlan.arrival.portal
	local position = world(at[1], at[2], at[3])
	local frame = CFrame.lookAt(position, position + Vector3.new(0, 0, -1))
	local from = lobbyPortalFrame()
	local across = frame * from:Inverse()
	copy:PivotTo(across * source:GetPivot())
	-- This one faces the sun, which the lobby's doesn't, so the glow comes down to leave room for the spiral.
	local field = (copy:FindFirstChild("Energy", true) :: Instance):FindFirstChildOfClass(
		"SurfaceAppearance"
	)
	if field then
		field.EmissiveStrength = 0.8
	end
	copy.Parent = arena
	for _, item in effects do
		local twin = item:Clone()
		twin.CFrame = across * item.CFrame
		-- In the sun the spiral needs more strength to show as well as the lobby's.
		for _, e in twin:GetChildren() do
			if e:IsA("ParticleEmitter") and string.sub(e.Name, 1, 5) == "Swirl" then
				local keys = {}
				for _, key in e.Transparency.Keypoints do
					table.insert(
						keys,
						NumberSequenceKeypoint.new(key.Time, 1 - (1 - key.Value) * 1.3)
					)
				end
				e.Transparency = NumberSequence.new(keys)
			end
		end
		twin.Parent = copy
	end
	pointLight(position + Vector3.new(0, 8, -4), Color3.fromRGB(107, 255, 115), 0.6, 14)
end

-- Lobby assets ------------------------------------------------------------------------
local function bounds(model: Instance): (Vector3, Vector3)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, part in model:GetDescendants() do
		if part:IsA("MeshPart") then
			lo, hi = lo:Min(part.Position - part.Size / 2), hi:Max(part.Position + part.Size / 2)
		end
	end
	return lo, hi
end

local function style(part: MeshPart, template: Instance?, emissive: number?)
	for _, child in part:GetChildren() do
		if child:IsA("SurfaceAppearance") then
			child:Destroy()
		end
	end
	hostile(part)
	part.CanQuery = false
	part.TextureID, part.Material, part.Color = "", Enum.Material.SmoothPlastic, Color3.new(1, 1, 1)
	if string.find(part.Name, "_Ink", 1, true) then
		part.Color, part.Material, part.CastShadow = LookPack.INK, Enum.Material.Neon, false
	elseif template then
		local surface = template:Clone() :: SurfaceAppearance
		surface.EmissiveStrength = emissive or 0
		surface.Parent = part
	end
end

-- Nothing but black past the island: the lobby is out there too, 6000 studs away (owner, 2026-11-03). An unlit
-- black box, casting no shadow and invisible to rays and the camera's collision, sealed on every side.
local VOID_REACH, VOID_TOP, VOID_BOTTOM = 520, 320, -420
local function buildVoid()
	local void = Instance.new("Folder")
	void.Name = "TrainingVoid"
	void.Parent = arena
	local span, height = VOID_REACH * 2 + 8, VOID_TOP - VOID_BOTTOM + 8
	local middle = (VOID_TOP + VOID_BOTTOM) / 2
	for _, spec in
		{
			{ Vector3.new(span, 4, span), Vector3.new(0, VOID_TOP, 0) },
			{ Vector3.new(span, 4, span), Vector3.new(0, VOID_BOTTOM, 0) },
			{ Vector3.new(4, height, span), Vector3.new(VOID_REACH, middle, 0) },
			{ Vector3.new(4, height, span), Vector3.new(-VOID_REACH, middle, 0) },
			{ Vector3.new(span, height, 4), Vector3.new(0, middle, VOID_REACH) },
			{ Vector3.new(span, height, 4), Vector3.new(0, middle, -VOID_REACH) },
		}
	do
		local wall = Instance.new("Part")
		wall.Name, wall.Size, wall.Position = "Void", spec[1], ORIGIN + spec[2]
		-- Black neon gives off nothing, so no light or ambient can grey it.
		wall.Color, wall.Material = Color3.new(0, 0, 0), Enum.Material.Neon
		wall.Anchored, wall.CanCollide, wall.CanQuery, wall.CanTouch = true, false, false, false
		wall.CastShadow = false
		wall.Parent = void
	end
end

-- Authored model ----------------------------------------------------------------------
local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local dummyParts: { MeshPart } = {}

local function buildAuthored()
	local container = InsertService:LoadAsset(draft.model)
	local model = Instance.new("Model")
	for _, item in container:GetDescendants() do
		if item:IsA("MeshPart") and authoredLayout.authored[item.Name] then
			item.Parent = model
		end
	end
	container:Destroy()
	-- Fit against the recorded bounds: true size, then the importer's turn, then position.
	local lo, hi = bounds(model)
	local wantLo, wantHi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, spec in authoredLayout.authored do
		wantLo, wantHi = wantLo:Min(v3(spec.min)), wantHi:Max(v3(spec.max))
	end
	local size, want = hi - lo, wantHi - wantLo
	model:ScaleTo(
		model:GetScale() * math.max(want.X, want.Y, want.Z) / math.max(size.X, size.Y, size.Z)
	)
	lo, hi = bounds(model)
	local center, targetCenter = (lo + hi) / 2, (wantLo + wantHi) / 2
	local best, smallest = CFrame.identity, math.huge
	for _, turn in { CFrame.identity, CFrame.Angles(0, math.pi, 0) } do
		local total = 0
		for _, part in model:GetChildren() do
			local spec = authoredLayout.authored[part.Name]
			if part:IsA("MeshPart") and spec then
				local wantCenter = (v3(spec.min) + v3(spec.max)) / 2
				total += (
					turn:VectorToWorldSpace(part.Position - center) - (wantCenter - targetCenter)
				).Magnitude
			end
		end
		if total < smallest then
			smallest, best = total, turn
		end
	end
	model:PivotTo(CFrame.new(targetCenter + ORIGIN) * best * CFrame.new(-center) * model:GetPivot())
	print(
		string.format(
			"[Training] authored fit error %.2f over %d parts",
			smallest,
			#model:GetChildren()
		)
	)
	local materials = ServerStorage:WaitForChild("TrainingMaterials")
	for _, part in model:GetChildren() do
		if not part:IsA("MeshPart") then
			continue
		end
		local spec = authoredLayout.authored[part.Name]
		local klass = spec.class :: string
		local template = if klass == "stone"
			then materials:FindFirstChild("StonePaint")
			elseif klass == "floor" then materials:FindFirstChild("FloorPaint")
			elseif klass == "rune" then materials:FindFirstChild("RunePaint")
			elseif string.sub(klass, 1, 4) == "glow" then materials:FindFirstChild(
				"GlyphPaint"
			)
			else nil
		style(part, template, 0)
		if klass == "ink" then
			part.Color, part.Material = LookPack.INK, Enum.Material.Neon
		elseif COLORS[klass] then
			part.Color = COLORS[klass]
			local paint = part:FindFirstChildOfClass("SurfaceAppearance")
			if string.sub(klass, 1, 4) == "glow" and paint then
				paint.Color, paint.EmissiveTint = COLORS[klass], COLORS[klass]
				paint.EmissiveStrength = GLYPH_GLOW
				part.CastShadow = false
			end
		end
		if string.sub(part.Name, 1, 5) == "Dummy" then
			part.Parent = nil
			table.insert(dummyParts, part)
		else
			part.Parent = arena
		end
	end
	model:Destroy()
end

-- Collision ---------------------------------------------------------------------------
-- Plain invisible boxes, exactly as the movement code expects: flat wall-run faces and clean ledges.
local solids = Instance.new("Folder")
solids.Name = "TrainingSolids"
solids.Parent = arena

local function solid(x: number, z: number, size: { number }, base: number?)
	local part = Instance.new("Part")
	part.Name, part.Anchored, part.Transparency = "Solid", true, 1
	part.CanTouch = false
	part.Size = v3(size)
	part.Position = world(x, (base or 0) + size[2] / 2, z)
	part.Parent = solids
end

local function triangle(a: Vector3, b: Vector3, c: Vector3)
	local ab, ac, bc = b - a, c - a, c - b
	if ab:Dot(ab) > ac:Dot(ac) and ab:Dot(ab) > bc:Dot(bc) then
		c, a = a, c
	elseif ac:Dot(ac) > bc:Dot(bc) then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right, back = ac:Cross(ab).Unit, bc.Unit
	local up = bc:Cross(right).Unit
	local width = math.abs(ab:Dot(up))
	for _, spec in
		{
			{ p = (a + b) / 2, r = right, z = back, length = math.abs(ab:Dot(back)) },
			{ p = (a + c) / 2, r = -right, z = -back, length = math.abs(ac:Dot(back)) },
		}
	do
		if spec.length > 0.001 then
			local wedge = Instance.new("WedgePart")
			wedge.Name, wedge.Anchored, wedge.Transparency = "Footing", true, 1
			wedge.CanTouch = false
			wedge.Size = Vector3.new(0.8, width, spec.length)
			wedge.CFrame = CFrame.fromMatrix(spec.p, spec.r, up, spec.z)
			wedge.Parent = solids
		end
	end
end

local function buildCollision()
	local outline = rim.rock :: { number }
	local middle = world(0, -0.37, 0)
	for i, r in outline do
		local j = i % #outline + 1
		local a, b = (i - 1) * 2 * math.pi / #outline, i * 2 * math.pi / #outline
		triangle(
			middle,
			world(math.sin(a) * r * SCALE, -0.37, -math.cos(a) * r * SCALE),
			world(math.sin(b) * outline[j] * SCALE, -0.37, -math.cos(b) * outline[j] * SCALE)
		)
	end
	local course, shooting = floorPlan.course, floorPlan.range
	for _, group in
		{
			course.vaults,
			course.mantles,
			course.jumps,
			course.wallRun,
			course.climb,
			shooting.cover,
		}
	do
		for _, item in group do
			solid(item.x, item.z, item.size)
		end
	end
	local lane = course.slideLane
	for _, side in { -1, 1 } do
		solid(lane.x, lane.z + side * lane.width / 2, { lane.length, 0.5, 1.2 })
	end
	local line = shooting.line
	solid((line.from + line.to) / 2, line.z, { line.to - line.from, 0.3, 1 })
	for _, item in shooting.raised do
		solid(item.x, shooting.firingZ - item.distance, { 10, item.height, 10 })
	end
	-- The runestones are turned a little; an upright box inside each is all a player needs to bump.
	for _, spec in floorPlan.runes do
		for index, at in spec.stones do
			solid(at[1], at[2], { 5.6, if index == 1 then 11 else 9.2, 3 })
		end
	end
end

local function buildLights()
	for _, spec in floorPlan.runes do
		local color = Color3.fromRGB(spec.color[1], spec.color[2], spec.color[3])
		for index, at in spec.stones do
			-- In front of the symbol on the side you arrive from, so it washes the stone and the ground.
			pointLight(world(at[1], if index == 1 then 7 else 6, at[2] + 3), color, 0.45, 11)
		end
	end
	local at = floorPlan.station.at
	pointLight(world(at[1], 3.5, at[2] + 2.5), COLORS.glowTarget, 0.35, 8)
end

-- The station: walk up and press F. The client draws the prompt and the panel.
local function buildStation()
	local at = floorPlan.station.at
	local holder = Instance.new("Part")
	holder.Name, holder.Size, holder.Transparency = "DummyStation", Vector3.one, 1
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
	holder.Position = world(at[1], 4.2, at[2])
	holder.Parent = arena
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TrainingDummyPrompt"
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.ActionText = "Dummy settings"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 13
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = holder
	solid(at[1], at[2], { 4.8, 4.2, 2.8 })
end

-- Dummies -----------------------------------------------------------------------------
local dummies = Instance.new("Folder")
dummies.Name = "TrainingDummies"
dummies.Parent = arena

local maxHealth = floorPlan.range.defaults.health :: number
local speedShared = floorPlan.range.defaults.speed :: number
type Mover = { model: Model, home: CFrame, motion: Motion.State }
local movers: { Mover } = {}

-- Knocked out, a dummy tips straight back about the back edge of its base, bounces once on the ground, then swings back
-- up with a little spring past upright, at full health (owner, 2026-11-03). Dummies face +Z, toward the firing line.
local FALL, LIE, RISE = 0.3, 0.55, 0.45
local KO_RESET = FALL + LIE + RISE
local FLAT = math.rad(84)
local HINGE = Vector3.new(0, -4.2, -2.3) -- from the root: the base's back edge, at the feet
local downAt: { [Model]: number } = {}
local homes: { [Model]: CFrame } = {}

local function tilt(since: number): number
	if since < FALL then
		local u = since / FALL
		return FLAT * u * u
	elseif since < FALL + LIE then
		local u = (since - FALL) / LIE
		return FLAT - math.rad(7) * math.sin(math.pi * math.min(u / 0.35, 1))
	elseif since < KO_RESET then
		local u = (since - FALL - LIE) / RISE - 1
		-- Ease out with overshoot: it rises a touch past upright and settles.
		return FLAT * -(2.70158 * u * u * u + 1.70158 * u * u)
	end
	return 0
end

local function tipped(base: CFrame, angle: number): CFrame
	if angle == 0 then
		return base
	end
	local hinge = base.Position + HINGE
	return CFrame.new(hinge) * CFrame.Angles(-angle, 0, 0) * CFrame.new(-hinge) * base
end

local function spawnDummy(name: string, feet: Vector3): Model
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name, root.Size, root.Transparency = "HumanoidRootPart", Vector3.new(2, 2, 1), 1
	root.Anchored, root.CanCollide = true, false
	root.CFrame = CFrame.new(feet + Vector3.new(0, 4.2, 0))
	root.Parent = model
	model.PrimaryPart = root
	for _, source in dummyParts do
		local part = source:Clone()
		-- The authored dummy stands at the arena's origin; move it to these feet. Combat finds the Head and body by name.
		part.CFrame = part.CFrame + (feet - ORIGIN)
		part.Name = string.gsub(part.Name, "^Dummy", "")
		part.CanQuery = not string.find(part.Name, "_Ink", 1, true) and part.Name ~= "Base"
		part.Parent = model
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.RequiresNeck, humanoid.BreakJointsOnDeath = false, false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.MaxHealth, humanoid.Health = maxHealth, maxHealth
	humanoid.Parent = model
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	model:SetAttribute("SessionDamage", 0)
	model:SetAttribute("Hits", 0)
	model:SetAttribute("KOs", 0)
	CollectionService:AddTag(model, "RangeDummy")
	model.Parent = dummies
	homes[model] = model:GetPivot()
	local knocked = false
	humanoid.HealthChanged:Connect(function(health)
		if health <= 0 and not knocked then
			knocked = true
			model:SetAttribute("KOs", ((model:GetAttribute("KOs") or 0) :: number) + 1)
			downAt[model] = os.clock()
			task.delay(KO_RESET, function()
				humanoid.Health = humanoid.MaxHealth
				knocked = false
			end)
		end
	end)
	return model
end

local function buildDummies()
	local shooting = floorPlan.range
	local z = shooting.firingZ
	for _, lane in shooting.still do
		spawnDummy(`Still {lane.distance}`, world(lane.x, 0, z - lane.distance))
	end
	for _, spot in shooting.raised do
		spawnDummy(`Raised {spot.distance}`, world(spot.x, spot.height, z - spot.distance))
	end
	for index, lane in shooting.moving do
		local model = spawnDummy(`Moving {lane.distance}`, world(lane.x, 0, z - lane.distance))
		local motion = Motion.new()
		motion.radius, motion.speed, motion.phase = lane.halfWidth, speedShared, index * 1.3
		table.insert(movers, { model = model, home = model:GetPivot(), motion = motion })
	end
end

local settingsRemote = Instance.new("RemoteEvent")
settingsRemote.Name = "TrainingDummySettings"
settingsRemote.Parent = ReplicatedStorage

local function publishSettings()
	workspace:SetAttribute("TrainingDummyHealth", maxHealth)
	workspace:SetAttribute("TrainingDummySpeed", speedShared)
end
publishSettings()

local requests: { [Player]: number } = {}
settingsRemote.OnServerEvent:Connect(function(player: Player, kind: any, value: any)
	local now = os.clock()
	if now - (requests[player] or -math.huge) < 0.08 or not player:GetAttribute("InTraining") then
		return
	end
	requests[player] = now
	local limits = floorPlan.range.defaults
	if typeof(value) ~= "number" or value ~= value then
		return
	end
	if kind == "Speed" then
		for _, mover in movers do
			if not Motion.setSpeed(mover.motion, value) then
				return
			end
		end
		speedShared = value
	elseif kind == "Health" and value >= limits.minHealth and value <= limits.maxHealth then
		maxHealth = math.round(value)
		for _, model in CollectionService:GetTagged("RangeDummy") do
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.MaxHealth, humanoid.Health = maxHealth, maxHealth
			end
		end
	else
		return
	end
	publishSettings()
end)

-- The same statistics as the temporary range, for the same readout client.
local function watchHits()
	local feed = ServerStorage:WaitForChild("SlugshotCombatHit") :: BindableEvent
	feed.Event:Connect(function(_shooter: Player, victim: Model, damage: number, distance: number)
		if not CollectionService:HasTag(victim, "RangeDummy") then
			return
		end
		local now = workspace:GetServerTimeNow()
		local last = victim:GetAttribute("LastHit") :: number?
		if not last or now - last > IDLE_RESET then
			victim:SetAttribute("SessionStart", now)
			victim:SetAttribute("SessionDamage", 0)
			victim:SetAttribute("Hits", 0)
		end
		victim:SetAttribute(
			"SessionDamage",
			((victim:GetAttribute("SessionDamage") or 0) :: number) + damage
		)
		victim:SetAttribute("Hits", ((victim:GetAttribute("Hits") or 0) :: number) + 1)
		victim:SetAttribute("LastHit", now)
		victim:SetAttribute("LastDamage", damage)
		victim:SetAttribute("LastDistance", distance)
	end)
end

RunService.Heartbeat:Connect(function(dt)
	local clock = os.clock()
	-- A moving dummy holds its place on its track while it is down.
	for _, mover in movers do
		local base = mover.home
			+ Vector3.new(Motion.step(mover.motion, if downAt[mover.model] then 0 else dt), 0, 0)
		homes[mover.model] = base
		if not downAt[mover.model] then
			mover.model:PivotTo(base)
		end
	end
	for model, at in downAt do
		local since = clock - at
		local base = homes[model]
		if since >= KO_RESET then
			downAt[model] = nil
			model:PivotTo(base)
		else
			model:PivotTo(tipped(base, tilt(since)))
		end
	end
	local now = workspace:GetServerTimeNow()
	for _, model in CollectionService:GetTagged("RangeDummy") do
		local last = model:GetAttribute("LastHit") :: number?
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if
			last
			and now - last > IDLE_RESET
			and humanoid
			and humanoid.Health > 0
			and humanoid.Health < humanoid.MaxHealth
		then
			humanoid.Health = humanoid.MaxHealth
		end
	end
end)

-- The zone ----------------------------------------------------------------------------
local portalRemote = Instance.new("RemoteEvent")
portalRemote.Name = "TrainingPortal"
portalRemote.Parent = ReplicatedStorage

local function isBlaster(item: Instance): boolean
	return Combat.isBlaster(item)
end

local function setArmed(player: Player, armed: boolean)
	local character, backpack = player.Character, player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	local carried: any = nil
	for _, holder in { character, backpack } :: { any } do
		for _, item in holder:GetChildren() do
			if isBlaster(item) then
				if armed then
					carried = item
				else
					item:Destroy()
				end
			end
		end
	end
	if armed then
		if not carried then
			local tool = StarterPack:FindFirstChild("Blaster")
			if tool then
				local copy = tool:Clone() :: Tool
				copy.Parent = backpack
				carried = copy
			end
		end
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if carried and humanoid then
			carried:SetAttribute("HoldStyle", "Pistol")
			humanoid:EquipTool(carried)
		end
	end
end

local function warp(player: Player, frame: CFrame)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root then
		return
	end
	-- The movement server's motion check takes this as a legal move.
	player:SetAttribute("TrainingWarpUntil", workspace:GetServerTimeNow() + WARP_GRACE)
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(frame)
end

local function arrivalFrame(): CFrame
	local at = floorPlan.arrival.spawn
	local position = world(at[1], at[2], at[3])
	return CFrame.lookAt(position, position + Vector3.new(0, 0, -1))
end

-- You come out just clear of the far portal, the same distance across its opening as you went in.
local THROUGH = 8
local function throughFrame(portal: CFrame, lateral: number): CFrame
	local position = portal.Position
		+ portal.LookVector * THROUGH
		+ portal.RightVector * math.clamp(lateral, -8, 8)
		+ Vector3.new(0, 3.6, 0)
	return CFrame.lookAt(position, position + portal.LookVector)
end

local function arenaPortalFrame(): CFrame
	local at = floorPlan.arrival.portal
	local position = world(at[1], at[2], at[3])
	return CFrame.lookAt(position, position + Vector3.new(0, 0, -1))
end

local lastUse: { [Player]: number } = {}
local function near(player: Player, position: Vector3, reach: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - position).Magnitude <= reach
end

portalRemote.OnServerEvent:Connect(function(player: Player, action: any, lateral: any)
	if typeof(lateral) ~= "number" or lateral ~= lateral then
		return
	end
	local now = os.clock()
	if now - (lastUse[player] or -math.huge) < 1 or not workspace:GetAttribute("TrainingReady") then
		return
	end
	if action == "Enter" and not player:GetAttribute("InTraining") then
		if near(player, lobbyPortalFrame().Position, 26) then
			lastUse[player] = now
			warp(player, throughFrame(arenaPortalFrame(), lateral))
			player:SetAttribute("InTraining", true)
			setArmed(player, true)
		end
	elseif action == "Exit" and player:GetAttribute("InTraining") then
		local at = floorPlan.arrival.portal
		if near(player, world(at[1], at[2], at[3]), 26) then
			lastUse[player] = now
			setArmed(player, false)
			player:SetAttribute("InTraining", false)
			warp(player, throughFrame((lobbyPortalFrame()), lateral))
		end
	end
end)

local function watch(player: Player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 15)
		task.wait(0.1)
		if player.Character ~= character then
			return
		end
		if player:GetAttribute("InTraining") then
			warp(player, arrivalFrame())
			setArmed(player, true)
		else
			setArmed(player, false)
		end
	end)
	if player.Character then
		setArmed(player, player:GetAttribute("InTraining") == true)
	end
end
Players.PlayerAdded:Connect(watch)
for _, player in Players:GetPlayers() do
	watch(player)
end
Players.PlayerRemoving:Connect(function(player)
	lastUse[player], requests[player] = nil, nil
end)

-- Falling off lands you back at the arrival pad, long before the lobby's own respawn depth.
task.spawn(function()
	while true do
		task.wait(0.2)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and player:GetAttribute("InTraining") and root.Position.Y < FALL_Y then
				warp(player, arrivalFrame())
			end
			-- The blaster reaches backpacks whenever its build finishes, so the lobby is kept clear rather than cleared once.
			if not player:GetAttribute("InTraining") then
				setArmed(player, false)
			end
		end
	end
end)

-- Build -------------------------------------------------------------------------------
local started = os.clock()
local art = waitForHub()
buildIsland(art)
buildAuthored()
buildCollision()
buildLights()
buildReturnPortal(art)
buildVoid()
buildStation()
buildDummies()
watchHits()
workspace:SetAttribute("TrainingReady", true)
print(
	string.format(
		"[Training] READY in %.1fs, %d arena parts",
		os.clock() - started,
		#arena:GetDescendants()
	)
)
