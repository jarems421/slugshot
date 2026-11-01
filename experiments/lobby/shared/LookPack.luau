--!strict
-- Slugshot look pack: the runtime half of the "Living Comic-Book Fantasy" look (docs/art/style-guide.md).
-- Roblox has no custom shaders, so the ink lives in the meshes: every Blender-built asset ships an
-- inverted-hull "<Group>_Ink" shell (Slugshot mix widths) and painted colour/normal/glow maps with the
-- interior ink baked in. This module supplies the rest: cavern lighting with crisp comic shadows, fog,
-- tone mapping, selective bloom, a colour grade, per-zone moods, and the rules that style an imported asset.
local Lighting = game:GetService("Lighting")

local LookPack = {}

export type Mood = {
	ambient: Color3, -- shadowed-side fill; leans blue-violet so shadows stay colourful, never grey
	outdoorAmbient: Color3,
	fog: Color3, -- Atmosphere colour
	decay: Color3, -- Atmosphere decay
	density: number,
	haze: number,
	tint: Color3, -- ColorCorrection tint
	contrast: number,
	saturation: number,
	brightness: number,
	exposure: number,
}

-- Ink: near-black charcoal from the Inked/Comic Cavern treatments (linear 0.006 -> sRGB about 14).
LookPack.INK = Color3.fromRGB(14, 14, 18)

-- Zone moods (lobby roadmap: hub calm and balanced, PvP warm and dramatic, Training cool and clear,
-- Veylume mysterious green/teal/violet). Values are a first pass for owner tuning in the look test.
LookPack.Moods = {
	Hub = {
		ambient = Color3.fromRGB(46, 50, 78),
		outdoorAmbient = Color3.fromRGB(40, 44, 70),
		fog = Color3.fromRGB(34, 38, 62),
		decay = Color3.fromRGB(22, 20, 44),
		density = 0.36,
		haze = 1.6,
		tint = Color3.fromRGB(236, 240, 255),
		contrast = 0.14,
		saturation = 0.1,
		brightness = 0,
		exposure = 0.15,
	},
	PvP = {
		ambient = Color3.fromRGB(70, 46, 44),
		outdoorAmbient = Color3.fromRGB(62, 42, 40),
		fog = Color3.fromRGB(62, 36, 30),
		decay = Color3.fromRGB(46, 20, 16),
		density = 0.38,
		haze = 1.8,
		tint = Color3.fromRGB(255, 236, 220),
		contrast = 0.2,
		saturation = 0.14,
		brightness = 0,
		exposure = 0.12,
	},
	Training = {
		ambient = Color3.fromRGB(42, 62, 84),
		outdoorAmbient = Color3.fromRGB(38, 56, 76),
		fog = Color3.fromRGB(28, 50, 64),
		decay = Color3.fromRGB(16, 32, 44),
		density = 0.3,
		haze = 1.2,
		tint = Color3.fromRGB(228, 246, 255),
		contrast = 0.12,
		saturation = 0.08,
		brightness = 0.02,
		exposure = 0.25,
	},
	Veylume = {
		ambient = Color3.fromRGB(56, 44, 84),
		outdoorAmbient = Color3.fromRGB(48, 40, 74),
		fog = Color3.fromRGB(40, 34, 70),
		decay = Color3.fromRGB(26, 40, 46),
		density = 0.42,
		haze = 2.2,
		tint = Color3.fromRGB(240, 232, 255),
		contrast = 0.16,
		saturation = 0.14,
		brightness = 0,
		exposure = 0.05,
	},
} :: { [string]: Mood }

local function effect(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local created = Instance.new(className)
	created.Name = name
	created.Parent = Lighting
	return created
end

-- Lighting and effects shared by every Slugshot scene. Technology = Future is set in the place file
-- (it cannot be changed from scripts). Safe to call more than once.
function LookPack.applyBase()
	Lighting.ClockTime = 0
	Lighting.Brightness = 0 -- underground: no sun; light comes from glows, lamps and the Sky Well
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0 -- crisp comic shadow edges
	Lighting.EnvironmentDiffuseScale = 0.25
	Lighting.EnvironmentSpecularScale = 0.45
	Lighting.GeographicLatitude = 0

	local atmosphere = effect("Atmosphere", "SlugshotAtmosphere") :: Atmosphere
	atmosphere.Offset = 0.15
	atmosphere.Glare = 0

	-- Bloom only on what glows: the threshold sits above lit surfaces so stone never washes out.
	local bloom = effect("BloomEffect", "SlugshotBloom") :: BloomEffect
	bloom.Intensity = 0.8
	bloom.Size = 30
	bloom.Threshold = 1.1

	effect("ColorCorrectionEffect", "SlugshotGrade")

	-- Tone mapping: newer Roblox builds expose ColorGradingEffect; skip quietly where it is missing.
	pcall(function()
		local grading = effect("ColorGradingEffect", "SlugshotTonemap");
		(grading :: any).TonemapperPreset = (Enum :: any).TonemapperPreset.Default
	end)

	for _, child in Lighting:GetChildren() do
		if child:IsA("SunRaysEffect") or child:IsA("Sky") then
			child:Destroy()
		end
	end
	LookPack.applyMood(LookPack.Moods.Hub)
end

function LookPack.applyMood(mood: Mood)
	Lighting.Ambient = mood.ambient
	Lighting.OutdoorAmbient = mood.outdoorAmbient
	Lighting.ExposureCompensation = mood.exposure
	local atmosphere = Lighting:FindFirstChild("SlugshotAtmosphere") :: Atmosphere?
	if atmosphere then
		atmosphere.Color = mood.fog
		atmosphere.Decay = mood.decay
		atmosphere.Density = mood.density
		atmosphere.Haze = mood.haze
	end
	local grade = Lighting:FindFirstChild("SlugshotGrade") :: ColorCorrectionEffect?
	if grade then
		grade.TintColor = mood.tint
		grade.Contrast = mood.contrast
		grade.Saturation = mood.saturation
		grade.Brightness = mood.brightness
	end
end

-- Weighted blend of several moods (weights need not sum to one).
function LookPack.blend(moods: { Mood }, weights: { number }): Mood
	local total = 0
	for _, w in weights do
		total += w
	end
	local function mix3(get: (Mood) -> Color3): Color3
		local r, g, b = 0, 0, 0
		for i, m in moods do
			local c, w = get(m), weights[i] / total
			r += c.R * w
			g += c.G * w
			b += c.B * w
		end
		return Color3.new(r, g, b)
	end
	local function mix1(get: (Mood) -> number): number
		local v = 0
		for i, m in moods do
			v += get(m) * weights[i] / total
		end
		return v
	end
	return {
		ambient = mix3(function(m)
			return m.ambient
		end),
		outdoorAmbient = mix3(function(m)
			return m.outdoorAmbient
		end),
		fog = mix3(function(m)
			return m.fog
		end),
		decay = mix3(function(m)
			return m.decay
		end),
		density = mix1(function(m)
			return m.density
		end),
		haze = mix1(function(m)
			return m.haze
		end),
		tint = mix3(function(m)
			return m.tint
		end),
		contrast = mix1(function(m)
			return m.contrast
		end),
		saturation = mix1(function(m)
			return m.saturation
		end),
		brightness = mix1(function(m)
			return m.brightness
		end),
		exposure = mix1(function(m)
			return m.exposure
		end),
	}
end

export type GroupSpec = { ink: string?, emissive: number }

-- Asset rules for a model imported from the Blender pipeline: clone the prebuilt SurfaceAppearance for
-- each painted group (map setters are plugin-only), turn "_Ink" shells into flat unlit-looking charcoal,
-- and scale glow. `glowScale` lets the look test tune all glows together.
function LookPack.styleModel(
	model: Model,
	key: string,
	groups: { [string]: GroupSpec },
	templates: Instance,
	glowScale: number
)
	for _, part in model:GetDescendants() do
		if not part:IsA("MeshPart") then
			continue
		end
		part.Anchored = true
		part.CanTouch = false
		if string.sub(part.Name, -4) == "_Ink" then
			part.Color = LookPack.INK
			-- Near-black Neon renders as flat ink under every light and is too dark to bloom.
			part.Material = Enum.Material.Neon
			part.TextureID = ""
			part.CastShadow = false
			part.CanCollide = false
			part.CanQuery = false
			part.DoubleSided = false
			for _, child in part:GetChildren() do
				if child:IsA("SurfaceAppearance") then
					child:Destroy()
				end
			end
			continue
		end
		local spec = groups[part.Name]
		local template = templates:FindFirstChild(key .. "/" .. part.Name)
		if not spec or not template then
			warn(`LookPack: no material for {key}/{part.Name}`)
			continue
		end
		for _, child in part:GetChildren() do
			if child:IsA("SurfaceAppearance") then
				child:Destroy()
			end
		end
		part.Color = Color3.new(1, 1, 1)
		part.Material = Enum.Material.SmoothPlastic
		part.TextureID = ""
		part.CastShadow = spec.emissive <= 0
		local surface = template:Clone() :: SurfaceAppearance
		surface.Name = "SlugshotMaterial"
		surface.EmissiveStrength = spec.emissive * glowScale
		surface.EmissiveTint = Color3.new(1, 1, 1)
		surface.Parent = part
	end
end

return LookPack
