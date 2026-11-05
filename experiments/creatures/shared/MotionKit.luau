--!strict
-- Tested motion maths for procedural slug performances, so new motion does not invent its own easing or spring. The
-- browser previews use the twin in tools/slugs/motion-preview/motion-kit.js; tests/slugs/test_motion_kit.py keeps the
-- two on the same golden numbers. Performances only move targets and give kicks; springs carry the rig between them.
local MotionKit = {}

local TAU = 2 * math.pi
-- Fixed, so the motion is the same at any frame rate. Same step as FloppyIdle and SlugIcon.
MotionKit.TimeStep = 1 / 120

export type Spring = { x: number, v: number, target: number, freq: number, damp: number }
export type Tune = { freq: number, damp: number }
export type Clock = { leftover: number }
export type Hop = {
	windup: number,
	hold: number,
	air: number,
	land: number,
	press: number,
	stretch: number,
	landPress: number,
}
export type HopSample = { stage: string, press: number, lift: number, air: number }

-- freq is in Hz; damp 1 settles without overshoot, lower values bounce.
function MotionKit.spring(tune: Tune, start: number?): Spring
	local x = start or 0
	return { x = x, v = 0, target = x, freq = tune.freq, damp = tune.damp }
end

-- InfernoMotion's springs give stiffness in 1/s rather than Hz.
function MotionKit.fromStiffness(stiffness: number, damping: number): Tune
	return { freq = stiffness / TAU, damp = damping }
end

function MotionKit.stepSpring(s: Spring, dt: number)
	local w = TAU * s.freq
	s.v += (w * w * (s.target - s.x) - 2 * s.damp * w * s.v) * dt
	s.x += s.v * dt
end

-- A sudden push, as a landing gives: it adds speed, so it blends with whatever the spring is already doing.
function MotionKit.kick(s: Spring, speed: number)
	s.v += speed
end

function MotionKit.clock(): Clock
	return { leftover = 0 }
end

-- Runs step once per fixed step owed. A long hitch is capped, so the rig does not lurch to catch up.
function MotionKit.advance(clock: Clock, dt: number, step: (number) -> ())
	local owed = math.min(dt, 0.1) + clock.leftover
	while owed >= MotionKit.TimeStep do
		owed -= MotionKit.TimeStep
		step(MotionKit.TimeStep)
	end
	clock.leftover = owed
end

-- Follow-through: each spring chases the one before it, so a head trails the body and an antenna tip trails its root.
function MotionKit.stepChain(chain: { Spring }, target: number, dt: number)
	local lead = target
	for _, s in chain do
		s.target = lead
		MotionKit.stepSpring(s, dt)
		lead = s.x
	end
end

-- Ease in and out, with zero speed at both ends.
function MotionKit.ease(share: number): number
	local t = math.clamp(share, 0, 1)
	return t * t * (3 - 2 * t)
end

-- A softer ease with no sudden change in acceleration either, for the face and for long transitions.
function MotionKit.soft(share: number): number
	local t = math.clamp(share, 0, 1)
	return t * t * t * (10 - 15 * t + 6 * t * t)
end

-- 0 to 1 and back over the range.
function MotionKit.arc(share: number): number
	return math.sin(math.clamp(share, 0, 1) * math.pi)
end

-- The arc with soft ends: time and length in seconds.
function MotionKit.pulse(t: number, at: number, length: number): number
	return math.sin(math.pi * math.clamp((t - at) / length, 0, 1)) ^ 2
end

-- 0 outside start to finish, 1 inside, with soft edges.
function MotionKit.window(t: number, start: number, finish: number, fade: number): number
	return MotionKit.ease((t - start) / fade) * (1 - MotionKit.ease((t - finish) / fade))
end

-- Height through a jump, for u from 0 to 1: peaks at 1 halfway.
function MotionKit.ballistic(u: number): number
	local t = math.clamp(u, 0, 1)
	return 4 * t * (1 - t)
end

function MotionKit.hopLength(hop: Hop): number
	return hop.windup + hop.hold + hop.air + hop.land
end

-- The compress, hold, stretch, cushion hop shared by the approved inspect returns, with its timing and amounts as
-- data so each slug has its own. press is squash (negative stretches); lift is the height from 0 to 1.
function MotionKit.hop(elapsed: number, hop: Hop): HopSample
	local air = elapsed - hop.windup - hop.hold
	if elapsed < 0 then
		return { stage = "rest", press = 0, lift = 0, air = 0 }
	elseif elapsed < hop.windup then
		return {
			stage = "windup",
			press = hop.press * MotionKit.ease(elapsed / hop.windup),
			lift = 0,
			air = 0,
		}
	elseif air < 0 then
		return { stage = "hold", press = hop.press, lift = 0, air = 0 }
	elseif air < hop.air then
		local u = air / hop.air
		return {
			stage = "air",
			press = hop.press * (1 - MotionKit.ease(u / 0.14))
				- hop.stretch * math.sin(math.pi * math.min(u / 0.5, 1)),
			lift = MotionKit.ballistic(u),
			air = u,
		}
	elseif air < hop.air + hop.land then
		local u = (air - hop.air) / hop.land
		return {
			stage = "land",
			press = if u < 0.18
				then hop.landPress * MotionKit.ease(u / 0.18)
				else hop.landPress * (1 - MotionKit.ease((u - 0.18) / 0.82)),
			lift = 0,
			air = 1,
		}
	end
	return { stage = "rest", press = 0, lift = 0, air = 1 }
end

-- Springs taken from code in the game, in Hz and damping. They carry a personality: Floppy's are slow and wobbly,
-- Inferno's fast and tight. Start from the row nearest the performance wanted and tune it for the new slug; copying a
-- whole set copies the old slug's character. Status and sources are in docs/slugs/motion-library.md.
MotionKit.Tunes = table.freeze({
	floppySquash = table.freeze({ freq = 5, damp = 0.26 }),
	floppySway = table.freeze({ freq = 3.4, damp = 0.42 }),
	floppyLag = table.freeze({ freq = 2.6, damp = 0.34 }),
	floppyTip = table.freeze({ freq = 2.2, damp = 0.4 }),
	floppyPitch = table.freeze({ freq = 1.8, damp = 0.8 }),
	floppyFlop = table.freeze({ freq = 2.4, damp = 0.5 }),
	floppyStand = table.freeze({ freq = 2.2, damp = 0.8 }),
	infernoLook = table.freeze(MotionKit.fromStiffness(6, 0.8)),
	infernoRise = table.freeze(MotionKit.fromStiffness(20, 0.8)),
	infernoCrouch = table.freeze(MotionKit.fromStiffness(18, 0.6)),
	infernoFlip = table.freeze(MotionKit.fromStiffness(26, 0.9)),
	infernoChin = table.freeze(MotionKit.fromStiffness(12, 0.6)),
	infernoWhip = table.freeze(MotionKit.fromStiffness(9, 0.35)),
	infernoWhipTip = table.freeze(MotionKit.fromStiffness(7, 0.4)),
	infernoMood = table.freeze(MotionKit.fromStiffness(5.5, 1)),
})

return MotionKit
