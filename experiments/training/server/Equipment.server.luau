--!strict
-- One owner for the game's weapon lifecycle. Lobby: carried at the hip, unusable.
-- Training: automatically drawn. Runs independently of the arena's art loading.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPack = game:GetService("StarterPack")
local Combat = require(ReplicatedStorage:WaitForChild("Combat"))

local function watch(player: Player)
	local function characterAdded(character: Model)
		-- CharacterAdded can run before Roblox parents the new character into Workspace.
		if not character.Parent then
			character.AncestryChanged:Wait()
		end
		local backpack = player:WaitForChild("Backpack") :: Backpack
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		if player.Character ~= character then
			return
		end
		local function update()
			if player.Character ~= character or not character.Parent then
				return
			end
			local allowed = Combat.canUseBlaster(player)
			character:SetAttribute("LobbyHolstered", not allowed)
			for _, holder in { character, backpack } :: { Instance } do
				for _, item in holder:GetChildren() do
					if item:IsA("Tool") and Combat.isBlaster(item) then
						item.Enabled = allowed
						if allowed and humanoid.Health > 0 and item.Parent == backpack then
							item:SetAttribute("HoldStyle", "Pistol")
							humanoid:EquipTool(item)
						elseif not allowed and item.Parent == character then
							item.Parent = backpack
						end
					end
				end
			end
		end
		-- Defer reparenting out of ChildAdded; doing it inside that event can conflict
		-- with Roblox's own Tool parenting. A forged draw is still rejected by combat.
		local function itemAdded(item: Instance)
			if Combat.isBlaster(item) then
				task.defer(update)
			end
		end
		local connections = {
			character.ChildAdded:Connect(itemAdded),
			backpack.ChildAdded:Connect(itemAdded),
			player:GetAttributeChangedSignal("InTraining"):Connect(update),
			character:GetAttributeChangedSignal("TrainingArrived"):Connect(update),
		}
		character.Destroying:Once(function()
			for _, connection in connections do
				connection:Disconnect()
			end
		end)
		update()
		-- StarterPack may be populated after the character appears on a cold join.
		local template = StarterPack:WaitForChild("Blaster", 120)
		if not template or player.Character ~= character or not character.Parent then
			return
		end
		if not character:FindFirstChild("Blaster") and not backpack:FindFirstChild("Blaster") then
			template:Clone().Parent = backpack
		end
		update()
	end
	player.CharacterAdded:Connect(characterAdded)
	if player.Character then
		task.spawn(characterAdded, player.Character)
	end
end

Players.PlayerAdded:Connect(watch)
for _, player in Players:GetPlayers() do
	watch(player)
end
