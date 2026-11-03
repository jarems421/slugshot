--!strict
-- Dresses a loaded Inferno model: surface materials, mouth ink and the light he throws. SurfaceAppearance content can only
-- be set by plugins, so materials are cloned from private templates. `scale` is the model's size against game size.
local Appearance = {}

local INK = Color3.fromRGB(46, 16, 14) -- dark maroon: this slug has no black in it (owner)
local MOUTH_INK = Color3.fromRGB(60, 14, 10)
local GLOW = Color3.fromRGB(255, 170, 90)
-- Strength 1: the eyes keep their yellow-to-red burn instead of blowing out to white.
local VISIBILITY_FLOOR = 0.05
local EMISSIVE_FLOOR = 0.05 -- tools/slugs/upload_inferno.py

Appearance.Ink = INK

local function light(parent: Instance, name: string, brightness: number, range: number)
	local glow = Instance.new("PointLight")
	glow.Name = name
	glow.Color = GLOW
	glow.Brightness = brightness
	glow.Range = range
	glow.Shadows = false
	glow.Parent = parent
end

function Appearance.dress(model: Model, materials: Instance, scale: number)
	local dressed = 0
	for _, part in model:GetDescendants() do
		if not part:IsA("MeshPart") then
			continue
		end
		for _, child in part:GetChildren() do
			if child:IsA("SurfaceAppearance") then
				child:Destroy()
			end
		end
		part.TextureID = ""
		part.Reflectance = 0
		if string.sub(part.Name, -8) == "MouthInk" or string.sub(part.Name, -9) == "MouthLine" then
			-- Flat ink. The line starts clear; the client brings it in as he clenches.
			part.Color = MOUTH_INK
			part.Material = Enum.Material.SmoothPlastic
			part.CastShadow = false
			part.Transparency = if string.sub(part.Name, -9) == "MouthLine" then 1 else 0
		elseif string.sub(part.Name, -5) == "Mouth" or string.sub(part.Name, -4) == "Eyes" then
			local template = materials:FindFirstChild(part.Name)
			assert(template and template:IsA("SurfaceAppearance"), `no material for {part.Name}`)
			part.Color = Color3.new(1, 1, 1)
			part.Material = Enum.Material.SmoothPlastic
			part.CastShadow = false
			local surface = template:Clone()
			surface.Name = "InfernoMaterial"
			surface.EmissiveStrength = 1
			surface.Parent = part
		else
			local template = materials:FindFirstChild(part.Name)
			assert(template and template:IsA("SurfaceAppearance"), `no material for {part.Name}`)
			part.Color = Color3.new(1, 1, 1)
			part.Material = Enum.Material.SmoothPlastic
			local surface = template:Clone()
			surface.Name = "InfernoMaterial"
			surface.EmissiveStrength = VISIBILITY_FLOOR / EMISSIVE_FLOOR
			surface.Parent = part
			dressed += 1
		end
	end
	assert(dressed == 1, `{model.Name} expected one textured body, found {dressed}`)
	local head = model:FindFirstChild("head", true)
	if head then
		light(head, "SlugGlow", 0.3, 5 * scale)
	end
	local flame = model:FindFirstChild("flame_1", true)
	if flame then
		light(flame, "FlameLight", 0.5, 3 * scale)
	end
end

-- A screen-space outline holds its shape from every angle and through every flip, which a hull around a bending,
-- carved mesh could not. Roblox limits how many Highlights draw at once, so a crowded scene needs a plan for this.
function Appearance.outline(model: Model, colour: Color3?)
	local highlight = Instance.new("Highlight")
	highlight.Name = "Outline"
	highlight.FillTransparency = 1
	highlight.OutlineColor = colour or INK
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = model
	highlight.Parent = model
end

return Appearance
