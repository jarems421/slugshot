--!strict
-- Bind known image assets explicitly. A model import can succeed while its
-- generated SurfaceAppearance texture pack is unavailable to the local place.
local Appearance = {}

local templates = game:GetService("ServerStorage"):WaitForChild("FloppyMaterials")

function Appearance.apply(model: Model)
	local applied = 0
	for _, part in model:GetDescendants() do
		if not part:IsA("MeshPart") then
			continue
		end
		local template = templates:FindFirstChild(part.Name)
		if not template or not template:IsA("SurfaceAppearance") then
			continue
		end
		for _, child in part:GetChildren() do
			if child:IsA("SurfaceAppearance") then
				child:Destroy()
			end
		end
		part.Color = Color3.new(1, 1, 1)
		part.Material = Enum.Material.SmoothPlastic
		part.Reflectance = 0
		part.TextureID = ""
		-- Map properties require plugin security when assigned by script. Clone
		-- templates serialized into the private build instead of setting them live.
		local surface = template:Clone()
		surface.Name = "FloppyMaterial"
		surface.Parent = part
		applied += 1
	end
	assert(applied == 3, `Floppy material binding expected 3 meshes, found {applied}`)
end

return Appearance
