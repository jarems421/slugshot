--!strict
-- The slugs standing in the HUD's canisters, alive (owner, 2026-11-15: "idle breathing chilling animations, idle facial
-- expressions especially for aqua beak"; the earlier moves made on the flat picture were "way too stiff").
--
-- Each slug's idle is its own performance on its real model (SlugIdle), captured in the world renderer as a looping
-- flipbook (tools/ui/build_canister_flipbooks.py), so the canister keeps the sharp, lit look of the stills: 176 frames
-- over the 6 s loop, about 29 a second (12 read as "choppy clips", owner, 2026-11-16). A slug without a flipbook shows
-- its still.
--
-- Two sizes (owner, 2026-11-16: "too low resolution and not crisp enough", without making the HUD bigger): frames at
-- the glass's design size, drawn at exactly their own pixel size on whole screen pixels wherever the glass is about
-- that size (1080p and near it; stretched even 3%, they blurred), and frames at twice that, on two sheets, where it is
-- bigger.
--
-- Each frame fades into the next as it plays (a second label on top shows the next frame, more opaque as its time
-- comes), so the motion flows between frames instead of stepping at 29 a second against the screen's 60 ("really poor
-- stocky transitions", owner, 2026-11-16).
local RunService = game:GetService("RunService")

local CanisterIdle = {}

local FRAMES = 176
local LOOP = 6 -- seconds, SlugIdle.LOOP
-- Frame size, frames a row and frames a sheet for each size.
local SMALL = { frame = Vector2.new(46, 62), perRow = 22, perSheet = 176 }
local BIG = { frame = Vector2.new(92, 124), perRow = 11, perSheet = 88 }
local SMALL_UP_TO = 1.3 -- the small frames serve while the glass is at most this much bigger than they are

type Set = { frame: Vector2, perRow: number, perSheet: number }
-- One label per sheet for the frame now (base) and one for the next (blend), for each size.
type Layer = { base: { ImageLabel }, blend: { ImageLabel } }
type Entry = { small: Layer?, big: Layer?, holder: GuiObject, clock: number }

local entries: { Entry } = {}
local connection: RBXScriptConnection? = nil

local function hide(layer: Layer?)
	if layer then
		for _, label in layer.base do
			label.Visible = false
		end
		for _, label in layer.blend do
			label.Visible = false
		end
	end
end

local function place(labels: { ImageLabel }, set: Set, i: number): ImageLabel
	local sheet = i // set.perSheet + 1
	local k = i % set.perSheet
	for n, label in labels do
		label.Visible = n == sheet
	end
	local label = labels[sheet]
	label.ImageRectOffset =
		Vector2.new((k % set.perRow) * set.frame.X, (k // set.perRow) * set.frame.Y)
	return label
end

local function play(layer: Layer, set: Set, at: number)
	local i = math.floor(at) % FRAMES
	place(layer.base, set, i)
	local next = place(layer.blend, set, (i + 1) % FRAMES)
	next.ImageTransparency = 1 - (at - math.floor(at))
end

-- Lays the small frames at exactly their pixel size on whole screen pixels, standing at the bottom middle of the glass.
local function snap(layer: Layer, holder: GuiObject)
	local size, position = holder.AbsoluteSize, holder.AbsolutePosition
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	-- In shares of the holder, since UDim offsets are whole numbers and the HUD's scale is not.
	local left = math.floor(position.X + (size.X - SMALL.frame.X) / 2 + 0.5)
	local top = math.floor(position.Y + size.Y - SMALL.frame.Y + 0.5)
	local offset = UDim2.fromScale((left - position.X) / size.X, (top - position.Y) / size.Y)
	local fit = UDim2.fromScale(SMALL.frame.X / size.X, SMALL.frame.Y / size.Y)
	for _, labels in { layer.base, layer.blend } do
		for _, label in labels do
			label.Position = offset
			label.Size = fit
		end
	end
end

local function show(entry: Entry)
	local at = entry.clock / LOOP * FRAMES
	local small = entry.small
		and (not entry.big or entry.holder.AbsoluteSize.Y <= SMALL.frame.Y * SMALL_UP_TO)
	if small and entry.small then
		hide(entry.big)
		snap(entry.small, entry.holder)
		play(entry.small, SMALL, at)
	elseif entry.big then
		hide(entry.small)
		play(entry.big, BIG, at)
	end
end

local function step(dt: number)
	for i = #entries, 1, -1 do
		local entry = entries[i]
		if not entry.holder.Parent then
			table.remove(entries, i)
			continue
		end
		entry.clock += dt
		if entry.holder.Visible then
			show(entry)
		end
	end
	if #entries == 0 and connection then
		connection:Disconnect()
		connection = nil
	end
end

local function label(holder: GuiObject, image: string, frame: Vector2?, z: number?): ImageLabel
	local item = Instance.new("ImageLabel")
	item.Name = "Slug"
	item.Size = UDim2.fromScale(1, 1)
	item.BackgroundTransparency = 1
	item.ZIndex = holder.ZIndex + (z or 0)
	item.Image = image
	if frame then
		item.ImageRectSize = frame
	end
	item.Parent = holder
	return item
end

local function layer(holder: GuiObject, sheets: { string }, frame: Vector2): Layer
	local out: Layer = { base = {}, blend = {} }
	for _, sheet in sheets do
		table.insert(out.base, label(holder, sheet, frame, 0))
		table.insert(out.blend, label(holder, sheet, frame, 1))
	end
	return out
end

-- Fills `holder` (the size of the glass) with the slug: its flipbook if it has one (`small`, one sheet of design-size
-- frames, and/or `big`, two sheets of double-size frames), else the still `image`. Each canister starts at its own
-- point in the loop, so they don't move in step.
function CanisterIdle.mount(holder: Frame, image: string, small: string, big: { string })
	local bigLayer = if big[1] ~= "" and big[2] ~= "" then layer(holder, big, BIG.frame) else nil
	local smallLayer = if small ~= "" then layer(holder, { small }, SMALL.frame) else nil
	if not (smallLayer or bigLayer) then
		label(holder, image)
		return
	end
	local entry: Entry =
		{ small = smallLayer, big = bigLayer, holder = holder, clock = math.random() * LOOP }
	show(entry)
	table.insert(entries, entry)
	if not connection then
		connection = RunService.RenderStepped:Connect(step)
	end
end

return CanisterIdle
