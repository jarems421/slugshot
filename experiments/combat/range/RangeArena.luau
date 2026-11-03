--!strict
-- TEMPORARY target range for slug shooting (owner, 2026-10-31): a throwaway test space,
-- not a map or design reference. Replaces the movement lab's map
-- factory in the range place only. Players spawn near (0, 5, 30) facing -Z; distance
-- lines and dummies are measured from the spawn line along -Z. Dummies are added by
-- RangeServer.
local Arena = {}

Arena.Spawn = Vector3.new(0, 0, 30)
-- Dummy distances from the spawn line (studs), sideways offsets so none hides another.
Arena.Lanes = {
	{ distance = 10, side = -6 },
	{ distance = 20, side = 5 },
	{ distance = 30, side = -10 },
	{ distance = 45, side = 9 },
	{ distance = 60, side = -4 },
	{ distance = 80, side = 6 },
}
Arena.Strafe = { distance = 35, width = 12, speed = 6 } -- a side-to-side moving dummy
Arena.Tower = { distance = 50, side = -20, height = 8 } -- a raised dummy, for arcs

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	frame: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = frame
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function label(part: BasePart, text: string)
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Top
	surface.CanvasSize = Vector2.new(200, 60)
	surface.LightInfluence = 0.4
	local caption = Instance.new("TextLabel")
	caption.Size = UDim2.fromScale(1, 1)
	caption.BackgroundTransparency = 1
	caption.Font = Enum.Font.GothamBlack
	caption.TextScaled = true
	caption.TextColor3 = Color3.fromRGB(240, 236, 220)
	caption.Text = text
	caption.Parent = surface
	surface.Parent = part
end

function Arena.create(): Model
	local model = Instance.new("Model")
	model.Name = "TemporaryTargetRange"
	local spawnZ = Arena.Spawn.Z
	local ground = Color3.fromRGB(96, 104, 78)
	local stripe = Color3.fromRGB(226, 221, 196)
	block(
		model,
		"Floor",
		Vector3.new(240, 2, 260),
		CFrame.new(0, -1, spawnZ - 90),
		ground,
		Enum.Material.Grass
	)
	block(
		model,
		"FiringLine",
		Vector3.new(60, 0.06, 0.6),
		CFrame.new(0, 0.03, spawnZ - 1.5),
		stripe
	)
	-- Distance lines every 10 studs, labelled at the left edge.
	for distance = 10, 100, 10 do
		local z = spawnZ - distance
		local line = block(
			model,
			`Line{distance}`,
			Vector3.new(60, 0.05, 0.25),
			CFrame.new(0, 0.025, z),
			stripe
		)
		line.Transparency = if distance % 20 == 0 then 0.1 else 0.45
		local plate = block(
			model,
			`Label{distance}`,
			Vector3.new(6, 0.06, 1.8),
			CFrame.new(-33, 0.03, z),
			Color3.fromRGB(40, 46, 38)
		)
		label(plate, `{distance} studs`)
	end
	-- Raised dummy platform and a backstop for long misses.
	local tower = Arena.Tower
	block(
		model,
		"Tower",
		Vector3.new(6, tower.height, 6),
		CFrame.new(tower.side, tower.height / 2, spawnZ - tower.distance),
		Color3.fromRGB(78, 86, 98)
	)
	block(
		model,
		"Backstop",
		Vector3.new(80, 14, 3),
		CFrame.new(0, 7, spawnZ - 110),
		Color3.fromRGB(64, 70, 58),
		Enum.Material.Slate
	)
	-- Marked as temporary in the world, readable from the firing line.
	local sign = block(
		model,
		"TemporarySign",
		Vector3.new(46, 6, 0.4),
		CFrame.new(0, 17, spawnZ - 108.2), -- its Back face (+Z) faces the firing line
		Color3.fromRGB(40, 46, 38)
	)
	local board = Instance.new("SurfaceGui")
	board.Face = Enum.NormalId.Back
	board.CanvasSize = Vector2.new(920, 120)
	board.LightInfluence = 0.3
	local words = Instance.new("TextLabel")
	words.Size = UDim2.fromScale(1, 1)
	words.BackgroundTransparency = 1
	words.Font = Enum.Font.GothamBlack
	words.TextScaled = true
	words.TextColor3 = Color3.fromRGB(255, 196, 92)
	words.Text = "TEMPORARY TEST RANGE"
	words.Parent = board
	board.Parent = sign
	-- Side cover blocks, for lobbing over.
	block(
		model,
		"CoverLeft",
		Vector3.new(6, 4, 2),
		CFrame.new(-16, 2, spawnZ - 40),
		Color3.fromRGB(122, 98, 70),
		Enum.Material.Wood
	)
	block(
		model,
		"CoverRight",
		Vector3.new(6, 4, 2),
		CFrame.new(16, 2, spawnZ - 25),
		Color3.fromRGB(122, 98, 70),
		Enum.Material.Wood
	)
	model.Parent = workspace
	return model
end

return table.freeze(Arena)
