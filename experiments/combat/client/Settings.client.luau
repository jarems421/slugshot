--!strict
-- The settings menu (owner, 2026-11-01): Controls with every key and mouse button rebindable and the
-- sprint options, Gameplay, and Crosshair. Owner, 2026-11-02: it must "pop way more" and feel dimensional,
-- so each tab has its own colour and everything responds; see PvpFx. Values are local player attributes
-- read by the camera, movement client, viewmodel and holster, and persisted by SettingsSync.
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Theme = require(script.Parent.PvpTheme)
local Fx = require(script.Parent.PvpFx)
local Goo = require(script.Parent.Goo)
local Backdrop = require(script.Parent.Backdrop)
local GooBar = require(script.Parent.GooBar)
local SlugIcon = require(script.Parent.SlugIcon)
local Combat = require(ReplicatedStorage:WaitForChild("Combat"))

local player = Players.LocalPlayer
local movement = player.PlayerScripts:WaitForChild("MovementSandbox")
local flipCamera = (require :: any)(movement:WaitForChild("AcrobaticCamera"))
local crosshairs = (require :: any)(movement:WaitForChild("CrosshairStyles"))
local recoil = (require :: any)(movement:WaitForChild("BlasterRecoil"))
local Keybinds = (require :: any)(movement:WaitForChild("Keybinds"))

local CAPTURE_WAIT = 5 -- seconds before a key prompt cancels itself
local PANEL_W, PANEL_H, SIDE_W, HEAD_H = 1220, 648, 160, 60
local CONTENT_W = PANEL_W - SIDE_W - 44
local CONTENT_Y = HEAD_H + 26 -- room for the goo hanging from the header
local PREVIEW_ZOOM = 4 -- the preview is enlarged so the shape is easy to judge
local TILE_ZOOM = 2
local COG_SIZE, COG_FALLBACK_X, COG_FALLBACK_HEIGHT = 34, 172, 58
local REPRESS_GUARD = 0.35 -- seconds after a key prompt ends before a click can open another
local PANEL_RADIUS = 14
local OPEN_BLUR = 14
local TAB_H, TAB_GAP = 50, 8
local BAND_COL, BAND_BACK_COL = 8, 16
local SLIDER_Y, SLIDER_INK, SLIDER_LIQUID, SLIDER_COL = 30, 3, 16, 6
local BAND_TOP = HEAD_H - 14 -- the goo comes out from under the header
local BAND_FRONT_SCROLL, BAND_BACK_SCROLL = 16, -11
local BAND_SWELL, BAND_SWELL_RATE = 3, 0.13
local BAND_TENSION, BAND_RESTORE, BAND_DAMPING = 0.3, 0.003, 0.99
local BAND_POKE = 0.9 -- how hard choosing a tab shakes it
local GOO_DRIPS = { 0.04, 0.17, 0.24, 0.38, 0.47, 0.6, 0.68, 0.83, 0.93 }
local TAB_ORDER = { "Controls", "Gameplay", "Crosshair" }

local Schema = require(ReplicatedStorage:WaitForChild("Combat").SettingsSchema)
local DEFAULTS = table.clone(Schema.Defaults)
DEFAULTS.CrosshairColor = Color3.fromHex(DEFAULTS.CrosshairColor)
for name, value in DEFAULTS do
	if player:GetAttribute(name) == nil then
		player:SetAttribute(name, value)
	end
end
player:GetAttributeChangedSignal("FlipCamera"):Connect(function()
	flipCamera.select(player:GetAttribute("FlipCamera"))
end)
flipCamera.select(player:GetAttribute("FlipCamera"))
require(script.Parent.SettingsSync).start(Keybinds)

local gui = Instance.new("ScreenGui")
gui.Name = "Settings"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local blur = Instance.new("BlurEffect")
blur.Name = "SettingsBlur"
blur.Size = 0
blur.Enabled = false
blur.Parent = Lighting

-- A small cog beside Roblox's own buttons. Theirs are dark and round, so this one is a pale
-- rounded square that cannot be mistaken for them.
local opener = Theme.button(gui, "", Theme.Body, 12, {
	Name = "SettingsOpener",
	Size = UDim2.fromOffset(COG_SIZE, COG_SIZE),
	BackgroundColor3 = Theme.Accent,
	ZIndex = 2,
})
Theme.corner(opener, 9)
Theme.edge(opener, 2)
local openerScale = Theme.new("UIScale", { Parent = opener })
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
opener.MouseEnter:Connect(function()
	Fx.sound("hover")
	Fx.tween(openerScale, 0.2, { Scale = 1.16 }, Enum.EasingStyle.Back)
	Fx.tween(cog, 0.45, { Rotation = 90 }, Enum.EasingStyle.Back)
end)
opener.MouseLeave:Connect(function()
	Fx.tween(openerScale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	Fx.tween(cog, 0.45, { Rotation = 0 }, Enum.EasingStyle.Back)
end)

-- Behind the menu: the world dims and blurs.
local dim = Theme.new("Frame", {
	Name = "Dim",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(8, 8, 22),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 0,
	Parent = gui,
})

-- The holder fits the screen; the panel inside it pops open.
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
Theme.fit(gui, Theme.new("UIScale", { Parent = holder }), 1280)
-- A frame takes one UIScale, so the pop goes on the inner frame.
local stage = Theme.new("Frame", {
	Name = "Stage",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Parent = holder,
})
local pop = Theme.new("UIScale", { Parent = stage })
local dropShadow = Theme.new("Frame", {
	Name = "Shadow",
	Position = UDim2.fromOffset(0, 9),
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Theme.Ink,
	BorderSizePixel = 0,
	ZIndex = 0,
	Parent = stage,
})
Theme.corner(dropShadow, PANEL_RADIUS)
local panel = Theme.new("Frame", {
	Name = "Panel",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	ClipsDescendants = true,
	ZIndex = 1,
	Parent = stage,
})
Theme.corner(panel, PANEL_RADIUS)
Theme.edge(panel, 4)
Theme.new("UIGradient", {
	Color = ColorSequence.new(Fx.PanelTop, Fx.PanelBottom),
	Rotation = 90,
	Parent = panel,
})
-- The cavern passage behind the menu, as on the loading screen (owner, 2026-11-03): one picture per tab colour so its
-- crystals' light matches, cross-fading with the tab. Dimmed more than the loading screen so every row stays easy to
-- read. The panel's gradient shows until the pictures have loaded. The panel clips square, so each layer is rounded.
local scenery = Theme.new("Frame", {
	Name = "Scenery",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 0,
	Parent = panel,
})
local backdrops: { [string]: CanvasGroup } = {}
for _, name in TAB_ORDER do
	local back = Backdrop.new(scenery, PANEL_W / PANEL_H, PANEL_RADIUS)
	back.set(`back{name}`)
	local group = back.group :: CanvasGroup
	group.Name = `Backdrop{name}`
	group.GroupTransparency = 1
	backdrops[name] = group
end
local veil = Theme.new("Frame", {
	Name = "Veil",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(10, 10, 26),
	BackgroundTransparency = 0.68,
	BorderSizePixel = 0,
	ZIndex = 2,
	Parent = scenery,
})
Theme.corner(veil, PANEL_RADIUS)
-- Slugterra first (owner, 2026-11-02): the menu is a place in the cavern. Crystals grow out of the panel,
-- light its corner and pulse slowly, with twinkles around them. All original art.
type Crystal = { image: ImageLabel, light: Fx.CrystalLight, phase: number }
local crystals: { Crystal } = {}
local function crystalCluster(image: string, position: UDim2, size: number, phase: number)
	local light = Fx.crystalLight(
		panel,
		Fx.Accents.Controls,
		position - UDim2.fromOffset(size * 0.5, 0),
		size,
		1
	)
	local cluster = Theme.new("ImageLabel", {
		Name = "Crystal",
		AnchorPoint = Vector2.new(1, 1),
		Position = position,
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		Image = Fx.asset(image),
		ImageColor3 = Fx.Accents.Controls,
		ZIndex = 2,
		Parent = panel,
	})
	table.insert(crystals, { image = cluster, light = light, phase = phase })
end
crystalCluster("crystal", UDim2.new(1, -2, 1, 6), 262, 0)
crystalCluster("crystalSmall", UDim2.new(0.56, 0, 1, 4), 92, 2.1)
local twinkles = Fx.twinkles(panel, {
	{ x = 1, y = 1, w = -290, h = -300, weight = 6 },
	{ x = 0.56, y = 1, w = -120, h = -120, weight = 2 },
}, 16, Fx.Accents.Controls)

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
local gooRipples = Goo.ripples(math.ceil(PANEL_W / BAND_COL / 2))
local gooEdge = BAND_TOP + Goo.Band.edge - Goo.Band.top
type Hanging = { at: number, drip: Goo.Drip }
local hanging: { Hanging } = {}
for _, at in GOO_DRIPS do
	table.insert(hanging, { at = at, drip = Goo.drip(panel, at * PANEL_W, gooEdge, 5) })
end
local gooColour, gooShown = Fx.Accents.Controls, nil :: Color3?
-- Comic title: an ink copy sits behind and below the coloured one.
Theme.label(head, "Settings", Theme.TitleBold, 32, {
	Name = "TitleInk",
	Position = UDim2.fromOffset(27, 1),
	Size = UDim2.fromOffset(300, BAND_TOP),
	TextColor3 = Theme.Ink,
	ZIndex = 5,
})
local title = Theme.label(head, "Settings", Theme.TitleBold, 32, {
	Name = "Title",
	Position = UDim2.fromOffset(24, -2),
	Size = UDim2.fromOffset(300, BAND_TOP),
	TextColor3 = Fx.Accents.Controls,
	ZIndex = 6,
})
-- Modal frees the cursor while the menu is open (first person locks it).
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
local closeScale = Theme.new("UIScale", { Parent = close })
close.MouseEnter:Connect(function()
	Fx.sound("hover")
	Fx.tween(close, 0.25, { Rotation = 90, BackgroundColor3 = Fx.Coral }, Enum.EasingStyle.Back)
	Fx.tween(closeScale, 0.2, { Scale = 1.12 }, Enum.EasingStyle.Back)
end)
close.MouseLeave:Connect(function()
	Fx.tween(close, 0.25, { Rotation = 0, BackgroundColor3 = Fx.Button }, Enum.EasingStyle.Back)
	Fx.tween(closeScale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
end)

local saveStatus = Theme.label(head, "", Theme.Body, 13, {
	Name = "SaveStatus",
	Position = UDim2.fromOffset(320, 8),
	Size = UDim2.fromOffset(650, 28),
	TextColor3 = Theme.Soft,
	ZIndex = 6,
})
local function refreshSaveStatus()
	local messages = {
		Loading = "Loading saved settings...",
		Saved = "Settings saved",
		Pending = "Saving settings...",
		LoadFailed = "Saved settings unavailable; retrying. Changes stay in this session.",
		SaveFailed = "Could not save settings; retrying...",
		NewerVersion = "Saved settings need a newer game version. Changes stay in this session.",
	}
	saveStatus.Text = messages[player:GetAttribute("SettingsSaveStatus")] or ""
end
player:GetAttributeChangedSignal("SettingsSaveStatus"):Connect(refreshSaveStatus)
refreshSaveStatus()

local side = Theme.new("Frame", {
	Name = "Tabs",
	Position = UDim2.fromOffset(0, HEAD_H),
	Size = UDim2.new(0, SIDE_W, 1, -HEAD_H),
	BackgroundColor3 = Fx.Deep,
	BorderSizePixel = 0,
	ZIndex = 2,
	Parent = panel,
})
Theme.new("Frame", {
	Position = UDim2.new(1, -3, 0, 0),
	Size = UDim2.new(0, 3, 1, 0),
	BackgroundColor3 = Theme.Ink,
	BorderSizePixel = 0,
	ZIndex = 2,
	Parent = side,
})

local function page(name: string): Frame
	return Theme.new("Frame", {
		Name = name,
		Position = UDim2.fromOffset(SIDE_W + 22, CONTENT_Y),
		Size = UDim2.fromOffset(CONTENT_W, PANEL_H - CONTENT_Y - 16),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 3,
		Parent = panel,
	})
end
local pages: { [string]: Frame } = {
	Controls = page("ControlsPage"),
	Gameplay = page("GameplayPage"),
	Crosshair = page("CrosshairPage"),
}

local function tabY(index: number): number
	return 26 + (index - 1) * (TAB_H + TAB_GAP)
end
-- One lit pill slides between the tabs.
local pillLip = Theme.new("Frame", {
	Name = "PillLip",
	Position = UDim2.fromOffset(10, tabY(1) + 4),
	Size = UDim2.new(1, -23, 0, TAB_H),
	BackgroundColor3 = Theme.Ink,
	BorderSizePixel = 0,
	ZIndex = 1,
	Parent = side,
})
Theme.corner(pillLip, 12)
Theme.edge(pillLip, 2)
local pill = Theme.new("Frame", {
	Name = "Pill",
	Position = UDim2.fromOffset(10, tabY(1)),
	Size = UDim2.new(1, -23, 0, TAB_H),
	BackgroundColor3 = Fx.Accents.Controls,
	BorderSizePixel = 0,
	ZIndex = 2,
	Parent = side,
})
Theme.corner(pill, 12)
Theme.edge(pill, 2)
Theme.new("UIGradient", {
	Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(176, 176, 190)),
	Rotation = 90,
	Parent = pill,
})
local pillGlow = Fx.glow(side, Fx.Accents.Controls, 1)
pillGlow.Position = UDim2.fromOffset(-14, tabY(1) - 24)
pillGlow.Size = UDim2.new(1, 28, 0, TAB_H + 48)
pillGlow.ImageTransparency = 0.45

type Tab = { button: TextButton, tint: (Color3) -> (), play: () -> () }
local tabs: { [string]: Tab } = {}
local railSlug: SlugIcon.Icon? = nil
local current = ""
local function setChrome(accent: Color3)
	Fx.tween(title, 0.25, { TextColor3 = accent })
	Fx.tween(pill, 0.25, { BackgroundColor3 = accent })
	Fx.tween(pillGlow, 0.25, { ImageColor3 = accent })
	gooColour = accent
	twinkles.setColour(accent)
	for _, cluster in crystals do
		Fx.tween(cluster.image, 0.35, { ImageColor3 = accent })
		cluster.light.setColour(accent)
	end
end
local function showPage(name: string, animate: boolean)
	if current == name then
		return
	end
	current = name
	local index = table.find(TAB_ORDER, name) or 1
	for key, frame in pages do
		frame.Visible = key == name
		local tab = tabs[key]
		local active = key == name
		Fx.tween(tab.button, 0.15, { TextColor3 = if active then Theme.OnAccent else Theme.Soft })
		tab.tint(if active then Theme.OnAccent else Theme.Soft)
	end
	Fx.tween(pill, 0.3, { Position = UDim2.fromOffset(10, tabY(index)) }, Enum.EasingStyle.Back)
	Fx.tween(
		pillLip,
		0.3,
		{ Position = UDim2.fromOffset(10, tabY(index) + 4) },
		Enum.EasingStyle.Back
	)
	Fx.tween(
		pillGlow,
		0.3,
		{ Position = UDim2.fromOffset(-14, tabY(index) - 24) },
		Enum.EasingStyle.Back
	)
	setChrome(Fx.Accents[name])
	for key, backdrop in backdrops do
		Fx.tween(backdrop, 0.35, { GroupTransparency = if key == name then 0 else 1 })
	end
	if animate then
		Fx.cascade(pages[name])
	end
end
-- Tab icons (owner, 2026-11-02): each does its own little thing rather than tilting. One 24 px square.
local function iconBox(button: TextButton): Frame
	return Theme.new("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, -24, 0.5, 0),
		Size = UDim2.fromOffset(24, 24),
		BackgroundTransparency = 1,
		Parent = button,
	})
end
local function iconImage(box: Frame, name: string, see: number): ImageLabel
	return Theme.new("ImageLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Image = Fx.asset(name),
		ImageColor3 = Theme.Soft,
		ImageTransparency = see,
		Parent = box,
	})
end
-- The mouse clicks twice: it dips and its left button fills.
local function mouseIcon_(button: TextButton): (TextButton, (Color3) -> (), () -> ())
	local box = iconBox(button)
	local body = iconImage(box, "iconControls", 0)
	local fill = iconImage(box, "iconMouseButton", 1)
	local token = 0
	return button,
		function(colour: Color3)
			Fx.tween(body, 0.15, { ImageColor3 = colour })
			Fx.tween(fill, 0.15, { ImageColor3 = colour })
		end,
		function()
			token += 1
			local mine = token
			task.spawn(function()
				for _ = 1, 2 do
					if mine ~= token then
						return
					end
					Fx.tween(box, 0.06, { Position = UDim2.new(0, -24, 0.5, 2) })
					Fx.tween(fill, 0.06, { ImageTransparency = 0 })
					task.wait(0.08)
					Fx.tween(
						box,
						0.12,
						{ Position = UDim2.new(0, -24, 0.5, 0) },
						Enum.EasingStyle.Back
					)
					Fx.tween(fill, 0.14, { ImageTransparency = 1 })
					task.wait(0.14)
				end
			end)
		end
end
-- The balls slide along their lines and come home.
local function slidersIcon(button: TextButton): (TextButton, (Color3) -> (), () -> ())
	local box = iconBox(button)
	local parts: { Frame } = {}
	local balls: { { ball: Frame, home: number, away: number, y: number } } = {}
	for _, row in
		{
			{ y = 5, home = 17, away = 6 },
			{ y = 12, home = 7, away = 18 },
			{ y = 19, home = 14, away = 5 },
		}
	do
		local line = Theme.new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromOffset(1, row.y),
			Size = UDim2.fromOffset(22, 2),
			BackgroundColor3 = Theme.Soft,
			BorderSizePixel = 0,
			Parent = box,
		})
		local ball = Theme.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(row.home, row.y),
			Size = UDim2.fromOffset(7, 7),
			BackgroundColor3 = Theme.Soft,
			BorderSizePixel = 0,
			Parent = box,
		})
		Theme.corner(ball, 4)
		table.insert(parts, line)
		table.insert(parts, ball)
		table.insert(balls, { ball = ball, home = row.home, away = row.away, y = row.y })
	end
	local token = 0
	return button,
		function(colour: Color3)
			for _, part in parts do
				Fx.tween(part, 0.15, { BackgroundColor3 = colour })
			end
		end,
		function()
			token += 1
			local mine = token
			for index, entry in balls do
				Fx.tween(
					entry.ball,
					0.26,
					{ Position = UDim2.fromOffset(entry.away, entry.y) },
					Enum.EasingStyle.Sine,
					(index - 1) * 0.05
				)
			end
			task.delay(0.42, function()
				if mine == token then
					for index, entry in balls do
						Fx.tween(
							entry.ball,
							0.32,
							{ Position = UDim2.fromOffset(entry.home, entry.y) },
							Enum.EasingStyle.Back,
							(index - 1) * 0.05
						)
					end
				end
			end)
		end
end
-- The crosshair spins round once.
local function crosshairIcon(button: TextButton): (TextButton, (Color3) -> (), () -> ())
	local box = iconBox(button)
	local image = iconImage(box, "iconCrosshair", 0)
	return button,
		function(colour: Color3)
			Fx.tween(image, 0.15, { ImageColor3 = colour })
		end,
		function()
			image.Rotation = 0
			Fx.tween(image, 0.6, { Rotation = 360 }, Enum.EasingStyle.Back)
		end
end
local TAB_ANIMATIONS = { Controls = mouseIcon_, Gameplay = slidersIcon, Crosshair = crosshairIcon }
for index, name in TAB_ORDER do
	local button = Theme.button(side, name, Theme.Title, 19, {
		Name = `{name}Tab`,
		Position = UDim2.fromOffset(10, tabY(index)),
		Size = UDim2.new(1, -23, 0, TAB_H),
		TextXAlignment = Enum.TextXAlignment.Left,
		BackgroundTransparency = 1,
		TextColor3 = Theme.Soft,
		ZIndex = 3,
	})
	Theme.new("UIPadding", { PaddingLeft = UDim.new(0, 44), Parent = button })
	local _, tint, play = TAB_ANIMATIONS[name](button)
	button.MouseEnter:Connect(function()
		Fx.sound("hover")
		play()
	end)
	button.Activated:Connect(function()
		if current ~= name then
			Fx.sound("select")
			showPage(name, true)
			Fx.sparkle(gui, button, Fx.Accents[name], 6)
			play()
			Goo.push(gooRipples, (index - 1) / #TAB_ORDER * 0.3, BAND_POKE, 5)
			if railSlug then
				SlugIcon.hop(railSlug) -- it notices
			end
		end
	end)
	tabs[name] = { button = button, tint = tint, play = play }
end
local reset = Theme.button(side, "Reset to defaults", Theme.Body, 12, {
	Name = "Reset",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 10, 1, -18),
	Size = UDim2.new(1, -23, 0, 44),
	ZIndex = 3,
})
Fx.chunky(reset, {
	accent = Fx.Coral,
	radius = 10,
	idle = Fx.Blank,
	idleText = Theme.Soft,
})

-- A live slug keeps you company on a rock ledge in the rail, doing its usual wiggles and hops.
Theme.new("ImageLabel", {
	Name = "Ledge",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, -2, 1, -72),
	Size = UDim2.fromOffset(146, 44),
	BackgroundTransparency = 1,
	Image = Fx.asset("ledge"),
	ZIndex = 3,
	Parent = side,
})
local slugSpot = Theme.new("Frame", {
	Name = "Slug",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, -2, 1, -96),
	Size = UDim2.fromOffset(120, 130),
	BackgroundTransparency = 1,
	ZIndex = 4,
	Parent = side,
})
local slug = SlugIcon.mount(slugSpot, Combat.Loadout[1], 0.9, true, 0.02, 1.7)
SlugIcon.setActive(slug, false)
railSlug = slug

type Option = { label: string, value: any }

-- A row of mutually exclusive buttons. Returns its refresh function.
local function choice(
	parent: Instance,
	accent: Color3,
	x: number,
	y: number,
	width: number,
	height: number,
	options: { Option },
	current_: () -> any,
	pick: (any) -> ()
): () -> ()
	local controls: { Fx.Control } = {}
	local each = (width - 10 * (#options - 1)) / #options
	local function refresh()
		for index, option in options do
			controls[index].set(current_() == option.value)
		end
	end
	for index, option in options do
		local item = Theme.button(parent, option.label, Theme.Body, 14, {
			Name = `Choice{option.label}`,
			Position = UDim2.fromOffset(x + (index - 1) * (each + 10), y),
			Size = UDim2.fromOffset(each, height),
			ZIndex = 2,
		})
		controls[index] = Fx.chunky(item, { accent = accent, radius = 10 })
		item.Activated:Connect(function()
			if current_() ~= option.value then
				Fx.sound("select")
				Fx.sparkle(gui, item, accent)
			end
			pick(option.value)
			refresh()
		end)
	end
	refresh()
	return refresh
end

local function attributeChoice(
	parent: Instance,
	accent: Color3,
	x: number,
	y: number,
	width: number,
	height: number,
	attribute: string,
	options: { Option }
)
	local refresh = choice(parent, accent, x, y, width, height, options, function()
		return player:GetAttribute(attribute)
	end, function(value)
		player:SetAttribute(attribute, value)
	end)
	player:GetAttributeChangedSignal(attribute):Connect(refresh)
end

-- A section heading with a small glowing gem.
local function heading(
	parent: Instance,
	text: string,
	accent: Color3,
	x: number,
	y: number,
	width: number
)
	local gem = Theme.new("Frame", {
		Name = "Gem",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x + 5, y + 13),
		Size = UDim2.fromOffset(9, 9),
		Rotation = 45,
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		Parent = parent,
	})
	Theme.edge(gem, 1.5)
	Theme.label(parent, text, Theme.Title, 19, {
		Position = UDim2.fromOffset(x + 16, y),
		Size = UDim2.fromOffset(width - 16, 26),
		TextStrokeColor3 = Theme.Ink,
		TextStrokeTransparency = 0.4,
	})
end

-- A labelled slider. read/write use the shown number; step rounds it.
-- The page a control sits on, so its liquid only runs while it can be seen.
local function pageOf(item: Instance): Instance
	local at = item
	while at.Parent and at.Parent ~= panel do
		at = at.Parent :: Instance
	end
	return at
end

local dragging: ((number) -> ())? = nil
local dragEnded: (() -> ())? = nil
local function slider(
	parent: Instance,
	accent: Color3,
	x: number,
	y: number,
	width: number,
	title_: string,
	low: number,
	high: number,
	step: number,
	read: () -> number,
	write: (number) -> (),
	format: (number) -> string
): () -> ()
	heading(parent, title_, accent, x, y, width - 80)
	local value = Theme.label(parent, "", Theme.TitleBold, 21, {
		Position = UDim2.fromOffset(x + width - 80, y),
		Size = UDim2.fromOffset(80, 26),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = accent,
		TextStrokeColor3 = Theme.Ink,
		TextStrokeTransparency = 0.4,
	})
	local valueScale = Theme.new("UIScale", { Parent = value })
	-- The same slime as the health bar, without drips (owner, 2026-11-02). The knob marks the value and the
	-- liquid swashes after it.
	local pageFrame = pageOf(parent) :: GuiObject
	local goo =
		GooBar.new(parent, Vector2.new(x, y + SLIDER_Y), width - SLIDER_INK * 2, SLIDER_LIQUID, {
			col = SLIDER_COL,
			colour = accent,
			empty = Fx.Blank,
			drips = false,
			lost = false,
			dragged = true,
			behindMark = true,
			active = function(): boolean
				return holder.Visible and pageFrame.Visible
			end,
		})
	-- An invisible track over the liquid takes the mouse and carries the knob.
	local track = Theme.button(parent, "", Theme.Body, 1, {
		Name = `{title_}Slider`,
		Position = UDim2.fromOffset(x + SLIDER_INK, y + SLIDER_Y),
		Size = UDim2.fromOffset(width - SLIDER_INK * 2, SLIDER_LIQUID + SLIDER_INK * 2),
		BackgroundTransparency = 1,
		ZIndex = 6,
	})
	local knobGlow = Fx.glow(track, accent, 1)
	knobGlow.AnchorPoint = Vector2.new(0.5, 0.5)
	knobGlow.Size = UDim2.fromOffset(60, 60)
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
	Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = accent,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = knob,
	})
	Theme.corner(knob:FindFirstChildOfClass("Frame") :: Instance, 5)
	local hovering, held = false, false
	local function refreshKnob()
		local big = held or hovering
		Fx.tween(
			knobScale,
			0.18,
			{ Scale = if held then 1.3 elseif big then 1.15 else 1 },
			Enum.EasingStyle.Back
		)
		Fx.tween(
			knobGlow,
			0.18,
			{ ImageTransparency = if held then 0.3 elseif big then 0.55 else 1 }
		)
		Fx.tween(knobEdge, 0.15, { Color = if big then accent else Theme.Ink })
	end
	local function refresh()
		local current_ = read()
		local share = math.clamp((current_ - low) / (high - low), 0, 1)
		goo.set(share)
		knob.Position = UDim2.fromScale(share, 0.5)
		knobGlow.Position = knob.Position
		value.Text = format(current_)
	end
	local function slide(mouseX: number)
		local share = math.clamp((mouseX - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		local before = read()
		write(math.round((low + share * (high - low)) / step) * step)
		refresh()
		if read() ~= before then
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
	local ended = dragEnded
	dragEnded = nil
	if ended then
		ended()
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

local function attributeSlider(
	parent: Instance,
	accent: Color3,
	x: number,
	y: number,
	width: number,
	title_: string,
	attribute: string,
	low: number,
	high: number
)
	local refresh = slider(parent, accent, x, y, width, title_, low, high, 1, function()
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
local TEAL = Fx.Accents.Controls
local SPRINT_TEXT: { [string]: string } = {
	Toggle = "Press Sprint once to start, and again to stop.",
	Always = "You always sprint. No key needed.",
	Hold = "You sprint only while you hold Sprint.",
}
local sprintGroup = Theme.new("Frame", {
	Name = "SprintGroup",
	Size = UDim2.new(1, 0, 0, 90),
	BackgroundTransparency = 1,
	Parent = controls,
})
local sprintBox = Fx.card(sprintGroup, { Name = "Sprint", Size = UDim2.new(1, 0, 0, 86) }, 12)
heading(sprintBox, "Sprint", TEAL, 14, 6, 200)
attributeChoice(sprintBox, TEAL, 14, 36, 300, 38, "SprintMode", {
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
	ZIndex = 2,
})
Fx.chunky(doubleTap, { accent = TEAL, radius = 10, idle = Fx.Blank, grow = 4 })
local doubleMark = Theme.label(doubleTap, "", Theme.Body, 15, {
	Position = UDim2.new(0, 10, 0.5, -12),
	Size = UDim2.fromOffset(24, 24),
	TextXAlignment = Enum.TextXAlignment.Center,
	TextColor3 = Theme.OnAccent,
	BackgroundTransparency = 0,
})
Theme.corner(doubleMark, 6)
Theme.edge(doubleMark, 2)
Theme.label(doubleTap, "Double-tap W, A, S or D to sprint that way", Theme.Body, 13, {
	Position = UDim2.fromOffset(44, 0),
	Size = UDim2.new(1, -52, 1, 0),
	TextWrapped = true,
})
local doubleOn = player:GetAttribute("SprintDoubleTap") ~= false
local function refreshSprint()
	local mode = (player:GetAttribute("SprintMode") :: string?) or "Toggle"
	sprintText.Text = SPRINT_TEXT[mode] or ""
	local on = player:GetAttribute("SprintDoubleTap") ~= false
	doubleMark.Text = if on then "✓" else ""
	Fx.tween(doubleMark, 0.12, { BackgroundColor3 = if on then TEAL else Fx.Blank })
	if on ~= doubleOn then
		doubleOn = on
		if on then
			Fx.sparkle(gui, doubleMark, TEAL, 5)
		end
	end
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
	TextColor3 = TEAL,
})
local function say(text: string)
	note.Text = text
	note.TextTransparency = 1
	Fx.tween(note, 0.2, { TextTransparency = 0 })
end

-- The prompt shown while waiting for a key.
local prompt = Theme.new("TextButton", {
	Name = "BindPrompt",
	AutoButtonColor = false,
	Text = "",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(8, 8, 22),
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
type Ring = { frame: Frame, stroke: UIStroke }
local rings: { Ring } = {}
for index = 1, 2 do
	local frame = Theme.new("Frame", {
		Name = `Ring{index}`,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundTransparency = 1,
		ZIndex = 21,
		Parent = prompt,
	})
	Theme.corner(frame, 400)
	table.insert(rings, { frame = frame, stroke = Theme.edge(frame, 4, TEAL) })
end
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
		TextStrokeColor3 = Theme.Ink,
		TextStrokeTransparency = 0.3,
		ZIndex = 22,
	})
end
local promptTitle = promptLine("Press a key or mouse button", Theme.TitleBold, 42, 0, 56, TEAL)
local promptFor = promptLine("", Theme.Title, 24, 58, 34, Theme.Text)
promptLine(
	"Backspace clears it. Cancels by itself in 5 seconds. For side buttons, set them to F13 and F14 in your mouse's app first.",
	Theme.Body,
	15,
	100,
	44,
	Theme.Soft
)
local promptTitleScale = Theme.new("UIScale", { Parent = promptTitle })

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
local function animatePrompt(token: number)
	promptTitleScale.Scale = 0.8
	Fx.tween(promptTitleScale, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
	task.spawn(function()
		local beat = 0
		while token == captureToken do
			local ring = rings[beat % 2 + 1]
			ring.frame.Size = UDim2.fromOffset(120, 120)
			ring.stroke.Transparency = 0.1
			Fx.tween(ring.frame, 1.3, { Size = UDim2.fromOffset(900, 900) })
			Fx.tween(ring.stroke, 1.3, { Transparency = 1 })
			beat += 1
			task.wait(0.65)
		end
	end)
end
local function beginCapture(action: string, label: string, slot: number, chip: TextButton)
	endPrompt()
	note.Text = ""
	promptFor.Text = `for {label}`
	prompt.Visible = true
	captureToken += 1
	local token = captureToken
	animatePrompt(token)
	cancelCapture = Keybinds.capture(function(input: string?)
		cancelCapture = nil
		captureEnded = os.clock()
		prompt.Visible = false
		captureToken += 1
		local displaced = Keybinds.set(action, slot, input)
		Fx.sound("select")
		if input then
			Fx.sparkle(gui, chip, TEAL, 9)
		end
		if displaced then
			say(`{Keybinds.label(input)} was on {displaced}, so {displaced} lost it.`)
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

local CHIP_W, ROW_H = 88, 40
local COLUMN_W = (CONTENT_W - 44) / 3
local COLUMN_Y = 102
for index, group in Keybinds.Groups do
	local column = Theme.new("Frame", {
		Name = group.name,
		Position = UDim2.fromOffset((index - 1) * (COLUMN_W + 22), COLUMN_Y),
		Size = UDim2.fromOffset(COLUMN_W, 28 + #group.rows * ROW_H),
		BackgroundTransparency = 1,
		Parent = controls,
	})
	heading(column, group.name, TEAL, 0, 0, 120)
	for slot, title_ in { "Main", "Second" } do
		Theme.label(column, title_, Theme.Body, 11, {
			Position = UDim2.new(1, -(3 - slot) * (CHIP_W + 10) + 10, 0, 0),
			Size = UDim2.fromOffset(CHIP_W, 28),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Theme.Muted,
		})
	end
	for rowIndex, row in group.rows do
		local y = 28 + (rowIndex - 1) * ROW_H
		local rowLabel = Theme.label(column, row.label, Theme.Body, 14, {
			Position = UDim2.fromOffset(0, y + 2),
			Size = UDim2.fromOffset(COLUMN_W - 2 * (CHIP_W + 10), ROW_H - 2),
			ZIndex = 2,
		})
		local chips: { Fx.Control } = {}
		for slot = 1, 2 do
			local chip = Theme.button(column, "", Theme.Body, 12, {
				Name = `{row.id}{slot}`,
				Position = UDim2.new(1, -(3 - slot) * (CHIP_W + 10) + 10, 0, y + 4),
				Size = UDim2.fromOffset(CHIP_W, 30),
				ZIndex = 3,
			})
			local control = Fx.chunky(chip, { accent = TEAL, radius = 8 })
			local icon = mouseIcon(chip)
			chip.Activated:Connect(function()
				-- The click that answered a prompt must not land on a chip and open the next one.
				if os.clock() - captureEnded > REPRESS_GUARD then
					beginCapture(row.id, row.label, slot, chip)
				end
			end)
			chips[slot] = control
			table.insert(refreshers, function()
				local input = Keybinds.get(row.id, slot)
				chip.Text = if input then Keybinds.label(input) else "Add"
				control.setIdle(
					if input then Fx.Button else Fx.Blank,
					if input then Theme.Text else Theme.Muted
				)
				icon.Visible = Keybinds.isMouseLabel(input)
			end)
		end
		if row.id == "sprint" then
			-- Always on needs no key.
			local function dim_()
				local off = player:GetAttribute("SprintMode") == "Always"
				rowLabel.TextTransparency = if off then 0.55 else 0
				for _, control in chips do
					control.setDim(off)
				end
			end
			player:GetAttributeChangedSignal("SprintMode"):Connect(dim_)
			dim_()
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

-- Gameplay ---------------------------------------------------------------------------
local gameplay = pages.Gameplay
local LIME = Fx.Accents.Gameplay
local COLUMN = (CONTENT_W - 36) / 2
local function gameplayColumn(x: number): Frame
	return Theme.new("Frame", {
		Position = UDim2.fromOffset(x, 0),
		Size = UDim2.new(0, COLUMN, 1, 0),
		BackgroundTransparency = 1,
		Parent = gameplay,
	})
end
local leftColumn, rightColumn = gameplayColumn(0), gameplayColumn(COLUMN + 36)
attributeSlider(leftColumn, LIME, 0, 8, COLUMN, "Field of view", "FieldOfView", 60, 110)
attributeSlider(leftColumn, LIME, 0, 90, COLUMN, "Look sensitivity", "LookSensitivity", 1, 100)
attributeSlider(leftColumn, LIME, 0, 172, COLUMN, "Aim sensitivity", "AimSensitivity", 1, 100)

heading(leftColumn, "Health number", LIME, 0, 256, COLUMN)
attributeChoice(leftColumn, LIME, 0, 288, COLUMN, 44, "HealthNumber", {
	{ label = "Always", value = "Always" },
	{ label = "On change", value = "On change" },
	{ label = "Off", value = "Off" },
})

heading(rightColumn, "Holstered blaster", LIME, 0, 8, COLUMN)
attributeChoice(rightColumn, LIME, 0, 40, COLUMN, 44, "HolsterMode", {
	{ label = "On hip", value = "Hip" },
	{ label = "Disappears", value = "Vanish" },
})

heading(rightColumn, "Flip camera", LIME, 0, 106, COLUMN)
local flipOptions: { Option } = {}
for index, option in flipCamera.Options do
	table.insert(flipOptions, { label = option.name, value = index })
end
local flipDetail = Theme.label(rightColumn, "", Theme.Body, 13, {
	Name = "FlipCameraDescription",
	Position = UDim2.fromOffset(0, 190),
	Size = UDim2.fromOffset(COLUMN, 36),
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextColor3 = Theme.Soft,
})
local refreshFlipChoice = choice(rightColumn, LIME, 0, 138, COLUMN, 44, flipOptions, function()
	local _, requested = flipCamera.status()
	return requested
end, function(index)
	player:SetAttribute("FlipCamera", index)
end)
local function refreshFlip()
	local selected, requested = flipCamera.status()
	refreshFlipChoice()
	flipDetail.Text = if selected ~= requested
		then `{flipCamera.Options[requested].name} will apply after this flip.`
		else flipCamera.Options[selected].description
end
refreshFlip()

heading(rightColumn, "Recoil animation", LIME, 0, 228, COLUMN)
local refreshRecoil = choice(rightColumn, LIME, 0, 260, COLUMN, 44, {
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
local LILAC = Fx.Accents.Crosshair
local PREVIEW_W = 340
local previewColumn = Theme.new("Frame", {
	Size = UDim2.new(0, PREVIEW_W, 1, 0),
	BackgroundTransparency = 1,
	Parent = appearance,
})
local plate = Fx.card(previewColumn, {
	Name = "Preview",
	Size = UDim2.fromOffset(PREVIEW_W, PREVIEW_W),
	BackgroundColor3 = Color3.fromRGB(62, 72, 104),
	ClipsDescendants = true,
}, 12)
local plateGlow = Fx.glow(plate, Color3.new(1, 1, 1), 1)
plateGlow.AnchorPoint = Vector2.new(0.5, 0.5)
plateGlow.Position = UDim2.fromScale(0.5, 0.5)
plateGlow.Size = UDim2.fromScale(0.9, 0.9)
plateGlow.ImageTransparency = 0.72
for _, size in { UDim2.new(0, 1, 1, 0), UDim2.new(1, 0, 0, 1) } do
	Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		BackgroundColor3 = Theme.Text,
		BackgroundTransparency = 0.78,
		BorderSizePixel = 0,
		ZIndex = 2,
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
		ZIndex = 3,
		Parent = parent,
	})
end
local livePreview = mark(plate, "LivePreview")
local previewPop = Theme.new("UIScale", { Parent = livePreview })

local refreshSize = slider(
	previewColumn,
	LILAC,
	0,
	354,
	PREVIEW_W,
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
local styleColumn = Theme.new("Frame", {
	Position = UDim2.fromOffset(STYLE_X, 0),
	Size = UDim2.new(0, STYLE_W, 1, 0),
	BackgroundTransparency = 1,
	Parent = appearance,
})
heading(styleColumn, "Style", LILAC, 0, 0, 200)
local styleDetail = Theme.label(styleColumn, "", Theme.Body, 14, {
	Position = UDim2.fromOffset(0, 240),
	Size = UDim2.fromOffset(STYLE_W, 22),
	TextColor3 = Theme.Soft,
})
heading(styleColumn, "Colour", LILAC, 0, 272, 200)
type Tile = { control: Fx.Control, mark: Frame, id: string }
local tiles: { Tile } = {}
local TILE_W = (STYLE_W - 30) / 4
for index, entry in crosshairs.Presets do
	local button = Theme.button(styleColumn, "", Theme.Body, 13, {
		Name = `CrosshairStyle{entry.id}`,
		Position = UDim2.fromOffset(
			((index - 1) % 4) * (TILE_W + 10),
			32 + math.floor((index - 1) / 4) * 102
		),
		Size = UDim2.fromOffset(TILE_W, 92),
		ZIndex = 2,
	})
	local control = Fx.chunky(button, {
		accent = LILAC,
		radius = 10,
		idle = Fx.Blank,
		selectedFill = Fx.Button,
		selectedText = Theme.Text,
		grow = 6,
	})
	Theme.label(button, entry.label, Theme.Body, 13, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -4),
		Size = UDim2.new(1, 0, 0, 20),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local holder_ = mark(button, "Mark")
	holder_.Position = UDim2.new(0.5, 0, 0, 36)
	button.Activated:Connect(function()
		if player:GetAttribute("CrosshairStyle") ~= entry.id then
			Fx.sound("select")
			Fx.sparkle(gui, button, LILAC)
		end
		player:SetAttribute("CrosshairStyle", entry.id)
	end)
	table.insert(tiles, { control = control, mark = holder_, id = entry.id })
end
type Swatch = { control: Fx.Control, color: Color3 }
local swatches: { Swatch } = {}
for index, entry in crosshairs.Colors do
	local button = Theme.button(styleColumn, "", Theme.Body, 12, {
		Name = `CrosshairColor{entry.label}`,
		Position = UDim2.fromOffset((index - 1) * 54, 304),
		Size = UDim2.fromOffset(44, 44),
		ZIndex = 2,
	})
	local control = Fx.chunky(button, {
		accent = Color3.new(1, 1, 1),
		radius = 10,
		idle = entry.color,
		selectedFill = entry.color,
		grow = 5,
	})
	button.Activated:Connect(function()
		if crosshairs.color(player:GetAttribute("CrosshairColor")) ~= entry.color then
			Fx.sound("select")
			Fx.sparkle(gui, button, entry.color)
		end
		player:SetAttribute("CrosshairColor", entry.color)
	end)
	table.insert(swatches, { control = control, color = entry.color })
end
Theme.label(styleColumn, "Hex", Theme.Body, 13, {
	Position = UDim2.fromOffset(0, 362),
	Size = UDim2.fromOffset(34, 38),
	TextColor3 = Theme.Soft,
})
local hex = Theme.new("TextBox", {
	Name = "CrosshairHex",
	Position = UDim2.fromOffset(36, 362),
	Size = UDim2.fromOffset(104, 38),
	BackgroundColor3 = Fx.Blank,
	BorderSizePixel = 0,
	TextColor3 = Theme.Text,
	FontFace = Theme.Body,
	TextSize = 14,
	ClearTextOnFocus = false,
	PlaceholderText = "#RRGGBB",
	Parent = styleColumn,
})
Theme.corner(hex, 8)
local hexEdge = Theme.edge(hex, 2)
hex.Focused:Connect(function()
	Fx.tween(hexEdge, 0.15, { Color = LILAC })
end)
local hexNote = Theme.label(styleColumn, "", Theme.Body, 13, {
	Position = UDim2.fromOffset(152, 362),
	Size = UDim2.fromOffset(STYLE_W - 152, 38),
	TextColor3 = Theme.Soft,
})
hex.FocusLost:Connect(function()
	Fx.tween(hexEdge, 0.15, { Color = Theme.Ink })
	local value = hex.Text:gsub("%s", ""):gsub("^#", "")
	if #value == 6 and value:match("^%x+$") then
		hexNote.Text = ""
		player:SetAttribute("CrosshairColor", Color3.fromHex(value))
	else
		hexNote.Text = "Use six hex digits, e.g. #86F0C1"
	end
end)

local shownStyle, shownColor: any = "", nil
local function refreshAppearance()
	local preset = crosshairs.find(player:GetAttribute("CrosshairStyle"))
	local color = crosshairs.color(player:GetAttribute("CrosshairColor"))
	local size = crosshairs.size(player:GetAttribute("CrosshairSize"))
	crosshairs.draw(livePreview, preset.id, color)
	crosshairs.resize(livePreview, size * PREVIEW_ZOOM)
	plateGlow.ImageColor3 = color
	styleDetail.Text = preset.description
	-- A change bounces in place. The mark's centre never moves, only its scale.
	if shownStyle ~= preset.id or shownColor ~= color then
		if shownStyle ~= "" then
			previewPop.Scale = 1.22
			Fx.tween(previewPop, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		for _, tile in tiles do
			crosshairs.draw(tile.mark, tile.id, color)
			crosshairs.resize(tile.mark, TILE_ZOOM)
		end
	end
	shownStyle, shownColor = preset.id, color
	for _, tile in tiles do
		tile.control.set(tile.id == preset.id)
	end
	for _, swatch in swatches do
		swatch.control.set(swatch.color == color)
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
	player:SetAttribute("FlipCamera", DEFAULTS.FlipCamera)
	say("Everything is back to its default.")
	Fx.sound("select")
	Fx.sparkle(gui, reset, Fx.Coral, 10)
end)

-- Opening ----------------------------------------------------------------------------
local openToken = 0
local isOpen = false
local function refreshOpen()
	local open = player:GetAttribute("PvpMenu") == "Settings"
	opener.Visible = player:GetAttribute("PvpMenu") == nil
	if open == isOpen then
		return
	end
	isOpen = open
	openToken += 1
	local token = openToken
	if open then
		holder.Visible = true
		dim.Visible = true
		blur.Enabled = true
		twinkles.setActive(true)
		SlugIcon.setActive(slug, true)
		pop.Scale = 0.86
		Fx.tween(pop, 0.32, { Scale = 1 }, Enum.EasingStyle.Back)
		Fx.tween(dim, 0.2, { BackgroundTransparency = 0.45 })
		Fx.tween(blur, 0.2, { Size = OPEN_BLUR })
		Fx.cascade(pages[current])
		Fx.sound("select")
	else
		endPrompt()
		endDrag()
		Fx.tween(pop, 0.12, { Scale = 0.93 })
		Fx.tween(dim, 0.14, { BackgroundTransparency = 1 })
		Fx.tween(blur, 0.14, { Size = 0 })
		task.delay(0.13, function()
			if token == openToken then
				holder.Visible = false
				dim.Visible = false
				blur.Enabled = false
				twinkles.setActive(false)
				SlugIcon.setActive(slug, false)
			end
		end)
	end
end
player:GetAttributeChangedSignal("PvpMenu"):Connect(refreshOpen)
opener.Activated:Connect(function()
	Fx.sound("click")
	Theme.setMenu("Settings")
end)
close.Activated:Connect(function()
	Fx.sound("click")
	Theme.setMenu(nil)
end)
Keybinds.on("settings", function(pressed: boolean)
	if pressed then
		Theme.toggleMenu("Settings")
	end
end)
showPage("Controls", false)
refreshOpen()
gui.Parent = player:WaitForChild("PlayerGui")

local gooClock = 0
local gooNextLap = 0.5
RunService:BindToRenderStep(
	"SlugshotSettingsCursor",
	Enum.RenderPriority.Camera.Value + 20,
	function(dt: number)
		-- Shift lock relocks the cursor every frame; keep it free while a menu is open.
		if player:GetAttribute("PvpMenu") ~= nil then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		if holder.Visible then
			refreshFlip()
			gooClock += dt
			Goo.settle(gooRipples, dt, BAND_TENSION, BAND_RESTORE, BAND_DAMPING)
			gooNextLap -= dt
			if gooNextLap <= 0 then
				gooNextLap = 0.5 + math.random() * 1.2
				Goo.push(gooRipples, math.random(), (math.random() - 0.5) * 0.5, 3)
			end
			local function height(across: number): number
				local share = across / PANEL_W
				return math.clamp(
					Goo.sample(gooRipples, share)
						+ BAND_SWELL
							* math.sin(2 * math.pi * BAND_SWELL_RATE * gooClock + share * 11),
					-7,
					7
				)
			end
			local frontScroll = gooClock * BAND_FRONT_SCROLL
			Goo.pose(gooBack, gooClock * BAND_BACK_SCROLL, function(across: number): number
				return -height(across) * 0.6 + 1
			end)
			Goo.pose(gooFront, frontScroll, height)
			Goo.pose(gooShine, frontScroll, height)
			if gooShown ~= gooColour then
				local previous = gooShown or gooColour
				local next_ = previous:Lerp(gooColour, 1 - math.exp(-9 * dt))
				if math.abs(next_.R - gooColour.R) + math.abs(next_.G - gooColour.G) < 0.004 then
					next_ = gooColour
				end
				gooShown = next_
				Goo.tint(gooFront, next_)
				Goo.tint(gooBack, Color3.new(next_.R * 0.68, next_.G * 0.68, next_.B * 0.68))
			end
			for _, entry in hanging do
				-- Each drip rides the edge above it, wave and all, so it always grows out of the goo.
				local across = entry.at * PANEL_W
				local shift = height(across)
					+ Goo.waveAt(Goo.Band, (frontScroll + across) % Goo.Band.period)
				entry.drip.step(dt, shift, true, gooShown or gooColour)
			end
			-- Crystals breathe light slowly; never a flicker (style guide).
			for _, cluster in crystals do
				local level = 0.5 + 0.5 * math.sin(gooClock * 1.1 + cluster.phase)
				cluster.light.breathe(level)
			end
		end
	end
)

if RunService:IsStudio() then
	-- For the UI check place: switch tabs without a mouse.
	player:GetAttributeChangedSignal("SettingsTestPage"):Connect(function()
		local name = player:GetAttribute("SettingsTestPage")
		if typeof(name) == "string" and pages[name] then
			showPage(name, true)
		end
	end)
end

-- The Roblox menu takes the keyboard, so an open key prompt gives way to it.
GuiService.MenuOpened:Connect(endPrompt)
