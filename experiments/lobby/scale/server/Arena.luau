--!strict
-- Plain, colour-coded lobby block-out for judging distance and layout (docs/art/lobby-roadmap.md). Every
-- number comes from layout.json, which also draws the top-down plan. Replaces the movement lab's map.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local layout = require(ReplicatedStorage:WaitForChild("LobbyScale"):WaitForChild("layout")) :: any

type Options = {
	ghost: boolean?, -- no collision, queries or touches: scenery the player and movement ignore
	neon: boolean?,
	transparency: number?,
	ball: boolean?,
}

local Arena = {}

local SECTOR = 360 / layout.sectors
local shore = layout.shore
local route = layout.route
local GROUND = Color3.fromRGB(82, 84, 98)
local WALL = Color3.fromRGB(58, 62, 76)
local CEILING = Color3.fromRGB(46, 50, 62)
local LIP = Color3.fromRGB(112, 116, 132)
local ROCK = Color3.fromRGB(142, 146, 162)
local PLANK = Color3.fromRGB(150, 108, 66)
local ROPE = Color3.fromRGB(205, 186, 138)
local WATER = Color3.fromRGB(70, 190, 200)
local LAVA = Color3.fromRGB(255, 120, 40)
local STEM = Color3.fromRGB(190, 182, 160)
local CAP = Color3.fromRGB(90, 220, 170)
local SLUG = Color3.fromRGB(226, 226, 96)
local LIGHT = Color3.fromRGB(235, 240, 225)
local IRON = Color3.fromRGB(70, 72, 84)
local MOUTH = Color3.fromRGB(126, 130, 158)

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local function polar(angle: number, radius: number, y: number): Vector3
	local rad = math.rad(angle)
	return Vector3.new(radius * math.sin(rad), y, -radius * math.cos(rad))
end

local function wrap(angle: number): number
	return (angle + 180) % 360 - 180
end

local function within(angle: number, from: number, to: number): boolean
	return (angle - from) % 360 <= (to - from) % 360
end

local function style(part: BasePart, color: Color3, parent: Instance, options: Options?)
	local chosen: Options = options or {}
	part.Anchored = true
	part.Color = color
	part.Material = if chosen.neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.Transparency = chosen.transparency or 0
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if chosen.ghost then
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
	end
	part.Parent = parent
end

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	frame: CFrame,
	color: Color3,
	options: Options?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = if options and options.ball then Enum.PartType.Ball else Enum.PartType.Block
	part.Size = size
	part.CFrame = frame
	style(part, color, parent, options)
	return part
end

-- A vertical cylinder, centred on position.
local function disc(
	parent: Instance,
	name: string,
	length: number,
	diameter: number,
	position: Vector3,
	color: Color3,
	options: Options?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(length, diameter, diameter)
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
	style(part, color, parent, options)
	return part
end

-- A slab between two points, with its top surface on the line from a to b.
local function beam(
	parent: Instance,
	name: string,
	a: Vector3,
	b: Vector3,
	width: number,
	thickness: number,
	color: Color3,
	options: Options?
): Part
	return block(
		parent,
		name,
		Vector3.new(width, thickness, (b - a).Magnitude),
		CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, -thickness / 2, 0),
		color,
		options
	)
end

-- A filled triangle from two WedgeParts, with its surface on abc and its thickness below it.
local function triangle(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	color: Color3,
	thickness: number,
	options: Options?
)
	if (b - a):Cross(c - a).Magnitude < 0.01 then
		return
	end
	local ab, ac, bc = b - a, c - a, c - b
	local abLength, acLength, bcLength = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abLength > acLength and abLength > bcLength then
		a, c = c, a
	elseif acLength > bcLength and acLength > abLength then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	local offset = (if right.Y >= 0 then -right else right) * thickness / 2
	local function wedge(mid: Vector3, depth: number, x: Vector3, z: Vector3)
		if depth < 0.05 then
			return
		end
		local part = Instance.new("WedgePart")
		part.Name = "Surface"
		part.Size = Vector3.new(thickness, height, depth)
		part.CFrame = CFrame.fromMatrix(mid + offset, x, up, z)
		style(part, color, parent, options)
	end
	wedge((a + b) / 2, math.abs(ab:Dot(back)), right, back)
	wedge((a + c) / 2, math.abs(ac:Dot(back)), -right, -back)
end

local function quad(
	parent: Instance,
	a: Vector3,
	b: Vector3,
	c: Vector3,
	d: Vector3,
	color: Color3,
	thickness: number,
	options: Options?
)
	triangle(parent, a, b, c, color, thickness, options)
	triangle(parent, a, c, d, color, thickness, options)
end

-- A surface of revolution about a vertical axis through center; profile rows are { radius, y }.
local function lathe(
	parent: Instance,
	center: Vector3,
	profile: { { number } },
	sides: number,
	color: Color3,
	thickness: number
)
	local step = 360 / sides
	for side = 0, sides - 1 do
		local a1, a2 = side * step, (side + 1) * step
		for row = 1, #profile - 1 do
			local p, q = profile[row], profile[row + 1]
			quad(
				parent,
				center + polar(a1, p[1], p[2]),
				center + polar(a2, p[1], p[2]),
				center + polar(a2, q[1], q[2]),
				center + polar(a1, q[1], q[2]),
				color,
				thickness
			)
		end
	end
end

-- A wall panel standing on one sector of a circle, centred on radius.
local function panel(
	parent: Instance,
	name: string,
	angle: number,
	radius: number,
	bottom: number,
	top: number,
	thickness: number,
	color: Color3,
	sector: number?
)
	local width = 2 * radius * math.tan(math.rad((sector or SECTOR) / 2)) + 0.2
	local position = polar(angle, radius, (bottom + top) / 2)
	block(
		parent,
		name,
		Vector3.new(width, top - bottom, thickness),
		CFrame.lookAt(position, Vector3.new(0, position.Y, 0)),
		color
	)
end

local function label(parent: Instance, text: string, position: Vector3)
	local anchor = block(
		parent,
		"Label",
		Vector3.one,
		CFrame.new(position),
		LIGHT,
		{ ghost = true, transparency = 1 }
	)
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(230, 34)
	board.AlwaysOnTop = true
	board.MaxDistance = 700
	board.LightInfluence = 0
	board.Parent = anchor
	local line = Instance.new("TextLabel")
	line.Size = UDim2.fromScale(1, 1)
	line.BackgroundTransparency = 1
	line.Font = Enum.Font.GothamBold
	line.TextScaled = true
	line.TextColor3 = LIGHT
	line.TextStrokeTransparency = 0.2
	line.Text = text
	line.Parent = board
end

local function folder(parent: Instance, name: string): Folder
	local made = Instance.new("Folder")
	made.Name = name
	made.Parent = parent
	return made
end

local function mushroom(parent: Instance, base: Vector3, height: number)
	disc(parent, "Stem", height, height * 0.16, base + Vector3.new(0, height / 2, 0), STEM)
	disc(parent, "Cap", height * 0.14, height * 0.75, base + Vector3.new(0, height, 0), CAP)
end

local function routeY(angle: number): number
	local points = route.points
	for index = 1, #points - 1 do
		local p, q = points[index], points[index + 1]
		if angle <= q.angle then
			return p.y + (q.y - p.y) * (angle - p.angle) / (q.angle - p.angle)
		end
	end
	return points[#points].y
end

local function zoneColor(angle: number, radius: number): Color3?
	local ravine = layout.ravine
	if
		within(angle, ravine.from, ravine.to)
		and radius > ravine.innerRadius
		and radius < ravine.outerRadius
	then
		return nil
	end
	local growth = layout.overgrowth
	if
		within(angle, growth.from, growth.to)
		and radius > growth.innerRadius
		and radius < growth.outerRadius
	then
		return rgb(growth.color)
	end
	for _, zone in layout.zones do
		if within(angle, zone.from, zone.to) then
			return rgb(zone.color)
		end
	end
	return GROUND
end

-- The concept measures its angles from +X toward +Z, in units of 5 studs.
local function conceptAngle(angle: number): number
	local rad = math.rad(angle)
	return math.atan2(-math.cos(rad), math.sin(rad))
end

local function rockRim(angle: number): number
	local a = conceptAngle(angle)
	return 5
		* 7
		* (1 + 0.05 * math.sin(a * 3 + 1) + 0.035 * math.sin(a * 7 + 2.1) + 0.02 * math.sin(a * 13))
end

local function pitEdge(angle: number): number
	local a = conceptAngle(angle)
	return 5 * (17.6 + 0.45 * math.sin(a * 5 + 1) + 0.3 * math.sin(a * 11 + 2))
end

local function buildSpawnRock(root: Instance)
	local rock = layout.spawnRock
	local parent = folder(root, "SpawnRock")
	local depth = rock.undersideDepth
	local step = 360 / rock.sides
	for side = 0, rock.sides - 1 do
		local a1, a2 = side * step, (side + 1) * step
		triangle(
			parent,
			Vector3.zero,
			polar(a1, rockRim(a1), 0),
			polar(a2, rockRim(a2), 0),
			ROCK,
			3
		)
	end
	lathe(folder(parent, "Underside"), Vector3.zero, {
		{ rock.radius, 0 },
		{ rock.radius * 0.72, -depth * 0.4 },
		{ rock.radius * 0.3, -depth * 0.8 },
		{ 0, -depth },
	}, rock.sides, WALL, 2)
	label(parent, `SPAWN ROCK  {rock.radius * 2} across`, Vector3.new(0, 14, 0))
end

local RIM_WIDTH = 104 -- where the hub's cliff art ends

local function buildShore(root: Instance)
	local parent = folder(root, "Shore")
	local radii = layout.floorRadii
	local rimStrip = folder(parent, "RimStrip")
	for sector = 0, layout.sectors - 1 do
		local a1 = sector * SECTOR - 180
		local a2 = a1 + SECTOR
		local middle = (a1 + a2) / 2
		-- Runs of equal colour merge into one cell to keep the part count down.
		local start = radii[1]
		for band = 1, #radii - 1 do
			local color = zoneColor(middle, (radii[band] + radii[band + 1]) / 2)
			local nextColor = if band < #radii - 1
				then zoneColor(middle, (radii[band + 1] + radii[band + 2]) / 2)
				else nil
			if color ~= nextColor then
				if color then
					local atPit = start == radii[1]
					local from = if atPit then RIM_WIDTH else start
					quad(
						parent,
						polar(a1, from, 0),
						polar(a2, from, 0),
						polar(a2, radii[band + 1], 0),
						polar(a1, radii[band + 1], 0),
						color,
						shore.thickness
					)
					-- The strip around the pit is its own piece, because the hub's rim art replaces how it looks.
					if atPit then
						quad(
							rimStrip,
							polar(a1, pitEdge(a1), 0),
							polar(a2, pitEdge(a2), 0),
							polar(a2, from, 0),
							polar(a1, from, 0),
							color,
							shore.thickness
						)
					end
				end
				start = radii[band + 1]
			end
		end
		-- A hop-over rock lip on the cliff edge, open where a bridge lands.
		local onBridge = false
		for _, angle in layout.bridges.angles do
			onBridge = onBridge or math.abs(wrap(middle - angle)) < SECTOR
		end
		if not onBridge then
			panel(
				parent,
				"Lip",
				middle,
				pitEdge(middle) + 2.75,
				0,
				shore.lipHeight,
				shore.lipWidth,
				LIP
			)
		end
	end
	-- Ground-level distance ticks from the bridge to the PvP gate.
	for radius = 100, 140, 20 do
		block(
			parent,
			"DistanceTick",
			Vector3.new(14, 0.05, 0.5),
			CFrame.new(polar(0, radius, 0.03)),
			LIGHT,
			{ ghost = true }
		)
		label(parent, `{radius} from centre`, polar(0, radius, 2))
	end
end

local function buildBridges(root: Instance)
	local bridges = layout.bridges
	local parent = folder(root, "Bridges")
	for index, angle in bridges.angles do
		local bridge = folder(parent, `Bridge{angle}`)
		local side = polar(angle + 90, bridges.width / 2 + 0.4, 0)
		-- Each bridge's span is set by how close its gateway stands to the island's edge.
		local centre = 5 * (bridges.gates[tostring(index - 1)] + 5.55)
		local inner, outer = centre - 25.5, centre + 25.5
		local function deck(t: number): Vector3
			-- A parabola: level at both ends, lowest by sag at the middle.
			local sag = bridges.sag * (1 - (2 * t - 1) ^ 2)
			return polar(angle, inner + (outer - inner) * t, -sag)
		end
		-- Short level pieces where it meets the rock and the shore, so nobody catches an edge.
		beam(
			bridge,
			"Plank",
			polar(angle, inner - 4, 0),
			polar(angle, inner, 0),
			bridges.width,
			1,
			PLANK
		)
		beam(
			bridge,
			"Plank",
			polar(angle, outer, 0),
			polar(angle, outer + 4, 0),
			bridges.width,
			1,
			PLANK
		)
		for plank = 1, bridges.planks do
			local a, b = deck((plank - 1) / bridges.planks), deck(plank / bridges.planks)
			beam(bridge, "Plank", a, b, bridges.width, 1, PLANK)
			local rail = Vector3.new(0, bridges.railHeight, 0)
			for _, sign in { 1, -1 } do
				beam(
					bridge,
					"Rope",
					a + side * sign + rail,
					b + side * sign + rail,
					0.3,
					0.3,
					ROPE,
					{ ghost = true }
				)
			end
		end
		for _, t in { 0, 1 } do
			for _, sign in { 1, -1 } do
				block(
					bridge,
					"Post",
					Vector3.new(1.2, bridges.railHeight + 1, 1.2),
					CFrame.new(deck(t) + side * sign + Vector3.new(0, bridges.railHeight / 2, 0)),
					PLANK,
					{ ghost = true }
				)
			end
		end
	end
	label(parent, `BRIDGE  51 long, {bridges.width} wide, {bridges.sag} droop`, polar(45, 55, 8))
end

local function buildMaelstrom(root: Instance)
	local maelstrom = layout.maelstrom
	local parent = folder(root, "Maelstrom")
	local sides = 36
	local bands = maelstrom.shaftBands
	local height = (-shore.thickness - maelstrom.shaftBottomY) / bands
	-- Alternating bands give the plunge a readable sense of speed.
	for band = 1, bands do
		local top = -shore.thickness - (band - 1) * height
		local color = if band % 2 == 0
			then Color3.fromRGB(34, 46, 66)
			else Color3.fromRGB(46, 64, 86)
		for side = 0, sides - 1 do
			panel(
				parent,
				"Shaft",
				side * 360 / sides,
				shore.innerRadius + 3,
				top - height,
				top,
				6,
				color,
				360 / sides
			)
		end
	end
	disc(
		parent,
		"WaterMarker",
		0.5,
		shore.innerRadius * 2,
		Vector3.new(0, maelstrom.waterY, 0),
		WATER,
		{ ghost = true, neon = true, transparency = 0.35 }
	)
	label(parent, `MAELSTROM  {shore.innerRadius * 2} across, no barriers`, polar(-45, 55, 8))
end

local function buildCavern(root: Instance)
	local cavern = layout.cavern
	local parent = folder(root, "Cavern")
	local ceiling = folder(parent, "Ceiling")
	local well = layout.skyWell
	for sector = 0, layout.sectors - 1 do
		local a1 = sector * SECTOR - 180
		local a2 = a1 + SECTOR
		panel(
			parent,
			"Wall",
			(a1 + a2) / 2,
			shore.wallRadius + 3,
			-shore.thickness,
			cavern.ceilingY,
			6,
			WALL
		)
		quad(
			ceiling,
			polar(a1, well.openingRadius, cavern.ceilingY),
			polar(a2, well.openingRadius, cavern.ceilingY),
			polar(a2, shore.wallRadius + 6, cavern.ceilingY),
			polar(a1, shore.wallRadius + 6, cavern.ceilingY),
			CEILING,
			cavern.ceilingThickness
		)
	end
	local sky = folder(parent, "SkyWell")
	local top = cavern.ceilingY + 14
	disc(
		sky,
		"Glow",
		1,
		well.openingRadius * 2 + 12,
		Vector3.new(0, top, 0),
		LIGHT,
		{ neon = true }
	)
	disc(
		sky,
		"LightColumn",
		top,
		well.columnRadius * 2,
		Vector3.new(0, top / 2, 0),
		LIGHT,
		{ ghost = true, transparency = 0.86 }
	)
	for _, rock in well.rocks do
		block(
			sky,
			"FloatingRock",
			Vector3.new(rock.size, rock.size * 0.6, rock.size * 0.8),
			CFrame.new(polar(rock.angle, rock.radius, rock.y)) * CFrame.Angles(0.2, rock.angle, 0.1),
			ROCK,
			{ ghost = true }
		)
	end
	label(sky, "SKY WELL  250 up, look only", Vector3.new(0, 95, 0))
end

local function buildPortals(root: Instance)
	local parent = folder(root, "Portals")
	local rise = layout.pvpRise
	lathe(parent, polar(0, rise.radius, 0), {
		{ 0, rise.height },
		{ rise.topRadius, rise.height },
		{ rise.baseRadius, 0 },
	}, 16, rgb(layout.zones[1].color):Lerp(LIGHT, 0.12), 2)
	for _, portal in layout.portals do
		local base = polar(portal.angle, portal.radius, portal.rise)
		local frame = CFrame.lookAt(base, Vector3.new(0, base.Y, 0))
		local post = 4
		local gate = folder(parent, portal.name)
		for _, sign in { 1, -1 } do
			block(
				gate,
				"Post",
				Vector3.new(post, portal.height, post),
				frame * CFrame.new(sign * (portal.width + post) / 2, portal.height / 2, 0),
				IRON
			)
		end
		block(
			gate,
			"Lintel",
			Vector3.new(portal.width + post * 2, post, post),
			frame * CFrame.new(0, portal.height + post / 2, 0),
			IRON
		)
		block(
			gate,
			"Energy",
			Vector3.new(portal.width, portal.height, 0.5),
			frame * CFrame.new(0, portal.height / 2, 0),
			rgb(portal.color),
			{ ghost = true, neon = true, transparency = 0.25 }
		)
		label(gate, portal.name:upper(), base + Vector3.new(0, portal.height + 9, 0))
	end
	local board = layout.bountyBoard
	local base = polar(board.angle, board.radius, 0)
	block(
		parent,
		"BountyBoard",
		Vector3.new(board.width, board.height, 1),
		CFrame.lookAt(base, Vector3.zero) * CFrame.new(0, board.height / 2 + 2, 0),
		PLANK
	)
	label(parent, "Bounty board", base + Vector3.new(0, board.height + 5, 0))
end

local function buildGunShop(root: Instance)
	local shop = layout.gunShop
	local parent = folder(root, "GunShop")
	local base = polar(shop.angle, shop.radius, 0)
	local frame = CFrame.lookAt(base, Vector3.zero)
	local color = rgb(shop.color)
	local h, w, d = shop.height, shop.width, shop.depth
	local wall = 2
	local function piece(name: string, size: Vector3, x: number, y: number, z: number)
		block(parent, name, size, frame * CFrame.new(x, y, z), color)
	end
	piece("BackWall", Vector3.new(w, h, wall), 0, h / 2, d / 2)
	piece("SideWall", Vector3.new(wall, h, d), -w / 2, h / 2, 0)
	piece("SideWall", Vector3.new(wall, h, d), w / 2, h / 2, 0)
	local front = (w - shop.door) / 2
	piece("FrontWall", Vector3.new(front, h, wall), -(shop.door + front) / 2, h / 2, -d / 2)
	piece("FrontWall", Vector3.new(front, h, wall), (shop.door + front) / 2, h / 2, -d / 2)
	piece("OverDoor", Vector3.new(shop.door, 5, wall), 0, h - 2.5, -d / 2)
	piece("Roof", Vector3.new(w + 6, 2, d + 6), 0, h + 1, 0)
	for index = -1, 1 do
		piece("DisplayStand", Vector3.new(6, 3.5, 3), index * 14, 1.75, d / 2 - 6)
	end
	label(parent, "GUN SHOP  50 x 40, walk in", base + Vector3.new(0, h + 8, 0))
end

local function buildPond(root: Instance)
	local pond = layout.pond
	local parent = folder(root, "SlugPond")
	local center = polar(pond.angle, pond.radius, 0)
	local radius = pond.diameter / 2
	disc(
		parent,
		"WadeableWater",
		0.4,
		pond.diameter,
		center + Vector3.new(0, 0.2, 0),
		WATER,
		{ ghost = true, neon = true, transparency = 0.3 }
	)
	for index = 1, pond.stones do
		local spot = center + polar(index * 360 / pond.stones, radius * 0.55, 0.4)
		disc(parent, "SteppingStone", 0.8, 6, spot, ROCK)
	end
	for index = 1, pond.mushrooms do
		mushroom(
			parent,
			center + polar(index * 360 / pond.mushrooms + 18, radius + 7, 0),
			16 + index % 3 * 5
		)
	end
	-- True-size ground slugs (0.93 studs) around and over the water, some mid-hop.
	for index = 1, pond.slugs do
		local spread = if index % 2 == 0 then radius * 0.8 else radius + 2
		local height = 0.9 + (index % 3) * 1.4
		block(
			parent,
			"SlugMarker",
			Vector3.one * 0.93,
			CFrame.new(center + polar(index * 360 / pond.slugs, spread, height)),
			SLUG,
			{ ball = true, neon = true, ghost = true }
		)
	end
	label(parent, "SLUG POND  70 across, wadeable", center + Vector3.new(0, 14, 0))
end

-- A ledge winding up a cone from fromY to toY at a fixed slope, starting on the side facing startAngle.
local function climb(
	parent: Instance,
	center: Vector3,
	radiusAt: (number) -> number,
	fromY: number,
	toY: number,
	startAngle: number
)
	local width = route.climbWidth
	local length = (toY - fromY) / math.tan(math.rad(route.climbSlope))
	local meanRadius = radiusAt((fromY + toY) / 2) + width / 2
	local turn = math.deg(length / meanRadius)
	local steps = math.ceil(turn / 12)
	local function ring(step: number): (number, number, number)
		local t = step / steps
		local y = fromY + (toY - fromY) * t
		return startAngle + turn * t, radiusAt(y), y
	end
	for step = 0, steps - 1 do
		local a1, r1, y1 = ring(step)
		local a2, r2, y2 = ring(step + 1)
		quad(
			parent,
			center + polar(a1, r1 - 1, y1),
			center + polar(a2, r2 - 1, y2),
			center + polar(a2, r2 + width, y2),
			center + polar(a1, r1 + width, y1),
			rgb(route.color),
			3
		)
	end
end

local function shoulder(parent: Instance, angle: number, fromRadius: number, y: number)
	beam(
		parent,
		"Shoulder",
		polar(angle, fromRadius, y),
		polar(angle, shore.wallRadius - route.width + 1, y),
		route.width,
		3,
		rgb(route.color)
	)
end

local function buildVolcano(root: Instance)
	local volcano = layout.volcano
	local parent = folder(root, "Volcano")
	local center = polar(volcano.angle, volcano.radius, 0)
	local h = volcano.height
	lathe(parent, center, {
		{ volcano.baseRadius, 0 },
		{ volcano.rimRadius, h },
		{ volcano.craterRadius, h },
		{ volcano.craterFloorRadius, volcano.craterFloorY },
		{ 0, volcano.craterFloorY },
	}, 24, rgb(volcano.color), 4)
	disc(
		parent,
		"CraterGlow",
		0.5,
		volcano.craterFloorRadius * 2 + 2,
		center + Vector3.new(0, volcano.craterFloorY + 2, 0),
		LAVA,
		{ ghost = true, neon = true }
	)
	local function radiusAt(y: number): number
		return volcano.baseRadius + (volcano.rimRadius - volcano.baseRadius) * y / h
	end
	local joinY = routeY(360)
	shoulder(parent, volcano.angle, volcano.radius + radiusAt(joinY) - 1, joinY)
	climb(parent, center, radiusAt, joinY, h, volcano.angle)
	label(parent, "VOLCANO  135 high, climb to the rim", center + Vector3.new(0, h + 8, 0))
end

local function buildMountain(root: Instance)
	local mountain = layout.mountain
	local parent = folder(root, "WaterfallMountain")
	local center = polar(mountain.angle, mountain.radius, 0)
	local h = mountain.height
	lathe(parent, center, {
		{ mountain.baseRadius, 0 },
		{ mountain.topRadius, h },
		{ 0, h },
	}, 24, rgb(mountain.color), 4)
	local function radiusAt(y: number): number
		return mountain.baseRadius + (mountain.topRadius - mountain.baseRadius) * y / h
	end
	local joinY = routeY(430)
	shoulder(parent, mountain.angle, mountain.radius + radiusAt(joinY) - 1, joinY)
	climb(parent, center, radiusAt, joinY, h, mountain.angle)
	-- The waterfall runs down the face looking at the pond, then along the ground into it.
	local fall = layout.waterfall
	local pond = polar(layout.pond.angle, layout.pond.radius, 0)
	local toward = (pond - center).Unit
	local top = center + toward * (radiusAt(fall.topY) + 0.8) + Vector3.new(0, fall.topY, 0)
	local foot = center + toward * (mountain.baseRadius + 0.8) + Vector3.new(0, 0.3, 0)
	local options: Options = { ghost = true, neon = true, transparency = 0.2 }
	beam(parent, "Waterfall", top, foot, fall.width, 0.4, WATER, options)
	beam(
		parent,
		"Stream",
		foot,
		pond - toward * layout.pond.diameter / 2,
		fall.width,
		0.3,
		WATER,
		options
	)
	label(parent, "WATERFALL MOUNTAIN  135 high, overlook", center + Vector3.new(0, h + 8, 0))
end

local function buildRavine(root: Instance)
	local ravine = layout.ravine
	local parent = folder(root, "LavaRavine")
	local color = rgb(ravine.color)
	local bottom = -ravine.wallDepth
	local inner, outer = ravine.innerRadius, ravine.outerRadius
	local ledge = ravine.ledge
	local function ledgeY(angle: number): number
		if angle <= ledge.levelAt then
			return ledge.y
		end
		return ledge.y * (ravine.to - angle) / (ravine.to - ledge.levelAt)
	end
	local angle = ravine.from
	while angle < ravine.to do
		local a1, a2 = angle, angle + SECTOR
		local middle = angle + SECTOR / 2
		panel(parent, "RavineWall", middle, inner - 1, bottom, 0, 2, color)
		panel(parent, "RavineWall", middle, outer + 1, bottom, 0, 2, color)
		quad(
			parent,
			polar(a1, inner, ravine.lavaY),
			polar(a2, inner, ravine.lavaY),
			polar(a2, outer, ravine.lavaY),
			polar(a1, outer, ravine.lavaY),
			LAVA,
			0.5,
			{ ghost = true, neon = true }
		)
		quad(
			parent,
			polar(a1, inner, ledgeY(a1)),
			polar(a2, inner, ledgeY(a2)),
			polar(a2, inner + ledge.width, ledgeY(a2)),
			polar(a1, inner + ledge.width, ledgeY(a1)),
			rgb(route.color),
			2
		)
		angle = a2
	end
	for _, edge in { ravine.from, ravine.to } do
		local a, b = polar(edge, inner, 0), polar(edge, outer, 0)
		quad(parent, a, b, b + Vector3.new(0, bottom, 0), a + Vector3.new(0, bottom, 0), color, 2)
	end
	local crossing = ravine.crossing
	beam(
		parent,
		"Crossing",
		polar(crossing.angle, inner - 1, 0),
		polar(crossing.angle, outer + 1, 0),
		crossing.width,
		1,
		PLANK
	)
	label(parent, "LAVA RAVINE  ledge and crossing", polar(crossing.angle, (inner + outer) / 2, 10))
end

local function buildOvergrowth(root: Instance)
	local growth = layout.overgrowth
	local parent = folder(root, "VeylumeOvergrowth")
	for index = 1, growth.mushrooms do
		local t = (index - 0.5) / growth.mushrooms
		local angle = growth.from + (growth.to - growth.from) * t
		local radius = growth.innerRadius
			+ (growth.outerRadius - growth.innerRadius) * (0.25 + (index % 3) * 0.25)
		mushroom(parent, polar(angle, radius, 0), 26 + index % 3 * 9)
	end
	label(
		parent,
		"VEYLUME OVERGROWTH",
		polar((growth.from + growth.to) / 2, growth.innerRadius + 30, 44)
	)
end

local function buildEntrance(root: Instance)
	local entrance = layout.entrance
	local parent = folder(root, "Entrance")
	local base = polar(entrance.angle, entrance.radius, 0)
	local frame = CFrame.lookAt(base, Vector3.zero)
	for _, sign in { 1, -1 } do
		block(
			parent,
			"MouthSide",
			Vector3.new(entrance.post, entrance.height, entrance.post),
			frame * CFrame.new(sign * entrance.width / 2, entrance.height / 2, 0),
			MOUTH
		)
	end
	block(
		parent,
		"MouthTop",
		Vector3.new(entrance.width + entrance.post, entrance.post, entrance.post),
		frame * CFrame.new(0, entrance.height + entrance.post / 2, 0),
		MOUTH
	)
	label(parent, "ENTRANCE  scenic cave mouth", base + Vector3.new(0, entrance.height + 12, 0))
end

local function buildRoute(root: Instance)
	local parent = folder(root, "SpiralRoute")
	local tunnel = route.tunnel
	local color = rgb(route.color)
	local inner = shore.wallRadius - route.width
	local first, last = route.points[1].angle, route.points[#route.points].angle
	local angle, sector = first, 0
	while angle < last do
		local a1, a2 = angle, angle + SECTOR
		local y1, y2 = routeY(a1), routeY(a2)
		quad(
			parent,
			polar(a1, inner, y1),
			polar(a2, inner, y2),
			polar(a2, shore.wallRadius, y2),
			polar(a1, shore.wallRadius, y1),
			color,
			2
		)
		-- The rock bank under the deck's inner edge, which also doubles as a long run wall.
		if y1 > 0.5 then
			quad(
				parent,
				polar(a1, inner, y1 - 0.5),
				polar(a2, inner, y2 - 0.5),
				polar(a2, inner, 0),
				polar(a1, inner, 0),
				GROUND,
				2
			)
		end
		if a1 >= tunnel.from and a2 <= tunnel.to then
			sector += 1
			local roof = tunnel.clearance
			quad(
				parent,
				polar(a1, inner, y1 + roof),
				polar(a2, inner, y2 + roof),
				polar(a2, shore.wallRadius, y2 + roof),
				polar(a1, shore.wallRadius, y1 + roof),
				WALL,
				2
			)
			if sector % tunnel.windowEvery ~= 0 then
				quad(
					parent,
					polar(a1, inner, y1),
					polar(a2, inner, y2),
					polar(a2, inner, y2 + roof),
					polar(a1, inner, y1 + roof),
					WALL,
					2
				)
			end
		end
		angle = a2
	end
	label(parent, "SPIRAL ROUTE START", polar(first + 4, inner + 7, 10))
	label(parent, "CAVERNS  tunnel section", polar(215, inner - 6, routeY(215) + 30))
	label(parent, "SPIRAL ROUTE  14 wide", polar(305, inner - 6, routeY(305) + 8))
end

function Arena.create(): Model
	local model = Instance.new("Model")
	model.Name = "LobbyScale"
	buildSpawnRock(model)
	buildShore(model)
	buildBridges(model)
	buildMaelstrom(model)
	buildCavern(model)
	buildPortals(model)
	buildGunShop(model)
	buildPond(model)
	buildVolcano(model)
	buildMountain(model)
	buildRavine(model)
	buildOvergrowth(model)
	buildEntrance(model)
	buildRoute(model)
	model.Parent = workspace
	return model
end

return table.freeze(Arena)
