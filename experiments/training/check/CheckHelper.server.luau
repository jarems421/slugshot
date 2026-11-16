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

-- Attempts a real server equip to verify the production lobby policy reverses it.
local equip = Instance.new("RemoteFunction")
equip.Name = "TrainingCheckEquip"
equip.Parent = ReplicatedStorage
equip.OnServerInvoke = function(player: Player): boolean
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local tool = backpack and backpack:FindFirstChild("Blaster")
	if not character or not humanoid or not tool or not tool:IsA("Tool") then
		return false
	end
	humanoid:EquipTool(tool)
	task.wait(0.4)
	return tool.Parent == backpack and not tool.Enabled
end

local respawn = Instance.new("RemoteFunction")
respawn.Name = "TrainingCheckRespawn"
respawn.Parent = ReplicatedStorage
respawn.OnServerInvoke = function(player: Player): boolean
	player:LoadCharacterAsync()
	return true
end
