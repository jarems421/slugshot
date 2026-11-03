--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
task.spawn(function()
	local lab = player:WaitForChild("PlayerGui"):WaitForChild("MovementSandboxHUD", 30)
	if lab and lab:IsA("ScreenGui") then
		lab.Enabled = false
	end
end)
local remote = ReplicatedStorage:WaitForChild("TrainingTargetSpeed") :: RemoteEvent
local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn = "TrainingControls", false
local panel = Instance.new("Frame")
panel.Size, panel.Position = UDim2.fromOffset(240, 172), UDim2.new(1, -260, 0, 82)
panel.BackgroundColor3, panel.BorderSizePixel = Color3.fromRGB(29, 40, 47), 0
panel.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius, corner.Parent = UDim.new(0, 12), panel
local title = Instance.new("TextLabel")
title.Text = "MOVING DUMMY"
title.TextColor3, title.BackgroundTransparency = Color3.fromRGB(170, 215, 198), 1
title.Font, title.TextSize = Enum.Font.GothamBold, 14
title.Position, title.Size = UDim2.fromOffset(12, 12), UDim2.fromOffset(216, 24)
title.Parent = panel
local readout = title:Clone()
readout.Name, readout.Font = "Speed", Enum.Font.Gotham
readout.Position, readout.TextSize, readout.Parent = UDim2.fromOffset(12, 42), 15, panel
local function button(
	name: string,
	text: string,
	position: UDim2,
	size: UDim2,
	callback: () -> ()
): TextButton
	local b = Instance.new("TextButton")
	b.Name, b.Text, b.Position, b.Size = name, text, position, size
	b.BackgroundColor3, b.TextColor3 = Color3.fromRGB(57, 78, 81), Color3.fromRGB(226, 234, 219)
	b.BorderSizePixel, b.Font, b.TextSize = 0, Enum.Font.GothamBold, 14
	b.Parent = panel
	local c = Instance.new("UICorner")
	c.CornerRadius, c.Parent = UDim.new(0, 7), b
	b.Activated:Connect(callback)
	return b
end
local function current(): number
	return (workspace:GetAttribute("TrainingTargetSpeed") or 7) :: number
end
button("Slower", "-", UDim2.fromOffset(12, 78), UDim2.fromOffset(48, 32), function()
	remote:FireServer(math.max(0, current() - 1))
end)
button("Faster", "+", UDim2.fromOffset(180, 78), UDim2.fromOffset(48, 32), function()
	remote:FireServer(math.min(20, current() + 1))
end)
button("Stationary", "Stationary", UDim2.fromOffset(67, 78), UDim2.fromOffset(106, 32), function()
	remote:FireServer(0)
end)
button(
	"ResetSpeed",
	"Reset · 7 studs/s",
	UDim2.fromOffset(12, 120),
	UDim2.fromOffset(216, 32),
	function()
		remote:FireServer(7)
	end
)
local function refresh()
	readout.Text = if current() == 0 then "Stationary" else `{current()} studs / second`
end
workspace:GetAttributeChangedSignal("TrainingTargetSpeed"):Connect(refresh)
refresh()
gui.Parent = player:WaitForChild("PlayerGui")
-- F opens/closes the controls and frees the first-person cursor while open.
local opened = false
local function setOpen(value: boolean)
	opened, panel.Visible = value, value
	player:SetAttribute("PvpMenu", if value then "Training" else nil)
	for _, child in panel:GetChildren() do
		if child:IsA("TextButton") then
			child.Modal = value
		end
	end
end
local toggle = Instance.new("TextButton")
toggle.Name, toggle.Text = "ToggleDummies", "F · Dummy controls"
toggle.Position, toggle.Size = UDim2.new(1, -240, 0, 42), UDim2.fromOffset(220, 32)
toggle.BackgroundColor3, toggle.TextColor3 =
	Color3.fromRGB(29, 40, 47), Color3.fromRGB(170, 215, 198)
toggle.Font, toggle.TextSize, toggle.Parent = Enum.Font.GothamBold, 14, gui
toggle.Activated:Connect(function()
	setOpen(not opened)
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.F then
		setOpen(not opened)
	end
end)
setOpen(false)
