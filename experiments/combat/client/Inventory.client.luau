--!strict
-- The inventory (owner, 2026-11-02): small, opened with E, expanding up out of the slug bar. The bar below it is
-- the loadout, so this only shows every slug found so far and details for the selected one, and the game stays
-- in view around it. Choosing which slug sits in which slot comes with the second slug.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Combat = require(ReplicatedStorage:WaitForChild("Combat"))
local Theme = require(script.Parent.PvpTheme)
local Fx = require(script.Parent.PvpFx)
local SlugIcon = require(script.Parent.SlugIcon)

local player = Players.LocalPlayer
local movement = player:WaitForChild("PlayerScripts"):WaitForChild("MovementSandbox")
local Keybinds = (require :: any)(movement:WaitForChild("Keybinds"))

local HEIGHT, PAD, GAP, COLUMNS = 244, 16, 8, 7
local TILE_H = 50
local OPEN_TIME, CLOSE_TIME = 0.3, 0.13
local TILE_STAGGER = 0.018

local bar =
	player:WaitForChild("PlayerGui"):WaitForChild("CombatHUD"):WaitForChild("SlugBar") :: Frame
local width = bar.Size.X.Offset

-- A child of the slug bar, so it shares its scale and always sits right on top of it.
local panel = Theme.new("Frame", {
	Name = "Inventory",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0, -9),
	Size = UDim2.fromOffset(width, 0),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Visible = false,
	ZIndex = 20,
	Parent = bar,
})
Theme.corner(panel, 17)
Theme.edge(panel, 3)
Theme.new("UIGradient", {
	Color = ColorSequence.new(Fx.PanelTop, Fx.PanelBottom),
	Rotation = 90,
	Parent = panel,
})
local content = Theme.new("Frame", {
	Name = "Content",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.fromOffset(width, HEIGHT),
	BackgroundTransparency = 1,
	Parent = panel,
})

-- Every slug the player has, then one "?" for each still to find.
local found: { string } = {}
for id in Combat.Slugs do
	table.insert(found, id)
end
table.sort(found)

Theme.label(content, "Slugs", Theme.TitleBold, 22, {
	Position = UDim2.fromOffset(PAD, 8),
	Size = UDim2.fromOffset(70, 28),
	TextColor3 = Theme.Accent,
	TextStrokeColor3 = Theme.Ink,
	TextStrokeTransparency = 0.4,
})
Theme.label(content, `{#found} of {Combat.SlugTotal} found`, Theme.Body, 13, {
	Position = UDim2.fromOffset(PAD + 66, 8),
	Size = UDim2.fromOffset(160, 28),
	TextColor3 = Theme.Soft,
})
-- Modal frees the cursor while the menu is open (first person locks it).
local close = Theme.button(content, "×", Theme.Body, 20, {
	Name = "Close",
	Modal = true,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(1, -24, 0, 22),
	Size = UDim2.fromOffset(28, 28),
	BackgroundColor3 = Fx.Button,
	ZIndex = 2,
})
Theme.corner(close, 8)
Theme.edge(close, 2)
close.MouseEnter:Connect(function()
	Fx.sound("hover")
	Fx.tween(close, 0.25, { Rotation = 90, BackgroundColor3 = Fx.Coral }, Enum.EasingStyle.Back)
end)
close.MouseLeave:Connect(function()
	Fx.tween(close, 0.25, { Rotation = 0, BackgroundColor3 = Fx.Button }, Enum.EasingStyle.Back)
end)

local tileW = (width - PAD * 2 - GAP * (COLUMNS - 1)) / COLUMNS
local GRID_Y = 42
type Pop = { scale: UIScale, index: number }
local pops: { Pop } = {}
local icons: { SlugIcon.Icon } = {}
for index = 1, Combat.SlugTotal do
	local slugId = found[index]
	local position = UDim2.fromOffset(
		PAD + ((index - 1) % COLUMNS) * (tileW + GAP),
		GRID_Y + math.floor((index - 1) / COLUMNS) * (TILE_H + GAP)
	)
	local holder = Theme.new("Frame", {
		Name = `Tile{index}`,
		Position = position,
		Size = UDim2.fromOffset(tileW, TILE_H),
		BackgroundTransparency = 1,
		Parent = content,
	})
	table.insert(pops, { scale = Theme.new("UIScale", { Parent = holder }), index = index })
	if slugId then
		local tile = Theme.button(holder, "", Theme.Body, 1, {
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
		})
		local control = Fx.chunky(tile, {
			accent = Theme.Accent,
			radius = 10,
			idle = Fx.Button,
			selectedFill = Fx.Button,
			selectedText = Theme.Text,
			grow = 4,
		})
		control.set(index == 1) -- only one slug to select so far
		table.insert(icons, SlugIcon.mount(tile, slugId, 0.8, false))
	else
		local tile = Theme.new("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Fx.Blank,
			BorderSizePixel = 0,
			Parent = holder,
		})
		Theme.corner(tile, 10)
		Theme.edge(tile, 2)
		Theme.label(tile, "?", Theme.Title, 20, {
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Theme.Muted,
		})
	end
end

-- Details of the selected slug. Floppy is the only one so far.
local slugId = found[1]
local slug = Combat.Slugs[slugId]
local DETAIL_Y = GRID_Y + 2 * TILE_H + GAP + 12
local detail = Fx.card(content, {
	Name = "Detail",
	Position = UDim2.fromOffset(PAD, DETAIL_Y),
	Size = UDim2.fromOffset(width - PAD * 2, HEIGHT - DETAIL_Y - 14),
}, 12)
local view = Theme.new("Frame", {
	Name = "View",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 6, 1, 0),
	Size = UDim2.fromOffset(64, 64),
	BackgroundTransparency = 1,
	Parent = detail,
})
local viewIcon = SlugIcon.mount(view, slugId, 0.86, true, 0.04, 1.4)
table.insert(icons, viewIcon)
Theme.label(detail, slug.Label, Theme.TitleBold, 21, {
	Position = UDim2.fromOffset(76, 6),
	Size = UDim2.fromOffset(150, 26),
	TextStrokeColor3 = Theme.Ink,
	TextStrokeTransparency = 0.5,
})
Theme.label(detail, slug.Blurb, Theme.Body, 12, {
	Position = UDim2.fromOffset(76, 32),
	Size = UDim2.fromOffset(160, 34),
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextColor3 = Theme.Soft,
})
local function stat(y: number, title: string, value: string)
	Theme.label(detail, title, Theme.Body, 12, {
		Position = UDim2.new(1, -136, 0, y),
		Size = UDim2.fromOffset(90, 20),
		TextColor3 = Theme.Soft,
	})
	Theme.label(detail, value, Theme.Body, 13, {
		Position = UDim2.new(1, -56, 0, y),
		Size = UDim2.fromOffset(46, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
end
stat(5, "Damage", tostring(slug.Damage))
stat(24, "Ready in", `{Combat.Cooldown} s`)
stat(43, "Carried", "Slot 1")

local open = false
local token = 0
local function refreshOpen()
	local want = player:GetAttribute("PvpMenu") == "Inventory"
	if want == open then
		return
	end
	open = want
	token += 1
	local mine = token
	for _, icon in icons do
		SlugIcon.setActive(icon, open)
	end
	if open then
		panel.Visible = true
		panel.Size = UDim2.fromOffset(width, 0)
		Fx.tween(
			panel,
			OPEN_TIME,
			{ Size = UDim2.fromOffset(width, HEIGHT) },
			Enum.EasingStyle.Back
		)
		Fx.sound("select")
		-- The tiles pop in across and up, following the panel out.
		for _, pop in pops do
			pop.scale.Scale = 0.4
			Fx.tween(
				pop.scale,
				0.22,
				{ Scale = 1 },
				Enum.EasingStyle.Back,
				0.06 + pop.index * TILE_STAGGER
			)
		end
	else
		Fx.tween(panel, CLOSE_TIME, { Size = UDim2.fromOffset(width, 0) })
		task.delay(CLOSE_TIME, function()
			if mine == token then
				panel.Visible = false
			end
		end)
	end
end
player:GetAttributeChangedSignal("PvpMenu"):Connect(refreshOpen)
close.Activated:Connect(function()
	Fx.sound("click")
	Theme.setMenu(nil)
end)
Keybinds.on("inventory", function(pressed: boolean)
	if pressed then
		Theme.toggleMenu("Inventory")
	end
end)
for _, icon in icons do
	SlugIcon.setActive(icon, false)
end
refreshOpen()
