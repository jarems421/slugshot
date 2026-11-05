--!strict
-- Same numbers as tools/slugs/golden_motion_kit.mjs; tests/slugs/test_motion_kit.py keeps the two lists equal.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SlugAssets")
local MotionKit = require(Shared.MotionKit)

local GOLDEN = {
	squashX = 1.012442,
	squashPeak = 1.416562,
	flipPeak = 0.994233,
	chain = { 0.983661, 0.825862 },
	kick = 0.057778,
	ease = 0.216,
	soft = 0.16308,
	arc = 0.707107,
	pulse = 0.904508,
	window = 0.352,
	ballistic = 0.75,
	hopPress = { 0, 0.18, 0.36, -0.159032, 0, 0.103246, 0.260107, 0 },
	hopLift = { 0, 0, 0, 0.570749, 0.475624, 0, 0, 0 },
}
-- End of golden numbers

local function near(value: number, expected: number, label: string)
	assert(math.abs(value - expected) < 2e-6, `{label}: {value}, expected {expected}`)
end

local function settle(tune: MotionKit.Tune, seconds: number, frameRate: number): (number, number)
	local s = MotionKit.spring(tune)
	local clock = MotionKit.clock()
	s.target = 1
	local peak = 0
	for _ = 1, math.round(seconds * frameRate) do
		MotionKit.advance(clock, 1 / frameRate, function(dt: number)
			MotionKit.stepSpring(s, dt)
			peak = math.max(peak, s.x)
		end)
	end
	return s.x, peak
end

local x60, peak60 = settle(MotionKit.Tunes.floppySquash, 0.5, 60)
local x30 = settle(MotionKit.Tunes.floppySquash, 0.5, 30)
near(x60, GOLDEN.squashX, "squash settles")
near(peak60, GOLDEN.squashPeak, "squash overshoots")
near(x30, x60, "same at any frame rate")
local _, flipPeak = settle(MotionKit.Tunes.infernoFlip, 0.25, 60)
near(flipPeak, GOLDEN.flipPeak, "flip barely overshoots")

local chain =
	{ MotionKit.spring(MotionKit.Tunes.floppyLag), MotionKit.spring(MotionKit.Tunes.floppyTip) }
for _ = 1, 60 do
	MotionKit.stepChain(chain, 1, 1 / 120)
end
near(chain[1].x, GOLDEN.chain[1], "chain lead")
near(chain[2].x, GOLDEN.chain[2], "chain tip")

local kicked = MotionKit.spring(MotionKit.Tunes.floppySquash)
MotionKit.kick(kicked, 3)
for _ = 1, 6 do
	MotionKit.stepSpring(kicked, 1 / 120)
end
near(kicked.x, GOLDEN.kick, "kick")

near(MotionKit.ease(0.3), GOLDEN.ease, "ease")
near(MotionKit.soft(0.3), GOLDEN.soft, "soft")
near(MotionKit.arc(0.25), GOLDEN.arc, "arc")
near(MotionKit.pulse(1.2, 1, 0.5), GOLDEN.pulse, "pulse")
near(MotionKit.window(0.5, 0.4, 1, 0.25), GOLDEN.window, "window")
near(MotionKit.ballistic(0.25), GOLDEN.ballistic, "ballistic")

local shape: MotionKit.Hop = {
	windup = 0.3,
	hold = 0.1,
	air = 0.58,
	land = 0.38,
	press = 0.36,
	stretch = 0.18,
	landPress = 0.5,
}
for i, t in { -0.1, 0.15, 0.35, 0.5, 0.9, 1.0, 1.2, 1.5 } do
	local sample = MotionKit.hop(t, shape)
	near(sample.press, GOLDEN.hopPress[i], `hop press at {t}`)
	near(sample.lift, GOLDEN.hopLift[i], `hop lift at {t}`)
end
print("MotionKit: all checks passed")
