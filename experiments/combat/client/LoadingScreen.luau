--!strict
-- The game's loading screen (owner, 2026-11-03), approved from the preview at
-- https://claude.ai/artifact/3JUUQvQepbCRhkYNtVKJ8F. A sheet of the menus' panel drops over the view with the
-- settings menu's slime along its top and leading edge, the place's name in comic type, and a liquid bar that the
-- place's comic slug hops along, landing on the front of the goo each hop. It stays at least MIN_TIME even when
-- nothing is slow, so the move is always noticed, and holds with the slug hopping on the spot while loading takes.
--
-- local handle = LoadingScreen.show("Training")
-- handle.covered() -- yields until the view is fully covered: move the player now
-- handle.finish() -- loading is done; the bar fills and the sheet lifts once MIN_TIME has passed
--
-- Everything is built ahead of time and only recoloured on show: building ~1,000 slime columns when the portal is
-- touched cost a 300 ms frame (Studio check, 2026-11-03).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local Theme = require(script.Parent.PvpTheme)
local Fx = require(script.Parent.PvpFx)
local Goo = require(script.Parent.Goo)
local GooBar = require(script.Parent.GooBar)
local Backdrop = require(script.Parent.Backdrop)

local LoadingScreen = {}

-- back is the cavern passage behind the sheet (owner's pick, 2026-11-03), rendered once per colour so its crystals
-- and the light they throw match the place: tools/ui/backgrounds.
export type Place = { title: string, colour: Color3, word: string, slug: string?, back: string }
LoadingScreen.Places = {
	Training = {
		title = "Training",
		colour = Fx.Accents.Gameplay,
		word = "Loading the island",
		slug = "slugFloppy",
		back = "backGameplay",
	},
	Lobby = {
		title = "Lobby",
		colour = Fx.Accents.Controls,
		word = "Heading back",
		slug = "slugFloppy",
		back = "backControls",
	},
	PvP = {
		title = "PvP",
		colour = Color3.fromRGB(255, 158, 64),
		word = "Finding a match",
		slug = "slugInferno",
		back = "backPvP",
	},
	-- No slug until there is a purple one (owner).
	Veylume = {
		title = "Veylume",
		colour = Color3.fromRGB(199, 155, 255),
		word = "Loading Veylume",
		back = "backCrosshair",
	},
} :: { [string]: Place }

export type Handle = { covered: () -> (), finish: () -> () }

local MIN_TIME = 2.1 -- 1.4 felt too short (owner, 2026-11-03)
local DROP, LIFT, TOP_UP = 0.26, 0.3, 0.15
local FILL_START = 0.15 -- the bar starts as the sheet lands
local FILL_SHARE = 0.92 -- how far it fills on its own; the rest waits for the real finish
local HOP, HOP_HEIGHT, SLUG_SIZE = 0.32, 24, 62
local DESIGN_W, DESIGN_H = 1280, 720
local BAR_W, BAR_H = 560, 22
local BAR_X, BAR_Y = DESIGN_W / 2 - BAR_W / 2, 470
local TOP_SCALE, EDGE_SCALE = 1.5, 2
local BAND_COL, BAND_BACK_COL = 8, 16
local DRIPS = { 0.05, 0.17, 0.29, 0.46, 0.61, 0.74, 0.92 }
local SPARKS = 4 -- per crystal
local SKIRT = 150 -- panel below the screen's bottom, so the leading slime edge is off screen once landed
local HIDDEN = UDim2.new(0, 0, -1, -160 - SKIRT) -- above the screen, its slime edge too
-- Width over height of each slug's picture.
local SLUG_ASPECT: { [string]: number } = { slugFloppy = 226 / 320, slugInferno = 231 / 320 }

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset, gui.ResetOnSpawn, gui.DisplayOrder = true, false, 300
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function shade(colour: Color3, by: number): Color3
	return Color3.new(colour.R * by, colour.G * by, colour.B * by)
end

-- The screen's real size: a hidden ScreenGui reports a stale AbsoluteSize.
local function viewport(): Vector2
	local camera = workspace.CurrentCamera
	return if camera then camera.ViewportSize else gui.AbsoluteSize
end

-- One band of slime across the screen: back, front and shine strips that ripple and scroll.
type Band = { strips: { Goo.Strip }, drips: { { at: number, drip: Goo.Drip } }, width: number }
local function band(parent: Instance, scale: number, width: number): Band
	local holder = Theme.new("Frame", {
		Name = "Slime",
		Size = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = parent,
	})
	Theme.new("UIScale", { Scale = scale, Parent = holder })
	local across = math.ceil(width / scale) + BAND_COL
	local back = Goo.strip(holder, "bandBack", Goo.Band, BAND_BACK_COL, 0, 0, across, 6)
	local front = Goo.strip(holder, "bandFront", Goo.Band, BAND_COL, 0, 0, across, 7)
	local shine = Goo.strip(holder, "bandShine", Goo.Band, BAND_COL, 0, 0, across, 7)
	Goo.tint(shine, Color3.new(1, 1, 1))
	local drips = {}
	local edge = Goo.Band.edge - Goo.Band.top
	for _, at in DRIPS do
		table.insert(drips, { at = at, drip = Goo.drip(holder, at * across, edge, 5) })
	end
	return { strips = { back, front, shine }, drips = drips, width = across }
end

local function tintBand(b: Band, colour: Color3)
	Goo.tint(b.strips[1], shade(colour, 0.68))
	Goo.tint(b.strips[2], colour)
end

local function poseBand(b: Band, clock: number, colour: Color3, seed: number, dt: number)
	local function height(across: number): number
		local share = across / b.width
		return 3 * math.sin(2 * math.pi * 0.13 * clock + share * 11 + seed)
			+ 1.6 * math.sin(clock * 1.7 + across / 90 + seed * 2)
	end
	local front = clock * 16
	Goo.pose(b.strips[1], -clock * 11, function(across: number): number
		return -height(across) * 0.6 + 1
	end)
	Goo.pose(b.strips[2], front, height)
	Goo.pose(b.strips[3], front, height)
	for _, entry in b.drips do
		local across = entry.at * b.width
		local shift = height(across) + Goo.waveAt(Goo.Band, (front + across) % Goo.Band.period)
		entry.drip.step(dt, shift, true, colour)
	end
end

type Sparkle = { image: ImageLabel, life: number, peak: number, offset: number, index: number }
type Built = {
	size: Vector2,
	sheet: Frame,
	backdrop: Backdrop.Backdrop,
	top: Band,
	edge: Band,
	crystals: { ImageLabel },
	lights: { Fx.CrystalLight },
	sparkles: { Sparkle },
	titles: { TextLabel },
	caption: TextLabel,
	bars: { [string]: { frame: Frame, bar: GooBar.Bar } },
	slug: ImageLabel,
}
local built: Built? = nil
local showing = false

local function build(): Built
	gui:ClearAllChildren()
	local size = viewport()
	local scale = math.clamp(math.min(size.X / DESIGN_W, size.Y / DESIGN_H), 0.45, 2.5)
	local sheet = Theme.new("Frame", {
		Name = "Sheet",
		Position = HIDDEN,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = gui,
	})
	Theme.new("UIGradient", {
		Color = ColorSequence.new(Fx.PanelTop, Fx.PanelBottom),
		Rotation = 90,
		Parent = sheet,
	})
	-- Behind everything on the sheet; the panel's gradient shows until its picture has loaded.
	local backdrop = Backdrop.new(sheet, size.X / size.Y)
	-- A soft shadow behind the name, bar and caption, so the scenery never competes with them.
	Theme.new("ImageLabel", {
		Name = "Shade",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 60 * scale),
		Size = UDim2.fromOffset(1050 * scale, 520 * scale),
		BackgroundTransparency = 1,
		Image = Fx.asset("glow"),
		ImageColor3 = Color3.fromRGB(8, 8, 20),
		ImageTransparency = 0.38,
		ZIndex = 2,
		Parent = backdrop.group,
	})
	Theme.new("Frame", {
		Name = "Skirt",
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, SKIRT),
		BackgroundColor3 = Fx.PanelBottom,
		BorderSizePixel = 0,
		Parent = sheet,
	})
	Theme.new("Frame", {
		Name = "EdgeInk",
		Position = UDim2.new(0, 0, 1, SKIRT - 3),
		Size = UDim2.new(1, 0, 0, 5),
		BackgroundColor3 = Theme.Ink,
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = sheet,
	})
	local edgeHolder = Theme.new("Frame", {
		Name = "Edge",
		Position = UDim2.new(0, 0, 1, SKIRT - 6),
		Size = UDim2.fromScale(1, 0),
		BackgroundTransparency = 1,
		Parent = sheet,
	})
	local top = band(sheet, TOP_SCALE * scale, size.X)
	local edge = band(edgeHolder, EDGE_SCALE * scale, size.X)

	-- Crystals in the bottom corners, with their light and sparkles.
	local crystals, lights, sparkles = {}, {}, {}
	local function corner(
		anchor: number,
		image: string,
		crystalSize: number,
		x: number,
		phase: number
	)
		local box = Theme.new("Frame", {
			Name = "Crystals",
			AnchorPoint = Vector2.new(anchor, 1),
			Position = UDim2.fromScale(anchor, 1),
			Size = UDim2.fromOffset(420, 420),
			BackgroundTransparency = 1,
			Parent = sheet,
		})
		Theme.new("UIScale", { Scale = scale, Parent = box })
		local foot = UDim2.new(0, x, 1, 8)
		table.insert(lights, Fx.crystalLight(box, Color3.new(1, 1, 1), foot, crystalSize, 1))
		table.insert(
			crystals,
			Theme.new("ImageLabel", {
				Name = "Crystal",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = foot,
				Size = UDim2.fromOffset(crystalSize, crystalSize),
				BackgroundTransparency = 1,
				Image = Fx.asset(image),
				ZIndex = 2,
				Parent = box,
			})
		)
		-- Sparkles open and close over the crystal's points.
		local over = Theme.new("Frame", {
			Name = "Sparkles",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = foot - UDim2.fromOffset(0, crystalSize * 0.15),
			Size = UDim2.fromOffset(crystalSize * 0.85, crystalSize * 0.8),
			BackgroundTransparency = 1,
			ZIndex = 3,
			Parent = box,
		})
		for index = 1, SPARKS do
			table.insert(sparkles, {
				image = Theme.new("ImageLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = Fx.asset("spark"),
					Visible = false,
					ZIndex = 3,
					Parent = over,
				}),
				life = 1.1 + (index * 0.37) % 0.8,
				peak = crystalSize * (0.08 + 0.07 * ((index * 0.61) % 1)),
				offset = phase * 3 + index * 0.83,
				index = index,
			})
		end
	end
	corner(0, "crystalSmall", 170, 170, 2.1)
	corner(1, "crystal", 310, 270, 0)

	-- The middle: name, bar, caption and slug, on a fixed design that scales with the screen.
	local stage = Theme.new("Frame", {
		Name = "Stage",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(DESIGN_W, DESIGN_H),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = sheet,
	})
	Theme.new("UIScale", { Scale = scale, Parent = stage })
	local titles = {}
	for _, layer in { { offset = 4, z = 3 }, { offset = 0, z = 4 } } do
		table.insert(
			titles,
			Theme.label(stage, "", Theme.TitleBold, 92, {
				Name = "Title",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromOffset(DESIGN_W / 2 + layer.offset, 300 + layer.offset),
				Size = UDim2.fromOffset(900, 110),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = Theme.Ink,
				ZIndex = layer.z,
			})
		)
	end
	-- A bar's colour is fixed when it is made, so each place has its own, all made now.
	local bars = {}
	for name, place in LoadingScreen.Places do
		local frame = Theme.new("Frame", {
			Name = `Bar{name}`,
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Visible = false,
			ZIndex = 4,
			Parent = stage,
		})
		local bar = GooBar.new(frame, Vector2.new(BAR_X - 3, BAR_Y - 3), BAR_W, BAR_H, {
			col = 6,
			colour = place.colour,
			empty = Fx.Blank,
			drips = false,
			lost = false,
			active = function(): boolean
				return gui.Enabled and frame.Visible
			end,
		})
		bars[name] = { frame = frame, bar = bar }
	end
	local caption = Theme.label(stage, "", Theme.Body, 21, {
		Name = "Caption",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(DESIGN_W / 2, BAR_Y + 44),
		Size = UDim2.fromOffset(600, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.Soft,
		ZIndex = 4,
	})
	local slug = Theme.new("ImageLabel", {
		Name = "Slug",
		AnchorPoint = Vector2.new(0.55, 1),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = stage,
	})
	return {
		size = size,
		sheet = sheet,
		backdrop = backdrop,
		top = top,
		edge = edge,
		crystals = crystals,
		lights = lights,
		sparkles = sparkles,
		titles = titles,
		caption = caption,
		bars = bars,
		slug = slug,
	}
end

-- Built once the game has settled, and again if the screen changes size while it is hidden.
-- Its images are fetched now, so the first portal doesn't wait on them.
task.defer(function()
	local ui = build()
	built = ui
	local images = {}
	for _, item in gui:GetDescendants() do
		if item:IsA("ImageLabel") and item.Image ~= "" then
			images[item.Image] = item
		end
	end
	for _, slug in { "slugFloppy", "slugInferno" } do
		images[Fx.asset(slug)] = ui.slug
	end
	for _, place in LoadingScreen.Places do
		for _, name in ui.backdrop.names(place.back) do
			if Fx.asset(name) ~= "" then
				images[Fx.asset(name)] = ui.slug
			end
		end
	end
	local list = {}
	for image in images do
		table.insert(list, image)
	end
	pcall(function()
		ContentProvider:PreloadAsync(list)
	end)
	-- Drawn once, out of sight above the screen, so the first real showing has nothing left to set up.
	if not showing then
		gui.Enabled = true
		task.wait(0.25)
		if not showing then
			gui.Enabled = false
		end
	end
end)
local resizeToken = 0
local function watchCamera()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		resizeToken += 1
		local mine = resizeToken
		task.delay(0.5, function()
			if mine == resizeToken and not showing then
				built = build()
			end
		end)
	end)
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

function LoadingScreen.show(name: string): Handle
	local place = LoadingScreen.Places[name] or LoadingScreen.Places.Training
	local colour = place.colour
	local setupStart = os.clock()
	showing = true
	local ui = built or build()
	built = ui

	-- Dress it for this place.
	ui.backdrop.set(place.back)
	tintBand(ui.top, colour)
	tintBand(ui.edge, colour)
	for _, crystal in ui.crystals do
		crystal.ImageColor3 = colour
	end
	for _, light in ui.lights do
		for _, layer in light.layers do
			layer.ImageColor3 = colour
		end
	end
	local sparkleTint = colour:Lerp(Color3.new(1, 1, 1), 0.5)
	for _, spark in ui.sparkles do
		spark.image.ImageColor3 = sparkleTint
		spark.image.Visible = false
	end
	ui.titles[1].Text, ui.titles[2].Text = place.title, place.title
	ui.titles[2].TextColor3 = colour
	ui.caption.Text = place.word
	local current = ui.bars[name] or ui.bars.Training
	for _, entry in ui.bars do
		entry.frame.Visible = entry == current
	end
	current.bar.set(0)
	ui.slug.Visible = place.slug ~= nil
	ui.slug.Image = if place.slug then Fx.asset(place.slug) else ""
	local aspect = if place.slug then SLUG_ASPECT[place.slug] or 0.7 else 0.7
	ui.sheet.Position = HIDDEN
	ui.sheet:SetAttribute("Lifting", nil)

	local started = os.clock()
	local covered, done = false, false
	local finishedAt: number? = nil
	local hop = { start = -1, from = 0, to = 0 }
	local clock = 0
	local function fillAt(t: number): number
		return FILL_SHARE * smooth((t - FILL_START) / (MIN_TIME - LIFT - TOP_UP - FILL_START))
	end
	gui.Enabled = true
	TweenService:Create(
		ui.sheet,
		TweenInfo.new(DROP, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.fromScale(0, 0) }
	):Play()
	local connection: RBXScriptConnection
	local frames = 0
	if workspace:GetAttribute("LoadingScreenTiming") then
		print(string.format("LOADTIME setup %.1fms", (os.clock() - setupStart) * 1000))
	end
	connection = RunService.RenderStepped:Connect(function(dt: number)
		clock += dt
		frames += 1
		if frames <= 30 and dt > 0.05 and workspace:GetAttribute("LoadingScreenTiming") then
			print(
				string.format(
					"LOADTIME frame %d %.0fms at %.2fs",
					frames,
					dt * 1000,
					os.clock() - started
				)
			)
		end
		local t = os.clock() - started
		covered = covered or t >= DROP
		local fill = fillAt(t)
		local ahead = fillAt(t + HOP)
		if done and t >= MIN_TIME - LIFT - TOP_UP then
			finishedAt = finishedAt or os.clock()
			local share = math.clamp((os.clock() - (finishedAt :: number)) / TOP_UP, 0, 1)
			fill += (1 - fill) * smooth(share)
			ahead = 1
			if share >= 1 and ui.sheet:GetAttribute("Lifting") == nil then
				ui.sheet:SetAttribute("Lifting", true)
				TweenService:Create(
					ui.sheet,
					TweenInfo.new(LIFT, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ Position = HIDDEN }
				):Play()
				task.delay(LIFT, function()
					connection:Disconnect()
					gui.Enabled = false
					showing = false
				end)
			end
		end
		current.bar.set(fill)
		poseBand(ui.top, clock, colour, 0, dt)
		poseBand(ui.edge, clock, colour, 3, dt)
		for index, light in ui.lights do
			light.breathe(0.5 + 0.5 * math.sin(clock * 1.1 + index * 2.1))
		end
		for _, spark in ui.sparkles do
			local cycle = (clock + spark.offset) / (spark.life + 0.9)
			local round = math.floor(cycle)
			local share = (cycle - round) * (spark.life + 0.9) / spark.life
			if share > 1 then
				spark.image.Visible = false
			else
				local seed = math.sin(round * 12.9898 + spark.index * 78.233) * 43758.5453
				local open = math.sin(math.pi * share) ^ 2
				local sparkSize = spark.peak * open
				spark.image.Visible = true
				spark.image.Position = UDim2.fromScale(seed % 1, (seed * 7.13) % 1)
				spark.image.Size = UDim2.fromOffset(sparkSize, sparkSize)
				spark.image.Rotation = math.deg((share - 0.5) * 1.2)
				spark.image.ImageTransparency = 1 - open
			end
		end
		if place.slug then
			-- Each hop lands where the front of the goo will be when it comes down; with nothing loading it hops on
			-- the spot, and once full it sits.
			if hop.start < 0 or clock - hop.start >= HOP then
				hop.from = if hop.start < 0 then fill else hop.to
				hop.to = ahead
				hop.start = if hop.from >= 1 and hop.to >= 1 then clock - HOP else clock
			end
			local u = math.clamp((clock - hop.start) / HOP, 0, 1)
			local sitting = hop.from >= 1 and hop.to >= 1
			local along = if sitting then 1 else hop.from + (hop.to - hop.from) * u
			local lift = if sitting then 0 else 4 * u * (1 - u) * HOP_HEIGHT
			local contact = if sitting
				then 0
				else math.max(0, 1 - u / 0.14) - math.max(0, (u - 0.86) / 0.14)
			local tall, wide = 1 + 0.12 * contact, 1 - 0.08 * contact
			ui.slug.Size = UDim2.fromOffset(SLUG_SIZE * aspect * wide, SLUG_SIZE * tall)
			ui.slug.Position = UDim2.fromOffset(BAR_X + BAR_W * along, BAR_Y + 6 - lift)
			ui.slug.Rotation = if sitting then 0 else math.deg((0.5 - u) * 0.22)
		end
	end)
	return {
		covered = function()
			while not covered do
				task.wait()
			end
		end,
		finish = function()
			done = true
		end,
	}
end

function LoadingScreen.isShowing(): boolean
	return showing
end

return LoadingScreen
