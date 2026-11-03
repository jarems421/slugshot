--!strict
-- Review-only: put the owner near a Floppy after the lobby art has loaded.
local Players = game:GetService("Players")
local function arrive(character: Model)
	while not workspace:GetAttribute("HubSolid") do
		task.wait(0.2)
	end
	local group = workspace:WaitForChild("HubArt"):WaitForChild("GroveSlugs")
	local resident = group:FindFirstChild("GroveSlug3") or group:FindFirstChildWhichIsA("Model")
	if resident and resident:IsA("Model") then
		local root = character:WaitForChild("HumanoidRootPart") :: BasePart
		local at = resident:GetPivot().Position + Vector3.new(0, 4, 7)
		root.CFrame = CFrame.lookAt(at, resident:GetPivot().Position + Vector3.yAxis * 4)
		root.AssemblyLinearVelocity = Vector3.zero
	end
end
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(arrive)
end)
for _, player in Players:GetPlayers() do
	player.CharacterAdded:Connect(arrive)
	if player.Character then
		task.spawn(arrive, player.Character)
	end
end
