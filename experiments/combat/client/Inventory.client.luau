--!strict
-- The inventory (owner, 2026-11-01): the four carried slugs, every slug found so far and details for
-- the one selected. Choosing which slug sits in which slot comes with the second slug.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Combat = require(ReplicatedStorage:WaitForChild("Combat"))
local Theme = require(script.Parent.PvpTheme)
local SlugIcon = require(script.Parent.SlugIcon)

local player = Players.LocalPlayer
local movement = player:WaitForChild("PlayerScripts"):WaitForChild("MovementSandbox")
local Keybinds = (require :: any)(movement:WaitForChild("Keybinds"))

local PANEL_W, PANEL_H, HEAD_H, DETAIL_W = 1100, 620, 60, 320
local GRID_COLUMNS = 7

local gui = Instance.new("ScreenGui")
gui.Name = "Inventory"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10

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
Theme.label(head, "Inventory", Theme.TitleBold, 28, {
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

local LEFT_W = PANEL_W - DETAIL_W - 48
local left = Theme.new("Frame", {
	Name = "Slugs",
	Position = UDim2.fromOffset(24, HEAD_H + 18),
	Size = UDim2.fromOffset(LEFT_W, PANEL_H - HEAD_H - 36),
	BackgroundTransparency = 1,
	Parent = panel,
})
Theme.label(left, "Loadout", Theme.Title, 20, { Size = UDim2.fromOffset(300, 28) })

local icons: { SlugIcon.Icon } = {}
local SLOT_W = (LEFT_W - 3 * 10) / 4
for index = 1, Combat.SlotCount do
	local slugId = Combat.Loadout[index]
	local slot = Theme.new("Frame", {
		Name = `Slot{index}`,
		Position = UDim2.fromOffset((index - 1) * (SLOT_W + 10), 36),
		Size = UDim2.fromOffset(SLOT_W, 150),
		BackgroundColor3 = if slugId then Theme.Slot else Theme.Blank,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = left,
	})
	Theme.corner(slot, 14)
	Theme.edge(slot, if slugId then 3 else 2, if slugId then Theme.Accent else Theme.Ink)
	Theme.label(slot, tostring(index), Theme.Title, 15, {
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.fromOffset(24, 24),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = if slugId then Theme.OnAccent else Theme.Muted,
		BackgroundColor3 = Theme.Accent,
		BackgroundTransparency = if slugId then 0 else 1,
		ZIndex = 4,
	})
	if slugId then
		Theme.corner(slot:FindFirstChildOfClass("TextLabel") :: Instance, 7)
		-- Stands on the slug's name rather than behind it.
		table.insert(icons, SlugIcon.mount(slot, slugId, 0.74, false, 0.18))
		Theme.label(slot, Combat.Slugs[slugId].Label, Theme.Title, 16, {
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -3),
			Size = UDim2.new(1, 0, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 3,
		})
	else
		Theme.label(slot, "Empty", Theme.Body, 13, {
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Theme.Muted,
		})
	end
end

-- Every slug the player has, then one "?" for each still to find.
local found: { string } = {}
for id in Combat.Slugs do
	table.insert(found, id)
end
table.sort(found)
Theme.label(left, `Slugs found: {#found} of {Combat.SlugTotal}`, Theme.Title, 20, {
	Position = UDim2.fromOffset(0, 208),
	Size = UDim2.fromOffset(400, 28),
})
local TILE_W, TILE_H = (LEFT_W - (GRID_COLUMNS - 1) * 8) / GRID_COLUMNS, 86
for index = 1, Combat.SlugTotal do
	local slugId = found[index]
	local tile = Theme.new("Frame", {
		Name = `Tile{index}`,
		Position = UDim2.fromOffset(
			((index - 1) % GRID_COLUMNS) * (TILE_W + 8),
			244 + math.floor((index - 1) / GRID_COLUMNS) * (TILE_H + 8)
		),
		Size = UDim2.fromOffset(TILE_W, TILE_H),
		BackgroundColor3 = if slugId then Theme.Slot else Theme.Blank,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = left,
	})
	Theme.corner(tile, 12)
	Theme.edge(tile, 2, if slugId then Theme.Text else Theme.Ink)
	if slugId then
		table.insert(icons, SlugIcon.mount(tile, slugId, 0.82, false))
	else
		Theme.label(tile, "?", Theme.Title, 24, {
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Theme.Muted,
		})
	end
end

-- Details of the selected slug. Floppy is the only one so far.
local slugId = found[1]
local slug = Combat.Slugs[slugId]
local detail = Theme.new("Frame", {
	Name = "Detail",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 0, 0, HEAD_H),
	Size = UDim2.new(0, DETAIL_W, 1, -HEAD_H),
	BackgroundColor3 = Color3.fromRGB(35, 42, 51),
	BorderSizePixel = 0,
	Parent = panel,
})
Theme.new("Frame", {
	Size = UDim2.new(0, 3, 1, 0),
	BackgroundColor3 = Theme.Ink,
	BorderSizePixel = 0,
	Parent = detail,
})
local view = Theme.new("Frame", {
	Name = "View",
	Position = UDim2.fromOffset(22, 16),
	Size = UDim2.new(1, -44, 0, 224),
	BackgroundTransparency = 1,
	Parent = detail,
})
local viewIcon = SlugIcon.mount(view, slugId, 0.7, true) -- room above it to hop
table.insert(icons, viewIcon)
Theme.label(detail, slug.Label, Theme.TitleBold, 32, {
	Position = UDim2.fromOffset(22, 246),
	Size = UDim2.new(1, -44, 0, 42),
})
Theme.label(detail, slug.Blurb, Theme.Body, 15, {
	Position = UDim2.fromOffset(22, 288),
	Size = UDim2.new(1, -44, 0, 26),
	TextColor3 = Theme.Soft,
})
local function stat(y: number, title: string, value: string)
	Theme.new("Frame", {
		Position = UDim2.fromOffset(22, y),
		Size = UDim2.new(1, -44, 0, 2),
		BackgroundColor3 = Theme.Ink,
		BorderSizePixel = 0,
		Parent = detail,
	})
	Theme.label(detail, title, Theme.Body, 16, {
		Position = UDim2.fromOffset(22, y + 2),
		Size = UDim2.new(1, -44, 0, 36),
		TextColor3 = Theme.Soft,
	})
	Theme.label(detail, value, Theme.Body, 16, {
		Position = UDim2.fromOffset(22, y + 2),
		Size = UDim2.new(1, -44, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Right,
	})
end
stat(322, "Damage", tostring(slug.Damage))
stat(360, "Ready again in", `{Combat.Cooldown} s`)
local slotted = Theme.label(detail, "In slot 1", Theme.TitleBold, 18, {
	Name = "Slotted",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 22, 1, -20),
	Size = UDim2.new(1, -44, 0, 48),
	TextXAlignment = Enum.TextXAlignment.Center,
	TextColor3 = Theme.OnAccent,
	BackgroundColor3 = Theme.Accent,
	BackgroundTransparency = 0,
})
Theme.corner(slotted, 4)
Theme.edge(slotted, 2)

local function refreshOpen()
	local open = player:GetAttribute("PvpMenu") == "Inventory"
	panel.Visible = open
	for _, icon in icons do
		SlugIcon.setActive(icon, open)
	end
end
player:GetAttributeChangedSignal("PvpMenu"):Connect(refreshOpen)
close.Activated:Connect(function()
	Theme.setMenu(nil)
end)
Keybinds.on("inventory", function(pressed: boolean)
	if pressed then
		Theme.toggleMenu("Inventory")
	end
end)
refreshOpen()
gui.Parent = player:WaitForChild("PlayerGui")
