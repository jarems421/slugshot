--!strict
-- Shared original draw/holster driver; existing G hold-style selection remains.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("MovementExperiment"):WaitForChild("Config"))
local Hold = Config.Animation.Hold
local player = Players.LocalPlayer
-- The player's client script is cloned at runtime, outside a static service map.
local movement = player:WaitForChild("PlayerScripts"):WaitForChild("MovementSandbox")
local animator = (require :: any)(movement:WaitForChild("BlasterAnimator"))
animator.start()

local function isBlaster(item: Instance): boolean
	return item:IsA("Tool") and item:GetAttribute("BlasterMotionDriver") == true
end

-- Hold-style candidates for the owner to choose between (local only).
local gui = Instance.new("ScreenGui")
gui.Name = "BlasterStyleHUD"
gui.ResetOnSpawn = false
local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 1)
label.Position = UDim2.new(0.5, 0, 1, -96)
label.Size = UDim2.fromOffset(360, 30)
label.BackgroundColor3 = Color3.fromRGB(20, 28, 40)
label.BackgroundTransparency = 0.25
label.TextColor3 = Color3.fromRGB(229, 239, 248)
label.Font = Enum.Font.GothamMedium
label.TextSize = 16
label.Visible = false
label.Parent = gui
gui.Parent = player:WaitForChild("PlayerGui")

local index = table.find(Hold.Order, Hold.Default) or 1
local function current(): string
	return Hold.Order[index]
end
local function apply()
	local character = player.Character
	if character then
		character:SetAttribute("HoldVariant", current())
	end
end
player.CharacterAdded:Connect(apply)
apply()

RunService.Heartbeat:Connect(function()
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	local holding = tool ~= nil and isBlaster(tool)
	label.Visible = holding
	label.Text = `Blaster hold: {current()}  ·  G to switch ({index}/{#Hold.Order})`
end)

ContextActionService:BindAction("RocklockBlasterStyle", function(_, state)
	if state == Enum.UserInputState.Begin then
		index = index % #Hold.Order + 1
		apply()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.G)
