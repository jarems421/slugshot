--!strict
-- Stable footing while the imported art loads; matches its measured rim.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Arena = {}
local function triangle(parent: Instance, a: Vector3, b: Vector3, c: Vector3)
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
			wedge.Name = "StableFooting"
			wedge.Size = Vector3.new(0.8, width, spec.length)
			wedge.CFrame = CFrame.fromMatrix(spec.p, spec.r, up, spec.z)
			wedge.Anchored, wedge.CanTouch, wedge.Transparency = true, false, 1
			wedge.Parent = parent
		end
	end
end
function Arena.create(): Model
	local model = Instance.new("Model")
	model.Name, model.Parent = "TrainingFooting", workspace
	local outline =
		require(ReplicatedStorage:WaitForChild("TrainingOutline")) :: { rock: { number } }
	for i, r in outline.rock do
		local j = i % #outline.rock + 1
		local a, b = (i - 1) * 2 * math.pi / #outline.rock, i * 2 * math.pi / #outline.rock
		local p = Vector3.new(math.sin(a) * r * 2.25, 0.1, -math.cos(a) * r * 2.25)
		local q = Vector3.new(
			math.sin(b) * outline.rock[j] * 2.25,
			0.1,
			-math.cos(b) * outline.rock[j] * 2.25
		)
		triangle(model, Vector3.new(0, 0.1, 0), p, q)
	end
	return model
end
return Arena
