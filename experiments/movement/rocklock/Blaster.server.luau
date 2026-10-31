--!strict
-- Rocklock: every player always carries the blaster (owner, 2026-10-30). Taking it out
-- and putting it away uses Roblox's standard hotbar (1). There is no firing, damage or
-- ammo: this is the held weapon and its pose only. The movement presentation holds any
-- tool whose HoldStyle is "Pistol". The private place maps ServerStorage's
-- RocklockBlasterMesh: the owner's uploaded blaster model (Open Cloud, account Jamz4136)
-- plus each mesh's colour, size and place in gun space. Without it, or if the model
-- cannot load, a plain native stand-in is used.
local InsertService = game:GetService("InsertService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local StarterPack = game:GetService("StarterPack")
local shared = ReplicatedStorage:WaitForChild("MovementExperiment")
local Config = require(shared.Config)
local Hold = Config.Animation.Hold

-- Gun space: X right, Y up, -Z toward the muzzle, origin at the middle of the grip.
-- The meshes are authored as a 2.2-stud pistol; the owner asked for it larger overall and
-- a bit thicker, so everything grew 25% and the width a further 25%.
-- Owner 2026-10-31: reduce the complete blaster by 12%; private meshes also shorten the grip.
local SCALE = Vector3.new(1.25 * 1.25, 1.25, 1.25) * 0.88

local function cosmetic(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Anchored = false
end

local tool = Instance.new("Tool")
tool.Name = "Blaster"
tool.ToolTip = "Blaster"
tool.CanBeDropped = false
tool:SetAttribute("HoldStyle", "Pistol")
-- The R6 hand frame's -Z runs out along the arm. The barrel tilts GripTilt above the
-- arm's line, and the grip's middle sits GripInset inside the hand block, so the fist
-- wraps the handle while the guard and front stay out ahead. Each hold style turns the
-- grip further (its Wrist) on the clients.
local along = Vector3.new(0, -math.sin(Hold.GripTilt), -math.cos(Hold.GripTilt))
tool.Grip = CFrame.new(along * Hold.GripInset) * CFrame.Angles(-Hold.GripTilt, 0, 0)

local handle = Instance.new("Part")
handle.Name = "Handle"
handle.Size = Vector3.new(0.2, 0.2, 0.2)
handle.Transparency = 1
cosmetic(handle)
handle.Parent = tool

local function attach(part: BasePart, offset: CFrame)
	cosmetic(part)
	local weld = Instance.new("Weld")
	weld.Part0, weld.Part1, weld.C0 = handle, part, offset
	weld.Parent = part
	part.Parent = tool
end

type MeshSpec = {
	name: string,
	color: string,
	material: string,
	reflectance: number,
	centre: Vector3,
	size: Vector3,
}
local abandoned = false -- set when loading takes too long and the stand-in is used
-- Loads the uploaded model and places each named mesh; false if anything is missing.
local function loadMeshes(): boolean
	local source = ServerStorage:FindFirstChild("RocklockBlasterMesh")
	if not (source and source:IsA("ModuleScript")) then
		return false
	end
	-- Private, optional module: required untyped.
	local spec = (require :: any)(
			source
		) :: { model: number, rotation: CFrame?, meshes: { MeshSpec } }
	local ok, model = pcall(InsertService.LoadAsset, InsertService, spec.model)
	if not ok then
		warn(
			`[RocklockBlaster] could not load blaster model {spec.model}: {model}. It belongs to`
				.. " Jamz4136: log Studio into that account, or publish the place under it."
		)
		return false
	end
	local parts: { [MeshSpec]: MeshPart } = {}
	for _, mesh in spec.meshes do
		local part = model:FindFirstChild(mesh.name, true)
		if not (part and part:IsA("MeshPart")) then
			warn("[RocklockBlaster] blaster model has no mesh", mesh.name)
			model:Destroy()
			return false
		end
		parts[mesh] = part
	end
	-- Blender's FBX export can leave its Z-up axes as a turn on each node instead of in
	-- the vertices, so a mesh may arrive lying on its back. Compare every mesh's native
	-- proportions with both readings and pick one for the whole blaster.
	local function mismatch(a: Vector3, b: Vector3): number
		return (a / math.max(a.X, a.Y, a.Z) - b / math.max(b.X, b.Y, b.Z)).Magnitude
	end
	local upright, lying = 0, 0
	for mesh, part in parts do
		local s = mesh.size
		upright += mismatch(part.MeshSize, s)
		lying += mismatch(part.MeshSize, Vector3.new(s.X, s.Z, s.Y))
	end
	local turned = lying < upright
	print(
		`[RocklockBlaster] mesh axes {if turned then "Z-up, turned upright" else "Y-up"}`
			.. ` (mismatch {math.round(upright * 100) / 100} vs {math.round(lying * 100) / 100})`
	)
	if abandoned then
		model:Destroy()
		return false
	end
	local fix = (if turned then CFrame.Angles(-math.pi / 2, 0, 0) else CFrame.identity)
		* (spec.rotation or CFrame.identity)
	for mesh, part in parts do
		local s = mesh.size * SCALE
		part.Name = mesh.name
		part.Size = if turned then Vector3.new(s.X, s.Z, s.Y) else s
		part.Color = Color3.fromHex(mesh.color)
		part.Material = (Enum.Material :: any)[mesh.material]
		part.Reflectance = mesh.reflectance
		attach(part, CFrame.new(mesh.centre * SCALE) * fix)
	end
	model:Destroy()
	return true
end

-- Never leave players without the tool: any loading error falls back to the stand-in.
local loaded, result: any, finished = false, "timed out after 10 s", false
task.spawn(function()
	loaded, result = pcall(loadMeshes)
	finished = true
end)
local started = os.clock()
while not finished and os.clock() - started < 10 do
	task.wait(0.1)
end
abandoned = not finished
if not loaded then
	warn("[RocklockBlaster] mesh setup failed:", result)
	for _, item in tool:GetChildren() do
		if item ~= handle then
			item:Destroy()
		end
	end
end
if not (loaded and result) then
	-- Stand-in: the blaster's main masses, welded to the handle.
	local function piece(
		name: string,
		shape: Enum.PartType,
		size: Vector3,
		offset: CFrame,
		color: string
	)
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = shape
		part.Size = size * SCALE.Y
		part.Color = Color3.fromHex(color)
		part.Material = Enum.Material.SmoothPlastic
		attach(part, CFrame.new(offset.Position * SCALE) * offset.Rotation)
	end
	local lengthwise = CFrame.Angles(0, math.pi / 2, 0) -- cylinders run along X
	piece(
		"Nose",
		Enum.PartType.Block,
		Vector3.new(0.26, 0.52, 1.0),
		CFrame.new(0, 0.18, -1.25),
		"E07A12"
	)
	piece(
		"Canister",
		Enum.PartType.Cylinder,
		Vector3.new(0.6, 0.24, 0.24),
		CFrame.new(0, 0.18, -0.95) * lengthwise,
		"2C6F7C"
	)
	piece(
		"Body",
		Enum.PartType.Block,
		Vector3.new(0.18, 0.5, 0.62),
		CFrame.new(0, 0.32, -0.32),
		"4E5156"
	)
	piece(
		"Charger",
		Enum.PartType.Cylinder,
		Vector3.new(0.22, 0.32, 0.32),
		CFrame.new(0, 0.33, -0.48),
		"0A0A0B"
	)
	piece(
		"Grip",
		Enum.PartType.Block,
		Vector3.new(0.2, 0.62 * 0.82, 0.28),
		CFrame.new(0, 0.0058, 0.04) * CFrame.Angles(-0.42, 0, 0),
		"22304A"
	)
end

tool.Parent = StarterPack

-- StarterPack covers every spawn; this covers anyone who spawned before it existed.
local function give(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local character = player.Character
	if
		backpack
		and not backpack:FindFirstChild(tool.Name)
		and not (character and character:FindFirstChild(tool.Name))
	then
		tool:Clone().Parent = backpack
	end
end
for _, player in Players:GetPlayers() do
	give(player)
end
