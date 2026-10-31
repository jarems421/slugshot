--!strict
-- Floppy test place: loads the owner's uploaded Floppy model, anchors it and
-- stands it on the floor facing -Z. The asset id lives only in ignored
-- private-assets/floppy/FloppyAsset.luau.
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local asset = require(ReplicatedStorage:WaitForChild("FloppyAsset")) :: { model: number }

-- Slugs are about 0.93 studs tall on the ground; show Floppy on a pedestal near eye level.
-- The blaster with Floppy loaded is a Tool (FloppyBlaster).
local PEDESTAL_TOP = 3
local pedestal = Instance.new("Part")
pedestal.Name = "Pedestal"
pedestal.Anchored = true
pedestal.Size = Vector3.new(3.4, PEDESTAL_TOP, 2)
pedestal.Position = Vector3.new(0, PEDESTAL_TOP / 2, 0)
pedestal.Color = Color3.fromRGB(70, 74, 68)
pedestal.Parent = workspace

local function load(id: number, name: string): Model?
	local ok, container = pcall(InsertService.LoadAsset, InsertService, id)
	if not ok then
		warn(name .. ": LoadAsset failed: " .. tostring(container))
		return nil
	end
	local model = Instance.new("Model")
	model.Name = name
	for _, child in (container :: Instance):GetChildren() do
		child.Parent = model
	end
	(container :: Instance):Destroy()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	model.Parent = workspace
	return model
end

-- Stand a model's bounding box on the pedestal top, centred on (x, z).
local function standAt(model: Model, x: number, z: number)
	local box, size = model:GetBoundingBox()
	model:PivotTo(
		model:GetPivot() + Vector3.new(x - box.X, PEDESTAL_TOP + size.Y / 2 - box.Y, z - box.Z)
	)
end

local floppy = load(asset.model, "Floppy")
if floppy then
	standAt(floppy, 0, 0)
	local meshes, bones = {}, {}
	for _, d in floppy:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(meshes, d.Name)
		elseif d:IsA("Bone") then
			table.insert(bones, d.Name)
		end
	end
	table.sort(meshes)
	table.sort(bones)
	local _, size = floppy:GetBoundingBox()
	local appearance = floppy:FindFirstChildWhichIsA("SurfaceAppearance", true)
	print(
		string.format(
			"Floppy: loaded %d parts {%s}, %d bones {%s}, size %.3f x %.3f x %.3f studs, SurfaceAppearance=%s",
			#meshes,
			table.concat(meshes, ", "),
			#bones,
			table.concat(bones, ", "),
			size.X,
			size.Y,
			size.Z,
			tostring(appearance ~= nil)
		)
	)
end
