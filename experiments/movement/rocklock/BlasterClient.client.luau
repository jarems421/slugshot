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
local Keybinds = (require :: any)(movement:WaitForChild("Keybinds"))
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

-- The first slug's key draws and holsters the blaster. Resolve the actual Tool each press;
-- holster/first-person visual copies are never tools.
Keybinds.on("slug1", function(pressed: boolean)
	if not pressed then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not character or not humanoid or humanoid.Health <= 0 or not backpack then
		return
	end
	local equipped = character:FindFirstChildOfClass("Tool")
	if equipped and equipped:GetAttribute("BlasterMotionDriver") == true then
		humanoid:UnequipTools()
		return
	end
	for _, tool in backpack:GetChildren() do
		if tool:IsA("Tool") and tool:GetAttribute("BlasterMotionDriver") == true then
			humanoid:EquipTool(tool)
			return
		end
	end
end)
