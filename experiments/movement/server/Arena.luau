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
