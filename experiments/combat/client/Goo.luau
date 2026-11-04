--!strict
-- Liquid for the UI. Roblox snaps UI to whole pixels, which made slow goo step at what the owner called
-- "0.5 frames a second" (2026-11-02). ImageRectOffset is not snapped, so everything here moves by resampling
-- its texture: thin columns read a wavy surface at any fraction of a pixel, and their heights come from a small
-- ripple simulation, so a hit really travels along the liquid. Drips play a rendered flipbook in which a drop
-- necks, pinches off and falls. Textures and SHARED numbers: tools/ui/build_goo_art.py.
local TweenService = game:GetService("TweenService")
local Theme = require(script.Parent.PvpTheme)
local Fx = require(script.Parent.PvpFx)

local Goo = {}

export type Spec = {
	period: number,
	density: number,
	rows: number,
	top: number,
	window: number,
	edge: number,
	wave: { { number } },
}
-- SHARED.
Goo.Bar = {
	period = 256,
	density = 3.75,
	rows = 32,
	top = 8,
	window = 16,
	edge = 11,
	wave = { { 2, 1.0, 0.4 }, { 3, 0.7, 1.9 }, { 5, 0.35, 4.1 } },
} :: Spec
Goo.Band = {
	period = 480,
	density = 2,
	rows = 46,
	top = 8,
	window = 30,
	edge = 26,
	wave = { { 3, 2.8, 0.4 }, { 5, 1.9, 1.9 }, { 8, 1.1, 4.1 } },
} :: Spec
local CELL_W, CELL_H, CELL_SCALE, CELL_COLS = 16, 52, 3, 21
local FRAMES, DETACH = 126, 78
local ATTACH_ROW = 10
local DETACH_Y = 23.5
local BEAD_SIZE = 6
local WINDOW_TOP, WINDOW_ROWS = 4, 44 -- the part of a cell shown; the rest is room to follow the goo's edge
local MAX_SHIFT = 4
local DRIP_FPS = 30
local REST_LOW, REST_HIGH = 0.6, 4.5
local DRY_RETRACT, DRY_FINISH = 4, 2 -- times normal speed: pulling back up, or finishing after the drop has gone
local FADE_RATE = 12
local BEAD_FALL, BEAD_TIME = 70, 0.6
local SIM_STEP = 1 / 60
local TAU = 2 * math.pi

-- The height of a surface's own wave at x, in the texture's px.
function Goo.waveAt(spec: Spec, x: number): number
	local theta = TAU * x / spec.period
	local total = 0
	for _, part in spec.wave do
		total += part[2] * math.sin(part[1] * theta + part[3])
	end
	return total
end

export type Strip = { labels: { ImageLabel }, col: number, spec: Spec }

-- A row of thin columns that together show one surface.
function Goo.strip(
	parent: Instance,
	image: string,
	spec: Spec,
	col: number,
	x: number,
	y: number,
	width: number,
	z: number
): Strip
	local labels: { ImageLabel } = {}
	local count = math.ceil(width / col)
	for index = 1, count do
		labels[index] = Theme.new("ImageLabel", {
			Name = "Column",
			Position = UDim2.fromOffset(x + (index - 1) * col, y),
			Size = UDim2.fromOffset(col, spec.window),
			BackgroundTransparency = 1,
			Image = Fx.asset(image),
			ImageRectSize = Vector2.new(col * spec.density, spec.window * spec.density),
			ZIndex = z,
			Parent = parent,
		})
	end
	return { labels = labels, col = col, spec = spec }
end

-- Moves a strip: scroll slides the surface sideways; height(i) raises or lowers column i, in design px, down positive.
function Goo.pose(strip: Strip, scroll: number, height: (x: number) -> number)
	local spec, col = strip.spec, strip.col
	local density = spec.density
	for index, label in strip.labels do
		local across = (index - 1) * col
		local x = (scroll + across) % spec.period
		label.ImageRectOffset = Vector2.new(x * density, (spec.top - height(across)) * density)
	end
end

function Goo.tint(strip: Strip, colour: Color3)
	for _, label in strip.labels do
		label.ImageColor3 = colour
	end
end

export type Ripples = { heights: { number }, speeds: { number }, leftover: number }

function Goo.ripples(count: number): Ripples
	local heights, speeds = {}, {}
	for index = 1, count do
		heights[index], speeds[index] = 0, 0
	end
	return { heights = heights, speeds = speeds, leftover = 0 }
end

-- share is along the surface from 0 to 1; amount is a push in design px/step, down positive.
function Goo.push(ripples: Ripples, share: number, amount: number, spread: number)
	local count = #ripples.heights
	local centre = 1 + share * (count - 1)
	for index = 1, count do
		local distance = (index - centre) / spread
		ripples.speeds[index] += amount * math.exp(-distance * distance)
	end
end

function Goo.settle(ripples: Ripples, dt: number, tension: number, restore: number, damping: number)
	local heights, speeds = ripples.heights, ripples.speeds
	local count = #heights
	ripples.leftover += dt
	while ripples.leftover >= SIM_STEP do
		ripples.leftover -= SIM_STEP
		for index = 1, count do
			local left = heights[if index > 1 then index - 1 else index]
			local right = heights[if index < count then index + 1 else index]
			local force = tension * (left + right - 2 * heights[index]) - restore * heights[index]
			speeds[index] = (speeds[index] + force) * damping
		end
		for index = 1, count do
			heights[index] += speeds[index]
		end
	end
end

-- The surface's height at a distance along it, smoothly between the simulated points.
function Goo.sample(ripples: Ripples, share: number): number
	local heights = ripples.heights
	local at = 1 + math.clamp(share, 0, 1) * (#heights - 1)
	local low = math.floor(at)
	local high = math.min(low + 1, #heights)
	return heights[low] + (heights[high] - heights[low]) * (at - low)
end

local function fall(parent: Instance, x: number, y: number, colour: Color3, z: number)
	local bead = Theme.new("ImageLabel", {
		Name = "Bead",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(BEAD_SIZE, BEAD_SIZE),
		BackgroundTransparency = 1,
		Image = Fx.asset("bead"),
		ImageColor3 = colour,
		ZIndex = z,
		Parent = parent,
	})
	local tween = TweenService:Create(
		bead,
		TweenInfo.new(BEAD_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Position = UDim2.fromOffset(x, y + BEAD_FALL), ImageTransparency = 1 }
	)
	tween.Completed:Connect(function()
		bead:Destroy()
	end)
	tween:Play()
end

export type Drip = {
	step: (dt: number, shift: number, wet: boolean, colour: Color3) -> (),
	poke: () -> (),
}

-- A drip hanging from (x, y), the goo's edge at rest. shift follows the edge as it moves, in design px.
function Goo.drip(parent: Instance, x: number, y: number, z: number): Drip
	local home = UDim2.fromOffset(x - CELL_W / 2, y - (ATTACH_ROW - WINDOW_TOP))
	-- A surface swells and waves by up to about 13 px, more than a cell's room, which left drips hanging below the
	-- goo (owner, 2026-11-03). The label moves by whole px, only when it must, and the cell takes the rest smoothly.
	local moved = 0
	local label = Theme.new("ImageLabel", {
		Name = "Drip",
		Position = home,
		Size = UDim2.fromOffset(CELL_W, WINDOW_ROWS),
		BackgroundTransparency = 1,
		Image = Fx.asset("dripBook"),
		ImageRectSize = Vector2.new(CELL_W * CELL_SCALE, WINDOW_ROWS * CELL_SCALE),
		Visible = false,
		ZIndex = z,
		Parent = parent,
	})
	local clock = math.random() * 6
	local frame: number? = nil -- playing, or nil while resting
	local restUntil = clock + math.random() * REST_HIGH
	local see = 1 -- starts hidden, and fades in once there is goo above it
	return {
		step = function(dt: number, shift: number, wet: boolean, colour: Color3)
			clock += dt
			-- With no goo above it a drip must not carry on (owner, 2026-11-02): one still hanging pulls back up
			-- and fades, and no drop falls. One that has already let go finishes its recoil, faster.
			see += ((if wet then 0 else 1) - see) * (1 - math.exp(-FADE_RATE * dt))
			label.Visible = see < 0.98
			label.ImageTransparency = see
			label.ImageColor3 = colour
			local shown = 0
			local playing = frame
			if playing and not wet and playing < DETACH then
				local after = playing - dt * DRIP_FPS * DRY_RETRACT
				if after <= 0 then
					frame = nil
					restUntil = clock + REST_LOW
				else
					frame = after
					shown = math.floor(after)
				end
			elseif playing then
				local speed = if wet then DRIP_FPS else DRIP_FPS * DRY_FINISH
				local after = playing + dt * speed
				if playing < DETACH and after >= DETACH then
					fall(parent, x, y + shift + DETACH_Y, colour, z)
				end
				if after >= FRAMES then
					frame = nil
					restUntil = clock + REST_LOW + math.random() * (REST_HIGH - REST_LOW)
				else
					frame = after
					shown = math.floor(after)
				end
			elseif wet and clock >= restUntil then
				frame = 0
			end
			local within = MAX_SHIFT - 0.5
			local keep = math.clamp(moved, math.ceil(shift - within), math.floor(shift + within))
			if keep ~= moved then
				moved = keep
				label.Position = home + UDim2.fromOffset(0, moved)
			end
			label.ImageRectOffset = Vector2.new(
				(shown % CELL_COLS) * CELL_W * CELL_SCALE,
				(math.floor(shown / CELL_COLS) * CELL_H + WINDOW_TOP - (shift - moved)) * CELL_SCALE
			)
		end,
		poke = function()
			if not frame then
				restUntil = 0
			end
		end,
	}
end

return Goo
