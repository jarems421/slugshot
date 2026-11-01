--!strict
-- Crosshair appearance only. Charge-ring color/animation has no dependency on this palette.
local CrosshairStyles = {}
local INK = Color3.fromRGB(14, 14, 18)
type Line = { number }
export type Preset = {
	id: string,
	label: string,
	description: string,
	dot: number?,
	outline: number,
	lines: { Line },
	ring: number?,
}
CrosshairStyles.DefaultStyle = "Classic"
CrosshairStyles.MinSize = 0.75
CrosshairStyles.MaxSize = 1.4
CrosshairStyles.Colors = {
	{ label = "Pearl", color = Color3.fromRGB(235, 244, 242) },
	{ label = "Mint", color = Color3.fromRGB(134, 240, 193) },
	{ label = "Ice", color = Color3.fromRGB(133, 221, 255) },
	{ label = "Amber", color = Color3.fromRGB(255, 195, 111) },
	{ label = "Coral", color = Color3.fromRGB(255, 133, 126) },
	{ label = "Lilac", color = Color3.fromRGB(204, 166, 255) },
	{ label = "Lime", color = Color3.fromRGB(212, 238, 124) },
	{ label = "Rose", color = Color3.fromRGB(255, 161, 212) },
}
CrosshairStyles.Presets = {
	{
		id = "Classic",
		label = "Classic",
		description = "Four short marks and a precise center dot.",
		dot = 2.4,
		outline = 1.5,
		lines = {
			{ 7, 0, 4, 1.8, 0 },
			{ -7, 0, 4, 1.8, 0 },
			{ 0, 7, 4, 1.8, 90 },
			{ 0, -7, 4, 1.8, 90 },
		},
	},
	{
		id = "Dot",
		label = "Pinpoint",
		description = "A small dot with a clear view of the target.",
		dot = 2.2,
		outline = 1,
		lines = {},
	},
	{
		id = "Micro",
		label = "Micro Cross",
		description = "A very small, fine cross for precise placement.",
		outline = 0.85,
		lines = { { 0, 0, 5.5, 1.2, 0 }, { 0, 0, 5.5, 1.2, 90 } },
	},
	{
		id = "Twin",
		label = "Twin Bars",
		description = "Two clean bars with an open aiming center.",
		outline = 1.1,
		lines = { { -4.5, 0, 4.5, 1.6, 0 }, { 4.5, 0, 4.5, 1.6, 0 } },
	},
	{
		id = "Triad",
		label = "Triad",
		description = "Three angled marks around a small center dot.",
		dot = 2.2,
		outline = 1.1,
		lines = {},
	},
	{
		id = "Open",
		label = "Open Cross",
		description = "Four slim marks leave the target center uncovered.",
		outline = 1.1,
		lines = {
			{ 6.5, 0, 3.6, 1.4, 0 },
			{ -6.5, 0, 3.6, 1.4, 0 },
			{ 0, 6.5, 3.6, 1.4, 90 },
			{ 0, -6.5, 3.6, 1.4, 90 },
		},
	},
	{
		id = "Ring",
		label = "Ring Dot",
		description = "A fine inner ring and dot for a compact sight.",
		dot = 1.8,
		ring = 8.8,
		outline = 0.8,
		lines = {},
	},
} :: { Preset }
for i = 1, 3 do
	local angle = math.rad(-90 + (i - 1) * 120)
	table.insert(
		CrosshairStyles.Presets[5].lines,
		{ math.cos(angle) * 6.3, math.sin(angle) * 6.3, 3.8, 1.5, math.deg(angle) }
	)
end

function CrosshairStyles.find(id: any): Preset
	for _, preset in CrosshairStyles.Presets do
		if preset.id == id then
			return preset
		end
	end
	return CrosshairStyles.Presets[1]
end

function CrosshairStyles.color(value: any): Color3
	return if typeof(value) == "Color3" then value else CrosshairStyles.Colors[1].color
end

function CrosshairStyles.size(value: any): number
	if typeof(value) ~= "number" or value ~= value then
		return 1
	end
	return math.clamp(value, CrosshairStyles.MinSize, CrosshairStyles.MaxSize)
end

local function round(frame: Frame)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
end

local function shape(
	parent: Frame,
	name: string,
	x: number,
	y: number,
	w: number,
	h: number,
	rotation: number,
	color: Color3
): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5 + x / 18, 0.5 + y / 18)
	frame.Size = UDim2.fromScale(w / 18, h / 18)
	frame.Rotation = rotation
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Parent = parent
	round(frame)
	return frame
end

function CrosshairStyles.draw(parent: Frame, id: any, color: Color3): Frame
	local previous = parent:FindFirstChild("Design")
	if previous then
		previous:Destroy()
	end
	local preset = CrosshairStyles.find(id)
	local design = Instance.new("Frame")
	design.Name = "Design"
	design.Size = UDim2.fromScale(1, 1)
	design.BackgroundTransparency = 1
	design:SetAttribute("StyleId", preset.id)
	design.Parent = parent
	-- All ink is behind all colored faces, so intersecting lines stay clean.
	for _, ink in { true, false } do
		local layer = Instance.new("Frame")
		layer.Name = if ink then "Ink" else "Face"
		layer.Size = UDim2.fromScale(1, 1)
		layer.BackgroundTransparency = 1
		layer.Parent = design
		local pad = if ink then preset.outline * 2 else 0
		local tint = if ink then INK else color
		for i, line in preset.lines do
			shape(layer, `Tick{i}`, line[1], line[2], line[3] + pad, line[4] + pad, line[5], tint)
		end
		if preset.dot then
			shape(layer, "AimDot", 0, 0, preset.dot + pad, preset.dot + pad, 0, tint)
		end
		if preset.ring then
			local circle = shape(layer, "SightRing", 0, 0, preset.ring, preset.ring, 0, tint)
			circle.BackgroundTransparency = 1
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = if ink then 3.2 else 1.2
			stroke.Color = tint
			stroke.Parent = circle
		end
	end
	design.ZIndex = parent.ZIndex
	for _, child in design:GetDescendants() do
		if child:IsA("GuiObject") then
			child.ZIndex = parent.ZIndex
		end
	end
	return design
end

return CrosshairStyles
