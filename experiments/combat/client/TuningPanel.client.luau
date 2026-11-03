--!strict
-- Studio-only live tuning (P): sliders over the shared Tuning values. You can keep
-- moving and shooting with it open; Print writes changed values to the Output.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

if not RunService:IsStudio() then
	return
end

local player = Players.LocalPlayer
local movement = player.PlayerScripts:WaitForChild("MovementSandbox")
local Tuning = (require :: any)(movement:WaitForChild("Tuning"))
local INK = Color3.fromRGB(229, 239, 248)
local PANEL = Color3.fromRGB(20, 26, 34)
local TRACK = Color3.fromRGB(44, 54, 66)
local ACCENT = Color3.fromRGB(255, 150, 60)
local ROW = 44

local gui = Instance.new("ScreenGui")
gui.Name = "TuningPanel"
gui.ResetOnSpawn = false
gui.DisplayOrder = 11

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -12, 0.5, 0)
panel.Size = UDim2.new(0, 300, 0.86, 0)
panel.BackgroundColor3 = PANEL
panel.BackgroundTransparency = 0.12
panel.Visible = false
panel.Parent = gui

local function label(parent: Instance, value: string, size: number, frame: UDim2, at: UDim2)
	local item = Instance.new("TextLabel")
	item.BackgroundTransparency = 1
	item.Font = Enum.Font.GothamBold
	item.TextSize = size
	item.TextColor3 = INK
	item.TextXAlignment = Enum.TextXAlignment.Left
	item.Text = value
	item.Size = frame
	item.Position = at
	item.Parent = parent
	return item
end

local function button(value: string, x: number): TextButton
	local item = Instance.new("TextButton")
	item.BackgroundColor3 = TRACK
	item.Font = Enum.Font.GothamBold
	item.TextSize = 13
	item.TextColor3 = INK
	item.Text = value
	item.Size = UDim2.fromOffset(84, 26)
	item.Position = UDim2.fromOffset(x, 8)
	item.Parent = panel
	return item
end

-- A modal button frees the cursor in first person and shift lock.
local closeButton = button("Close (P)", 8)
closeButton.Modal = true
local resetButton = button("Reset all", 100)
local printButton = button("Print", 192)

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(0, 42)
list.Size = UDim2.new(1, 0, 1, -42)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.Parent = panel

type Row = { entry: any, fill: Frame, value: TextLabel, bar: TextButton }
local rows: { Row } = {}
local dragging: Row? = nil

local function format(value: number): string
	return string.format("%.2f", value)
end

local function show(row: Row)
	local entry = row.entry
	local current = Tuning.values[entry.key]
	row.fill.Size = UDim2.fromScale((current - entry.min) / (entry.max - entry.min), 1)
	row.value.Text = format(current)
	local changed = math.abs(current - Tuning.defaults[entry.key]) > 1e-6
	row.value.TextColor3 = if changed then ACCENT else INK
end

local function drag(row: Row, x: number)
	local entry = row.entry
	local t = math.clamp((x - row.bar.AbsolutePosition.X) / row.bar.AbsoluteSize.X, 0, 1)
	local raw = entry.min + (entry.max - entry.min) * t
	Tuning.values[entry.key] =
		math.clamp(math.round(raw / entry.step) * entry.step, entry.min, entry.max)
	show(row)
end

local y, group = 6, ""
for _, entry in Tuning.Entries do
	if entry.group ~= group then
		group = entry.group
		local heading = label(
			list,
			string.upper(group),
			12,
			UDim2.new(1, -24, 0, 18),
			UDim2.fromOffset(12, y + 4)
		)
		heading.TextColor3 = ACCENT
		y += 26
	end
	label(list, entry.label, 13, UDim2.new(1, -90, 0, 18), UDim2.fromOffset(12, y))
	local value = label(list, "", 13, UDim2.fromOffset(60, 18), UDim2.new(1, -74, 0, y))
	value.TextXAlignment = Enum.TextXAlignment.Right
	local bar = Instance.new("TextButton")
	bar.AutoButtonColor = false
	bar.Text = ""
	bar.BackgroundColor3 = TRACK
	bar.Size = UDim2.new(1, -28, 0, 12)
	bar.Position = UDim2.fromOffset(12, y + 22)
	bar.Parent = list
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = ACCENT
	fill.BorderSizePixel = 0
	fill.Parent = bar
	local row: Row = { entry = entry, fill = fill, value = value, bar = bar }
	bar.MouseButton1Down:Connect(function(x: number)
		dragging = row
		drag(row, x)
	end)
	table.insert(rows, row)
	show(row)
	y += ROW
end
list.CanvasSize = UDim2.fromOffset(0, y + 8)

UserInputService.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		drag(dragging, input.Position.X)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = nil
	end
end)

local function setOpen(open: boolean)
	panel.Visible = open
	player:SetAttribute("TuningPanelOpen", open)
	if not open then
		dragging = nil
	end
end
closeButton.Activated:Connect(function()
	setOpen(false)
end)
resetButton.Activated:Connect(function()
	for key, value in Tuning.defaults do
		Tuning.values[key] = value
	end
	for _, row in rows do
		show(row)
	end
end)
printButton.Activated:Connect(function()
	local any = false
	for _, entry in Tuning.Entries do
		local current = Tuning.values[entry.key]
		if math.abs(current - Tuning.defaults[entry.key]) > 1e-6 then
			print(`[Tuning] {entry.key} = {format(current)} ({entry.group}: {entry.label})`)
			any = true
		end
	end
	if not any then
		print("[Tuning] nothing changed from the defaults")
	end
end)
ContextActionService:BindAction("SlugshotTuning", function(_, state)
	if state == Enum.UserInputState.Begin then
		setOpen(not panel.Visible)
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.P)
-- Shift lock relocks the cursor every frame; keep it free while the panel is open.
RunService:BindToRenderStep(
	"SlugshotTuningCursor",
	Enum.RenderPriority.Camera.Value + 21,
	function()
		if panel.Visible then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end
)

gui.Parent = player:WaitForChild("PlayerGui")
