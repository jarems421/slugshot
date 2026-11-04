--!strict
-- Server-time cosmetic samples: opening toss, creature act, low returning toss/catch.
local Inspect = {}
Inspect.Release = 0.3
Inspect.Catch = 0.54
Inspect.Lower = 3.35
Inspect.Duration = 3.90
Inspect.ReturnRelease = Inspect.Lower + 0.08
Inspect.ReturnCatch = Inspect.Lower + 0.32
Inspect.InfernoLower = 4.12
Inspect.InfernoDuration = Inspect.InfernoLower + Inspect.Duration - Inspect.Lower
Inspect.ThirdToss = 1.6
local TAU = 2 * math.pi
local TOSS = Vector3.new(-0.35, 1.45, -0.55)
-- The hand drops to wind up, flicks through its release height, drifts down, then
-- meets the gun at that same height and rides the catch's weight down. Both keys at
-- zero (release and catch) are where the gun leaves and rejoins the hand.
local HAND_RISE = {
	{ 0, 0 },
	{ 0.21, -0.2 },
	{ Inspect.Release, 0 },
	{ 0.36, 0.2 },
	{ 0.44, -0.07 },
	{ Inspect.Catch, 0 },
	{ 0.65, -0.24 },
	{ 0.84, 0.035 },
	{ 1.04, 0 },
}
-- Catch weight carries on through the wrist in the flip's direction, then settles.
local CATCH_ROCK = {
	{ Inspect.Catch, 0 },
	{ 0.64, 0.24 },
	{ 0.82, -0.05 },
	{ 1.0, 0 },
}
local REVEAL = {
	{ 0.62, 0 },
	{ 0.88, 1.07 },
	{ 1.08, 1 },
}

local function smooth(value: number): number
	local x = math.clamp(value, 0, 1)
	return x * x * (3 - 2 * x)
end

local function pulse(t: number, start: number, length: number): number
	local x = math.clamp((t - start) / length, 0, 1)
	return math.sin(math.pi * x) ^ 2
end

-- Hermite through { time, value } keys, with flat ends and Catmull-Rom tangents.
local function track(keys: { { number } }, t: number): number
	local count = #keys
	if t <= keys[1][1] then
		return keys[1][2]
	elseif t >= keys[count][1] then
		return keys[count][2]
	end
	local i = 1
	while keys[i + 1][1] < t do
		i += 1
	end
	local function slope(k: number): number
		if k <= 1 or k >= count then
			return 0
		end
		return (keys[k + 1][2] - keys[k - 1][2]) / (keys[k + 1][1] - keys[k - 1][1])
	end
	local from, to = keys[i], keys[i + 1]
	local span = to[1] - from[1]
	local u = (t - from[1]) / span
	local uu, uuu = u * u, u * u * u
	return (2 * uuu - 3 * uu + 1) * from[2]
		+ (uuu - 2 * uu + u) * span * slope(i)
		+ (-2 * uuu + 3 * uu) * to[2]
		+ (uuu - uu) * span * slope(i + 1)
end

local function infernoSelected(character: Model): boolean
	local tool = character:FindFirstChildOfClass("Tool")
	return tool ~= nil and tool:GetAttribute("SelectedSlugId") == "Inferno"
end

-- Species acting uses real seconds. Both creatures share the same quick toss,
-- catch, reveal and drop; Inferno simply holds longer for his approved breath.
function Inspect.creatureElapsed(character: Model): number?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local stamp = character:GetAttribute("SlugInspectAt")
	if not humanoid or humanoid.Health <= 0 or typeof(stamp) ~= "number" then
		return nil
	end
	local t = workspace:GetServerTimeNow() - stamp
	local duration = if infernoSelected(character)
		then Inspect.InfernoDuration
		else Inspect.Duration
	return if t >= 0 and t < duration then t else nil
end

function Inspect.gunTime(t: number, slugId: string): number
	if slugId ~= "Inferno" or t <= 1.15 then
		return t
	end
	if t < Inspect.InfernoLower then
		return 1.15 + (t - 1.15) * (Inspect.Lower - 1.15) / (Inspect.InfernoLower - 1.15)
	end
	return Inspect.Lower + t - Inspect.InfernoLower
end

function Inspect.elapsed(character: Model): number?
	local t = Inspect.creatureElapsed(character)
	return if t
		then Inspect.gunTime(t, if infernoSelected(character) then "Inferno" else "Floppy")
		else nil
end

function Inspect.weight(t: number): number
	return smooth(t / 0.24)
		* (1 - smooth((t - Inspect.Lower) / (Inspect.ReturnCatch - Inspect.Lower)))
end

-- First person swaps poses below the screen, so the arm never sweeps across the view.
function Inspect.viewWeight(t: number): number
	if t <= Inspect.ReturnCatch then
		return smooth(t / 0.1)
			* (1 - 0.20 * smooth((t - Inspect.Lower) / (Inspect.ReturnCatch - Inspect.Lower)))
	end
	return 0.80 * (1 - smooth((t - Inspect.ReturnCatch) / (Inspect.Duration - Inspect.ReturnCatch)))
end

function Inspect.reveal(t: number): number
	return track(REVEAL, t)
end

-- A moving hold: 0 outside the upright part, so the catch and drop stay clean.
local function holding(t: number): number
	return smooth((t - 1.15) / 0.5) * (1 - smooth((t - Inspect.Lower + 0.3) / 0.4))
end

local function wave(t: number, period: number, phase: number): number
	return math.sin(TAU * (t - 1.26) / period + phase)
end

-- Slow wrist turns with unrelated periods, so the hold never reads as a loop.
-- It stays small and keeps the chamber facing out: the slug is the show here.
local function sway(t: number): CFrame
	local amount = holding(t)
	if amount <= 0 then
		return CFrame.identity
	end
	local roll = 5 * wave(t, 2.7, 0) + 1.5 * wave(t, 1.3, 0.8)
	local pitch = 2.5 * wave(t, 3.4, 1)
	local lean = 2 * wave(t, 2.1, 2.3)
	return CFrame.Angles(math.rad(pitch * amount), math.rad(lean * amount), math.rad(roll * amount))
end

-- A breath's worth of hand drift, in studs, so the gun is alive but stays put.
function Inspect.holdLift(t: number): number
	return 0.035 * holding(t) * wave(t, 3.1, 0.4)
end

function Inspect.gunRotation(t: number?): CFrame
	local barrel = Vector3.new(-0.42, 0.89, 0.2).Unit
	local back = -barrel
	local right = (-Vector3.zAxis - back * back:Dot(-Vector3.zAxis)).Unit
	local side = CFrame.fromMatrix(Vector3.zero, right, back:Cross(right), back)
	-- Catch first, then tilt the wrist outward to show the chamber and slug.
	local at = t or 2
	return side * CFrame.Angles(0, 0, math.rad(65) * (1 - Inspect.reveal(at))) * sway(at)
end

function Inspect.airborne(t: number): number
	if t >= Inspect.ReturnRelease then
		local u = (t - Inspect.ReturnRelease) / (Inspect.ReturnCatch - Inspect.ReturnRelease)
		return if u > 0 and u < 1 then u else 0
	end
	local u = (t - Inspect.Release) / (Inspect.Catch - Inspect.Release)
	return if u > 0 and u < 1 then u else 0
end

function Inspect.handRise(t: number): number
	if t >= Inspect.Lower then
		return -0.09 * pulse(t, Inspect.Lower, 0.13) + 0.055 * pulse(t, Inspect.ReturnCatch, 0.1)
	end
	return track(HAND_RISE, t)
end

-- One steady backward turn in flight, barrel coming back toward the holder.
function Inspect.spinAngle(t: number): number
	if t >= Inspect.Lower then
		if t < Inspect.ReturnRelease then
			return TAU - 0.18 * pulse(t, Inspect.Lower, Inspect.ReturnRelease - Inspect.Lower)
		elseif t < Inspect.ReturnCatch then
			return TAU
				* (
					1
					+ smooth(
						(t - Inspect.ReturnRelease) / (Inspect.ReturnCatch - Inspect.ReturnRelease)
					)
				)
		end
		return TAU * 2
			+ 0.08 * pulse(t, Inspect.ReturnCatch, Inspect.Duration - Inspect.ReturnCatch)
	end
	local u = Inspect.airborne(t)
	if u > 0 then
		return TAU * u
	elseif t >= Inspect.Catch then
		return TAU + track(CATCH_ROCK, t)
	end
	return -0.4 * pulse(t, 0.1, Inspect.Release - 0.1) -- tips forward in the wind-up
end

-- The gun's view-axis offset from the moving hand: a ballistic path while thrown.
function Inspect.flight(t: number, height: number): Vector3
	local u = Inspect.airborne(t)
	if u <= 0 then
		return Vector3.zero
	end
	if t >= Inspect.ReturnRelease then
		return Vector3.new(
			0.08 * math.sin(math.pi * u),
			0.48 * height * 4 * u * (1 - u),
			-0.08 * math.sin(math.pi * u)
		)
	end
	local toss = Vector3.new(
		TOSS.X * math.sin(math.pi * u),
		TOSS.Y * height * 4 * u * (1 - u),
		TOSS.Z * math.sin(math.pi * u)
	)
	return toss - Vector3.yAxis * Inspect.handRise(t)
end

-- height scales the throw: the third-person camera sits far further from the gun.
function Inspect.flourish(t: number, height: number?): CFrame
	local rotation = Inspect.gunRotation(t)
	local travel = rotation:VectorToObjectSpace(Inspect.flight(t, height or 1))
	local pivot = Vector3.new(0, 0.1, -0.3)
	return CFrame.new(travel)
		* CFrame.new(pivot)
		* CFrame.Angles(Inspect.spinAngle(t), 0, 0)
		* CFrame.new(-pivot)
end

function Inspect.armFromGun(): CFrame
	local up = Vector3.new(0, 0.05, 1).Unit
	local right = Vector3.xAxis
	return CFrame.fromMatrix(Vector3.zero, right, up, right:Cross(up))
end

function Inspect.viewGun(t: number): CFrame
	local carry = pulse(t, 0, Inspect.Catch + 0.16)
	local rise = Inspect.handRise(t) + Inspect.holdLift(t)
	-- The return blends into the live carry pose while the second toss is airborne.
	local entry = 1 - smooth(t / 0.2)
	local lowCatch = 0.24 * smooth((t - Inspect.Lower) / (Inspect.ReturnCatch - Inspect.Lower))
	return CFrame.new(
		0.25,
		-0.68 - lowCatch - 0.1 * carry + rise - 2.8 * entry,
		-2.8 - 0.55 * carry
	) * CFrame.Angles(0.5 * rise, 0, 0) * Inspect.gunRotation(t)
end

-- Third-person shoulder pitch for the same hand curve on a rigid R6 arm.
function Inspect.armPitch(t: number): number
	return (Inspect.handRise(t) + Inspect.holdLift(t)) / 1.4
end

-- The slug's act: a quick smile at the holder, a soft wiggle with his base stuck down, a small
-- hop back into his normal position, then a snug settling wiggle while the arm lowers. These
-- are targets; his driver's springs carry him between them.
Inspect.Home = 2.9 -- he leaves the holder as he takes off
local CROUCH_AT, LAND_AT = 2.76, 3.2
function Inspect.looking(t: number): number
	return if t < Inspect.Home then smooth((t - 0.45) / 0.55) else 0
end

local WIGGLE_AT, WIGGLE_TIME, WIGGLE_RATE = 1.4, 1.4, 1.4
function Inspect.wiggle(t: number): (number, number, number)
	local u = t - WIGGLE_AT
	local swell = smooth(u / 0.35) * (1 - smooth((u - WIGGLE_TIME + 0.4) / 0.4))
	return swell, math.sin(TAU * WIGGLE_RATE * u), math.abs(math.cos(TAU * WIGGLE_RATE * u))
end

-- Returns the hop's height (0 to 1) and the squash it wants (1 flattened, -1 stretched).
function Inspect.hop(t: number): (number, number)
	if t >= CROUCH_AT and t < Inspect.Home then
		return 0, 0.35
	elseif t >= Inspect.Home and t < LAND_AT then
		local u = (t - Inspect.Home) / (LAND_AT - Inspect.Home)
		return 4 * u * (1 - u), -0.3 * math.abs(2 * u - 1)
	end
	return 0, 0
end

function Inspect.landed(t: number): boolean
	return t >= LAND_AT
end

-- The little wiggle of getting comfortable again, dying away as the arm finishes lowering.
function Inspect.snug(t: number): number
	local u = t - LAND_AT
	if u <= 0 then
		return 0
	end
	return 0.5 * smooth(u / 0.08) * (1 - smooth(u / 0.57)) * math.sin(TAU * 2.4 * u)
end

return Inspect
