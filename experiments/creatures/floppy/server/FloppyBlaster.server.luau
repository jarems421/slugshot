--!strict
-- Floppy test place: a display copy of the owner's blaster at the Rocklock
-- size reduced by 12%, given to every player as a Tool (hotbar 1), with Floppy loaded. Slugs
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
local Appearance = require(script.Parent.FloppyAppearance)
local asset = require(ReplicatedStorage:WaitForChild("FloppyAsset")) :: {
	model: number,
}

-- Gun space: X right, Y up, -Z toward the muzzle, origin at the grip. Same
-- size as the Rocklock blaster: 25% larger than the 2.2-stud mesh, and the
-- width a further 25%.
local SCALE = Vector3.new(1.25 * 1.25, 1.25, 1.25) * 0.88
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
	part.CastShadow = false
end

local tool = Instance.new("Tool")
tool.Name = "Blaster"
tool.ToolTip = "Blaster (Floppy loaded)"
tool.CanBeDropped = false
tool:SetAttribute("BlasterMotionDriver", true)
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
		-- trim and the inward-facing surface light below.
		part.Material = Enum.Material.SmoothPlastic
		part.Color = Color3.fromRGB(120, 170, 255)
		part.Transparency = 0.9
		part.Reflectance = 0.1
	end
	attach(part, CFrame.new(mesh.centre * SCALE) * fix, tool)
end
-- The light inside the charger spiral. The spiral itself never moves: these thin bars sit
-- just proud of the backplate and under the vane tops, so they show only through the gaps.
-- The combat client sweeps them round while charging; the later bars form the trail.
for mesh in parts do
	if mesh.name == "ChargerBlack" then
		local diameter = math.min(mesh.size.Y, mesh.size.Z) * SCALE.Y * 0.84
		local depth = mesh.size.X * SCALE.X + 0.008
		for index = 1, 4 do
			local light = Instance.new("Part")
			light.Name = `ChargerLight{index}`
			light.Material = Enum.Material.Neon
			light.Color = Color3.fromRGB(205, 232, 255)
			light.Size = Vector3.new(depth, diameter, 0.035)
			light.Transparency = 1
			attach(light, CFrame.new(mesh.centre * SCALE), tool)
		end
		break
	end
end
model:Destroy()

-- The sight pod on top of the housing. Closed, it reads as part of the gun; the combat client
-- opens it when aiming (AdsSight). Gun-space: X right, Y up, -Z toward the muzzle.
-- Seated on the receiver roof over the charger, 0.45 studs forward of the old mount.
-- The short saddle feet follow the two roof levels; the cover stays flat when shut.
local POD = Vector3.new(0, 0.68, -0.6)
local function sightPart(
	name: string,
	size: Vector3,
	offset: Vector3,
	color: Color3,
	material: Enum.Material,
	transparency: number?
)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Transparency = transparency or 0
	attach(part, CFrame.new(POD + offset), tool)
end
local GRAPHITE = Color3.fromRGB(37, 45, 52)
local STEEL = Color3.fromRGB(162, 171, 177)
local BURNT = Color3.fromRGB(150, 66, 32)
sightPart("AdsBase", Vector3.new(0.19, 0.026, 0.22), Vector3.zero, GRAPHITE, Enum.Material.Metal)
sightPart(
	"AdsMountFront",
	Vector3.new(0.16, 0.052, 0.055),
	Vector3.new(0, -0.038, -0.09),
	GRAPHITE,
	Enum.Material.Metal
)
sightPart(
	"AdsMountRear",
	Vector3.new(0.16, 0.034, 0.055),
	Vector3.new(0, -0.029, 0.09),
	GRAPHITE,
	Enum.Material.Metal
)
sightPart(
	"AdsEmitter",
	Vector3.new(0.09, 0.03, 0.12),
	Vector3.new(0, 0.012, 0),
	STEEL,
	Enum.Material.Metal
)
sightPart(
	"AdsLens",
	Vector3.new(0.06, 0.008, 0.08),
	Vector3.new(0, 0.03, 0),
	Color3.fromRGB(235, 240, 237),
	Enum.Material.Neon,
	1
)
local SIDES: { [string]: number } = { L = -1, R = 1 }
for tag, sign in SIDES do
	sightPart(
		"AdsDoor" .. tag,
		Vector3.new(0.085, 0.016, 0.21),
		Vector3.new(sign * 0.0425, 0.026, 0),
		BURNT,
		Enum.Material.Metal
	)
	sightPart(
		"AdsProng" .. tag,
		Vector3.new(0.012, 0.025, 0.03),
		Vector3.new(sign * 0.028, 0.015, 0),
		GRAPHITE,
		Enum.Material.Metal,
		1
	)
end

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

-- Floppy inside the canister: lying head-first toward the muzzle, belly down.
local ok2, container = pcall(InsertService.LoadAsset, InsertService, asset.model)
assert(ok2, "could not load Floppy: " .. tostring(container))
local floppy = Instance.new("Model")
floppy.Name = "Floppy"
for _, child in (container :: Instance):GetChildren() do
	child.Parent = floppy
end
(container :: Instance):Destroy()
Appearance.apply(floppy, 0.16)
-- Use actual bone axes to handle importer rotations, then move the complete
-- skinned model as one assembly. Never place its mesh pieces independently.
local SOURCE_SIZE = Vector3.new(1.966, 2.72, 1.774)
local EYE_SPACING = 0.74
local eyeL = floppy:FindFirstChild("eye_L", true) :: Bone
local eyeR = floppy:FindFirstChild("eye_R", true) :: Bone
local rootBone = floppy:FindFirstChild("root", true) :: Bone
local head = floppy:FindFirstChild("head", true) :: Bone
assert(eyeL and eyeR and rootBone and head, "Floppy is missing its reference bones")
for _, descendant in floppy:GetDescendants() do
	if descendant:IsA("Bone") then
		descendant.Transform = CFrame.identity
	end
end
local _, reported = floppy:GetBoundingBox()
local current = (eyeR.WorldPosition - eyeL.WorldPosition).Magnitude / EYE_SPACING
assert(current > 1e-5, "Floppy eye spacing is zero")
-- Leave room for the antenna tips, idle motion and the chamber walls.
local target = math.min(
	canisterSize.X * 0.84 / SOURCE_SIZE.X,
	canisterSize.Y * 0.82 / SOURCE_SIZE.Z,
	canisterSize.Z * 0.86 / SOURCE_SIZE.Y,
	-- Turning sweeps the source rectangle's corners. Reserve a circular
	-- envelope plus articulation margin, not just its front-facing width.
	math.min(canisterSize.X, canisterSize.Y)
		* 0.9
		/ (Vector2.new(SOURCE_SIZE.X, SOURCE_SIZE.Z).Magnitude + 0.2)
)
local shrink = target / current
floppy:ScaleTo(floppy:GetScale() * shrink)
-- Numeric containment contract for the client-only inspect, derived from this fit.
floppy:SetAttribute("ChamberCentre", canisterCentre)
floppy:SetAttribute("ChamberHalfSize", canisterSize / 2)
floppy:SetAttribute("LoadedHalfLength", (SOURCE_SIZE.Y / 2 + 0.12) * target)
floppy:SetAttribute(
	"LoadedRadius",
	(Vector2.new(SOURCE_SIZE.X, SOURCE_SIZE.Z).Magnitude / 2 + 0.1) * target
)
floppy:SetAttribute(
	"InspectHopHeight",
	math.max(0, math.min(0.035, canisterSize.Z / 2 - (SOURCE_SIZE.Y / 2 + 0.12) * target - 0.008))
)
local up = (head.WorldPosition - rootBone.WorldPosition).Unit
local face = (eyeL.WorldPosition + eyeR.WorldPosition) / 2 - head.WorldPosition
local front = (face - up * face:Dot(up)).Unit
local back = -front
local reference = CFrame.fromMatrix(
	rootBone.WorldPosition + up * SOURCE_SIZE.Y * target / 2,
	up:Cross(back),
	up,
	back
)
-- Head toward the muzzle, belly down and back upward, irrespective of import axes.
local placed = CFrame.fromMatrix(canisterCentre, Vector3.xAxis, -Vector3.zAxis)
floppy:PivotTo(placed * reference:Inverse() * floppy:GetPivot())
local loadedUp = (head.WorldPosition - rootBone.WorldPosition).Unit
local loadedFace = (eyeL.WorldPosition + eyeR.WorldPosition) / 2 - head.WorldPosition
local loadedFront = (loadedFace - loadedUp * loadedFace:Dot(loadedUp)).Unit
assert(loadedUp:Dot(-Vector3.zAxis) > 0.995, "Loaded Floppy's head must face the muzzle")
assert(loadedFront:Dot(-Vector3.yAxis) > 0.995, "Loaded Floppy must rest on its belly")
for _, descendant in floppy:GetDescendants() do
	if descendant:IsA("BasePart") then
		local offset = handle.CFrame:ToObjectSpace(descendant.CFrame)
		attach(descendant, offset, descendant.Parent :: Instance)
	end
end
floppy.Parent = tool

-- Inferno's base form in the canister, fitted the same way. CombatClient shows whichever slug is selected.
local infernoAsset = ReplicatedStorage:FindFirstChild("InfernoAsset")
local infernoAppearance = script.Parent:FindFirstChild("InfernoAppearance")
local infernoMaterials = game:GetService("ServerStorage"):FindFirstChild("InfernoMaterials")
if infernoAsset and infernoAppearance and infernoMaterials then
	local INFERNO_SIZE = Vector3.new(1.636, 2.506, 1.83) -- source units: wide, tall, deep
	local infernoAssets = (require :: any)(infernoAsset)
	local infernoOk, infernoContainer =
		pcall(InsertService.LoadAsset, InsertService, infernoAssets.base.model)
	if infernoOk then
		local inferno = Instance.new("Model")
		-- Not "Inferno": InfernoMotion would set him flipping about inside the gun.
		inferno.Name = "InfernoLoaded"
		for _, child in (infernoContainer :: Instance):GetChildren() do
			child.Parent = inferno
		end
		(infernoContainer :: Instance):Destroy()
		local fit = math.min(
			canisterSize.X * 0.84 / INFERNO_SIZE.X,
			canisterSize.Y * 0.82 / INFERNO_SIZE.Z,
			canisterSize.Z * 0.86 / INFERNO_SIZE.Y
		);
		(require :: any)(infernoAppearance).dress(inferno, infernoMaterials, fit)
		local left = inferno:FindFirstChild("antenna_L", true) :: Bone
		local right = inferno:FindFirstChild("antenna_R", true) :: Bone
		local infernoRoot = inferno:FindFirstChild("root", true) :: Bone
		local infernoHead = inferno:FindFirstChild("head", true) :: Bone
		inferno:ScaleTo(
			inferno:GetScale() * fit / ((right.WorldPosition - left.WorldPosition).Magnitude / 0.72)
		)
		local infernoUp = (infernoHead.WorldPosition - infernoRoot.WorldPosition).Unit
		local infernoBack = -(right.WorldPosition - left.WorldPosition).Unit:Cross(infernoUp)
		local infernoReference = CFrame.fromMatrix(
			infernoRoot.WorldPosition + infernoUp * INFERNO_SIZE.Y * fit / 2,
			infernoUp:Cross(infernoBack),
			infernoUp,
			infernoBack
		)
		inferno:PivotTo(placed * infernoReference:Inverse() * inferno:GetPivot())
		for _, descendant in inferno:GetDescendants() do
			if descendant:IsA("BasePart") then
				attach(
					descendant,
					handle.CFrame:ToObjectSpace(descendant.CFrame),
					descendant.Parent :: Instance
				)
				if not descendant:IsA("MeshPart") then
					descendant.Transparency = 1
				end
			end
		end
		inferno.Parent = tool
	else
		warn(`could not load Inferno: {infernoContainer}`)
	end
end

-- One broad, low-intensity fill instead of sub-stud light pools. The
-- albedo-modulated material floor keeps the slug readable if local lighting
-- changes quality/visibility; the white coil is a constant Neon surface.
local emitter = Instance.new("Part")
emitter.Name = "ChamberInteriorEmitter"
emitter.Size = Vector3.new(0.05, 0.05, 0.05)
emitter.Transparency = 1
emitter.CastShadow = false
attach(emitter, CFrame.new(canisterCentre + Vector3.yAxis * 0.35), tool)
local fill = Instance.new("PointLight")
fill.Name = "ChamberBroadFill"
fill.Color = Color3.fromRGB(245, 246, 244)
fill.Brightness = 0.35
fill.Range = 8
fill.Shadows = false
fill.Parent = emitter

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
