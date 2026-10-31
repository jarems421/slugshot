--!strict
-- Floppy test place: a display copy of the owner's blaster, scaled up so a
-- 0.83-stud Floppy fits inside its canister, given to every player as a Tool
-- (hotbar 1). No firing or ammo: this only shows the slug loaded in the gun.
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

-- Gun space: X right, Y up, -Z toward the muzzle, origin at the grip.
-- The canister is 0.216 studs across; Floppy is ~0.6 wide and 0.54 deep, so
-- the whole gun grows until the canister is ~0.66 across.
local CANISTER = "CanisterTeal"
local CANISTER_FIT = 0.66
local canisterSpec: MeshSpec? = nil
for _, mesh in spec.meshes do
	if mesh.name == CANISTER then
		canisterSpec = mesh
	end
end
assert(canisterSpec, "BlasterMesh has no canister")
local SCALE = CANISTER_FIT / math.min(canisterSpec.size.X, canisterSpec.size.Y)
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
		-- A see-through shell so the slug inside shows.
		part.Material = Enum.Material.Glass
		part.Transparency = 0.6
	end
	attach(part, CFrame.new(mesh.centre * SCALE) * fix, tool)
end
model:Destroy()

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
local box, size = floppy:GetBoundingBox()
-- Model up (+Y) -> gun -Z (muzzle); model face (-Z) -> gun +Y (up).
local lie = CFrame.fromMatrix(Vector3.zero, Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1))
local placed = CFrame.new(canisterCentre) * lie
for _, d in floppy:GetDescendants() do
	if d:IsA("BasePart") then
		local relative = CFrame.new(box.Position):ToObjectSpace(d.CFrame)
		attach(d, placed * relative, d.Parent :: Instance)
	end
end
floppy.Parent = tool
print(
	string.format(
		"Floppy blaster: scale %.2f, length %.2f studs, canister %.2f across x %.2f long, Floppy %.2f x %.2f x %.2f",
		SCALE,
		2.2 * SCALE,
		canisterSpec.size.X * SCALE,
		canisterSpec.size.Z * SCALE,
		size.X,
		size.Y,
		size.Z
	)
)

tool.Parent = StarterPack
for _, player in Players:GetPlayers() do
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack and not backpack:FindFirstChild(tool.Name) then
		tool:Clone().Parent = backpack
	end
end
