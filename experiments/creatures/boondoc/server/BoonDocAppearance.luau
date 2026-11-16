--!strict
-- Dresses a loaded Boon Doc model (either form) from the private SurfaceAppearance templates named after its MeshParts
-- (tools/slugs/upload_boon_doc.py): SurfaceAppearance content can only be set by plugins, so materials are cloned.
-- Also records each bone's rest rotation as imported, which BoonDocMotion turns its moves into bone space with.
local Appearance = {}

function Appearance.dress(model: Model, materials: Instance)
	for _, item in model:GetDescendants() do
		if item:IsA("Bone") and item:GetAttribute("RestRotation") == nil then
			-- Freshly loaded, the model is still in its import space.
			item:SetAttribute("RestRotation", item.WorldCFrame.Rotation)
		end
		if not item:IsA("MeshPart") then
			continue
		end
		for _, child in item:GetChildren() do
			if child:IsA("SurfaceAppearance") then
				child:Destroy()
			end
		end
		local template = materials:FindFirstChild(item.Name)
		assert(template and template:IsA("SurfaceAppearance"), `no material for {item.Name}`)
		item.TextureID = ""
		item.Reflectance = 0
		item.Color = Color3.new(1, 1, 1)
		item.Material = Enum.Material.SmoothPlastic
		local surface = template:Clone()
		surface.Name = "BoonDocMaterial"
		surface.EmissiveStrength = 1
		surface.Parent = item
	end
	model:SetAttribute("ImportScale", model:GetScale())
end

return Appearance
