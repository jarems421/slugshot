--!strict
-- Settings panel (owner, 2026-10-31): field of view, and whether the holstered blaster
-- hangs at the hip or disappears, plus flip camera and crosshair appearance.
-- Opened with the Settings button or M (the cursor is
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
local movement = player.PlayerScripts:WaitForChild("MovementSandbox")
local flipCamera = (require :: any)(movement:WaitForChild("AcrobaticCamera"))
local crosshairs = (require :: any)(movement:WaitForChild("CrosshairStyles"))
local recoil = (require :: any)(movement:WaitForChild("BlasterRecoil"))
local FOV_MIN, FOV_MAX = 60, 110
local INK = Color3.fromRGB(229, 239, 248)
local PANEL = Color3.fromRGB(20, 26, 34)
local ACCENT = Color3.fromRGB(255, 150, 60)

if player:GetAttribute("FieldOfView") == nil then
	player:SetAttribute("FieldOfView", Config.Camera.Fov)
end
if player:GetAttribute("RecoilAnimation") == nil then
	player:SetAttribute("RecoilAnimation", recoil.Default)
end
if player:GetAttribute("HolsterMode") == nil then
	player:SetAttribute("HolsterMode", "Hip")
end

if player:GetAttribute("CrosshairStyle") == nil then
	player:SetAttribute("CrosshairStyle", crosshairs.DefaultStyle)
end
if player:GetAttribute("CrosshairColor") == nil then
	player:SetAttribute("CrosshairColor", crosshairs.Colors[1].color)
end
if player:GetAttribute("CrosshairSize") == nil then
	player:SetAttribute("CrosshairSize", 1)
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
panel.Size = UDim2.fromOffset(380, 490)
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

local function page(name: string): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.Position = UDim2.fromOffset(0, 40)
	frame.Size = UDim2.new(1, 0, 1, -40)
	frame.Parent = panel
	return frame
end
local gameplay = page("GameplayPage")
local appearance = page("CrosshairPage")
appearance.Visible = false
local gameplayTab = button(panel, "Gameplay", UDim2.fromOffset(20, 54), UDim2.fromOffset(164, 28))
local crosshairTab =
	button(panel, "Crosshair", UDim2.fromOffset(196, 54), UDim2.fromOffset(164, 28))
gameplayTab.Name = "GameplayTab"
crosshairTab.Name = "CrosshairTab"
local panelScale = Instance.new("UIScale")
panelScale.Parent = panel
local function fitPanel()
	panelScale.Scale = math.min(1, (gui.AbsoluteSize.X - 24) / 380, (gui.AbsoluteSize.Y - 24) / 490)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitPanel)
-- Field of view slider.
text(gameplay, "Field of view", 15, UDim2.fromOffset(20, 60), UDim2.fromOffset(200, 22))
local fovValue = text(gameplay, "", 15, UDim2.new(1, -80, 0, 60), UDim2.fromOffset(60, 22))
fovValue.TextXAlignment = Enum.TextXAlignment.Right
local track = button(gameplay, "", UDim2.fromOffset(20, 92), UDim2.new(1, -40, 0, 10))
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
text(gameplay, "Holstered blaster", 15, UDim2.fromOffset(20, 128), UDim2.fromOffset(200, 22))
local hip = button(gameplay, "On hip", UDim2.fromOffset(20, 158), UDim2.fromOffset(160, 40))
local vanish = button(gameplay, "Disappears", UDim2.new(1, -180, 0, 158), UDim2.fromOffset(160, 40))

text(
	gameplay,
	"Flip camera (default: Spot)",
	15,
	UDim2.fromOffset(20, 220),
	UDim2.fromOffset(340, 22)
)
local flipButtons: { TextButton } = {}
local flipDetail = text(gameplay, "", 13, UDim2.fromOffset(20, 300), UDim2.fromOffset(340, 50))
flipDetail.Name = "FlipCameraDescription"
flipDetail.TextWrapped = true
flipDetail.TextYAlignment = Enum.TextYAlignment.Top
local function refreshFlip()
	local selected, requested = flipCamera.status()
	for index, control in flipButtons do
		control.BackgroundColor3 = if requested == index then ACCENT else Color3.fromRGB(44, 54, 66)
	end
	flipDetail.Text = if selected ~= requested
		then `{flipCamera.Options[requested].name} will apply after this flip.`
		else flipCamera.Options[selected].description
end
for index, option in flipCamera.Options do
	local control = button(
		gameplay,
		option.name,
		UDim2.fromOffset(20 + (index - 1) * 116, 250),
		UDim2.fromOffset(108, 40)
	)
	control.Name = `FlipCamera{option.name}`
	control.Activated:Connect(function()
		flipCamera.select(index)
		refreshFlip()
	end)
	flipButtons[index] = control
end
refreshFlip()
text(gameplay, "Recoil animation", 15, UDim2.fromOffset(20, 352), UDim2.fromOffset(340, 22))
local kickButton = button(gameplay, "Kick up", UDim2.fromOffset(20, 382), UDim2.fromOffset(160, 36))
kickButton.Name = "RecoilKick"
local flipButton =
	button(gameplay, "Flip & catch", UDim2.fromOffset(200, 382), UDim2.fromOffset(160, 36))
flipButton.Name = "RecoilFlip"
local function refreshRecoil()
	local style = recoil.style(player:GetAttribute("RecoilAnimation"))
	kickButton.BackgroundColor3 = if style == "Kick" then ACCENT else Color3.fromRGB(44, 54, 66)
	flipButton.BackgroundColor3 = if style == "Flip" then ACCENT else Color3.fromRGB(44, 54, 66)
end
kickButton.Activated:Connect(function()
	player:SetAttribute("RecoilAnimation", "Kick")
end)
flipButton.Activated:Connect(function()
	player:SetAttribute("RecoilAnimation", "Flip")
end)
player:GetAttributeChangedSignal("RecoilAnimation"):Connect(refreshRecoil)
refreshRecoil()
-- Appearance is local to the aiming mark; charge colors remain in Reticle.
text(appearance, "Crosshair style", 15, UDim2.fromOffset(20, 60), UDim2.fromOffset(340, 22))
local selector = button(appearance, "", UDim2.fromOffset(20, 90), UDim2.fromOffset(340, 44))
selector.Name = "CrosshairDropdown"
local selectorLabel = text(selector, "", 15, UDim2.fromOffset(48, 0), UDim2.new(1, -80, 1, 0))
text(selector, "v", 14, UDim2.new(1, -28, 0, 0), UDim2.new(0, 20, 1, 0))
local function preview(parent: Instance, position: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.ZIndex = if parent:IsA("GuiObject") then parent.ZIndex + 1 else 1
	frame.BackgroundTransparency = 1
	frame.Position = position
	frame.Size = UDim2.fromOffset(18, 18)
	frame.Parent = parent
	return frame
end
local selectedPreview = preview(selector, UDim2.fromOffset(14, 13))
local detail = text(appearance, "", 12, UDim2.fromOffset(20, 142), UDim2.fromOffset(340, 32))
detail.TextWrapped = true
text(appearance, "Crosshair color", 15, UDim2.fromOffset(20, 182), UDim2.fromOffset(340, 22))
local colorLabel = text(appearance, "", 12, UDim2.fromOffset(20, 250), UDim2.fromOffset(230, 20))
local hex = Instance.new("TextBox")
hex.Name = "CrosshairHex"
hex.Position = UDim2.fromOffset(20, 286)
hex.Size = UDim2.fromOffset(150, 36)
hex.BackgroundColor3 = Color3.fromRGB(44, 54, 66)
hex.TextColor3 = INK
hex.TextSize = 15
hex.Font = Enum.Font.GothamBold
hex.ClearTextOnFocus = false
hex.PlaceholderText = "#RRGGBB"
hex.Parent = appearance
round(hex, 6)
local apply = button(appearance, "Apply", UDim2.fromOffset(182, 286), UDim2.fromOffset(72, 36))
apply.Name = "ApplyCrosshairHex"
text(appearance, "Preview", 12, UDim2.fromOffset(276, 250), UDim2.fromOffset(70, 20))
local plate = Instance.new("Frame")
plate.Position = UDim2.fromOffset(276, 274)
plate.Size = UDim2.fromOffset(64, 54)
plate.BackgroundColor3 = Color3.fromRGB(36, 45, 54)
plate.Parent = appearance
round(plate, 8)
local livePreview = preview(plate, UDim2.fromOffset(23, 18))
local previewScale = Instance.new("UIScale")
previewScale.Scale = 1.22
previewScale.Parent = livePreview
text(appearance, "Crosshair size", 15, UDim2.fromOffset(20, 338), UDim2.fromOffset(220, 22))
local sizeValue = text(appearance, "", 15, UDim2.new(1, -80, 0, 338), UDim2.fromOffset(60, 22))
sizeValue.TextXAlignment = Enum.TextXAlignment.Right
local sizeTrack = button(appearance, "", UDim2.fromOffset(20, 375), UDim2.new(1, -40, 0, 10))
sizeTrack.Name = "CrosshairSizeSlider"
local sizeFill = Instance.new("Frame")
sizeFill.BackgroundColor3 = ACCENT
sizeFill.Parent = sizeTrack
round(sizeFill, 5)
local sizeKnob = Instance.new("Frame")
sizeKnob.AnchorPoint = Vector2.new(0.5, 0.5)
sizeKnob.Size = UDim2.fromOffset(18, 18)
sizeKnob.BackgroundColor3 = INK
sizeKnob.Parent = sizeTrack
round(sizeKnob, 9)
local help = text(
	appearance,
	"Crosshair only. Charge ring stays white.",
	12,
	UDim2.fromOffset(20, 405),
	UDim2.fromOffset(340, 28)
)
help.TextColor3 = Color3.fromRGB(158, 177, 190)
local options = Instance.new("ScrollingFrame")
options.Name = "CrosshairOptions"
options.Position = UDim2.fromOffset(20, 136)
options.Size = UDim2.fromOffset(340, 224)
options.CanvasSize = UDim2.fromOffset(0, #crosshairs.Presets * 40)
options.ScrollBarThickness = 4
options.BackgroundColor3 = PANEL
options.BorderSizePixel = 0
options.ZIndex = 30
options.Visible = false
options.Parent = appearance
round(options, 6)
local rows: { TextButton } = {}
local rowPreviews: { Frame } = {}
local swatches: { TextButton } = {}
local function refreshAppearance()
	local preset = crosshairs.find(player:GetAttribute("CrosshairStyle"))
	local color = crosshairs.color(player:GetAttribute("CrosshairColor"))
	local size = crosshairs.size(player:GetAttribute("CrosshairSize"))
	local sizeFraction = (size - crosshairs.MinSize) / (crosshairs.MaxSize - crosshairs.MinSize)
	sizeFill.Size = UDim2.fromScale(sizeFraction, 1)
	sizeKnob.Position = UDim2.fromScale(sizeFraction, 0.5)
	sizeValue.Text = `{math.round(size * 100)}%`
	previewScale.Scale = 1.22 * size
	selectorLabel.Text = preset.label
	detail.Text = preset.description
	crosshairs.draw(selectedPreview, preset.id, color)
	crosshairs.draw(livePreview, preset.id, color)
	local colorName = "Custom"
	for index, swatch in swatches do
		local entry = crosshairs.Colors[index]
		local selected = color == entry.color
		swatch.Text = if selected then "•" else ""
		if selected then
			colorName = entry.label
		end
	end
	local code = "#" .. string.upper(color:ToHex())
	colorLabel.Text = colorName .. "  " .. code
	if not hex:IsFocused() then
		hex.Text = code
	end
	for index, row in rows do
		local entry = crosshairs.Presets[index]
		row.BackgroundColor3 = if entry.id == preset.id then Color3.fromRGB(68, 79, 90) else PANEL
		crosshairs.draw(rowPreviews[index], entry.id, color)
	end
end
for index, entry in crosshairs.Presets do
	local row =
		button(options, entry.label, UDim2.fromOffset(0, (index - 1) * 40), UDim2.new(1, -6, 0, 40))
	row.Name = "CrosshairStyle" .. entry.id
	row.ZIndex = 31
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.Text = ""
	local rowLabel = text(row, entry.label, 15, UDim2.fromOffset(48, 0), UDim2.new(1, -48, 1, 0))
	rowLabel.ZIndex = 32
	rows[index] = row
	rowPreviews[index] = preview(row, UDim2.fromOffset(14, 11))
	row.Activated:Connect(function()
		player:SetAttribute("CrosshairStyle", entry.id)
		options.Visible = false
	end)
end
for index, entry in crosshairs.Colors do
	local swatch = button(
		appearance,
		"",
		UDim2.fromOffset(20 + (index - 1) * 42, 214),
		UDim2.fromOffset(32, 32)
	)
	swatch.Name = "CrosshairColor" .. entry.label
	swatch.BackgroundColor3 = entry.color
	swatch.TextColor3 = PANEL
	swatch.TextSize = 25
	swatches[index] = swatch
	swatch.Activated:Connect(function()
		player:SetAttribute("CrosshairColor", entry.color)
	end)
end
local function applyHex()
	local value = hex.Text:gsub("%s", ""):gsub("^#", "")
	if #value ~= 6 or not value:match("^%x+$") then
		colorLabel.Text = "Use six hex digits, e.g. #86F0C1"
		return
	end
	player:SetAttribute("CrosshairColor", Color3.fromHex(value))
	refreshAppearance()
end
apply.Activated:Connect(applyHex)
hex.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		applyHex()
	end
end)
selector.Activated:Connect(function()
	options.Visible = not options.Visible
end)
local function showAppearance(show: boolean)
	appearance.Visible = show
	gameplay.Visible = not show
	options.Visible = false
	crosshairTab.BackgroundColor3 = if show then ACCENT else Color3.fromRGB(44, 54, 66)
	gameplayTab.BackgroundColor3 = if show then Color3.fromRGB(44, 54, 66) else ACCENT
end
gameplayTab.Activated:Connect(function()
	showAppearance(false)
end)
crosshairTab.Activated:Connect(function()
	showAppearance(true)
end)
player:GetAttributeChangedSignal("CrosshairStyle"):Connect(refreshAppearance)
player:GetAttributeChangedSignal("CrosshairColor"):Connect(refreshAppearance)
player:GetAttributeChangedSignal("CrosshairSize"):Connect(refreshAppearance)
refreshAppearance()
showAppearance(false)
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
local sizeDragging = false
local function slideSize(x: number)
	local fraction = math.clamp((x - sizeTrack.AbsolutePosition.X) / sizeTrack.AbsoluteSize.X, 0, 1)
	local value = crosshairs.MinSize + fraction * (crosshairs.MaxSize - crosshairs.MinSize)
	player:SetAttribute("CrosshairSize", math.round(value * 20) / 20)
end
sizeTrack.InputBegan:Connect(function(input)
	if
		input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
	then
		sizeDragging = true
		slideSize(input.Position.X)
	end
end)
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
		sizeDragging
		and (
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		)
	then
		slideSize(input.Position.X)
	end
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
		sizeDragging = false
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
	options.Visible = false
	fitPanel()
	opener.Visible = not open
	player:SetAttribute("CombatSettingsOpen", open)
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
			refreshFlip()
		end
	end
)
