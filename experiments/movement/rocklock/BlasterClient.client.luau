--!strict
-- Shared original draw/holster driver (the Flip toss flourish). The holster mode (hip or
-- disappear) is chosen in the Settings panel, which stores it as the local player's
-- HolsterMode attribute; this copies it onto each character for the animator.
local Players = game:GetService("Players")
local player = Players.LocalPlayer
-- The player's client script is cloned at runtime, outside a static service map.
local movement = player:WaitForChild("PlayerScripts"):WaitForChild("MovementSandbox")
local animator = (require :: any)(movement:WaitForChild("BlasterAnimator"))
local Motion = (require :: any)(movement:WaitForChild("BlasterMotion"))
animator.start()

local function apply()
	local character = player.Character
	if character then
		character:SetAttribute(
			"HolsterMode",
			player:GetAttribute("HolsterMode") or Motion.DefaultMode
		)
	end
end
player.CharacterAdded:Connect(apply)
player:GetAttributeChangedSignal("HolsterMode"):Connect(apply)
apply()
