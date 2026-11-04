--!strict
-- Check place only: puts the test client at a portal the same legal way the portal moves a player.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remote = Instance.new("RemoteEvent")
remote.Name = "TrainingCheckPlace"
remote.Parent = ReplicatedStorage
remote.OnServerEvent:Connect(function(player: Player, frame: any)
	local character = player.Character
	if character and typeof(frame) == "CFrame" then
		player:SetAttribute("TrainingWarpUntil", workspace:GetServerTimeNow() + 1.5)
		character:PivotTo(frame)
	end
end)

-- Knocks a training dummy out, as a finishing shot would, so the check can watch it fall and stand up.
local knock = Instance.new("RemoteEvent")
knock.Name = "TrainingCheckKnock"
knock.Parent = ReplicatedStorage
knock.OnServerEvent:Connect(function(_player: Player, dummy: any)
	if typeof(dummy) ~= "Instance" or not dummy:HasTag("RangeDummy") then
		return
	end
	local humanoid = dummy:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = 0
	end
end)
