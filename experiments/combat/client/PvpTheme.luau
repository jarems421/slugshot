--!strict
-- The PvP UI's one look (owner, 2026-11-01): quiet slate panels with dark ink edges and a neutral
-- Moonlight accent that sits beside any slug's colours. Oswald titles over Nunito text.
local Players = game:GetService("Players")

local Theme = {}

Theme.Ink = Color3.fromRGB(11, 12, 16)
Theme.Panel = Color3.fromRGB(28, 33, 41)
Theme.Deep = Color3.fromRGB(22, 26, 33)
Theme.Raised = Color3.fromRGB(42, 50, 61)
Theme.Blank = Color3.fromRGB(20, 24, 31)
Theme.Slot = Color3.fromRGB(44, 52, 64)
Theme.SlotEmpty = Color3.fromRGB(26, 31, 39)
Theme.Bar = Color3.fromRGB(16, 19, 25)
Theme.Text = Color3.fromRGB(235, 244, 242)
Theme.Soft = Color3.fromRGB(199, 209, 214)
Theme.Muted = Color3.fromRGB(174, 185, 192)
Theme.Accent = Color3.fromRGB(230, 236, 239)
Theme.OnAccent = Color3.fromRGB(20, 20, 26)
Theme.Health = Color3.fromRGB(185, 217, 122)
Theme.HealthLow = Color3.fromRGB(242, 133, 122)
Theme.Return = Color3.fromRGB(215, 240, 160) -- Floppy's bulb glow marks a slug coming back

Theme.Title = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Medium)
Theme.TitleBold = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.SemiBold)
Theme.Body = Font.new("rbxasset://fonts/families/Nunito.json", Enum.FontWeight.Bold)

-- The mockups are drawn at this size, so the UI keeps the same share of any screen.
Theme.DesignHeight = 720

function Theme.new(class: string, props: { [string]: any }): any
	local item: any = Instance.new(class)
	local parent = props.Parent
	for key, value in props do
		if key ~= "Parent" then
			item[key] = value
		end
	end
	item.Parent = parent
	return item
end

function Theme.corner(parent: Instance, radius: number)
	Theme.new("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

function Theme.edge(parent: Instance, thickness: number, color: Color3?): UIStroke
	return Theme.new("UIStroke", {
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Thickness = thickness,
		Color = color or Theme.Ink,
		Parent = parent,
	})
end

function Theme.label(
	parent: Instance,
	text: string,
	font: Font,
	size: number,
	props: { [string]: any }?
): TextLabel
	local item = Theme.new("TextLabel", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		FontFace = font,
		TextSize = size,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = text,
		Parent = parent,
	})
	for key, value in (props or {}) :: { [string]: any } do
		item[key] = value
	end
	return item
end

function Theme.button(
	parent: Instance,
	text: string,
	font: Font,
	size: number,
	props: { [string]: any }?
): TextButton
	local item = Theme.new("TextButton", {
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Raised,
		BorderSizePixel = 0,
		FontFace = font,
		TextSize = size,
		TextColor3 = Theme.Text,
		Text = text,
		Parent = parent,
	})
	for key, value in (props or {}) :: { [string]: any } do
		item[key] = value
	end
	return item
end

-- Paints a button on or off, the same way everywhere.
function Theme.paint(button: TextButton, selected: boolean)
	button.BackgroundColor3 = if selected then Theme.Accent else Theme.Raised
	button.TextColor3 = if selected then Theme.OnAccent else Theme.Text
end

-- Which menu is open ("Settings", "Inventory" or nil). Opening one closes the other, and either
-- frees the cursor and stops firing through the shared CombatSettingsOpen flag.
function Theme.setMenu(name: string?)
	local player = Players.LocalPlayer
	player:SetAttribute("PvpMenu", name)
	player:SetAttribute("CombatSettingsOpen", name ~= nil)
end

function Theme.toggleMenu(name: string)
	local player = Players.LocalPlayer
	Theme.setMenu(if player:GetAttribute("PvpMenu") == name then nil else name)
end

-- The in-match HUD stays small: this size on a 1080p screen, in proportion elsewhere.
function Theme.fitHud(gui: ScreenGui, scale: UIScale)
	local function apply()
		scale.Scale = math.clamp(gui.AbsoluteSize.Y / 1080, 0.75, 1.5)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(apply)
	apply()
end

-- Keeps a UIScale at the design's share of the screen.
function Theme.fit(gui: ScreenGui, scale: UIScale, widthDesign: number?)
	local function apply()
		local size = gui.AbsoluteSize
		local value = size.Y / Theme.DesignHeight
		if widthDesign then
			value = math.min(value, size.X / widthDesign)
		end
		scale.Scale = math.clamp(value, 0.6, 2)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(apply)
	apply()
end

return Theme
