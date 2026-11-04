--!strict
-- The menus' feel (owner, 2026-11-02: "pop way more", "dimensional", animated on hover, "little effects").
-- Chunky buttons that sit on an ink lip, lift when hovered and press down when clicked; soft glows, sparks,
-- drifting motes and a staggered slide-in. Each settings tab has its own vivid colour; the match HUD keeps
-- the neutral Moonlight accent the owner chose to sit beside any slug.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.PvpTheme)

local Fx = {}

Fx.Accents = {
	Controls = Color3.fromRGB(84, 228, 214), -- cave crystal
	Gameplay = Color3.fromRGB(190, 236, 96), -- slug goo
	Crosshair = Color3.fromRGB(199, 155, 255), -- amethyst
}
-- Colourful shadows, per the style guide: deep indigo rather than grey.
Fx.PanelTop = Color3.fromRGB(42, 40, 84)
Fx.PanelBottom = Color3.fromRGB(19, 24, 48)
Fx.Deep = Color3.fromRGB(24, 23, 52)
Fx.Card = Color3.fromRGB(47, 49, 92)
Fx.Button = Color3.fromRGB(63, 67, 118)
Fx.Blank = Color3.fromRGB(23, 25, 50)
Fx.Coral = Color3.fromRGB(255, 118, 118)

local artModule = ReplicatedStorage:WaitForChild("GooArt", 5)
local art: { [string]: number } = if artModule then (require :: any)(artModule) else {}

function Fx.asset(name: string): string
	local id = art[name]
	return if id then `rbxassetid://{id}` else ""
end

function Fx.tween(
	item: Instance,
	time: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	delay: number?
): Tween
	local tween = TweenService:Create(
		item,
		TweenInfo.new(
			time,
			style or Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out,
			0,
			false,
			delay or 0
		),
		goal
	)
	tween:Play()
	return tween
end

-- Roblox's own short tick, pitched for each use. Quiet on hover so it never nags.
local SOUNDS = {
	hover = { volume = 0.1, speed = 1.7 },
	click = { volume = 0.35, speed = 1.05 },
	select = { volume = 0.35, speed = 1.4 },
}
local sounds: { [string]: Sound } = {}
function Fx.sound(kind: string)
	local sound = sounds[kind]
	if not sound then
		local spec = SOUNDS[kind]
		sound = Theme.new("Sound", {
			Name = `Ui{kind}`,
			SoundId = "rbxasset://sounds/volume_slider.ogg",
			Volume = spec.volume,
			PlaybackSpeed = spec.speed,
			Parent = SoundService,
		})
		sounds[kind] = sound
	end
	sound.TimePosition = 0
	sound:Play()
end

-- A soft light behind something. Starts hidden.
function Fx.glow(parent: Instance, colour: Color3, z: number?): ImageLabel
	return Theme.new("ImageLabel", {
		Name = "Glow",
		BackgroundTransparency = 1,
		Image = Fx.asset("glow"),
		ImageColor3 = colour,
		ImageTransparency = 1,
		ZIndex = z or 0,
		Parent = parent,
	})
end

-- A crystal's light (owner, 2026-11-03: diffuse it and blend it in, with sparkles, on every menu): a wide, faint wash
-- that fades into the panel and a softer core, both rising from the crystal's foot. foot is the crystal's bottom middle.
export type CrystalLight = {
	layers: { ImageLabel },
	setColour: (Color3) -> (),
	breathe: (level: number) -> (),
}
function Fx.crystalLight(
	parent: Instance,
	colour: Color3,
	foot: UDim2,
	size: number,
	z: number?
): CrystalLight
	local wide = Fx.glow(parent, colour, z)
	wide.AnchorPoint = Vector2.new(0.5, 0.5)
	wide.Position = foot - UDim2.fromOffset(0, size * 0.42)
	wide.Size = UDim2.fromOffset(size * 3.2, size * 2.7)
	local core = Fx.glow(parent, colour, z)
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = foot - UDim2.fromOffset(0, size * 0.45)
	core.Size = UDim2.fromOffset(size * 1.6, size * 1.5)
	local light: CrystalLight
	light = {
		layers = { wide, core },
		setColour = function(value: Color3)
			for _, layer in light.layers do
				Fx.tween(layer, 0.35, { ImageColor3 = value })
			end
		end,
		-- level runs 0 to 1, slowly: a breath, never a flicker.
		breathe = function(level: number)
			wide.ImageTransparency = 0.84 - 0.08 * level
			core.ImageTransparency = 0.78 - 0.12 * level
		end,
	}
	light.breathe(0.5)
	return light
end

export type ControlOptions = {
	accent: Color3,
	radius: number,
	idle: Color3?,
	idleText: Color3?,
	selectedFill: Color3?, -- for buttons that must not fill with the accent when chosen
	selectedText: Color3?,
	grow: number?, -- px added on hover; keep under the gap to the neighbours, so nothing is covered
	lip: number?,
}
export type Control = {
	button: TextButton,
	set: (selected: boolean) -> (),
	setIdle: (fill: Color3, text: Color3) -> (),
	setDim: (dim: boolean) -> (),
}

local LIGHT_BAND = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(176, 176, 190)),
})

-- Makes a button chunky and alive. Its Position must be final; the lift moves it from there.
function Fx.chunky(button: TextButton, options: ControlOptions): Control
	local accent = options.accent
	local depth = options.lip or 3
	local grow = options.grow or 4
	local idle = options.idle or Fx.Button
	local idleText = options.idleText or Theme.Text
	local base = button.Position
	local baseSize = button.Size
	local z = button.ZIndex
	local parent = button.Parent
	local anchor = button.AnchorPoint

	local stroke = button:FindFirstChildOfClass("UIStroke") or Theme.edge(button, 2)
	if not button:FindFirstChildOfClass("UICorner") then
		Theme.corner(button, options.radius)
	end
	Theme.new("UIGradient", { Color = LIGHT_BAND, Rotation = 90, Parent = button })
	local shine = Theme.new("Frame", {
		Name = "Shine",
		Position = UDim2.fromOffset(4, 2),
		Size = UDim2.new(1, -8, 0, 2),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.68,
		BorderSizePixel = 0,
		Parent = button,
	})
	Theme.corner(shine, 1)
	local lip = Theme.new("Frame", {
		Name = "Lip",
		AnchorPoint = anchor,
		Position = base + UDim2.fromOffset(0, depth),
		Size = button.Size,
		BackgroundColor3 = Theme.Ink,
		BorderSizePixel = 0,
		ZIndex = z - 1,
		Parent = parent,
	})
	Theme.corner(lip, options.radius)
	Theme.edge(lip, stroke.Thickness)
	local function syncVisible()
		lip.Visible = button.Visible
	end
	button:GetPropertyChangedSignal("Visible"):Connect(syncVisible)
	syncVisible()

	local selected, hovering, pressed, dimmed = false, false, false, false
	local function refresh()
		local live = hovering and not dimmed
		local fill = if selected then options.selectedFill or accent else idle
		if live then
			fill = fill:Lerp(Color3.new(1, 1, 1), 0.12)
		end
		local text = if selected then options.selectedText or Theme.OnAccent else idleText
		Fx.tween(button, 0.12, { BackgroundColor3 = fill, TextColor3 = text })
		local edge = if selected and not options.selectedFill
			then Theme.Ink
			elseif selected or live then accent
			else Theme.Ink
		Fx.tween(stroke, 0.12, { Color = edge })
		-- The shadow grows and moves with the button, so it looks the same hovered or not.
		local added = if live and not pressed then grow else 0
		local size = baseSize + UDim2.fromOffset(added, added)
		local at = base + UDim2.fromOffset((anchor.X - 0.5) * added, (anchor.Y - 0.5) * added)
		local sink = if pressed then depth - 1 else 0
		Fx.tween(
			button,
			0.14,
			{ Position = at + UDim2.fromOffset(0, sink), Size = size },
			Enum.EasingStyle.Back
		)
		Fx.tween(
			lip,
			0.14,
			{ Position = at + UDim2.fromOffset(0, depth), Size = size },
			Enum.EasingStyle.Back
		)
	end
	button.MouseEnter:Connect(function()
		hovering = true
		if not dimmed then
			Fx.sound("hover")
		end
		refresh()
	end)
	button.MouseLeave:Connect(function()
		hovering, pressed = false, false
		refresh()
	end)
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			pressed = true
			if not dimmed then
				Fx.sound("click")
			end
			refresh()
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			pressed = false
			refresh()
		end
	end)
	button.BackgroundColor3 = idle
	button.TextColor3 = idleText

	local control: Control = {
		button = button,
		set = function(value: boolean)
			if selected ~= value then
				selected = value
				refresh()
			end
		end,
		setIdle = function(fill: Color3, text: Color3)
			if idle ~= fill or idleText ~= text then
				idle, idleText = fill, text
				refresh()
			end
		end,
		setDim = function(value: boolean)
			if dimmed ~= value then
				dimmed = value
				local see = if value then 0.55 else 0
				button.BackgroundTransparency, button.TextTransparency = see, see
				lip.BackgroundTransparency = see
				refresh()
			end
		end,
	}
	return control
end

-- A raised card: lit from above, sitting on a thick ink lip.
function Fx.card(parent: Instance, props: { [string]: any }, radius: number): Frame
	local position: UDim2 = props.Position or UDim2.new()
	local size: UDim2 = props.Size
	local lip = Theme.new("Frame", {
		Name = "CardLip",
		Position = position + UDim2.fromOffset(0, 4),
		Size = size,
		BackgroundColor3 = Theme.Ink,
		BorderSizePixel = 0,
		Parent = parent,
	})
	Theme.corner(lip, radius)
	Theme.edge(lip, 2)
	local card = Theme.new("Frame", {
		BackgroundColor3 = Fx.Card,
		BorderSizePixel = 0,
		Parent = parent,
	})
	for key, value in props do
		card[key] = value
	end
	Theme.corner(card, radius)
	Theme.edge(card, 2)
	Theme.new("UIGradient", { Color = LIGHT_BAND, Rotation = 90, Parent = card })
	return card
end

-- A burst of sparks from the middle of something. Sparks live in the given full-screen ScreenGui.
function Fx.sparkle(gui: ScreenGui, from: GuiObject, colour: Color3, count: number?)
	local centre = from.AbsolutePosition + from.AbsoluteSize / 2 - gui.AbsolutePosition
	for _ = 1, count or 7 do
		local angle = math.random() * 2 * math.pi
		local reach = 22 + math.random() * 34
		local size = 8 + math.random() * 12
		local spark = Theme.new("ImageLabel", {
			Name = "Spark",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(centre.X, centre.Y),
			Size = UDim2.fromOffset(size, size),
			BackgroundTransparency = 1,
			Image = Fx.asset("spark"),
			ImageColor3 = colour:Lerp(Color3.new(1, 1, 1), 0.35),
			ZIndex = 60,
			Parent = gui,
		})
		local life = 0.32 + math.random() * 0.25
		local tween = Fx.tween(spark, life, {
			Position = UDim2.fromOffset(
				centre.X + math.cos(angle) * reach,
				centre.Y + math.sin(angle) * reach
			),
			Rotation = (math.random() - 0.5) * 200,
			ImageTransparency = 1,
			Size = UDim2.fromOffset(size * 0.3, size * 0.3),
		})
		tween.Completed:Connect(function()
			spark:Destroy()
		end)
	end
end

-- Things slide in one after another. Only for plain containers, never a Fx.chunky button.
local homes: { [GuiObject]: UDim2 } = setmetatable({}, { __mode = "k" }) :: any
function Fx.cascade(page: GuiObject)
	local index = 0
	for _, child in page:GetChildren() do
		if child:IsA("Frame") then
			local home = homes[child] or child.Position
			homes[child] = home
			child.Position = home + UDim2.fromOffset(34, 0)
			Fx.tween(child, 0.3, { Position = home }, Enum.EasingStyle.Back, index * 0.022)
			index += 1
		end
	end
end

-- Twinkles: little stars that open, turn and close, gathered around the crystals (owner, 2026-11-02).
export type Spot = { x: number, y: number, w: number, h: number, weight: number }
export type Twinkles = { setColour: (Color3) -> (), setActive: (boolean) -> () }
type Twinkle = {
	image: ImageLabel,
	age: number,
	life: number,
	peak: number,
	wait: number,
	turn: number,
}
function Fx.twinkles(parent: Instance, spots: { Spot }, count: number, colour: Color3): Twinkles
	local total = 0
	for _, spot in spots do
		total += spot.weight
	end
	local tint = colour:Lerp(Color3.new(1, 1, 1), 0.45)
	local twinkles: { Twinkle } = {}
	for _ = 1, count do
		table.insert(twinkles, {
			image = Theme.new("ImageLabel", {
				Name = "Twinkle",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = Fx.asset("spark"),
				ImageColor3 = tint,
				Visible = false,
				ZIndex = 2,
				Parent = parent,
			}),
			age = 0,
			life = 1,
			peak = 10,
			wait = math.random() * 3,
			turn = 0,
		})
	end
	local function respawn(twinkle: Twinkle)
		local pick = math.random() * total
		for _, spot in spots do
			pick -= spot.weight
			if pick <= 0 then
				twinkle.image.Position =
					UDim2.new(spot.x, math.random() * spot.w, spot.y, math.random() * spot.h)
				break
			end
		end
		twinkle.age = 0
		twinkle.life = 0.7 + math.random() * 0.8
		twinkle.peak = 10 + math.random() * 16
		twinkle.turn = (math.random() - 0.5) * 70
	end
	local active = false
	RunService.RenderStepped:Connect(function(dt: number)
		if not active then
			return
		end
		for _, twinkle in twinkles do
			if twinkle.wait > 0 then
				twinkle.wait -= dt
				if twinkle.wait <= 0 then
					respawn(twinkle)
				end
			else
				twinkle.age += dt
				local share = twinkle.age / twinkle.life
				if share >= 1 then
					twinkle.image.Visible = false
					twinkle.wait = 0.1 + math.random() * 1.4
				else
					local open = math.sin(math.pi * share) ^ 2
					local size = twinkle.peak * open
					twinkle.image.Visible = true
					twinkle.image.Size = UDim2.fromOffset(size, size)
					twinkle.image.Rotation = twinkle.turn * share
					twinkle.image.ImageTransparency = 1 - open
				end
			end
		end
	end)
	return {
		setColour = function(value: Color3)
			tint = value:Lerp(Color3.new(1, 1, 1), 0.45)
			for _, twinkle in twinkles do
				Fx.tween(twinkle.image, 0.35, { ImageColor3 = tint })
			end
		end,
		setActive = function(value: boolean)
			active = value
		end,
	}
end

return Fx
