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
-- Round 2: fog thinned by 0.12 so the walls show. Round 3 (owner: "don't just make the rocks blue"): ambient and
-- fog are dark and nearly neutral; walls are lit from above by lights instead (LookTest wall lights).
LookPack.Moods = {
	Hub = {
		ambient = Color3.fromRGB(44, 44, 52),
		outdoorAmbient = Color3.fromRGB(40, 40, 48),
		fog = Color3.fromRGB(30, 30, 40),
		decay = Color3.fromRGB(22, 20, 30),
		density = 0.24,
		haze = 1.6,
		tint = Color3.fromRGB(236, 240, 255),
		contrast = 0.14,
		saturation = 0.1,
		brightness = 0,
		exposure = 0.15,
	},
	PvP = {
		ambient = Color3.fromRGB(56, 44, 42),
		outdoorAmbient = Color3.fromRGB(50, 40, 38),
		fog = Color3.fromRGB(46, 32, 28),
		decay = Color3.fromRGB(34, 20, 16),
		density = 0.26,
		haze = 1.8,
		tint = Color3.fromRGB(255, 236, 220),
		contrast = 0.2,
		saturation = 0.14,
		brightness = 0,
		exposure = 0.12,
	},
	Training = {
		ambient = Color3.fromRGB(42, 47, 54),
		outdoorAmbient = Color3.fromRGB(38, 43, 50),
		fog = Color3.fromRGB(28, 36, 42),
		decay = Color3.fromRGB(18, 26, 30),
		density = 0.18,
		haze = 1.2,
		tint = Color3.fromRGB(228, 246, 255),
		contrast = 0.12,
		saturation = 0.08,
		brightness = 0.02,
		exposure = 0.25,
	},
	Veylume = {
		ambient = Color3.fromRGB(49, 44, 58),
		outdoorAmbient = Color3.fromRGB(44, 40, 52),
		fog = Color3.fromRGB(36, 32, 48),
		decay = Color3.fromRGB(26, 30, 34),
		density = 0.3,
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

-- Zone moods shift colour only (owner round 4: "the lighting keeps changing"). Exposure, fog density, haze,
-- contrast and brightness always come from the Hub, so walking between zones never re-lights the cavern.
function LookPack.applyMood(mood: Mood)
	local hub = LookPack.Moods.Hub
	Lighting.Ambient = mood.ambient
	Lighting.OutdoorAmbient = mood.outdoorAmbient
	Lighting.ExposureCompensation = hub.exposure
	local atmosphere = Lighting:FindFirstChild("SlugshotAtmosphere") :: Atmosphere?
	if atmosphere then
		atmosphere.Color = mood.fog
		atmosphere.Decay = mood.decay
		atmosphere.Density = hub.density
		atmosphere.Haze = hub.haze
	end
	local grade = Lighting:FindFirstChild("SlugshotGrade") :: ColorCorrectionEffect?
	if grade then
		grade.TintColor = mood.tint
		grade.Contrast = hub.contrast
		grade.Saturation = mood.saturation
		grade.Brightness = hub.brightness
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

export type GroupSpec = { ink: string?, emissive: number, center: Vector3 }

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

export type EffectPoint = { kind: string, p: Vector3, s: number, c: Color3 }
export type AssetInfo = {
	model: number,
	height: number,
	center: Vector3,
	groups: { [string]: GroupSpec },
	points: { EffectPoint },
	spores: { p: Vector3, r: number, c: Color3 }?,
}

local function fxPart(name: string, position: Vector3, size: Vector3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = size
	p.Position = position
	p.Parent = parent
	return p
end

local function pointLight(parent: Instance, color: Color3, brightness: number, range: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = parent
end

-- Glow effects for an imported asset (round 2, owner 2026-11-01): crystals and small glowing mushroom caps
-- light the rock around them, crystals add star twinkles scaled to their size, small caps get no spores, and
-- the giant mushroom drops a continuous stream of glowing spores that fade at the floor.
-- Round 4 (owner: "the lighting keeps changing"): one light per emitter came to about 300 lights, and
-- Roblox renders only so many near the camera, so lights faded in and out as it moved. Emitters within
-- LIGHT_MERGE studs now share one light with their blended colour.
-- `conceptToWorld` maps concept coordinates (studs) to world space, including the axis flip the import
-- applies (measured in LookTest.server).
local LIGHT_MERGE = 4

function LookPack.addEffects(
	model: Model,
	info: AssetInfo,
	fx: { spore: number, twinkle: number },
	conceptToWorld: (Vector3) -> Vector3
)
	local clusters: { { p: Vector3, rgb: Vector3, weight: number, reach: number, crystal: boolean } } =
		{}
	for _, pt in info.points do
		local world = conceptToWorld(pt.p)
		local size = math.max(pt.s, 0.3)
		local rgb = Vector3.new(pt.c.R, pt.c.G, pt.c.B) * size
		local joined = nil
		for _, cluster in clusters do
			if (cluster.p - world).Magnitude < LIGHT_MERGE then
				joined = cluster
				break
			end
		end
		if joined then
			local total = joined.weight + size
			joined.p = (joined.p * joined.weight + world * size) / total
			joined.rgb += rgb
			joined.weight = total
			joined.reach = math.max(joined.reach, (joined.p - world).Magnitude + size)
			joined.crystal = joined.crystal or pt.kind == "crystal"
		else
			table.insert(
				clusters,
				{ p = world, rgb = rgb, weight = size, reach = size, crystal = pt.kind == "crystal" }
			)
		end
		if pt.kind == "crystal" then
			local part = fxPart("Twinkle", world, Vector3.one * size * 1.6, model)
			local e = Instance.new("ParticleEmitter")
			e.Name = "Twinkle"
			e.Texture = "rbxassetid://" .. fx.twinkle
			e.Color = ColorSequence.new(pt.c:Lerp(Color3.new(1, 1, 1), 0.45))
			e.LightEmission = 1
			e.LightInfluence = 0
			e.Brightness = 2.5
			local peak = math.clamp(0.18 + size * 0.22, 0.2, 1.1)
			e.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.4, peak),
				NumberSequenceKeypoint.new(1, 0),
			})
			e.Lifetime = NumberRange.new(0.5, 1.1)
			e.Rate = 1 + size * 2
			e.Speed = NumberRange.new(0.05, 0.25)
			e.SpreadAngle = Vector2.new(180, 180)
			e.Rotation = NumberRange.new(0, 90)
			e.RotSpeed = NumberRange.new(-40, 40)
			e.Shape = Enum.ParticleEmitterShape.Sphere
			e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
			e.Parent = part
		end
	end
	for _, cluster in clusters do
		local rgb = cluster.rgb / math.max(cluster.rgb.X, cluster.rgb.Y, cluster.rgb.Z, 1e-3)
		local part = fxPart("Glow", cluster.p, Vector3.one, model)
		local range = math.min(6 + cluster.reach * 2, 14)
		pointLight(
			part,
			Color3.new(rgb.X, rgb.Y, rgb.Z),
			if cluster.crystal then 1.2 else 1.0,
			range
		)
	end
	local spores = info.spores
	if spores then
		local glow = spores.c
		local source = fxPart(
			"SporeSource",
			conceptToWorld(spores.p),
			Vector3.new(spores.r * 2, 0.4, spores.r * 2),
			model
		)
		source:SetAttribute("Radius", spores.r)
		source:SetAttribute("Glow", glow)
		local fall = 0.95
		local e = Instance.new("ParticleEmitter")
		e.Name = "Spores"
		e.Texture = "rbxassetid://" .. fx.spore
		e.Color = ColorSequence.new(glow:Lerp(Color3.new(1, 1, 1), 0.25))
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Brightness = 3
		e.Size = NumberSequence.new(0.22, 0.1)
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.06, 0.1),
			NumberSequenceKeypoint.new(0.85, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Lifetime = NumberRange.new(conceptToWorld(spores.p).Y / fall * 0.95)
		e.Rate = 9
		e.Speed = NumberRange.new(fall * 0.9, fall * 1.1)
		e.SpreadAngle = Vector2.new(8, 8)
		e.EmissionDirection = Enum.NormalId.Bottom
		e.Shape = Enum.ParticleEmitterShape.Disc
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.Parent = source
	end
end

return LookPack
