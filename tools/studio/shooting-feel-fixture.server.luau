--!strict
-- Disposable target service; only mapped into the private native check place.
assert(game:GetService("RunService"):IsStudio())
local remote = Instance.new("RemoteFunction")
remote.Name = "ShootingFeelFixture"
local target = Instance.new("Part")
target.Name = "ShootingFeelTarget"
target.Anchored = true
target.Size = Vector3.new(0.4, 45, 40)
target.Material = Enum.Material.SmoothPlastic
target.Parent = workspace
remote.OnServerInvoke = function(player: Player, distance: any, dark: any, height: any)
	assert(
		typeof(distance) == "number" and distance >= 10 and distance <= 150,
		"unsupported fixture distance"
	)
	assert(
		height == nil or (typeof(height) == "number" and math.abs(height) <= 10),
		"unsupported fixture height"
	)
	local root = (player.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
	target.Position = root.Position + Vector3.new(distance, 1.5 + (height or 0), 0)
	target.Color = if dark then Color3.fromRGB(9, 10, 15) else Color3.fromRGB(235, 235, 228)
	return target.Position - Vector3.new(0.2, 0, 0)
end
remote.Parent = game:GetService("ReplicatedStorage")
