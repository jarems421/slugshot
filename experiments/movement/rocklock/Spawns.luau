--!strict
-- The map chooses a stable spawn before the unchanged controller initializes its
-- authority history. No teleport-after-spawn or client spawn request is involved.
local Players = game:GetService("Players")
local slots: { [Player]: number } = {}
local Spawns = {}

Players.PlayerRemoving:Connect(function(player: Player)
	slots[player] = nil
end)

function Spawns.frameFor(player: Player): CFrame
	local slot = slots[player]
	if not slot then
		local occupied: { [number]: boolean } = {}
		for _, taken in slots do
			occupied[taken] = true
		end
		-- Two-player playtest. Extra Studio clients alternate rather than blocking joins.
		slot = if not occupied[1]
			then 1
			elseif not occupied[2] then 2
			else (#Players:GetPlayers() % 2) + 1
		slots[player] = slot
	end
	local map = workspace:WaitForChild("Rocklock")
	local markers = map:WaitForChild("Spawns")
	local marker = markers:WaitForChild(if slot == 1 then "North" else "South") :: BasePart
	player:SetAttribute("RocklockSpawn", marker.Name)
	return marker.CFrame
end

return table.freeze(Spawns)
