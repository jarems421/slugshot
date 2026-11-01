--!strict
-- Shared original draw/holster driver (the Flip toss flourish). The holster mode (hip or
-- disappear) is chosen in the Settings panel, which stores it as the local player's
-- HolsterMode attribute; this copies it onto each character for the animator.
local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
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

-- Own the blaster's 1-key toggle once, above the native backpack hotkey. Resolve
-- the actual Tool each press; holster/first-person visual copies are never tools.
ContextActionService:BindActionAtPriority("SlugshotBlasterToggle", function(_, state)
	if UserInputService:GetFocusedTextBox() then
		return Enum.ContextActionResult.Pass
	end
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Sink
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not character or not humanoid or humanoid.Health <= 0 or not backpack then
		return Enum.ContextActionResult.Pass
	end
	local equipped = character:FindFirstChildOfClass("Tool")
	if equipped and equipped:GetAttribute("BlasterMotionDriver") == true then
		humanoid:UnequipTools()
		return Enum.ContextActionResult.Sink
	end
	for _, tool in backpack:GetChildren() do
		if tool:IsA("Tool") and tool:GetAttribute("BlasterMotionDriver") == true then
			humanoid:EquipTool(tool)
			return Enum.ContextActionResult.Sink
		end
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.One)
