--!strict
-- The settings menu (owner, 2026-11-01): Controls with every key and mouse button rebindable and the
-- sprint options, Gameplay, and Crosshair. Values are local player attributes read by the camera,
-- movement client, viewmodel and holster; they last for the session.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage:WaitForChild("MovementExperiment"):WaitForChild("Config"))
local Theme = require(script.Parent.PvpTheme)

local player = Players.LocalPlayer
local movement = player.PlayerScripts:WaitForChild("MovementSandbox")
local flipCamera = (require :: any)(movement:WaitForChild("AcrobaticCamera"))
local crosshairs = (require :: any)(movement:WaitForChild("CrosshairStyles"))
local recoil = (require :: any)(movement:WaitForChild("BlasterRecoil"))
local Keybinds = (require :: any)(movement:WaitForChild("Keybinds"))

local CAPTURE_WAIT = 5 -- seconds before a key prompt cancels itself
local PANEL_W, PANEL_H, SIDE_W, HEAD_H = 1220, 648, 160, 60
local CONTENT_W = PANEL_W - SIDE_W - 44
local PREVIEW_ZOOM = 4 -- the preview is enlarged so the shape is easy to judge
local TILE_ZOOM = 2
local COG_SIZE, COG_FALLBACK_X, COG_FALLBACK_HEIGHT = 34, 172, 58
local REPRESS_GUARD = 0.35 -- seconds after a key prompt ends before a click can open another

local DEFAULTS: { [string]: any } = {
	FieldOfView = Config.Camera.Fov,
	LookSensitivity = 50,
	AimSensitivity = 50,
	RecoilAnimation = recoil.Default,
	HolsterMode = "Hip",
	HealthNumber = "Always",
	SprintMode = "Toggle",
	SprintDoubleTap = true,
	CrosshairStyle = crosshairs.DefaultStyle,
	CrosshairColor = crosshairs.Colors[1].color,
	CrosshairSize = 1,
}
for name, value in DEFAULTS do
	if player:GetAttribute(name) == nil then
		player:SetAttribute(name, value)
	end
end

local gui = Instance.new("ScreenGui")
gui.Name = "Settings"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10

-- A small cog beside Roblox's own buttons. Theirs are dark and round, so this one is a pale
-- rounded square that cannot be mistaken for them.
local opener = Theme.button(gui, "", Theme.Body, 12, {
	Name = "SettingsOpener",
	Size = UDim2.fromOffset(COG_SIZE, COG_SIZE),
	BackgroundColor3 = Theme.Accent,
})
Theme.corner(opener, 9)
Theme.edge(opener, 2)
local cog = Theme.new("Frame", {
	Name = "Cog",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(22, 22),
	BackgroundTransparency = 1,
	Parent = opener,
})
for tooth = 0, 3 do
	local bar = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(4, 22),
		Rotation = tooth * 45,
		BackgroundColor3 = Theme.OnAccent,
		BorderSizePixel = 0,
		Parent = cog,
	})
	Theme.corner(bar, 1)
end
for _, disc in { { size = 16, color = Theme.OnAccent }, { size = 7, color = Theme.Accent } } do
	local round = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(disc.size, disc.size),
		BackgroundColor3 = disc.color,
		BorderSizePixel = 0,
		Parent = cog,
	})
	Theme.corner(round, 8)
end
local function placeOpener()
	local inset = GuiService.TopbarInset
	local x = if inset.Min.X > 0 then inset.Min.X else COG_FALLBACK_X
	local height = if inset.Height > 0 then inset.Height else COG_FALLBACK_HEIGHT
	-- Roblox's buttons sit low in their bar, so this lines up with their middle.
	opener.Position = UDim2.fromOffset(x + 4, (height + 12 - COG_SIZE) / 2)
end
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(placeOpener)
placeOpener()

local panel = Theme.new("Frame", {
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(PANEL_W, PANEL_H),
	BackgroundColor3 = Theme.Panel,
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Visible = false,
	Parent = gui,
})
Theme.corner(panel, 6)
Theme.edge(panel, 3)
Theme.fit(gui, Theme.new("UIScale", { Parent = panel }), 1280)

local head = Theme.new("Frame", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, HEAD_H),
	BackgroundColor3 = Theme.Deep,
	BorderSizePixel = 0,
	Parent = panel,
})
Theme.new("Frame", {
	Position = UDim2.new(0, 0, 1, -3),
	Size = UDim2.new(1, 0, 0, 3),
	BackgroundColor3 = Theme.Ink,
	BorderSizePixel = 0,
	Parent = head,
})
Theme.label(head, "Settings", Theme.TitleBold, 28, {
	Position = UDim2.fromOffset(24, 0),
	Size = UDim2.fromOffset(300, HEAD_H - 3),
	TextColor3 = Theme.Accent,
})
-- Modal frees the cursor while the menu is open (first person locks it).
local close = Theme.button(head, "×", Theme.Body, 28, {
	Name = "Close",
	Modal = true,
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -8, 0, 6),
	Size = UDim2.fromOffset(44, 44),
	BackgroundTransparency = 1,
})

local side = Theme.new("Frame", {
	Name = "Tabs",
	Position = UDim2.fromOffset(0, HEAD_H),
	Size = UDim2.new(0, SIDE_W, 1, -HEAD_H),
	BackgroundColor3 = Theme.Deep,
	BorderSizePixel = 0,
	Parent = panel,
})
Theme.new("Frame", {
	Position = UDim2.new(1, -3, 0, 0),
	Size = UDim2.new(0, 3, 1, 0),
	BackgroundColor3 = Theme.Ink,
	BorderSizePixel = 0,
	Parent = side,
})

local function page(name: string): Frame
	return Theme.new("Frame", {
		Name = name,
		Position = UDim2.fromOffset(SIDE_W + 22, HEAD_H + 16),
		Size = UDim2.fromOffset(CONTENT_W, PANEL_H - HEAD_H - 32),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = panel,
	})
end
local pages: { [string]: Frame } = {
	Controls = page("ControlsPage"),
	Gameplay = page("GameplayPage"),
	Crosshair = page("CrosshairPage"),
}
local tabs: { [string]: TextButton } = {}
local function showPage(name: string)
	for key, frame in pages do
		frame.Visible = key == name
		local tab = tabs[key]
		tab.BackgroundColor3 = if key == name then Theme.Accent else Theme.Deep
		tab.TextColor3 = if key == name then Theme.OnAccent else Theme.Soft
	end
end
for index, name in { "Controls", "Gameplay", "Crosshair" } do
	local tab = Theme.button(side, name, Theme.Title, 18, {
		Name = `{name}Tab`,
		Position = UDim2.fromOffset(12, 16 + (index - 1) * 52),
		Size = UDim2.new(1, -27, 0, 46),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	Theme.corner(tab, 4)
	Theme.new("UIPadding", { PaddingLeft = UDim.new(0, 12), Parent = tab })
	tab.Activated:Connect(function()
		showPage(name)
	end)
	tabs[name] = tab
end
local reset = Theme.button(side, "Reset to defaults", Theme.Body, 12, {
	Name = "Reset",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 12, 1, -16),
	Size = UDim2.new(1, -27, 0, 44),
	BackgroundTransparency = 1,
	TextColor3 = Theme.Soft,
})
Theme.corner(reset, 4)
Theme.edge(reset, 2, Color3.fromRGB(74, 85, 96))

type Option = { label: string, value: any }

-- A row of mutually exclusive buttons. Returns its refresh function.
local function choice(
	parent: Instance,
	x: number,
	y: number,
	width: number,
	height: number,
	options: { Option },
	current: () -> any,
	pick: (any) -> ()
): () -> ()
	local buttons: { TextButton } = {}
	local each = (width - 4 * (#options - 1)) / #options
	local function refresh()
		for index, option in options do
			Theme.paint(buttons[index], current() == option.value)
		end
	end
	for index, option in options do
		local item = Theme.button(parent, option.label, Theme.Body, 14, {
			Name = `Choice{option.label}`,
			Position = UDim2.fromOffset(x + (index - 1) * (each + 4), y),
			Size = UDim2.fromOffset(each, height),
		})
		Theme.corner(item, 4)
		Theme.edge(item, 2)
		item.Activated:Connect(function()
			pick(option.value)
			refresh()
		end)
		buttons[index] = item
	end
	refresh()
	return refresh
end

local function attributeChoice(
	parent: Instance,
	x: number,
	y: number,
	width: number,
	height: number,
	attribute: string,
	options: { Option }
)
	local refresh = choice(parent, x, y, width, height, options, function()
		return player:GetAttribute(attribute)
	end, function(value)
		player:SetAttribute(attribute, value)
	end)
	player:GetAttributeChangedSignal(attribute):Connect(refresh)
end

-- A labelled slider. read/write use the shown number; step rounds it.
local dragging: ((number) -> ())? = nil
local function slider(
	parent: Instance,
	x: number,
	y: number,
	width: number,
	title: string,
	low: number,
	high: number,
	step: number,
	read: () -> number,
	write: (number) -> (),
	format: (number) -> string
): () -> ()
	Theme.label(parent, title, Theme.Title, 18, {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(width - 80, 26),
	})
	local value = Theme.label(parent, "", Theme.Title, 18, {
		Position = UDim2.fromOffset(x + width - 80, y),
		Size = UDim2.fromOffset(80, 26),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.Accent,
	})
	local track = Theme.button(parent, "", Theme.Body, 1, {
		Name = `{title}Slider`,
		Position = UDim2.fromOffset(x, y + 36),
		Size = UDim2.fromOffset(width, 10),
		BackgroundColor3 = Theme.Blank,
	})
	Theme.corner(track, 5)
	local fill = Theme.new("Frame", {
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = track,
	})
	Theme.corner(fill, 5)
	local knob = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = track,
	})
	Theme.corner(knob, 10)
	Theme.edge(knob, 2)
	local function refresh()
		local current = read()
		local share = math.clamp((current - low) / (high - low), 0, 1)
		fill.Size = UDim2.fromScale(share, 1)
		knob.Position = UDim2.fromScale(share, 0.5)
		value.Text = format(current)
	end
	local function slide(mouseX: number)
		local share = math.clamp((mouseX - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		write(math.round((low + share * (high - low)) / step) * step)
		refresh()
	end
	track.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = slide
			slide(input.Position.X)
		end
	end)
	refresh()
	return refresh
end
UserInputService.InputChanged:Connect(function(input)
	local drag = dragging
	if
		drag
		and (
			input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch
		)
	then
		drag(input.Position.X)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if
		input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
	then
		dragging = nil
	end
end)

local function attributeSlider(
	parent: Instance,
	x: number,
	y: number,
	width: number,
	title: string,
	attribute: string,
	low: number,
	high: number
)
	local refresh = slider(parent, x, y, width, title, low, high, 1, function()
		return (player:GetAttribute(attribute) :: number?) or low
	end, function(value)
		player:SetAttribute(attribute, value)
	end, function(value)
		return tostring(math.round(value))
	end)
	player:GetAttributeChangedSignal(attribute):Connect(refresh)
end

-- Controls ---------------------------------------------------------------------------
local controls = pages.Controls
local SPRINT_TEXT: { [string]: string } = {
	Toggle = "Press Sprint once to start, and again to stop.",
	Always = "You always sprint. No key needed.",
	Hold = "You sprint only while you hold Sprint.",
}
local sprintBox = Theme.new("Frame", {
	Name = "Sprint",
	Size = UDim2.new(1, 0, 0, 86),
	BackgroundColor3 = Color3.fromRGB(35, 42, 51),
	BorderSizePixel = 0,
	Parent = controls,
})
Theme.corner(sprintBox, 4)
Theme.edge(sprintBox, 2)
Theme.label(sprintBox, "Sprint", Theme.Title, 18, {
	Position = UDim2.fromOffset(14, 8),
	Size = UDim2.fromOffset(200, 24),
})
attributeChoice(sprintBox, 14, 36, 300, 38, "SprintMode", {
	{ label = "Toggle", value = "Toggle" },
	{ label = "Always on", value = "Always" },
	{ label = "Hold", value = "Hold" },
})
local sprintText = Theme.label(sprintBox, "", Theme.Body, 14, {
	Position = UDim2.fromOffset(334, 36),
	Size = UDim2.fromOffset(370, 38),
	TextWrapped = true,
	TextColor3 = Theme.Soft,
})
local doubleTap = Theme.button(sprintBox, "", Theme.Body, 13, {
	Name = "SprintDoubleTap",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -14, 0.5, 0),
	Size = UDim2.fromOffset(262, 56),
	BackgroundColor3 = Theme.Panel,
})
Theme.corner(doubleTap, 4)
Theme.edge(doubleTap, 2)
local doubleMark = Theme.label(doubleTap, "", Theme.Body, 15, {
	Position = UDim2.new(0, 10, 0.5, -12),
	Size = UDim2.fromOffset(24, 24),
	TextXAlignment = Enum.TextXAlignment.Center,
	TextColor3 = Theme.OnAccent,
	BackgroundTransparency = 0,
})
Theme.corner(doubleMark, 3)
Theme.edge(doubleMark, 2)
Theme.label(doubleTap, "Double-tap W, A, S or D to sprint that way", Theme.Body, 13, {
	Position = UDim2.fromOffset(44, 0),
	Size = UDim2.new(1, -52, 1, 0),
	TextWrapped = true,
})
local function refreshSprint()
	local mode = (player:GetAttribute("SprintMode") :: string?) or "Toggle"
	sprintText.Text = SPRINT_TEXT[mode] or ""
	local on = player:GetAttribute("SprintDoubleTap") ~= false
	doubleMark.Text = if on then "✓" else ""
	doubleMark.BackgroundColor3 = if on then Theme.Accent else Theme.Panel
	doubleTap.Visible = mode ~= "Always"
end
player:GetAttributeChangedSignal("SprintMode"):Connect(refreshSprint)
player:GetAttributeChangedSignal("SprintDoubleTap"):Connect(refreshSprint)
doubleTap.Activated:Connect(function()
	player:SetAttribute("SprintDoubleTap", player:GetAttribute("SprintDoubleTap") == false)
end)
refreshSprint()

local note = Theme.label(controls, "", Theme.Body, 14, {
	Name = "Note",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.new(1, 0, 0, 20),
	TextColor3 = Theme.Accent,
})

-- The prompt shown while waiting for a key.
local prompt = Theme.new("TextButton", {
	Name = "BindPrompt",
	AutoButtonColor = false,
	Text = "",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(8, 9, 12),
	BackgroundTransparency = 0.12,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 20,
	Parent = gui,
})
local promptBody = Theme.new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(760, 170),
	BackgroundTransparency = 1,
	ZIndex = 21,
	Parent = prompt,
})
Theme.fit(gui, Theme.new("UIScale", { Parent = promptBody }), 1280)
local function promptLine(
	text: string,
	font: Font,
	size: number,
	y: number,
	height: number,
	color: Color3
): TextLabel
	return Theme.label(promptBody, text, font, size, {
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, height),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = true,
		TextColor3 = color,
		ZIndex = 22,
	})
end
promptLine("Press a key or mouse button", Theme.TitleBold, 40, 0, 56, Theme.Accent)
local promptFor = promptLine("", Theme.Title, 24, 58, 34, Theme.Text)
promptLine(
	"Backspace clears it. Cancels by itself in 5 seconds. For side buttons, set them to F13 and F14 in your mouse's app first.",
	Theme.Body,
	15,
	100,
	44,
	Theme.Soft
)

local refreshers: { () -> () } = {}
local cancelCapture: (() -> ())? = nil
local captureToken = 0
local captureEnded = -math.huge
local function endPrompt()
	prompt.Visible = false
	captureToken += 1
	if cancelCapture then
		cancelCapture()
		cancelCapture = nil
	end
end
local function beginCapture(action: string, label: string, slot: number)
	endPrompt()
	note.Text = ""
	promptFor.Text = `for {label}`
	prompt.Visible = true
	captureToken += 1
	local token = captureToken
	cancelCapture = Keybinds.capture(function(input: string?)
		cancelCapture = nil
		captureEnded = os.clock()
		prompt.Visible = false
		captureToken += 1
		local displaced = Keybinds.set(action, slot, input)
		if displaced then
			note.Text = `{Keybinds.label(input)} was on {displaced}, so {displaced} lost it.`
		end
	end)
	task.delay(CAPTURE_WAIT, function()
		if token == captureToken then
			endPrompt()
		end
	end)
end

local function mouseIcon(parent: Instance): Frame
	local body = Theme.new("Frame", {
		Name = "MouseIcon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 5, 0.5, 0),
		Size = UDim2.fromOffset(9, 14),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	Theme.corner(body, 5)
	Theme.edge(body, 1.5, Theme.Soft)
	Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.new(0, 1, 0.4, 0),
		BackgroundColor3 = Theme.Soft,
		BorderSizePixel = 0,
		Parent = body,
	})
	return body
end

local CHIP_W, ROW_H = 90, 40
local COLUMN_W = (CONTENT_W - 44) / 3
local COLUMN_Y = 98
for index, group in Keybinds.Groups do
	local column = Theme.new("Frame", {
		Name = group.name,
		Position = UDim2.fromOffset((index - 1) * (COLUMN_W + 22), COLUMN_Y),
		Size = UDim2.fromOffset(COLUMN_W, 28 + #group.rows * ROW_H),
		BackgroundTransparency = 1,
		Parent = controls,
	})
	Theme.label(column, group.name, Theme.Title, 18, { Size = UDim2.fromOffset(120, 28) })
	for slot, title in { "Main", "Second" } do
		Theme.label(column, title, Theme.Body, 11, {
			Position = UDim2.new(1, -(3 - slot) * (CHIP_W + 6) + 6, 0, 0),
			Size = UDim2.fromOffset(CHIP_W, 28),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Theme.Muted,
		})
	end
	for rowIndex, row in group.rows do
		local y = 28 + (rowIndex - 1) * ROW_H
		Theme.new("Frame", {
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, 2),
			BackgroundColor3 = Theme.Ink,
			BorderSizePixel = 0,
			Parent = column,
		})
		local rowLabel = Theme.label(column, row.label, Theme.Body, 14, {
			Position = UDim2.fromOffset(0, y + 2),
			Size = UDim2.fromOffset(COLUMN_W - 2 * (CHIP_W + 6), ROW_H - 2),
		})
		local chips: { TextButton } = {}
		for slot = 1, 2 do
			local chip = Theme.button(column, "", Theme.Body, 12, {
				Name = `{row.id}{slot}`,
				Position = UDim2.new(1, -(3 - slot) * (CHIP_W + 6) + 6, 0, y + 6),
				Size = UDim2.fromOffset(CHIP_W, 30),
			})
			Theme.corner(chip, 3)
			Theme.edge(chip, 2)
			local icon = mouseIcon(chip)
			chip.Activated:Connect(function()
				-- The click that answered a prompt must not land on a chip and open the next one.
				if os.clock() - captureEnded > REPRESS_GUARD then
					beginCapture(row.id, row.label, slot)
				end
			end)
			chips[slot] = chip
			table.insert(refreshers, function()
				local input = Keybinds.get(row.id, slot)
				chip.Text = if input then Keybinds.label(input) else "Add"
				chip.BackgroundColor3 = if input then Theme.Raised else Theme.Blank
				chip.TextColor3 = if input then Theme.Text else Theme.Muted
				icon.Visible = Keybinds.isMouseLabel(input)
			end)
		end
		if row.id == "sprint" then
			-- Always on needs no key.
			local function dim()
				local off = player:GetAttribute("SprintMode") == "Always"
				rowLabel.TextTransparency = if off then 0.55 else 0
				for _, chip in chips do
					chip.TextTransparency = if off then 0.55 else 0
					chip.BackgroundTransparency = if off then 0.55 else 0
				end
			end
			player:GetAttributeChangedSignal("SprintMode"):Connect(dim)
			dim()
		end
	end
end
local function refreshChips()
	for _, refresh in refreshers do
		refresh()
	end
end
Keybinds.onChanged(refreshChips)
refreshChips()

local sideCard = Theme.new("Frame", {
	Name = "SideButtons",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, COLUMN_Y + 28 + 3 * ROW_H + 14),
	Size = UDim2.fromOffset(COLUMN_W, 5 * ROW_H - 14),
	BackgroundColor3 = Color3.fromRGB(35, 42, 51),
	BorderSizePixel = 0,
	Parent = controls,
})
Theme.corner(sideCard, 4)
Theme.edge(sideCard, 2)
Theme.label(sideCard, "Side mouse buttons", Theme.Title, 17, {
	Position = UDim2.fromOffset(12, 8),
	Size = UDim2.new(1, -24, 0, 24),
	TextColor3 = Theme.Accent,
})
Theme.label(
	sideCard,
	"Left, Right, Middle and the wheel bind straight away. Roblox can't read side buttons yet, so set them to F13 and F14 in your mouse's app. Then press them here and they show as Side 1 and Side 2.",
	Theme.Body,
	13,
	{
		Position = UDim2.fromOffset(12, 36),
		Size = UDim2.new(1, -24, 1, -44),
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextColor3 = Theme.Soft,
	}
)

-- Gameplay ---------------------------------------------------------------------------
local gameplay = pages.Gameplay
local COLUMN = (CONTENT_W - 36) / 2
local RIGHT = COLUMN + 36
local function heading(text: string, x: number, y: number)
	Theme.label(gameplay, text, Theme.Title, 18, {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(COLUMN, 26),
	})
end
attributeSlider(gameplay, 0, 8, COLUMN, "Field of view", "FieldOfView", 60, 110)
attributeSlider(gameplay, 0, 90, COLUMN, "Look sensitivity", "LookSensitivity", 1, 100)
attributeSlider(gameplay, 0, 172, COLUMN, "Aim sensitivity", "AimSensitivity", 1, 100)

heading("Health number", 0, 256)
attributeChoice(gameplay, 0, 288, COLUMN, 44, "HealthNumber", {
	{ label = "Always", value = "Always" },
	{ label = "On change", value = "On change" },
	{ label = "Off", value = "Off" },
})

heading("Holstered blaster", RIGHT, 8)
attributeChoice(gameplay, RIGHT, 40, COLUMN, 44, "HolsterMode", {
	{ label = "On hip", value = "Hip" },
	{ label = "Disappears", value = "Vanish" },
})

heading("Flip camera", RIGHT, 106)
local flipOptions: { Option } = {}
for index, option in flipCamera.Options do
	table.insert(flipOptions, { label = option.name, value = index })
end
local flipDetail = Theme.label(gameplay, "", Theme.Body, 13, {
	Name = "FlipCameraDescription",
	Position = UDim2.fromOffset(RIGHT, 188),
	Size = UDim2.fromOffset(COLUMN, 36),
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextColor3 = Theme.Soft,
})
local refreshFlipChoice = choice(gameplay, RIGHT, 138, COLUMN, 44, flipOptions, function()
	local _, requested = flipCamera.status()
	return requested
end, function(index)
	flipCamera.select(index)
end)
local function refreshFlip()
	local selected, requested = flipCamera.status()
	refreshFlipChoice()
	flipDetail.Text = if selected ~= requested
		then `{flipCamera.Options[requested].name} will apply after this flip.`
		else flipCamera.Options[selected].description
end
refreshFlip()

heading("Recoil animation", RIGHT, 228)
local refreshRecoil = choice(gameplay, RIGHT, 260, COLUMN, 44, {
	{ label = "Kick up", value = "Kick" },
	{ label = "Flip & catch", value = "Flip" },
}, function()
	return recoil.style(player:GetAttribute("RecoilAnimation"))
end, function(value)
	player:SetAttribute("RecoilAnimation", value)
end)
player:GetAttributeChangedSignal("RecoilAnimation"):Connect(refreshRecoil)

-- Crosshair --------------------------------------------------------------------------
local appearance = pages.Crosshair
local plate = Theme.new("Frame", {
	Name = "Preview",
	Size = UDim2.fromOffset(340, 340),
	BackgroundColor3 = Color3.fromRGB(48, 58, 72),
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Parent = appearance,
})
Theme.corner(plate, 4)
Theme.edge(plate, 3)
for _, size in { UDim2.new(0, 1, 1, 0), UDim2.new(1, 0, 0, 1) } do
	Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		BackgroundColor3 = Theme.Text,
		BackgroundTransparency = 0.78,
		BorderSizePixel = 0,
		Parent = plate,
	})
end
-- Anchored at its centre, so resizing can never move it off the guide lines.
local function mark(parent: Instance, name: string): Frame
	return Theme.new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		Parent = parent,
	})
end
local livePreview = mark(plate, "LivePreview")

local refreshSize = slider(
	appearance,
	0,
	350,
	340,
	"Size",
	crosshairs.MinSize,
	crosshairs.MaxSize,
	0.05,
	function()
		return crosshairs.size(player:GetAttribute("CrosshairSize"))
	end,
	function(value)
		player:SetAttribute("CrosshairSize", value)
	end,
	function(value)
		return `{math.round(value * 100)}%`
	end
)

local STYLE_X = 368
local STYLE_W = CONTENT_W - STYLE_X
Theme.label(appearance, "Style", Theme.Title, 18, {
	Position = UDim2.fromOffset(STYLE_X, 0),
	Size = UDim2.fromOffset(200, 26),
})
local styleDetail = Theme.label(appearance, "", Theme.Body, 14, {
	Position = UDim2.fromOffset(STYLE_X, 238),
	Size = UDim2.fromOffset(STYLE_W, 22),
	TextColor3 = Theme.Soft,
})
Theme.label(appearance, "Colour", Theme.Title, 18, {
	Position = UDim2.fromOffset(STYLE_X, 272),
	Size = UDim2.fromOffset(200, 26),
})
type Tile = { button: TextButton, edge: UIStroke, mark: Frame, id: string }
local tiles: { Tile } = {}
local TILE_W = (STYLE_W - 24) / 4
for index, entry in crosshairs.Presets do
	local button = Theme.button(appearance, "", Theme.Body, 13, {
		Name = `CrosshairStyle{entry.id}`,
		Position = UDim2.fromOffset(
			STYLE_X + ((index - 1) % 4) * (TILE_W + 8),
			32 + math.floor((index - 1) / 4) * 100
		),
		Size = UDim2.fromOffset(TILE_W, 92),
		BackgroundColor3 = Theme.Blank,
	})
	Theme.corner(button, 4)
	local edge = Theme.edge(button, 2)
	Theme.label(button, entry.label, Theme.Body, 13, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -4),
		Size = UDim2.new(1, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local holder = mark(button, "Mark")
	holder.Position = UDim2.new(0.5, 0, 0, 36)
	button.Activated:Connect(function()
		player:SetAttribute("CrosshairStyle", entry.id)
	end)
	table.insert(tiles, { button = button, edge = edge, mark = holder, id = entry.id })
end
type Swatch = { edge: UIStroke, color: Color3 }
local swatches: { Swatch } = {}
for index, entry in crosshairs.Colors do
	local button = Theme.button(appearance, "", Theme.Body, 12, {
		Name = `CrosshairColor{entry.label}`,
		Position = UDim2.fromOffset(STYLE_X + (index - 1) * 50, 304),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = entry.color,
	})
	Theme.corner(button, 4)
	button.Activated:Connect(function()
		player:SetAttribute("CrosshairColor", entry.color)
	end)
	table.insert(swatches, { edge = Theme.edge(button, 2), color = entry.color })
end
Theme.label(appearance, "Hex", Theme.Body, 13, {
	Position = UDim2.fromOffset(STYLE_X, 360),
	Size = UDim2.fromOffset(34, 38),
	TextColor3 = Theme.Soft,
})
local hex = Theme.new("TextBox", {
	Name = "CrosshairHex",
	Position = UDim2.fromOffset(STYLE_X + 36, 360),
	Size = UDim2.fromOffset(104, 38),
	BackgroundColor3 = Color3.fromRGB(15, 18, 23),
	BorderSizePixel = 0,
	TextColor3 = Theme.Text,
	FontFace = Theme.Body,
	TextSize = 14,
	ClearTextOnFocus = false,
	PlaceholderText = "#RRGGBB",
	Parent = appearance,
})
Theme.corner(hex, 3)
Theme.edge(hex, 2)
local hexNote = Theme.label(appearance, "", Theme.Body, 13, {
	Position = UDim2.fromOffset(STYLE_X + 152, 360),
	Size = UDim2.fromOffset(STYLE_W - 152, 38),
	TextColor3 = Theme.Soft,
})
hex.FocusLost:Connect(function()
	local value = hex.Text:gsub("%s", ""):gsub("^#", "")
	if #value == 6 and value:match("^%x+$") then
		hexNote.Text = ""
		player:SetAttribute("CrosshairColor", Color3.fromHex(value))
	else
		hexNote.Text = "Use six hex digits, e.g. #86F0C1"
	end
end)

local function refreshAppearance()
	local preset = crosshairs.find(player:GetAttribute("CrosshairStyle"))
	local color = crosshairs.color(player:GetAttribute("CrosshairColor"))
	local size = crosshairs.size(player:GetAttribute("CrosshairSize"))
	crosshairs.draw(livePreview, preset.id, color)
	crosshairs.resize(livePreview, size * PREVIEW_ZOOM)
	styleDetail.Text = preset.description
	for _, tile in tiles do
		crosshairs.draw(tile.mark, tile.id, color)
		crosshairs.resize(tile.mark, TILE_ZOOM)
		local selected = tile.id == preset.id
		tile.button.BackgroundColor3 = if selected then Theme.Raised else Theme.Blank
		tile.edge.Color = if selected then Theme.Accent else Theme.Ink
	end
	for _, swatch in swatches do
		local selected = swatch.color == color
		swatch.edge.Color = if selected then Theme.Accent else Theme.Ink
		swatch.edge.Thickness = if selected then 3 else 2
	end
	if not hex:IsFocused() then
		hex.Text = "#" .. string.upper(color:ToHex())
	end
	refreshSize()
end
for _, attribute in { "CrosshairStyle", "CrosshairColor", "CrosshairSize" } do
	player:GetAttributeChangedSignal(attribute):Connect(refreshAppearance)
end
refreshAppearance()

reset.Activated:Connect(function()
	Keybinds.reset()
	for name, value in DEFAULTS do
		player:SetAttribute(name, value)
	end
	flipCamera.select(Config.Camera.FirstPerson.FlipCameraDefault)
	note.Text = "Everything is back to its default."
end)

-- Opening ----------------------------------------------------------------------------
local function refreshOpen()
	local open = player:GetAttribute("PvpMenu") == "Settings"
	panel.Visible = open
	opener.Visible = player:GetAttribute("PvpMenu") == nil
	if not open then
		endPrompt()
		dragging = nil
	end
end
player:GetAttributeChangedSignal("PvpMenu"):Connect(refreshOpen)
opener.Activated:Connect(function()
	Theme.setMenu("Settings")
end)
close.Activated:Connect(function()
	Theme.setMenu(nil)
end)
Keybinds.on("settings", function(pressed: boolean)
	if pressed then
		Theme.toggleMenu("Settings")
	end
end)
showPage("Controls")
refreshOpen()
gui.Parent = player:WaitForChild("PlayerGui")

-- Shift lock relocks the cursor every frame; keep it free while a menu is open.
RunService:BindToRenderStep(
	"SlugshotSettingsCursor",
	Enum.RenderPriority.Camera.Value + 20,
	function()
		if player:GetAttribute("PvpMenu") ~= nil then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		if panel.Visible then
			refreshFlip()
		end
	end
)

-- The Roblox menu takes the keyboard, so an open key prompt gives way to it.
GuiService.MenuOpened:Connect(endPrompt)
