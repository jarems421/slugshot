--!strict
-- Start the owner's combined test holding the loaded gun; native tool switching remains.
local Players = game:GetService("Players")
local StarterPack = game:GetService("StarterPack")
local tool = StarterPack:WaitForChild("Blaster", 90)
assert(tool and tool:IsA("Tool"), "Loaded blaster did not initialize")
assert(tool:FindFirstChild("Floppy"), "Combined test gun must contain Floppy")
tool:SetAttribute("HoldStyle", "Pistol")
local function ready(character: Model)
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end
	local humanoid = character:WaitForChild("Humanoid", 15) :: Humanoid?
	local backpack = player:WaitForChild("Backpack", 15)
	if not humanoid or not backpack or player.Character ~= character then
		return
	end
	local carried = character:FindFirstChild("Blaster") or backpack:FindFirstChild("Blaster")
	if not carried then
		carried = tool:Clone()
		carried.Parent = backpack
	end
	(carried :: Tool):SetAttribute("HoldStyle", "Pistol")
	humanoid:EquipTool(carried :: Tool)
end
local function watch(player: Player)
	player.CharacterAdded:Connect(function(character)
		task.defer(ready, character)
	end)
	if player.Character then
		task.defer(ready, player.Character)
	end
end
Players.PlayerAdded:Connect(watch)
for _, player in Players:GetPlayers() do
	watch(player)
end
workspace:SetAttribute("UnifiedRocklockBuild", "movement-v7.39-solid-muzzle-floppies")
print(
	"[UnifiedRocklock] loaded blaster ready; movement v7.39, Rocklock v2.1, draw/holster and terrain tester included"
)
