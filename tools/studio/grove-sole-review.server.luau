--!strict
-- Review-only: inspect the actual imported mesh, not just a model-version label.
local Http = game:GetService("HttpService")
while not workspace:GetAttribute("HubSolid") do
	task.wait(0.2)
end
local group = workspace:WaitForChild("HubArt"):WaitForChild("GroveSlugs")
task.wait(3)
local witnesses = {}
for _, resident in group:GetChildren() do
	if not resident:IsA("Model") or resident:GetAttribute("Slug") ~= "Floppy" then
		continue
	end
	local body = resident:FindFirstChild("FloppyBody", true)
	local root = resident:FindFirstChild("root", true)
	assert(body and body:IsA("MeshPart") and root and root:IsA("Bone"), "review body/root missing")
	local lowest = math.huge
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local corner = body.CFrame:PointToWorldSpace(body.Size * Vector3.new(x, y, z) * 0.5)
				lowest = math.min(
					lowest,
					(corner - root.WorldPosition):Dot(resident:GetPivot().UpVector)
				)
			end
		end
	end
	assert(lowest > -0.04, "old rounded Floppy underside is still loaded")
	table.insert(witnesses, { name = resident.Name, lowestBodyBoundFromRoot = lowest })
end
assert(#witnesses > 0, "no Floppy residents imported")
print("GROVEREVIEW flat sole PASS " .. Http:JSONEncode(witnesses))
