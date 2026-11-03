--!strict
-- The lobby plays in first person with the game's settings and no guns (owner, 2026-11-03). V still toggles the camera. The combat HUD
-- isn't here, so this also hides the movement lab's help text, which the HUD would otherwise hide.
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local movement = player:WaitForChild("PlayerScripts"):WaitForChild("MovementSandbox")
local FirstPerson = (require :: any)(movement:WaitForChild("FirstPerson"))

player:SetAttribute("PvpHud", true)

local function enter()
	-- After the movement client has reset its camera for this character.
	task.wait(0.5)
	FirstPerson.setActive(true)
end

player.CharacterAdded:Connect(enter)
if player.Character then
	task.spawn(enter)
end
