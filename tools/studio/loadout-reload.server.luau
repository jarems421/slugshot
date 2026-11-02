--!strict
-- Disposable Studio-only fixture, absent from every normal project.
local RS = game:GetService("ReplicatedStorage")
assert(game:GetService("RunService"):IsStudio())
local reload = Instance.new("RemoteFunction")
reload.Name = "LoadoutReload"
reload.OnServerInvoke = function(player: Player)
	player:LoadCharacterAsync()
	return true
end
reload.Parent = RS
