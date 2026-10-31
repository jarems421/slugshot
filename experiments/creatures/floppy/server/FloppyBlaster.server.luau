--!strict
-- Floppy test place: a display copy of the owner's blaster at the Rocklock
-- size, given to every player as a Tool (hotbar 1), with Floppy loaded. Slugs
-- shrink when loaded (owner, 2026-10-31), so the gun stays a normal size and
-- Floppy is scaled down to fit its canister. No firing or ammo.
-- The real Rocklock blaster (experiments/movement in the main repo) is left
-- unchanged. The mesh layout is the private BlasterMesh module (ignored
-- private-assets/floppy, copied from the blaster pipeline).
local InsertService = game:GetService("InsertService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterPack = game:GetService("StarterPack")

type MeshSpec = {
	name: string,
	color: string,
	material: string,
	reflectance: number,
	centre: Vector3,
	size: Vector3,
}

local spec = (require :: any)(ServerStorage:WaitForChild("BlasterMesh")) :: {
	model: number,
	rotation: CFrame?,
	meshes: { MeshSpec },
}
local asset = require(ReplicatedStorage:WaitForChild("FloppyAsset")) :: { model: number }

-- Gun space: X right, Y up, -Z toward the muzzle, origin at the grip. Same
-- size as the Rocklock blaster: 25% larger than the 2.2-stud mesh, and the
-- width a further 25%.
local SCALE = Vector3.new(1.25 * 1.25, 1.25, 1.25)
local CANISTER = "CanisterTeal"
local canisterSpec: MeshSpec? = nil
for _, mesh in spec.meshes do
	if mesh.name == CANISTER then
		canisterSpec = mesh
	end
end
assert(canisterSpec, "BlasterMesh has no canister")
local canisterSize = canisterSpec.size * SCALE
local canisterCentre = canisterSpec.centre * SCALE

local function cosmetic(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Anchored = false
end

local tool = Instance.new("Tool")
tool.Name = "Blaster"
tool.ToolTip = "Blaster (Floppy loaded)"
tool.CanBeDropped = false
-- Rocklock's pistol grip: barrel tilted 0.2 rad above the arm, grip 0.14 studs into the hand.
local tilt, inset = 0.2, 0.14
tool.Grip = CFrame.new(Vector3.new(0, -math.sin(tilt), -math.cos(tilt)) * inset)
	* CFrame.Angles(-tilt, 0, 0)

local handle = Instance.new("Part")
handle.Name = "Handle"
handle.Size = Vector3.new(0.4, 0.4, 0.4)
handle.Transparency = 1
cosmetic(handle)
handle.Parent = tool

local function attach(part: BasePart, offset: CFrame, parent: Instance)
	cosmetic(part)
	local weld = Instance.new("Weld")
	weld.Part0, weld.Part1, weld.C0 = handle, part, offset
	weld.Parent = part
	part.Parent = parent
end

-- Blaster meshes, as the Rocklock tool places them (axis detection included).
local ok, model = pcall(InsertService.LoadAsset, InsertService, spec.model)
assert(ok, "could not load blaster model: " .. tostring(model))
local parts: { [MeshSpec]: MeshPart } = {}
for _, mesh in spec.meshes do
	local part = model:FindFirstChild(mesh.name, true)
	assert(part and part:IsA("MeshPart"), "blaster model has no mesh " .. mesh.name)
	parts[mesh] = part
end
local function mismatch(a: Vector3, b: Vector3): number
	return (a / math.max(a.X, a.Y, a.Z) - b / math.max(b.X, b.Y, b.Z)).Magnitude
end
local upright, lying = 0, 0
for mesh, part in parts do
	upright += mismatch(part.MeshSize, mesh.size)
	lying += mismatch(part.MeshSize, Vector3.new(mesh.size.X, mesh.size.Z, mesh.size.Y))
end
local turned = lying < upright
local fix = (if turned then CFrame.Angles(-math.pi / 2, 0, 0) else CFrame.identity)
	* (spec.rotation or CFrame.identity)
for mesh, part in parts do
	local s = mesh.size * SCALE
	part.Name = mesh.name
	part.Size = if turned then Vector3.new(s.X, s.Z, s.Y) else s
	part.Color = Color3.fromHex(mesh.color)
	part.Material = (Enum.Material :: any)[mesh.material]
	part.Reflectance = mesh.reflectance
	if mesh.name == CANISTER then
		-- Clear, faintly blue shell. Not Glass (it blurs and darkens what's
		-- behind it) and not Neon (it tints the slug): the glow comes from the
		-- trim, and the slug carries his own soft glow (below).
		part.Material = Enum.Material.SmoothPlastic
		part.Color = Color3.fromRGB(120, 170, 255)
		part.Transparency = 0.9
		part.Reflectance = 0.1
		-- A faint light-blue spill onto the gun and hand.
		local glow = Instance.new("PointLight")
		glow.Name = "ChamberGlow"
		glow.Color = Color3.fromRGB(170, 215, 255)
		glow.Brightness = 0.8
		glow.Range = 3
		glow.Shadows = false
		glow.Parent = part
		glow.Parent = part
	end
	attach(part, CFrame.new(mesh.centre * SCALE) * fix, tool)
end
model:Destroy()

-- Soft light-blue trim on the chamber: a ring at each end and a thin strip along
-- the top and bottom edges, so the tube glows without covering the slug.
local GLOW = Color3.fromRGB(165, 210, 255)
local radius = math.min(canisterSize.X, canisterSize.Y) / 2
local function trim(name: string, size: Vector3, offset: CFrame)
	local part = Instance.new("Part")
	part.Name = name
	part.Material = Enum.Material.Neon
	part.Color = GLOW
	part.Size = size
	part.Transparency = 0.45
	part.CastShadow = false
	attach(part, offset, tool)
	return part
end
for i, z in { -1, 1 } do
	local ring = trim(
		"ChamberRing" .. i,
		Vector3.new(0.03, radius * 2.04, radius * 2.04),
		CFrame.new(canisterCentre + Vector3.new(0, 0, z * (canisterSize.Z / 2 - 0.04)))
			* CFrame.Angles(0, math.pi / 2, 0)
	)
	ring.Shape = Enum.PartType.Cylinder
end
for i, y in { -1, 1 } do
	trim(
		"ChamberStrip" .. i,
		Vector3.new(0.02, 0.02, canisterSize.Z - 0.08),
		CFrame.new(canisterCentre + Vector3.new(0, y * radius * 0.98, 0))
	)
end

-- Floppy inside the canister: lying head-first toward the muzzle, on his back
-- so his face shows through the glass.
local ok2, container = pcall(InsertService.LoadAsset, InsertService, asset.model)
assert(ok2, "could not load Floppy: " .. tostring(container))
local floppy = Instance.new("Model")
floppy.Name = "Floppy"
for _, child in (container :: Instance):GetChildren() do
	child.Parent = floppy
end
(container :: Instance):Destroy()
-- Loaded form: shrink until he fills the canister lying down (his width
-- across the gun, his depth up, his height along the barrel). His true size
-- comes from his eye spacing (0.74 at source) and his source dimensions,
-- because the bounding box of an imported skinned model can be inflated.
local SOURCE_SIZE = Vector3.new(1.7, 2.72, 1.77) -- body width (no antenna tips), height, depth
local EYE_SPACING = 0.74
local eyeL = floppy:FindFirstChild("eye_L", true) :: Bone
local eyeR = floppy:FindFirstChild("eye_R", true) :: Bone
local _, reported = floppy:GetBoundingBox()
local current = (eyeR.WorldPosition - eyeL.WorldPosition).Magnitude / EYE_SPACING
local target = math.min(
	canisterSize.X * 0.95 / SOURCE_SIZE.X,
	canisterSize.Y * 0.97 / SOURCE_SIZE.Z,
	canisterSize.Z * 0.95 / SOURCE_SIZE.Y
)
local shrink = target / current
floppy:ScaleTo(shrink)
-- His middle: the root bone sits at the centre of his base, so go up half his height.
local root = floppy:FindFirstChild("root", true) :: Bone
local middle = CFrame.new(root.WorldPosition + Vector3.yAxis * SOURCE_SIZE.Y * target / 2)
-- Model up (+Y) -> gun -Z (muzzle); model face (-Z) -> gun +Y (up).
local lie = CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1))
local placed = CFrame.new(canisterCentre) * lie
for _, d in floppy:GetDescendants() do
	if d:IsA("BasePart") then
		local relative = middle:ToObjectSpace(d.CFrame)
		attach(d, placed * relative, d.Parent :: Instance)
	end
end
floppy.Parent = tool
-- Lit from within: a constant, unlit fill in his own sage green, so he reads
-- clearly in the chamber whatever the lighting. Small lights inside the gun
-- flickered on and off with Roblox's light culling and flared the prongs.
local inner = Instance.new("Highlight")
inner.Name = "ChamberGlow"
inner.FillColor = Color3.fromRGB(176, 180, 138)
inner.FillTransparency = 0.55
inner.OutlineTransparency = 1
inner.DepthMode = Enum.HighlightDepthMode.Occluded
inner.Parent = floppy
print(
	string.format(
		"Floppy blaster: canister %.2f x %.2f x %.2f studs; Floppy loaded at %.0f%% of ground size,"
			.. " %.2f wide x %.2f long (bounding box said %.2f x %.2f x %.2f)",
		canisterSize.X,
		canisterSize.Y,
		canisterSize.Z,
		shrink * 100,
		SOURCE_SIZE.X * target,
		SOURCE_SIZE.Y * target,
		reported.X,
		reported.Y,
		reported.Z
	)
)

tool.Parent = StarterPack
for _, player in Players:GetPlayers() do
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack and not backpack:FindFirstChild(tool.Name) then
		tool:Clone().Parent = backpack
	end
end
