--!strict
-- Original draw/holster flourishes. Degrees/studs, no root motion or input locks.
-- Grip frame (R6): X out from the hand, -Z along the barrel (down the arm, so a
-- hanging arm holds the gun muzzle-down at the hip), Y the gun's top. Positive
-- pitch rolls the muzzle forward over the trigger finger.
-- Row: time, wrist pitch/yaw/roll, grip offset x/y/z, shoulder pitch/yaw/roll,
-- visibility. Every track ends on whole turns so it settles without a jump; the
-- held pose itself comes from the hold style, which these only flourish over.
-- Holstered (HolsterMode setting), the gun either hangs at the right hip (Hip) or
-- shrinks away into it (Vanish); a holster moves it there during StowAt and a draw
-- lifts it from wherever it is (Unstow).
local Motion = {}

-- Spins turn about the trigger guard, a little ahead of the fist. A spinning gun
-- lies along the arm, so it is carried out past the side of the block hand (x) or
-- in front of it (y) while it turns, or it would sweep through the forearm.
local PIVOT = Vector3.new(0, 0.1, -0.3)

export type Track = { { number } }
export type Style = {
	Label: string,
	Draw: Track,
	Holster: Track,
	-- Optional moving variants, blended in by speed: the third-person camera sits
	-- behind and above, where a low flourish in front of the hip is hidden (owner).
	RunDraw: Track?,
	RunHolster: Track?,
	StowAt: { number }?,
}

Motion.Styles = {
	-- A small toss out of the hand, flipped forward (muzzle up over the front: a
	-- backflip read as flipping downward from behind) and caught with a dip. The arm
	-- carries it (owner: arm too static): lifts off the hip, flicks up to launch, rides
	-- up under it, gives on the catch and rebounds. Moving, the arm rises further
	-- forward (not out: owner wants it neither flared nor tucked) and the toss rises
	-- clear of the body. The arm drops back to its own pose while the gun is stowed.
	Toss = {
		Label = "Flip toss",
		Draw = {
			{ 0.00, 0, 0, 0, 0, 0, 0, -6, 0, 2, 1 },
			{ 0.06, -20, 0, 0, 0, 0.05, 0, -10, 0, 4, 1 },
			{ 0.16, 40, 0, 0, 0.3, 0.35, 0, 38, -4, 4, 1 },
			{ 0.30, 250, 0, 0, 0.35, 0.5, 0, 30, -2, 5, 1 },
			{ 0.40, 365, 0, 0, 0.05, 0.05, 0, -10, 2, 2, 1 },
			{ 0.48, 361, 0, 0, 0, 0, 0, 5, 0, -1, 1 },
			{ 0.56, 360, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
		},
		RunDraw = {
			{ 0.00, 0, 0, 0, 0, 0, 0, -8, 0, 2, 1 },
			{ 0.06, -20, 0, 0, 0.1, 0.05, 0, -14, 0, 5, 1 },
			{ 0.16, 40, 0, 0, 0.45, 0.6, 0, 62, -6, 8, 1 },
			{ 0.30, 250, 0, 0, 0.55, 1.0, 0, 68, -4, 9, 1 },
			{ 0.40, 365, 0, 0, 0.1, 0.1, 0, 22, 2, 4, 1 },
			{ 0.48, 361, 0, 0, 0, 0, 0, 6, 0, -1, 1 },
			{ 0.56, 360, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
		},
		Holster = {
			{ 0.00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
			{ 0.08, 25, 0, 0, 0, 0.05, 0, 22, -4, 4, 1 },
			{ 0.18, -60, 0, 0, 0.3, 0.3, 0, 30, -4, 6, 1 },
			{ 0.30, -300, 0, 0, 0.3, 0.35, 0, 10, 0, 6, 1 },
			{ 0.38, -360, 0, 0, 0, 0, 0, -14, 2, 3, 1 },
			{ 0.46, -360, 0, 0, 0, 0, 0, -6, 0, 1, 1 },
			{ 0.56, -360, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
		},
		RunHolster = {
			{ 0.00, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
			{ 0.08, 25, 0, 0, 0, 0.05, 0, 45, -4, 8, 1 },
			{ 0.18, -60, 0, 0, 0.45, 0.55, 0, 62, -6, 10, 1 },
			{ 0.30, -300, 0, 0, 0.45, 0.8, 0, 40, 0, 9, 1 },
			{ 0.38, -360, 0, 0, 0, 0, 0, -10, 2, 4, 1 },
			{ 0.46, -360, 0, 0, 0, 0, 0, -6, 0, 1, 1 },
			{ 0.56, -360, 0, 0, 0, 0, 0, 0, 0, 0, 1 },
		},
		StowAt = { 0.36, 0.5 },
	},
} :: { [string]: Style }
-- Owner (2026-10-31): Flip toss is the single draw/holster flourish; the Twirl,
-- Pinwheel and Snap candidates and their J switch were removed.
Motion.Default = "Toss"

-- The free (left) arm swings against the gun arm's pitch by this fraction.
Motion.CounterSwing = 0.3
-- Horizontal speed (studs/s) at which the moving variant fully applies.
Motion.RunSpeed = 14

-- An interrupted flourish blends into the new one rather than snapping (offhand spam
-- stays clean). Every flourish plays at its authored speed: speeding up back-to-back
-- switches made the flip's pace depend on click timing (owner, 2026-10-31).
Motion.Blend = 0.08
-- Playback rate for every flourish, applied to the whole timeline (owner: a tad faster).
Motion.Speed = 1.12
-- Seconds a draw takes to lift the gun from the hip (or mid-holster) into the hand.
Motion.Unstow = 0.14
-- Holster settings, cycled by the player. Hip: a classic hip holster (owner's
-- reference photos): muzzle down and canted forward, grip up and back at the belt,
-- side facing out. Rides the right leg (a torso mount stayed put while the leg swung
-- forward, so it looked left behind; owner). Centred on the hip, flush against the
-- outside of the leg, its
-- top just under the resting hand: tucked behind the arm it read as floating and
-- pulled the arm back (owner, who accepts the grip tip touching the arm at times).
-- Kept near full size (owner); it reaches down the thigh. The hand dips to it (Reach) as a draw starts and
-- as a holster stows. Vanish: shrinks to VanishScale and fades into the same spot, the
-- arm keeping its own motion.
Motion.Modes = { "Hip", "Vanish" }
Motion.DefaultMode = "Hip"
Motion.Hip = {
	Above = 0.45, -- top of the holster over the hip joint (the leg's top face)
	Cant = 15, -- degrees the muzzle tilts forward
	Scale = 0.95, -- owner: keep the size, at most a barely visible reduction
	Gap = 0.02, -- off the leg's outer face
	Back = 0.1, -- holster centre behind the hip's centre line
	-- Shoulder offset (pitch, yaw, roll degrees) taking the hand to the grip.
	Reach = { -6, 0, 2 },
	ReachIn = 0.1, -- seconds before the stow window the hand heads for the holster
	ReachOut = 0.1, -- seconds the hand takes to leave it
}
Motion.VanishScale = 0.3

local ANGLES = { 1, 2, 3, 7, 8, 9 }

function Motion.style(name: any): Style
	return Motion.Styles[name] or Motion.Styles[Motion.Default]
end

function Motion.tracks(style: Style, drawing: boolean): (Track, Track)
	if drawing then
		return style.Draw, style.RunDraw or style.Draw
	end
	return style.Holster, style.RunHolster or style.Holster
end

function Motion.length(track: Track): number
	return track[#track][1]
end

function Motion.stowAt(style: Style): (number, number)
	if style.StowAt then
		return style.StowAt[1], style.StowAt[2]
	end
	local length = Motion.length(style.Holster)
	return length - 0.12, length
end

local function interpolate(track: Track, index: number, column: number, x: number): number
	local first, last = track[index], track[index + 1]
	local before, after = track[math.max(1, index - 1)], track[math.min(#track, index + 2)]
	local duration = last[1] - first[1]
	local startSlope = if index == 1
		then 0
		else (last[column] - before[column]) / (last[1] - before[1]) * duration
	local endSlope = if index + 1 == #track
		then 0
		else (after[column] - first[column]) / (after[1] - first[1]) * duration
	local x2, x3 = x * x, x * x * x
	local value = (2 * x3 - 3 * x2 + 1) * first[column]
		+ (x3 - 2 * x2 + x) * startSlope
		+ (-2 * x3 + 3 * x2) * last[column]
		+ (x3 - x2) * endSlope
	return math.clamp(
		value,
		math.min(first[column], last[column]),
		math.max(first[column], last[column])
	)
end

-- The ten channel values at elapsed seconds.
function Motion.values(track: Track, elapsed: number): { number }
	local index = 1
	while index < #track - 1 and elapsed > track[index + 1][1] do
		index += 1
	end
	local first, last = track[index], track[index + 1]
	local x = math.clamp((elapsed - first[1]) / (last[1] - first[1]), 0, 1)
	local values = table.create(10, 0)
	for column = 2, 11 do
		values[column - 1] = interpolate(track, index, column, x)
	end
	return values
end

function Motion.smooth(alpha: number): number
	alpha = math.clamp(alpha, 0, 1)
	return alpha * alpha * (3 - 2 * alpha)
end

-- Ease from an interrupted pose; angles take the short way round so a half-done
-- spin never unwinds backwards.
function Motion.blend(from: { number }, to: { number }, alpha: number): { number }
	local out = table.clone(to)
	local t = Motion.smooth(alpha)
	for column = 1, 10 do
		local start = from[column]
		if table.find(ANGLES, column) then
			start = to[column] + ((start - to[column] + 180) % 360 - 180)
		end
		out[column] = start + (to[column] - start) * t
	end
	return out
end

-- Standing and moving variants sampled together, mixed by moving (0-1).
function Motion.sample(stand: Track, run: Track, elapsed: number, moving: number): { number }
	local values = Motion.values(stand, elapsed)
	if run == stand or moving <= 0 then
		return values
	end
	local fast = Motion.values(run, elapsed)
	for column = 1, 10 do
		values[column] += (fast[column] - values[column]) * moving
	end
	return values
end

-- Wrist (applied between the hand's grip frame and the tool's Grip), gun and free
-- shoulder offsets in torso axes, and visibility.
function Motion.frames(values: { number }): (CFrame, CFrame, CFrame, number)
	local wrist = CFrame.new(values[4], values[5], values[6])
		* CFrame.new(PIVOT)
		* CFrame.Angles(math.rad(values[1]), math.rad(values[2]), math.rad(values[3]))
		* CFrame.new(-PIVOT)
	local arm = CFrame.Angles(math.rad(values[7]), math.rad(values[8]), math.rad(values[9]))
	local counter = CFrame.Angles(-math.rad(values[7]) * Motion.CounterSwing, 0, 0)
	return wrist, arm, counter, math.clamp(values[10], 0, 1)
end

-- Handle frame relative to the right leg for the holstered gun, and its scale, from the
-- gun's own extents (centre and half-size in handle space) so any blaster fits.
function Motion.mount(leg: BasePart, centre: Vector3, half: Vector3): (CFrame, number)
	local hip, scale = Motion.Hip, Motion.Hip.Scale
	-- Side out (X), top forward (Y), muzzle down (-Z), then canted muzzle-forward.
	local rotation = CFrame.Angles(math.rad(hip.Cant), 0, 0)
		* CFrame.fromMatrix(Vector3.zero, Vector3.xAxis, -Vector3.zAxis)
	local corners: { Vector3 } = {}
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				table.insert(corners, rotation * (half * Vector3.new(x, y, z) * scale))
			end
		end
	end
	local function bound(pick: (Vector3) -> number, most: boolean): number
		local best = if most then -math.huge else math.huge
		for _, corner in corners do
			best = if most then math.max(best, pick(corner)) else math.min(best, pick(corner))
		end
		return best
	end
	-- Leg space: the hip joint is at the leg's top face, its outer face at +X.
	local y = leg.Size.Y / 2 + hip.Above - bound(function(v)
		return v.Y
	end, true)
	local x = leg.Size.X / 2 + hip.Gap - bound(function(v)
		return v.X
	end, false)
	local z = hip.Back
	return CFrame.new(x, y, z) * rotation * CFrame.new(-centre * scale), scale
end

-- How far the hand is reaching for the holster (0-1): leaving it as a draw starts,
-- and going to it around a holster's stow window.
function Motion.reach(style: Style, drawing: boolean, elapsed: number): number
	local hip = Motion.Hip
	if drawing then
		return 1 - Motion.smooth(elapsed / Motion.Unstow)
	end
	local a, b = Motion.stowAt(style)
	return Motion.smooth((elapsed - (a - hip.ReachIn)) / hip.ReachIn)
		* (1 - Motion.smooth((elapsed - b) / hip.ReachOut))
end

return Motion
