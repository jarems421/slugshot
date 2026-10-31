--!strict
-- Floppy test place: loads the owner's uploaded Floppy model, anchors it and
-- stands it on the floor facing -Z. The asset id lives only in ignored
-- private-assets/floppy/FloppyAsset.luau.
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local asset = require(ReplicatedStorage:WaitForChild("FloppyAsset")) :: { model: number }

local ok, container = pcall(InsertService.LoadAsset, InsertService, asset.model)
if not ok then
	warn("Floppy: LoadAsset failed: " .. tostring(container))
	return
end

local model = Instance.new("Model")
model.Name = "Floppy"
for _, child in (container :: Instance):GetChildren() do
	child.Parent = model
end
(container :: Instance):Destroy()

local meshes, bones = {}, {}
for _, d in model:GetDescendants() do
	if d:IsA("BasePart") then
		d.Anchored = true
		d.CanCollide = false
		d.CanQuery = false
		d.CanTouch = false
		table.insert(meshes, d.Name)
	elseif d:IsA("Bone") then
		table.insert(bones, d.Name)
	end
end
model.Parent = workspace
local box, size = model:GetBoundingBox()
model:PivotTo(model:GetPivot() + Vector3.new(-box.X, size.Y / 2 - box.Y, -box.Z))
table.sort(meshes)
table.sort(bones)
local appearance = model:FindFirstChildWhichIsA("SurfaceAppearance", true)
print(
	string.format(
		"Floppy: loaded %d parts {%s}, %d bones {%s}, size %.2f x %.2f x %.2f studs, SurfaceAppearance=%s",
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
