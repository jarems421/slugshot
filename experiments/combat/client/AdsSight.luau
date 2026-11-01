--!strict
-- The holographic sight: a small pod on the blaster opens when aiming, then projects a clear
-- pane with a black, incomplete frame. The mechanism moves by weld, so the first-person gun
-- copies follow; the hologram is client-only and rides on the visible gun. Timing runs on its
-- own clock, so aiming itself is never held up. The crosshair stays the player's normal HUD one.
-- There is no glass: like the reference, only the frame is drawn and the view stays clear.
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local movement = player:WaitForChild("PlayerScripts"):WaitForChild("MovementSandbox")
local Ads = (require :: any)(movement:WaitForChild("Ads"))
local Tuning = (require :: any)(movement:WaitForChild("Tuning"))

local AdsSight = {}

local DOOR_ANGLE = math.rad(112)
local DOOR_HINGE = 0.0425 -- from each door's centre to its outer edge
local EMITTER_RISE = 0.05
local PRONG_SPREAD = math.rad(34)
local FRAME_WIDTH = 0.008
local HALF_WIDTH, HALF_HEIGHT = 0.252, 0.196
local FRAME_START_SCALE = 0.45 -- the frame blooms out of the pod from this size
local INK = Color3.fromRGB(14, 14, 18)
-- One quadrant of the frame, as a share of half-width and half-height, from the bottom gap
-- round to the top gap; a gap at the side splits it into two brackets.
local BOTTOM = {
	Vector2.new(0.24, -1),
	Vector2.new(0.52, -1),
	Vector2.new(1, -0.66),
	Vector2.new(1, -0.31),
}
local TOP =
	{ Vector2.new(1, 0.31), Vector2.new(1, 0.66), Vector2.new(0.52, 1), Vector2.new(0.24, 1) }

type Stage = { from: number, to: number }
-- Generous overlaps, so each part is already moving as the last settles.
local DOORS: Stage = { from = 0, to = 0.42 }
local EMITTER: Stage = { from = 0.14, to = 0.56 }
local PRONGS: Stage = { from = 0.28, to = 0.68 }
local BLOOM: Stage = { from = 0.34, to = 1 }
local TRACE: Stage = { from = 0.34, to = 0.92 }

type Bar = { part: BasePart, a: Vector2, b: Vector2, start: number, finish: number }
local bars: { Bar } = {}
local folder: Folder? = nil
local open = 0

local function stage(s: Stage): number
	local t = math.clamp((open - s.from) / (s.to - s.from), 0, 1)
	return t * t * t * (t * (t * 6 - 15) + 10)
end

local function piece(class: string, color: Color3): BasePart
	local part = Instance.new(class) :: BasePart
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.CastShadow = false
	part.Transparency = 1
	part.Parent = folder
	return part
end

local function build(camera: Camera)
	local holder = Instance.new("Folder")
	holder.Name = "AdsHologram"
	holder.Parent = camera
	folder = holder
	-- Each side traces continuously from the emitter upward, as one line drawing itself.
	local function trace(path: { Vector2 }, sign: number, walked: number, total: number): number
		for i = 1, #path - 1 do
			local a = path[i] * Vector2.new(sign, 1)
			local b = path[i + 1] * Vector2.new(sign, 1)
			local length = (path[i + 1] - path[i]).Magnitude
			table.insert(bars, {
				part = piece("Part", INK),
				a = a,
				b = b,
				start = walked / total,
				finish = (walked + length) / total,
			})
			walked += length
		end
		return walked
	end
	local function lengthOf(path: { Vector2 }): number
		local sum = 0
		for i = 1, #path - 1 do
			sum += (path[i + 1] - path[i]).Magnitude
		end
		return sum
	end
	local total = lengthOf(BOTTOM) + lengthOf(TOP)
	for _, sign in { -1, 1 } do
		trace(TOP, sign, trace(BOTTOM, sign, 0, total), total)
	end
end

local function hideHologram()
	for _, bar in bars do
		bar.part.Transparency = 1
	end
end

local function showHologram(gun: CFrame)
	local T = Tuning.values
	local w, h = HALF_WIDTH * T.adsPaneSize, HALF_HEIGHT * T.adsPaneSize
	-- Centred on the crosshair, whatever the size.
	local base = gun * CFrame.new(0, T.adsGunDown, T.adsPaneBack)
	-- The whole frame blooms up out of the pod at its bottom edge while each side draws itself.
	local bloom = stage(BLOOM)
	local scale = FRAME_START_SCALE + (1 - FRAME_START_SCALE) * bloom
	local drawn = stage(TRACE)
	local function place(point: Vector2): Vector3
		return Vector3.new(point.X * w * scale, -h + (point.Y * h + h) * scale, 0)
	end
	for _, bar in bars do
		local amount = math.clamp((drawn - bar.start) / (bar.finish - bar.start), 0, 1)
		if amount <= 0 then
			bar.part.Transparency = 1
			continue
		end
		local a, b = place(bar.a), place(bar.b)
		local tip = a:Lerp(b, amount)
		local span = tip - a
		-- A hair over-long, so the mitred corners close.
		bar.part.Size = Vector3.new(span.Magnitude + FRAME_WIDTH, FRAME_WIDTH, FRAME_WIDTH)
		bar.part.CFrame = base
			* CFrame.new((a + tip) / 2)
			* CFrame.Angles(0, 0, math.atan2(span.Y, span.X))
		-- Fades in as it draws, and the frame as a whole fades with the open and close.
		bar.part.Transparency = 1 - math.min(amount * 2.5, 1) * math.min(bloom * 2.5, 1)
	end
end

-- The pod's rest welds, read once per tool before anything moves them.
type Rest = { [string]: { weld: Weld, base: CFrame, part: BasePart } }
local rests: { [Tool]: Rest } = setmetatable({}, { __mode = "k" }) :: any

local function restOf(tool: Tool): Rest
	local known = rests[tool]
	if known then
		return known
	end
	local rest: Rest = {}
	do
		for _, name in { "AdsDoorL", "AdsDoorR", "AdsEmitter", "AdsLens", "AdsProngL", "AdsProngR" } do
			local part = tool:FindFirstChild(name)
			local weld = part and part:FindFirstChildOfClass("Weld")
			if part and part:IsA("BasePart") and weld then
				rest[name] = { weld = weld, base = weld.C0, part = part }
			end
		end
		rests[tool] = rest
	end
	return rest
end

local DOOR_SIDES: { [string]: number } = { AdsDoorL = -1, AdsDoorR = 1 }
local PRONG_SIDES: { [string]: number } = { AdsProngL = -1, AdsProngR = 1 }

local function moveMechanism(tool: Tool)
	local rest = restOf(tool)
	local doors = stage(DOORS) * DOOR_ANGLE
	local rise = stage(EMITTER) * EMITTER_RISE
	local prongs = stage(PRONGS)
	for name, sign in DOOR_SIDES do
		local item = rest[name]
		if item then
			-- Each door swings up about its outer edge, like a clamshell.
			local hinge = CFrame.new(sign * DOOR_HINGE, 0, 0)
			item.weld.C0 = item.base * hinge * CFrame.Angles(0, 0, -sign * doors) * hinge:Inverse()
		end
	end
	local emitter = rest.AdsEmitter
	if emitter then
		emitter.weld.C0 = emitter.base * CFrame.new(0, rise, 0)
	end
	local lens = rest.AdsLens
	if lens then
		lens.weld.C0 = lens.base * CFrame.new(0, rise, 0)
		lens.part.Transparency = 1 - stage(EMITTER)
	end
	for name, sign in PRONG_SIDES do
		local item = rest[name]
		if item then
			item.weld.C0 = item.base
				* CFrame.new(0, rise + prongs * 0.035, 0)
				* CFrame.Angles(0, 0, -sign * PRONG_SPREAD * prongs)
			item.part.Transparency = if prongs > 0 then 0 else 1
		end
	end
end

-- `gun` is the visible gun's handle frame while in first person; nil hides the hologram.
function AdsSight.update(camera: Camera, tool: Tool?, gun: CFrame?, dt: number)
	local target = if Ads.aiming() and gun then 1 else 0
	if target == 0 and open == 0 then
		return
	end
	local rate = if target == 1
		then 1 / Tuning.values.adsOpenTime
		else 1 / Tuning.values.adsCloseTime
	open = if target == 1 then math.min(open + rate * dt, 1) else math.max(open - rate * dt, 0)
	if tool then
		moveMechanism(tool)
	end
	if not folder then
		build(camera)
	end
	if gun and open > 0 then
		showHologram(gun)
	else
		hideHologram()
	end
end

return AdsSight
