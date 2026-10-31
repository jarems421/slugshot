--!strict
-- Settings panel (owner, 2026-10-31): field of view, and whether the holstered blaster
-- hangs at the hip or disappears. Opened with the Settings button or M (the cursor is
-- locked in first person and shift lock). Values are local player attributes read by
-- the camera (FieldOfView), the first-person viewmodel and the holster (HolsterMode);
-- they last for the session.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage:WaitForChild("MovementExperiment"):WaitForChild("Config"))

local player = Players.LocalPlayer
local FOV_MIN, FOV_MAX = 60, 110
local INK = Color3.fromRGB(229, 239, 248)
local PANEL = Color3.fromRGB(20, 26, 34)
local ACCENT = Color3.fromRGB(255, 150, 60)

if player:GetAttribute("FieldOfView") == nil then
	player:SetAttribute("FieldOfView", Config.Camera.Fov)
end
if player:GetAttribute("HolsterMode") == nil then
	player:SetAttribute("HolsterMode", "Hip")
end

local gui = Instance.new("ScreenGui")
gui.Name = "Settings"
gui.ResetOnSpawn = false
gui.DisplayOrder = 10

local function round(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end
local function text(
	parent: Instance,
	value: string,
	size: number,
	position: UDim2,
	extent: UDim2
): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = size
	label.TextColor3 = INK
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = value
	label.Position = position
	label.Size = extent
	label.Parent = parent
	return label
end
local function button(parent: Instance, value: string, position: UDim2, extent: UDim2): TextButton
	local control = Instance.new("TextButton")
	control.AutoButtonColor = false
	control.BackgroundColor3 = Color3.fromRGB(44, 54, 66)
	control.Font = Enum.Font.GothamBold
	control.TextSize = 15
	control.TextColor3 = INK
	control.Text = value
	control.Position = position
	control.Size = extent
	control.Parent = parent
	round(control, 6)
	return control
end

local opener = button(gui, "Settings (M)", UDim2.new(1, -16, 0, 8), UDim2.fromOffset(120, 30))
opener.AnchorPoint = Vector2.new(1, 0)
opener.BackgroundColor3 = PANEL
opener.BackgroundTransparency = 0.25

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(380, 230)
panel.BackgroundColor3 = PANEL
panel.BackgroundTransparency = 0.08
panel.Visible = false
panel.Parent = gui
round(panel, 12)
text(panel, "SETTINGS", 20, UDim2.fromOffset(20, 14), UDim2.fromOffset(200, 26))
-- Modal frees the cursor while the panel is open (first person locks it).
local close = button(panel, "×", UDim2.new(1, -44, 0, 12), UDim2.fromOffset(30, 30))
close.Modal = true
close.TextSize = 22

-- Field of view slider.
text(panel, "Field of view", 15, UDim2.fromOffset(20, 60), UDim2.fromOffset(200, 22))
local fovValue = text(panel, "", 15, UDim2.new(1, -80, 0, 60), UDim2.fromOffset(60, 22))
fovValue.TextXAlignment = Enum.TextXAlignment.Right
local track = button(panel, "", UDim2.fromOffset(20, 92), UDim2.new(1, -40, 0, 10))
track.BackgroundColor3 = Color3.fromRGB(44, 54, 66)
local fill = Instance.new("Frame")
fill.BackgroundColor3 = ACCENT
fill.Size = UDim2.fromScale(0, 1)
fill.Parent = track
round(fill, 5)
local knob = Instance.new("Frame")
knob.AnchorPoint = Vector2.new(0.5, 0.5)
knob.Size = UDim2.fromOffset(18, 18)
knob.BackgroundColor3 = INK
knob.Parent = track
round(knob, 9)

-- Holstered blaster: hip or disappear.
text(panel, "Holstered blaster", 15, UDim2.fromOffset(20, 128), UDim2.fromOffset(200, 22))
local hip = button(panel, "On hip", UDim2.fromOffset(20, 158), UDim2.fromOffset(160, 40))
local vanish = button(panel, "Disappears", UDim2.new(1, -180, 0, 158), UDim2.fromOffset(160, 40))
gui.Parent = player:WaitForChild("PlayerGui")

local function refresh()
	local fov = (player:GetAttribute("FieldOfView") or Config.Camera.Fov) :: number
	local fraction = (fov - FOV_MIN) / (FOV_MAX - FOV_MIN)
	fill.Size = UDim2.fromScale(fraction, 1)
	knob.Position = UDim2.fromScale(fraction, 0.5)
	fovValue.Text = tostring(math.round(fov))
	local mode = player:GetAttribute("HolsterMode")
	hip.BackgroundColor3 = if mode == "Hip" then ACCENT else Color3.fromRGB(44, 54, 66)
	vanish.BackgroundColor3 = if mode == "Vanish" then ACCENT else Color3.fromRGB(44, 54, 66)
end
player:GetAttributeChangedSignal("FieldOfView"):Connect(refresh)
player:GetAttributeChangedSignal("HolsterMode"):Connect(refresh)
refresh()

local dragging = false
local function slide(x: number)
	local fraction = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
	player:SetAttribute("FieldOfView", math.round(FOV_MIN + fraction * (FOV_MAX - FOV_MIN)))
end
track.InputBegan:Connect(function(input)
	if
		input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
	then
		dragging = true
		slide(input.Position.X)
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if
		dragging
		and (
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		)
	then
		slide(input.Position.X)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if
		input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
	then
		dragging = false
	end
end)
hip.Activated:Connect(function()
	player:SetAttribute("HolsterMode", "Hip")
end)
vanish.Activated:Connect(function()
	player:SetAttribute("HolsterMode", "Vanish")
end)

local function setOpen(open: boolean)
	panel.Visible = open
	opener.Visible = not open
end
opener.Activated:Connect(function()
	setOpen(true)
end)
close.Activated:Connect(function()
	setOpen(false)
end)
ContextActionService:BindAction("SlugshotSettings", function(_, state)
	if state == Enum.UserInputState.Begin then
		setOpen(not panel.Visible)
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.M)
-- Shift lock relocks the cursor every frame; keep it free while the panel is open.
RunService:BindToRenderStep(
	"SlugshotSettingsCursor",
	Enum.RenderPriority.Camera.Value + 20,
	function()
		if panel.Visible then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end
)
