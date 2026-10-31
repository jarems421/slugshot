--!strict
local Arena = {}

function Arena.create(): Model
	local model = Instance.new("Model")
	model.Name = "MovementSandbox"
	local function block(name: string, size: Vector3, frame: CFrame, color: Color3): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = frame
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
		return part
	end
	local dark = Color3.fromRGB(42, 51, 64)
	local blue = Color3.fromRGB(68, 145, 180)
	local amber = Color3.fromRGB(225, 169, 75)
	block("Flat", Vector3.new(220, 2, 220), CFrame.new(0, -1, 0), dark)
	block("Elevation", Vector3.new(24, 8, 22), CFrame.new(-28, 4, -25), blue)
	block(
		"Ramp",
		Vector3.new(18, 2, 30),
		CFrame.new(-28, 4, -1) * CFrame.Angles(math.rad(-15), 0, 0),
		blue
	)
	block("Wall", Vector3.new(3, 16, 42), CFrame.new(32, 8, -18), blue)
	block("Landing", Vector3.new(24, 3, 18), CFrame.new(0, 1.5, -52), amber)
	for i = 1, 5 do
		block("Step" .. i, Vector3.new(14, i * 0.9, 4), CFrame.new(3, i * 0.45, -6 - i * 4), amber)
	end
	-- Traversal course: mantle ledges of rising height (the last needs a jump
	-- first), and a chimney of two facing walls for wall hops up to a ledge.
	for i, height in { 1.5, 3, 4.5, 5.5, 7.5 } do
		block(
			"Ledge" .. i,
			Vector3.new(10, height, 8),
			CFrame.new(52, height / 2, 26 - i * 11),
			if i % 2 == 0 then amber else blue
		)
	end
	-- Vault course: thin low walls to run and jump over (westward, from spawn).
	for i, height in { 2, 2.8, 3.4 } do
		block(
			"VaultWall" .. i,
			Vector3.new(1.6, height, 10),
			CFrame.new(-26 - i * 16, height / 2, 40),
			if i % 2 == 0 then amber else blue
		)
	end
	-- Detection checks (east of spawn): a thin floating slab (top 5 studs up, 1 thick,
	-- nothing under it) and a narrow pillar (1.6 wide; approach along Z), both mantled
	-- by jumping into them.
	block("FloatingLedge", Vector3.new(10, 1, 6), CFrame.new(24, 4.5, 50), amber)
	block("NarrowPillar", Vector3.new(1.6, 4, 3), CFrame.new(38, 2, 50), blue)
	-- Wall-run corridor: two long facing walls (east of the ledges) to run along and
	-- kick between.
	block("RunWallWest", Vector3.new(2, 40, 160), CFrame.new(94, 20, 0), amber)
	block("RunWallEast", Vector3.new(2, 40, 160), CFrame.new(108, 20, 0), blue)
	-- North-west terrain lane: raised strips, a thin ledge and a connected
	-- rectangular tower (outside corners), plus an L for an inside corner.
	block("UnevenRunWall", Vector3.new(3, 34, 100), CFrame.new(-90, 17, -10), blue)
	for i, depth in { 0.25, 0.5, 0.8 } do
		block(
			"RunBump" .. i,
			Vector3.new(depth, 34, 3),
			CFrame.new(-88.5 + depth / 2, 17, 18 - i * 17),
			amber
		)
	end
	block("ThinWallLedge", Vector3.new(0.6, 0.45, 22), CFrame.new(-88.2, 9, -10), amber)
	block("CornerTower", Vector3.new(24, 34, 24), CFrame.new(-55, 17, -78), blue)
	block("InsideCornerLong", Vector3.new(3, 34, 38), CFrame.new(-12, 17, -80), blue)
	block("InsideCornerReturn", Vector3.new(25, 34, 3), CFrame.new(0, 17, -97.5), amber)
	block("ChimneyLedge", Vector3.new(8, 14, 14), CFrame.new(70, 7, -6), blue)
	block("ChimneyWall", Vector3.new(2, 22, 14), CFrame.new(83, 11, -6), amber)
	for i = 0, 5 do
		local line = block(
			"Distance" .. i * 10,
			Vector3.new(12, 0.03, 0.2),
			CFrame.new(-65, 0.02, 25 - i * 10),
			amber
		)
		line.CanCollide = false
	end
	model.Parent = workspace
	return model
end

return Arena
