--!strict
-- The stone station by the firing line: walk up and press F for the dummies' settings. Built from the settings menu's
-- own parts, with the same slime along the top and the same liquid sliders. The server owns and checks both values.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local combat = ((script.Parent :: Instance).Parent :: Instance):WaitForChild("Combat")
local Theme = (require :: any)(combat:WaitForChild("PvpTheme"))
local Fx = (require :: any)(combat:WaitForChild("PvpFx"))
local Goo = (require :: any)(combat:WaitForChild("Goo"))
local GooBar = (require :: any)(combat:WaitForChild("GooBar"))
local floorPlan = require(ReplicatedStorage:WaitForChild("TrainingFloor")) :: any
local remote = ReplicatedStorage:WaitForChild("TrainingDummySettings") :: RemoteEvent
local limits = floorPlan.range.defaults

local MENU = "TrainingDummies"
local PANEL_W, PANEL_H, RADIUS = 720, 430, 14
local BAND_TOP = 46
local BAND_COL, BAND_BACK_COL = 8, 16
local SLIDER_Y, SLIDER_INK, SLIDER_LIQUID, SLIDER_COL = 30, 3, 16, 6
local BAND_FRONT_SCROLL, BAND_BACK_SCROLL = 16, -11
local BAND_SWELL, BAND_SWELL_RATE = 3, 0.13
local BAND_TENSION, BAND_RESTORE, BAND_DAMPING = 0.3, 0.003, 0.99
local DRIPS = { 0.06, 0.2, 0.37, 0.52, 0.68, 0.86 }
local OPEN_BLUR = 14
local SEND_GAP = 0.1 -- the server takes one change at a time this far apart
local WALK_AWAY = 18
local ACCENT = Fx.Accents.Gameplay

local gui = Instance.new("ScreenGui")
gui.Name = "TrainingControls"
gui.ResetOnSpawn, gui.IgnoreGuiInset = false, true
gui.DisplayOrder = 10
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local blur = Instance.new("BlurEffect")
blur.Name, blur.Size, blur.Enabled, blur.Parent = "TrainingControlsBlur", 0, false, Lighting

local dim = Theme.new("Frame", {
	Name = "Dim",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(8, 8, 22),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Visible = false,
	Parent = gui,
})
local holder = Theme.new("Frame", {
	Name = "Holder",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(PANEL_W, PANEL_H),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 1,
	Parent = gui,
})
Theme.fit(gui, Theme.new("UIScale", { Parent = holder }), 800)
local stage = Theme.new("Frame", {
	Name = "Stage",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Parent = holder,
})
local pop = Theme.new("UIScale", { Parent = stage })
local shadow = Theme.new("Frame", {
	Name = "Shadow",
	Position = UDim2.fromOffset(0, 9),
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Theme.Ink,
	BorderSizePixel = 0,
	ZIndex = 0,
	Parent = stage,
})
Theme.corner(shadow, RADIUS)
local panel = Theme.new("Frame", {
	Name = "Panel",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 1,
	Parent = stage,
})
Theme.corner(panel, RADIUS)
Theme.edge(panel, 4)
Theme.new("UIGradient", {
	Color = ColorSequence.new(Fx.PanelTop, Fx.PanelBottom),
	Rotation = 90,
	Parent = panel,
})

-- The crystal in the corner, breathing light slowly, with twinkles on its points.
local crystalLight = Fx.crystalLight(panel, ACCENT, UDim2.new(1, -87, 1, 6), 170, 1)
local twinkles = Fx.twinkles(panel, { { x = 1, y = 1, w = -190, h = -190, weight = 1 } }, 7, ACCENT)
Theme.new("ImageLabel", {
	Name = "Crystal",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -2, 1, 6),
	Size = UDim2.fromOffset(170, 170),
	BackgroundTransparency = 1,
	Image = Fx.asset("crystal"),
	ImageColor3 = ACCENT,
	ZIndex = 2,
	Parent = panel,
})

local head = Theme.new("Frame", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, BAND_TOP + 4),
	BackgroundColor3 = Fx.Deep,
	BorderSizePixel = 0,
	ZIndex = 6,
	Parent = panel,
})
Theme.new("Frame", {
	Position = UDim2.new(0, 0, 1, -3),
	Size = UDim2.new(1, 0, 0, 3),
	BackgroundColor3 = Theme.Ink,
	BorderSizePixel = 0,
	Parent = head,
})
local gooBack = Goo.strip(panel, "bandBack", Goo.Band, BAND_BACK_COL, 0, BAND_TOP, PANEL_W, 3)
local gooFront = Goo.strip(panel, "bandFront", Goo.Band, BAND_COL, 0, BAND_TOP, PANEL_W, 4)
local gooShine = Goo.strip(panel, "bandShine", Goo.Band, BAND_COL, 0, BAND_TOP, PANEL_W, 4)
Goo.tint(gooShine, Color3.new(1, 1, 1))
Goo.tint(gooFront, ACCENT)
Goo.tint(gooBack, Color3.new(ACCENT.R * 0.68, ACCENT.G * 0.68, ACCENT.B * 0.68))
local ripples = Goo.ripples(math.ceil(PANEL_W / BAND_COL / 2))
local gooEdge = BAND_TOP + Goo.Band.edge - Goo.Band.top
type Hanging = { at: number, drip: any }
local hanging: { Hanging } = {}
for _, at in DRIPS do
	table.insert(hanging, { at = at, drip = Goo.drip(panel, at * PANEL_W, gooEdge, 5) })
end
Theme.label(head, "Dummy settings", Theme.TitleBold, 32, {
	Name = "TitleInk",
	Position = UDim2.fromOffset(27, 1),
	Size = UDim2.fromOffset(400, BAND_TOP),
	TextColor3 = Theme.Ink,
	ZIndex = 5,
})
Theme.label(head, "Dummy settings", Theme.TitleBold, 32, {
	Name = "Title",
	Position = UDim2.fromOffset(24, -2),
	Size = UDim2.fromOffset(400, BAND_TOP),
	TextColor3 = ACCENT,
	ZIndex = 6,
})

local opened = false
local close = Theme.button(head, "×", Theme.Body, 28, {
	Name = "Close",
	Modal = true,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(1, -30, 0, 24),
	Size = UDim2.fromOffset(40, 40),
	BackgroundColor3 = Fx.Button,
	ZIndex = 6,
})
Theme.corner(close, 10)
Theme.edge(close, 2)
close.Activated:Connect(function()
	Fx.sound("click")
	Theme.setMenu(nil)
end)

local page = Theme.new("Frame", {
	Name = "Page",
	Position = UDim2.fromOffset(28, 84),
	Size = UDim2.fromOffset(PANEL_W - 56, PANEL_H - 100),
	BackgroundTransparency = 1,
	ZIndex = 3,
	Parent = panel,
})

-- Values on their way to the server show at once; one is sent per gap, last value wins.
local waiting: { [string]: number } = {}
local sent: { [string]: number? } = {}
local function read(kind: string, attribute: string, fallback: number): number
	return waiting[kind] or sent[kind] or (workspace:GetAttribute(attribute) or fallback) :: number
end
local function health(): number
	return read("Health", "TrainingDummyHealth", limits.health)
end
local function speed(): number
	return read("Speed", "TrainingDummySpeed", limits.speed)
end

local dragging: ((number) -> ())? = nil
local dragEnded: (() -> ())? = nil
local function slider(
	y: number,
	name: string,
	low: number,
	high: number,
	step: number,
	get: () -> number,
	write: (number) -> (),
	format: (number) -> string
): () -> ()
	local width = page.Size.X.Offset
	local gem = Theme.new("Frame", {
		Name = "Gem",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(5, y + 13),
		Size = UDim2.fromOffset(9, 9),
		Rotation = 45,
		BackgroundColor3 = ACCENT,
		BorderSizePixel = 0,
		Parent = page,
	})
	Theme.edge(gem, 1.5)
	Theme.label(page, name, Theme.Title, 19, {
		Position = UDim2.fromOffset(16, y),
		Size = UDim2.fromOffset(width - 120, 26),
		TextStrokeColor3 = Theme.Ink,
		TextStrokeTransparency = 0.4,
	})
	local value = Theme.label(page, "", Theme.TitleBold, 21, {
		Position = UDim2.fromOffset(width - 100, y),
		Size = UDim2.fromOffset(100, 26),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = ACCENT,
		TextStrokeColor3 = Theme.Ink,
		TextStrokeTransparency = 0.4,
	})
	local valueScale = Theme.new("UIScale", { Parent = value })
	local goo =
		GooBar.new(page, Vector2.new(0, y + SLIDER_Y), width - SLIDER_INK * 2, SLIDER_LIQUID, {
			col = SLIDER_COL,
			colour = ACCENT,
			empty = Fx.Blank,
			drips = false,
			lost = false,
			dragged = true,
			behindMark = true,
			active = function(): boolean
				return holder.Visible
			end,
		})
	local track = Theme.button(page, "", Theme.Body, 1, {
		Name = `{name}Slider`,
		Position = UDim2.fromOffset(SLIDER_INK, y + SLIDER_Y),
		Size = UDim2.fromOffset(width - SLIDER_INK * 2, SLIDER_LIQUID + SLIDER_INK * 2),
		BackgroundTransparency = 1,
		ZIndex = 6,
	})
	local knob = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = Theme.Text,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = track,
	})
	Theme.corner(knob, 12)
	local knobEdge = Theme.edge(knob, 3)
	local knobScale = Theme.new("UIScale", { Parent = knob })
	local dot = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = ACCENT,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = knob,
	})
	Theme.corner(dot, 5)
	local hovering, held = false, false
	local function refreshKnob()
		Fx.tween(
			knobScale,
			0.18,
			{ Scale = if held then 1.3 elseif hovering then 1.15 else 1 },
			Enum.EasingStyle.Back
		)
		Fx.tween(knobEdge, 0.15, { Color = if held or hovering then ACCENT else Theme.Ink })
	end
	local function refresh()
		local share = math.clamp((get() - low) / (high - low), 0, 1)
		goo.set(share)
		knob.Position = UDim2.fromScale(share, 0.5)
		value.Text = format(get())
	end
	local function slide(mouseX: number)
		local share = math.clamp((mouseX - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		local before = get()
		write(math.round((low + share * (high - low)) / step) * step)
		refresh()
		if get() ~= before then
			valueScale.Scale = 1.18
			Fx.tween(valueScale, 0.16, { Scale = 1 }, Enum.EasingStyle.Back)
			Fx.sound("hover")
		end
	end
	track.MouseEnter:Connect(function()
		hovering = true
		refreshKnob()
	end)
	track.MouseLeave:Connect(function()
		hovering = false
		refreshKnob()
	end)
	track.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			dragging = slide
			held = true
			dragEnded = function()
				held = false
				refreshKnob()
			end
			refreshKnob()
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
local function endDrag()
	dragging = nil
	if dragEnded then
		dragEnded()
		dragEnded = nil
	end
end
UserInputService.InputEnded:Connect(function(input)
	if
		input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
	then
		endDrag()
	end
end)

local refreshHealth = slider(
	6,
	"Dummy HP",
	limits.minHealth,
	limits.maxHealth,
	25,
	health,
	function(value)
		waiting.Health = value
	end,
	function(value)
		return tostring(value)
	end
)
local refreshSpeed = slider(
	92,
	"Moving dummy speed",
	limits.minSpeed,
	limits.maxSpeed,
	1,
	speed,
	function(value)
		waiting.Speed = value
	end,
	function(value)
		return if value == 0 then "Still" else `{value} /s`
	end
)

local function chunky(text: string, x: number, width: number, callback: () -> ())
	local button = Theme.button(page, text, Theme.Title, 18, {
		Name = text,
		Position = UDim2.fromOffset(x, 192),
		Size = UDim2.fromOffset(width, 44),
		ZIndex = 4,
	})
	Fx.chunky(button, { accent = ACCENT, radius = 10 })
	button.Activated:Connect(function()
		Fx.sound("select")
		callback()
		refreshHealth()
		refreshSpeed()
	end)
end
chunky("Keep still", 0, 170, function()
	waiting.Speed = limits.minSpeed
end)
chunky("Reset", 184, 170, function()
	waiting.Speed = limits.speed
	waiting.Health = limits.health
end)

-- The server's answer replaces what was sent.
workspace:GetAttributeChangedSignal("TrainingDummyHealth"):Connect(function()
	sent.Health = nil
	refreshHealth()
end)
workspace:GetAttributeChangedSignal("TrainingDummySpeed"):Connect(function()
	sent.Speed = nil
	refreshSpeed()
end)

-- Opening -----------------------------------------------------------------------------
local openToken = 0
local function refreshOpen()
	local open = player:GetAttribute("PvpMenu") == MENU
	if open == opened then
		return
	end
	opened = open
	openToken += 1
	local token = openToken
	if open then
		holder.Visible, dim.Visible, blur.Enabled = true, true, true
		twinkles.setActive(true)
		pop.Scale = 0.86
		Fx.tween(pop, 0.32, { Scale = 1 }, Enum.EasingStyle.Back)
		Fx.tween(dim, 0.2, { BackgroundTransparency = 0.45 })
		Fx.tween(blur, 0.2, { Size = OPEN_BLUR })
		Fx.sound("select")
		refreshHealth()
		refreshSpeed()
	else
		endDrag()
		Fx.tween(pop, 0.12, { Scale = 0.93 })
		Fx.tween(dim, 0.14, { BackgroundTransparency = 1 })
		Fx.tween(blur, 0.14, { Size = 0 })
		task.delay(0.13, function()
			if token == openToken then
				holder.Visible, dim.Visible, blur.Enabled = false, false, false
				twinkles.setActive(false)
			end
		end)
	end
end
player:GetAttributeChangedSignal("PvpMenu"):Connect(refreshOpen)

-- The prompt over the station ---------------------------------------------------------
local function isStation(prompt: ProximityPrompt): boolean
	return prompt.Name == "TrainingDummyPrompt"
end
ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
	if not isStation(prompt) then
		return
	end
	local board = Instance.new("BillboardGui")
	board.Name = "TrainingPromptBoard"
	board.Adornee = prompt.Parent :: Instance
	board.Size = UDim2.fromOffset(210, 44)
	board.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
	board.LightInfluence = 0
	board.AlwaysOnTop = true
	board.Active = true
	local back = Theme.button(board, "", Theme.Body, 1, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Fx.Deep,
	})
	Theme.corner(back, 10)
	Theme.edge(back, 2)
	back.Activated:Connect(function()
		prompt:InputHoldBegin()
		prompt:InputHoldEnd()
	end)
	local key = Theme.label(back, "F", Theme.TitleBold, 20, {
		Position = UDim2.fromOffset(8, 7),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = ACCENT,
		BackgroundTransparency = 0,
		TextColor3 = Theme.OnAccent,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Theme.corner(key, 7)
	Theme.edge(key, 2)
	Theme.label(back, "Dummy settings", Theme.Title, 18, {
		Position = UDim2.fromOffset(48, 0),
		Size = UDim2.new(1, -54, 1, 0),
		TextStrokeColor3 = Theme.Ink,
		TextStrokeTransparency = 0.4,
	})
	board.Parent = gui
	prompt.PromptHidden:Once(function()
		board:Destroy()
	end)
end)
ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
	if isStation(prompt) then
		Theme.toggleMenu(MENU)
	end
end)

gui.Parent = player:WaitForChild("PlayerGui")

-- Running ----------------------------------------------------------------------------
local clock, nextRipple, nextSend = 0, 0.5, 0
RunService.RenderStepped:Connect(function(dt: number)
	local now = os.clock()
	if now >= nextSend then
		for _, kind in { "Health", "Speed" } do
			local value = waiting[kind]
			if value then
				waiting[kind] = nil
				sent[kind] = value
				remote:FireServer(kind, value)
				nextSend = now + SEND_GAP
				-- A refused or unchanged value gets no answer, so it can't stick.
				task.delay(0.6, function()
					if sent[kind] == value then
						sent[kind] = nil
						refreshHealth()
						refreshSpeed()
					end
				end)
				break
			end
		end
	end
	if opened then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local at, origin = floorPlan.station.at, floorPlan.origin
		local station = Vector3.new(origin[1] + at[1], origin[2], origin[3] + at[2])
		local away = root and (root.Position - station) * Vector3.new(1, 0, 1)
		if not player:GetAttribute("InTraining") or (away and away.Magnitude > WALK_AWAY) then
			Theme.setMenu(nil)
		end
	end
	if not holder.Visible then
		return
	end
	clock += dt
	Goo.settle(ripples, dt, BAND_TENSION, BAND_RESTORE, BAND_DAMPING)
	nextRipple -= dt
	if nextRipple <= 0 then
		nextRipple = 0.5 + math.random() * 1.2
		Goo.push(ripples, math.random(), (math.random() - 0.5) * 0.5, 3)
	end
	local function height(across: number): number
		local share = across / PANEL_W
		return math.clamp(
			Goo.sample(ripples, share)
				+ BAND_SWELL * math.sin(2 * math.pi * BAND_SWELL_RATE * clock + share * 11),
			-7,
			7
		)
	end
	local scroll = clock * BAND_FRONT_SCROLL
	Goo.pose(gooBack, clock * BAND_BACK_SCROLL, function(across: number): number
		return -height(across) * 0.6 + 1
	end)
	Goo.pose(gooFront, scroll, height)
	Goo.pose(gooShine, scroll, height)
	for _, entry in hanging do
		local across = entry.at * PANEL_W
		local shift = height(across) + Goo.waveAt(Goo.Band, (scroll + across) % Goo.Band.period)
		entry.drip.step(dt, shift, true, ACCENT)
	end
	crystalLight.breathe(0.5 + 0.5 * math.sin(clock * 1.1))
end)
