--!strict
-- Shared original draw/holster driver (the Flip toss flourish). K, the one setting,
-- chooses whether the holstered gun hangs at the hip or disappears.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
-- The player's client script is cloned at runtime, outside a static service map.
local movement = player:WaitForChild("PlayerScripts"):WaitForChild("MovementSandbox")
local animator = (require :: any)(movement:WaitForChild("BlasterAnimator"))
local Motion = (require :: any)(movement:WaitForChild("BlasterMotion"))
animator.start()

local function isBlaster(item: Instance): boolean
	return item:IsA("Tool") and item:GetAttribute("BlasterMotionDriver") == true
end

-- Holster setting (local only).
local gui = Instance.new("ScreenGui")
gui.Name = "BlasterStyleHUD"
gui.ResetOnSpawn = false
local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 1)
label.Position = UDim2.new(0.5, 0, 1, -96)
label.Size = UDim2.fromOffset(280, 30)
label.BackgroundColor3 = Color3.fromRGB(20, 28, 40)
label.BackgroundTransparency = 0.25
label.TextColor3 = Color3.fromRGB(229, 239, 248)
label.Font = Enum.Font.GothamMedium
label.TextSize = 16
label.Visible = false
label.Parent = gui
gui.Parent = player:WaitForChild("PlayerGui")

local mode = table.find(Motion.Modes, Motion.DefaultMode) or 1
local function apply()
	local character = player.Character
	if character then
		character:SetAttribute("HolsterMode", Motion.Modes[mode])
	end
end
player.CharacterAdded:Connect(apply)
apply()

RunService.Heartbeat:Connect(function()
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	local holding = tool ~= nil and isBlaster(tool)
	label.Visible = holding
	label.Text = `Holster: {Motion.Modes[mode]} (K)`
end)

ContextActionService:BindAction("RocklockBlasterHolster", function(_, state)
	if state == Enum.UserInputState.Begin then
		mode = mode % #Motion.Modes + 1
		apply()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.K)
