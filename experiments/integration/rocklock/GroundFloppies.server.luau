--!strict
-- Cosmetic Floppies on the existing walkways. No pickups, AI or collisions.
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Appearance = require(script.Parent.FloppyAppearance)
local asset = require(ReplicatedStorage:WaitForChild("FloppyAsset")) :: { model: number }
local map = workspace:WaitForChild("Rocklock")
local container = InsertService:LoadAsset(asset.model)
local template = Instance.new("Model")
template.Name = "Floppy"
for _, child in container:GetChildren() do
	child.Parent = template
end
container:Destroy()
Appearance.apply(template, 0.08)
for _, item in template:GetDescendants() do
	if item:IsA("BasePart") then
		item.Anchored = true
		item.CanCollide, item.CanQuery, item.CanTouch = false, false, false
	elseif item:IsA("Bone") then
		item.Transform = CFrame.identity
	end
end
local eyeL = template:FindFirstChild("eye_L", true) :: Bone
local eyeR = template:FindFirstChild("eye_R", true) :: Bone
assert(eyeL and eyeR, "Ground Floppy reference bones missing")
local sourceScale = (eyeR.WorldPosition - eyeL.WorldPosition).Magnitude / 0.74
template:ScaleTo(template:GetScale() * 0.92 / (2.72 * sourceScale))
local group = Instance.new("Folder")
group.Name = "MapFloppies"
group.Parent = workspace
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.FilterDescendantsInstances = { map }
local locations = {
	Vector2.new(-6, -75),
	Vector2.new(6, -73),
	Vector2.new(-6, 75),
	Vector2.new(6, 73),
	Vector2.new(-48, -62),
	Vector2.new(42, -76),
	Vector2.new(-48, 62),
	Vector2.new(42, 76),
}
local count = 0
for index, position in locations do
	local hit =
		workspace:Raycast(Vector3.new(position.X, 21, position.Y), Vector3.new(0, -40, 0), params)
	assert(hit and hit.Normal.Y > 0.7, `Floppy {index} needs a walkable support`)
	local floppy = template:Clone()
	local root = floppy:FindFirstChild("root", true) :: Bone
	local offset = root.WorldPosition - floppy:GetPivot().Position
	local turn = CFrame.Angles(0, index * 1.7, 0)
	floppy:PivotTo(
		CFrame.new(hit.Position + Vector3.yAxis * 0.025)
			* turn
			* CFrame.new(-offset)
			* floppy:GetPivot().Rotation
	)
	floppy:SetAttribute("MapFloppyIndex", index)
	floppy.Parent = group
	count += 1
end
template:Destroy()
workspace:SetAttribute("GroundFloppyCount", count)
print(`[UnifiedRocklock] placed {count} animated Floppies on map supports`)
