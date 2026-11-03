--!strict
-- Client-side motion for the look test (owner round 2, 2026-11-01): a few light-carrying spores fall from
-- each giant mushroom so the glow passes over its surroundings, and portal energy breathes. Particle
-- streams themselves are ParticleEmitters created by the server.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local LEAD_SPORES = 4
local FALL_SPEED = 0.95 -- studs per second, matching the spore particles

type Spore = {
	part: Part,
	light: PointLight,
	source: BasePart,
	radius: number,
	x: number,
	z: number,
	y: number,
	top: number,
	phase: number,
}
local spores: { Spore } = {}

local function launch(s: Spore)
	local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * s.radius
	s.x = s.source.Position.X + math.cos(a) * r
	s.z = s.source.Position.Z + math.sin(a) * r
	s.top = s.source.Position.Y
	s.y = s.top
	s.phase = math.random() * math.pi * 2
end

local function addSource(source: BasePart)
	local radius = (source:GetAttribute("Radius") :: number?) or 4
	local glow = (source:GetAttribute("Glow") :: Color3?) or Color3.fromRGB(80, 255, 190)
	for i = 1, LEAD_SPORES do
		local p = Instance.new("Part")
		p.Name = "LeadSpore"
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.one * 0.28
		p.Material = Enum.Material.Neon
		p.Color = glow
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = workspace
		local l = Instance.new("PointLight")
		l.Color = glow
		l.Range = 8
		l.Shadows = false
		l.Parent = p
		local s: Spore = {
			part = p,
			light = l,
			source = source,
			radius = radius,
			x = 0,
			z = 0,
			y = 0,
			top = 0,
			phase = 0,
		}
		launch(s)
		s.y = s.top * (1 - (i - 1) / LEAD_SPORES) -- stagger so the stream is continuous from the start
		table.insert(spores, s)
	end
end

local function consider(d: Instance)
	if d.Name == "SporeSource" and d:IsA("BasePart") then
		addSource(d)
	end
end
for _, d in workspace:GetDescendants() do
	consider(d)
end
workspace.DescendantAdded:Connect(consider)

local portals: { SurfaceAppearance } = {}
local function addPortal(energy: Instance)
	local surface = energy:FindFirstChildOfClass("SurfaceAppearance")
	if surface then
		surface:SetAttribute("BaseEmissive", surface.EmissiveStrength)
		table.insert(portals, surface)
	end
end
for _, e in CollectionService:GetTagged("SlugshotPortalEnergy") do
	addPortal(e)
end
CollectionService:GetInstanceAddedSignal("SlugshotPortalEnergy"):Connect(addPortal)

RunService.RenderStepped:Connect(function(dt: number)
	local t = os.clock()
	for _, s in spores do
		s.y -= FALL_SPEED * dt
		if s.y <= 0.15 then
			launch(s)
		end
		local swayX = math.sin(t * 0.7 + s.phase) * 0.35
		local swayZ = math.cos(t * 0.6 + s.phase) * 0.3
		s.part.Position = Vector3.new(s.x + swayX, s.y, s.z + swayZ)
		-- Fade in under the cap and out just before reaching the floor.
		local k = math.clamp((s.top - s.y) / 1.2, 0, 1) * math.clamp(s.y / 1.5, 0, 1)
		s.light.Brightness = 1.3 * k
		s.part.Transparency = 1 - k
	end
	local pulse = 0.85 + 0.2 * math.sin(t * 1.6) + 0.05 * math.sin(t * 4.1)
	for _, surface in portals do
		surface.EmissiveStrength = ((surface:GetAttribute("BaseEmissive") :: number?) or 1) * pulse
	end
	local scene = workspace:FindFirstChild("LookTest")
	local holder = scene and scene:FindFirstChild("PortalGlow")
	local portalLight = holder and holder:FindFirstChildOfClass("PointLight")
	if portalLight then
		portalLight.Brightness = 1.4 * pulse
	end
end)
