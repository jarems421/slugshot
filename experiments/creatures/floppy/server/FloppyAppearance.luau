--!strict
-- Bind known image assets explicitly. A model import can succeed while its
-- generated SurfaceAppearance texture pack is unavailable to the local place.
local Appearance = {}

local templates = game:GetService("ServerStorage"):WaitForChild("FloppyMaterials")

-- Emissive mask value on plain skin (tools/slugs/upload_floppy_images.py EMISSIVE_FLOOR). Strength is the visibility
-- floor divided by it, so plain skin keeps its faint floor while the bulbs and sore centres glow (owner, 2026-11-01).
local EMISSIVE_FLOOR = 0.05
-- Soft yellow-green, so the moss-brown bulbs glow like the concept's bulb light.
local GLOW_TINT = Color3.fromRGB(215, 240, 160)
-- Slugshot look: Floppy's ink shell is flat near-black (look pack INK), Neon so lamps never grey it.
local INK = Color3.fromRGB(14, 14, 18)

function Appearance.apply(model: Model, minimumLight: number?)
	local applied, inked = 0, 0
	for _, part in model:GetDescendants() do
		if not part:IsA("MeshPart") then
			continue
		end
		if part.Name == "FloppyBody_Ink" then
			for _, child in part:GetChildren() do
				if child:IsA("SurfaceAppearance") then
					child:Destroy()
				end
			end
			part.Color = INK
			part.Material = Enum.Material.Neon
			part.TextureID = ""
			part.CastShadow = false
			inked += 1
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
		surface.EmissiveStrength = (minimumLight or 0.08) / EMISSIVE_FLOOR
		surface.EmissiveTint = GLOW_TINT
		surface.Parent = part
		applied += 1
	end
	assert(applied == 3, `Floppy material binding expected 3 meshes, found {applied}`)
	assert(inked == 1, `Floppy expected one ink shell, found {inked}`)
	-- A soft yellow-green light from the head, so a slug lights up its surroundings and stands out in a dark
	-- cavern (owner, 2026-11-01). The antenna bones sit at the antenna roots, so the head bone carries it.
	local head = model:FindFirstChild("head", true)
	if
		head
		and (head:IsA("Bone") or head:IsA("BasePart"))
		and not head:FindFirstChild("SlugGlow")
	then
		local light = Instance.new("PointLight")
		light.Name = "SlugGlow"
		light.Color = GLOW_TINT
		light.Brightness = 0.9
		light.Range = 5
		light.Shadows = false
		light.Parent = head
	end
end

return Appearance
