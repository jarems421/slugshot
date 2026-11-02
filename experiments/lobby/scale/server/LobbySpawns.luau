--!strict
-- Spawn spots on the floating rock, all facing the PvP gate (-Z). Mounted beside the generated copy of
-- the movement server, which calls frameFor from its one spawn line and respawnY from its fall check.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local layout = require(ReplicatedStorage:WaitForChild("LobbyScale"):WaitForChild("layout")) :: any
local rock = layout.spawnRock
local SLOTS = 25
local GOLDEN_ANGLE = 2.39996

local slots: { [Player]: number } = {}
local LobbySpawns = { respawnY = layout.fall.respawnY :: number }

Players.PlayerRemoving:Connect(function(player: Player)
	slots[player] = nil
end)

local function freeSlot(): number
	local taken: { [number]: boolean } = {}
	for _, slot in slots do
		taken[slot] = true
	end
	for slot = 1, SLOTS do
		if not taken[slot] then
			return slot
		end
	end
	return math.random(SLOTS)
end

function LobbySpawns.frameFor(player: Player): CFrame
	local slot = slots[player]
	if not slot then
		slot = freeSlot()
		slots[player] = slot
	end
	-- A sunflower spiral spreads a full server evenly across the rock.
	local distance = rock.spawnRadius * math.sqrt((slot - 0.5) / SLOTS)
	local angle = slot * GOLDEN_ANGLE
	return CFrame.new(distance * math.cos(angle), rock.spawnY, distance * math.sin(angle))
end

return table.freeze(LobbySpawns)
