--!strict
-- F opens the inventory above the persistent canisters in lobby and training.
-- Browse the slugs available in this build and swap them in and out of the five carried slots (owner, 2026-11-16: "this
-- is what the inventory is for, make it so you can swap out the slugs in your HUD bar using inventory"): pick a slug,
-- then a slot. PvP's future pre-match loadout draft is separate.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Combat = require(ReplicatedStorage:WaitForChild("Combat"))
local Theme = require(script.Parent.PvpTheme)
local Fx = require(script.Parent.PvpFx)
local SlugIcon = require(script.Parent.SlugIcon)
local remote = ReplicatedStorage:WaitForChild("SlugshotCombat") :: RemoteEvent

local player = Players.LocalPlayer
local movement = player:WaitForChild("PlayerScripts"):WaitForChild("MovementSandbox")
local Keybinds = (require :: any)(movement:WaitForChild("Keybinds"))

local HEIGHT, PAD, GAP, COLUMNS = 288, 16, 8, 7
local DETAIL_H, SLOT_H = 68, 36 -- the slug's details, then the row of carried slots under them
local TILE_H = 50
local OPEN_TIME, CLOSE_TIME = 0.3, 0.13
local TILE_STAGGER = 0.018

local bar =
	player:WaitForChild("PlayerGui"):WaitForChild("CombatHUD"):WaitForChild("SlugBar") :: Frame
-- Its own width, which the canister row had before the canisters slimmed (owner, 2026-11-15), so the tiles keep their size.
local width = 398

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

-- Available in this build, not an ownership claim: acquisition is not implemented.
local found: { string } = {}
for _, id in ipairs(Combat.Roster) do
	if not table.find(found, id) then
		table.insert(found, id)
	end
end

Theme.label(content, "Slugs", Theme.TitleBold, 22, {
	Position = UDim2.fromOffset(PAD, 8),
	Size = UDim2.fromOffset(70, 28),
	TextColor3 = Theme.Accent,
	TextStrokeColor3 = Theme.Ink,
	TextStrokeTransparency = 0.4,
})
Theme.label(content, `{#found} available`, Theme.Body, 13, {
	Position = UDim2.fromOffset(PAD + 66, 8),
	Size = UDim2.fromOffset(160, 28),
	TextColor3 = Theme.Soft,
})
-- Modal frees the cursor while the menu is open (first person locks it).
local close = Theme.button(content, utf8.char(0x00D7), Theme.Body, 20, {
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
local controls: { [string]: Fx.Control } = {}
local selected = found[1]
local selectDetail: (string) -> () = function() end
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
			Name = slugId,
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
		controls[slugId] = control
		control.set(slugId == selected)
		tile.Activated:Connect(function()
			selectDetail(slugId)
		end)
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

-- Browsing updates details without changing the carried loadout or drawing the gun; the slot row below carries it.
local slugId = found[1]
local slug = Combat.Slugs[slugId]
local DETAIL_Y = GRID_Y + 2 * TILE_H + GAP + 12
local detail = Fx.card(content, {
	Name = "Detail",
	Position = UDim2.fromOffset(PAD, DETAIL_Y),
	Size = UDim2.fromOffset(width - PAD * 2, DETAIL_H),
}, 12)
local view = Theme.new("Frame", {
	Name = "View",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 6, 1, 0),
	Size = UDim2.fromOffset(64, 64),
	BackgroundTransparency = 1,
	Parent = detail,
})
local detailIcons: { [string]: SlugIcon.Icon } = {}
for _, id in found do
	local icon = SlugIcon.mount(view, id, 0.86, true, 0.04, 1.4)
	detailIcons[id] = icon
	icon.frame.Visible = id == selected
	SlugIcon.setActive(icon, false)
end
local slugName = Theme.label(detail, slug.Label, Theme.TitleBold, 21, {
	Name = "SlugName",
	Position = UDim2.fromOffset(76, 6),
	Size = UDim2.fromOffset(150, 26),
	TextStrokeColor3 = Theme.Ink,
	TextStrokeTransparency = 0.5,
})
local blurb = Theme.label(detail, slug.Blurb, Theme.Body, 12, {
	Position = UDim2.fromOffset(76, 32),
	Size = UDim2.fromOffset(width - PAD * 2 - 76 - 144, 34),
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	TextColor3 = Theme.Soft,
})
local function stat(y: number, title: string, value: string): TextLabel
	Theme.label(detail, title, Theme.Body, 12, {
		Position = UDim2.new(1, -136, 0, y),
		Size = UDim2.fromOffset(78, 20),
		TextColor3 = Theme.Soft,
	})
	return Theme.label(detail, value, Theme.Body, 13, {
		Position = UDim2.new(1, -56, 0, y),
		Size = UDim2.fromOffset(46, 20),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
end
local damage = stat(5, "Damage", tostring(slug.Damage))
stat(24, "Ready in", `{Combat.Cooldown} s`)
local carried = stat(43, "Carried", "Slot 1")

-- The carried slots: each shows the slug in it, the selected slug's own slot lit. Pressing one carries the selected
-- slug there; one already carried trades places with it. The server owns the loadout (CombatServer "Carry").
local SLOT_Y = DETAIL_Y + DETAIL_H + 6
local slotW = (width - PAD * 2 - GAP * (Combat.SlotCount - 1)) / Combat.SlotCount
local slotButtons: { TextButton } = {}
local slotControls: { Fx.Control } = {}
for slot = 1, Combat.SlotCount do
	local button = Theme.button(content, "", Theme.Body, 11, {
		Name = `Carry{slot}`,
		Position = UDim2.fromOffset(PAD + (slot - 1) * (slotW + GAP), SLOT_Y),
		Size = UDim2.fromOffset(slotW, SLOT_H),
		TextWrapped = true,
		ZIndex = 2,
	})
	slotButtons[slot] = button
	slotControls[slot] = Fx.chunky(button, {
		accent = Theme.Accent,
		radius = 8,
		idle = Fx.Button,
		selectedFill = Fx.Button,
		selectedText = Theme.Text,
		grow = 3,
	})
	button.Activated:Connect(function()
		if Combat.loadoutOf(player)[slot] ~= selected then
			Fx.sound("click")
			remote:FireServer("Carry", { slot = slot, slug = selected })
		end
	end)
end
local function refreshSlots()
	local loadout = Combat.loadoutOf(player)
	for slot, button in slotButtons do
		local id = loadout[slot]
		button.Text = `{slot}  {if id then Combat.Slugs[id].Label else "-"}`
		slotControls[slot].set(id == selected)
	end
	local slot = table.find(loadout, selected)
	carried.Text = if slot then `Slot {slot}` else "-"
end

local open = false
selectDetail = function(id: string)
	selected = id
	local info = Combat.Slugs[id]
	slugName.Text, blurb.Text, damage.Text = info.Label, info.Blurb, tostring(info.Damage)
	refreshSlots()
	for otherId, control in controls do
		control.set(otherId == id)
	end
	for otherId, icon in detailIcons do
		icon.frame.Visible = otherId == id
		SlugIcon.setActive(icon, open and otherId == id)
	end
end
selectDetail(selected)
player:GetAttributeChangedSignal("Loadout"):Connect(refreshSlots)
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
	for id, icon in detailIcons do
		SlugIcon.setActive(icon, open and id == selected)
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
-- Left of the health bar, level with it and as far from it as the health number is on its right (PvpHud).
local toggle = Theme.button(bar, "", Theme.Body, 14, {
	Name = "InventoryToggle",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.fromOffset(
		(bar:GetAttribute("HealthLeft") :: any or 0) - (bar:GetAttribute("HealthGap") :: any or 12),
		bar:GetAttribute("HealthMiddle") :: any or 14
	),
	Size = UDim2.fromOffset(36, 36),
	BackgroundColor3 = Fx.Button,
})
Fx.chunky(toggle, { radius = 10, grow = 2, accent = Theme.Accent })
Theme.new("ImageLabel", {
	Name = "Bag",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(0.94, 0.94),
	BackgroundTransparency = 1,
	Image = Fx.asset("iconInventory"),
	Parent = toggle,
})
local tip = Theme.label(toggle, "Inventory", Theme.Body, 13, {
	Name = "Tooltip",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 0, -7),
	Size = UDim2.fromOffset(110, 24),
	BackgroundColor3 = Theme.Panel,
	BackgroundTransparency = 0,
	TextXAlignment = Enum.TextXAlignment.Center,
	Visible = false,
})
Theme.corner(tip, 6)
Theme.edge(tip, 2)
toggle.MouseEnter:Connect(function()
	local key = Keybinds.label(Keybinds.get("inventory", 1))
	tip.Text = if key == "" then "Inventory" else `Inventory ({key})`
	tip.Visible = true
end)
toggle.MouseLeave:Connect(function()
	tip.Visible = false
end)
toggle.Activated:Connect(function()
	Theme.toggleMenu("Inventory")
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
