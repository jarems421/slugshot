--!strict
-- The health bar as real liquid (owner, 2026-11-02: dripping goo with "a very fluid inside", "slightly more
-- swashy"). A hit sends ripples along the surface and tips the whole level so it swashes from end to end; the
-- level is a spring, so the end surges past its new mark and comes back. See Goo for how it stays smooth. The
-- settings sliders use the same liquid, without drips (owner, 2026-11-02: "just the swooshingness").
local RunService = game:GetService("RunService")
local Theme = require(script.Parent.PvpTheme)
local Fx = require(script.Parent.PvpFx)
local Goo = require(script.Parent.Goo)

local GooBar = {}

export type Bar = { set: (share: number) -> () }
export type Options = {
	col: number?, -- wider columns cost less; a slider does not need the health bar's detail
	colour: Color3?, -- a fixed colour; otherwise health colours, coral when low
	empty: Color3?,
	drips: boolean?,
	lost: boolean?, -- flash what was just lost
	dragged: boolean?, -- moved by hand: slosh away from the direction of travel, in proportion to it
	behindMark: boolean?, -- the end never passes the value, so it stays under a slider's knob (owner, 2026-11-02)
	active: (() -> boolean)?, -- nothing runs while this is false
}

local INSET = 3 -- the ink around the liquid
local COL = 4
local BACK_COL = 8 -- the widest the texture allows
local EDGE_W, EDGE_TIP = 12, 10.5 -- the rounded end's mask, and how far in its curve reaches
local LOW_HEALTH = 0.3
local EMPTY = Color3.fromRGB(20, 23, 28)
local LOST = Color3.fromRGB(214, 58, 58) -- red for the health you just lost (owner)
local BACK_SHADE, DRIP_SHADE, SHINE = 0.7, 0.9, Color3.new(1, 1, 1)
local TAU = 2 * math.pi

local SCROLL_FRONT, SCROLL_BACK = 15, -10 -- texture px per second
local SWELL, SWELL_RATE = 0.9, 0.31
local TENSION, RESTORE, DAMPING = 0.3, 0.004, 0.985
local LAP_LOW, LAP_HIGH = 1.2, 3 -- seconds between small laps, so it is never still
local LAP_PUSH = 0.1
local HIT_PUSH, HIT_PUSH_MIN = 1.4, 0.32
local MAX_HEIGHT = 7
local LEVEL_FREQ, LEVEL_DAMP = 2.6, 0.3 -- underdamped: it overshoots and swashes back
local TILT_FREQ, TILT_DAMP = 0.9, 0.16
local TILT_KICK = 30 -- design px/s for a full bar of damage
local TILT_KICK_MIN = 6
local DRAG_TILT, DRAG_PUSH = 90, 3.5 -- for a full bar's travel by hand
local DRAG_PUSH_MAX, DRAG_SPREAD = 0.3, 8
local MAX_TILT = 6
local TIME_STEP = 1 / 120
local TRAIL_HOLD, TRAIL_RATE = 0.25, 3.5
local COLOUR_RATE = 5
local DRIP_SPOTS = { 0.07, 0.24, 0.44, 0.63, 0.82 }
local DRIP_DRY_MARGIN = 0.02 -- a drip dries up once the level passes it

local function shade(colour: Color3, amount: number): Color3
	return Color3.new(colour.R * amount, colour.G * amount, colour.B * amount)
end

function GooBar.new(
	parent: Instance,
	position: Vector2,
	width: number,
	height: number,
	options: Options?
): Bar
	local settings: Options = options or {}
	local col = settings.col or COL
	local emptyColour = settings.empty or EMPTY
	local fixed = settings.colour
	local withLost = settings.lost ~= false
	local dragged = settings.dragged == true
	local behindMark = settings.behindMark == true
	local active = settings.active
	local inner = Theme.new("Frame", {
		Name = "Liquid",
		Position = UDim2.fromOffset(position.X + INSET, position.Y + INSET),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = emptyColour,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 1,
		Parent = parent,
	})
	local back = Goo.strip(inner, "barBack", Goo.Bar, BACK_COL, 0, 0, width, 2)
	local front = Goo.strip(inner, "barFront", Goo.Bar, col, 0, 0, width, 3)
	local shine = Goo.strip(inner, "barShine", Goo.Bar, col, 0, 0, width, 4)
	Goo.tint(shine, SHINE)

	local function cover(name: string, colour: Color3, z: number): (ImageLabel, Frame)
		local edge = Theme.new("ImageLabel", {
			Name = name .. "Edge",
			Size = UDim2.fromOffset(EDGE_W, height),
			BackgroundTransparency = 1,
			Image = Fx.asset("edge"),
			ImageColor3 = colour,
			ZIndex = z,
			Parent = inner,
		})
		local rest = Theme.new("Frame", {
			Name = name,
			Size = UDim2.fromOffset(width + EDGE_W, height),
			BackgroundColor3 = colour,
			BorderSizePixel = 0,
			ZIndex = z,
			Parent = inner,
		})
		return edge, rest
	end
	-- Just-lost health shows red for a moment before draining away.
	local lostEdge, lostFill = cover("Lost", LOST, 7)
	local emptyEdge, empty = cover("Empty", emptyColour, 8)

	-- The ink outline lies over the liquid and rounds its corners.
	Theme.new("ImageLabel", {
		Name = "Frame",
		Position = UDim2.fromOffset(position.X, position.Y),
		Size = UDim2.fromOffset(width + INSET * 2, height + INSET * 2),
		BackgroundTransparency = 1,
		Image = Fx.asset("barFrame"),
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(48, 40, 112, 48),
		SliceScale = 0.25,
		ZIndex = 5,
		Parent = parent,
	})
	-- Drips leave through the bottom of the outline.
	local underside = position.Y + height + INSET * 2
	local drips: { { at: number, drip: Goo.Drip } } = {}
	local spots: { number } = if settings.drips == false then {} else DRIP_SPOTS
	for _, at in spots do
		table.insert(drips, {
			at = at,
			drip = Goo.drip(parent, position.X + INSET + at * width, underside, 6),
		})
	end

	local ripples = Goo.ripples(math.ceil(width / col))
	local target, level, levelSpeed, lost = 1, 1, 0, 1
	local holdLost = 0
	local tilt, tiltSpeed = 0, 0
	local kickSide = 1
	local frontScroll, backScroll = 0, 0
	local clock = math.random() * 20
	local leftover = 0
	local nextLap = LAP_LOW
	local colour = fixed or Theme.Health
	local started = false
	Goo.tint(front, colour)
	Goo.tint(back, shade(colour, BACK_SHADE))

	local function surface(across: number): number
		local share = across / width
		local swell = SWELL * math.sin(TAU * SWELL_RATE * clock + share * 5)
		local total = Goo.sample(ripples, share) + swell + tilt * (share - 0.5) * 2
		return math.clamp(total, -MAX_HEIGHT, MAX_HEIGHT)
	end
	local function backSurface(across: number): number
		-- The back wave answers the front one, a little behind and opposite, so the surface laps.
		local share = across / width
		return math.clamp(
			-Goo.sample(ripples, share) * 0.5
				- tilt * (share - 0.5) * 1.4
				+ SWELL * math.sin(TAU * SWELL_RATE * 0.8 * clock + 2 - share * 4),
			-MAX_HEIGHT,
			MAX_HEIGHT
		)
	end

	-- The curve's tip sits at the level, and slides off the end when the bar is full.
	local function place(edge: ImageLabel, rest: Frame, share: number)
		local at = math.clamp(share, 0, 1)
		local x = at * (width + 2) - EDGE_TIP * (1 - at)
		edge.Position = UDim2.fromOffset(x, 0)
		rest.Position = UDim2.fromOffset(x + EDGE_W, 0)
	end

	RunService.RenderStepped:Connect(function(rawDt: number)
		if active and not active() then
			return
		end
		local dt = math.min(rawDt, 1 / 20) -- a long frame must not fling the springs
		clock += dt
		leftover += dt
		while leftover >= TIME_STEP do
			leftover -= TIME_STEP
			local w = TAU * LEVEL_FREQ
			levelSpeed += (w * w * (target - level) - 2 * LEVEL_DAMP * w * levelSpeed) * TIME_STEP
			level += levelSpeed * TIME_STEP
			w = TAU * TILT_FREQ
			tiltSpeed += (-w * w * tilt - 2 * TILT_DAMP * w * tiltSpeed) * TIME_STEP
			tilt += tiltSpeed * TIME_STEP
		end
		nextLap -= dt
		if nextLap <= 0 then
			nextLap = LAP_LOW + math.random() * (LAP_HIGH - LAP_LOW)
			Goo.push(ripples, math.random(), (math.random() - 0.5) * 2 * LAP_PUSH, 3)
		end
		Goo.settle(ripples, dt, TENSION, RESTORE, DAMPING)
		holdLost -= dt
		if lost <= target or not withLost then
			lost = target
		elseif holdLost <= 0 then
			lost += (target - lost) * (1 - math.exp(-TRAIL_RATE * dt))
		end

		frontScroll += SCROLL_FRONT * dt
		backScroll += SCROLL_BACK * dt
		Goo.pose(back, backScroll, backSurface)
		Goo.pose(front, frontScroll, surface)
		Goo.pose(shine, frontScroll, surface)

		-- The curve's tip travels a little further than the share, so a mark is scaled to land exactly on it.
		local shown = if behindMark
			then math.min(level, target) * width / (width + 2 + EDGE_TIP)
			else level
		place(emptyEdge, empty, if withLost then math.max(level, lost) else shown)
		place(lostEdge, lostFill, level)
		local showLost = withLost and lost - level > 0.004
		lostEdge.Visible, lostFill.Visible = showLost, showLost

		local wanted = fixed or (if target <= LOW_HEALTH then Theme.HealthLow else Theme.Health)
		if colour ~= wanted then
			colour = colour:Lerp(wanted, 1 - math.exp(-COLOUR_RATE * dt))
			if math.abs(colour.R - wanted.R) + math.abs(colour.G - wanted.G) < 0.004 then
				colour = wanted
			end
			Goo.tint(front, colour)
			Goo.tint(back, shade(colour, BACK_SHADE))
		end
		local dripColour = shade(colour, DRIP_SHADE)
		-- Read the real health too, so a drip dries the moment it is lost, not when the swash passes it.
		local wetTo = math.min(level, target) - DRIP_DRY_MARGIN
		for _, entry in drips do
			entry.drip.step(dt, 0, entry.at < wetTo, dripColour)
		end
	end)

	local function set(share: number)
		local new = math.clamp(share, 0, 1)
		if not started then
			started = true
			target, level, lost = new, new, new
			return
		end
		local change = target - new
		target = new
		if change == 0 then
			return
		end
		if dragged then
			tiltSpeed += change * DRAG_TILT
			tilt = math.clamp(tilt, -MAX_TILT, MAX_TILT)
			-- A broad, capped push: a sharp one shows as steps between the columns on a big jump.
			Goo.push(
				ripples,
				new,
				math.min(math.abs(change) * DRAG_PUSH, DRAG_PUSH_MAX),
				DRAG_SPREAD
			)
			return
		end
		kickSide = -kickSide
		local size = math.abs(change)
		tiltSpeed += kickSide * math.max(TILT_KICK * size, TILT_KICK_MIN)
		local push = math.max(HIT_PUSH * size, HIT_PUSH_MIN)
		Goo.push(ripples, math.clamp(new, 0.1, 0.9), push, 4)
		Goo.push(ripples, math.clamp(new * 0.4, 0.05, 0.9), -push * 0.6, 3)
		if change > 0 then
			-- Damage: the shake shakes drops loose.
			holdLost = TRAIL_HOLD
			for _, entry in drips do
				if entry.at < new and math.random() < 0.6 then
					entry.drip.poke()
				end
			end
		end
	end
	return { set = set }
end

return GooBar
