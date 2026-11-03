--!strict
local shared = game:GetService("ReplicatedStorage"):WaitForChild("MovementExperiment")
local mathUtils = require(shared.MotionMath)

for _, fps in { 30, 60, 144 } do
	local speed = 0
	for _ = 1, fps do
		speed = mathUtils.approach(speed, 30, 100, 1 / fps)
	end
	assert(math.abs(speed - 30) < 0.001, "Acceleration must converge without overshoot")
	for _ = 1, fps do
		speed = mathUtils.approach(speed, 0, 145, 1 / fps)
	end
	assert(speed == 0, "Braking must reach rest at every tested timestep")
	local blend = 0
	for _ = 1, fps do
		blend += (1 - blend) * mathUtils.alpha(18, 1 / fps)
	end
	assert(
		math.abs(blend - (1 - math.exp(-18))) < 0.00001,
		"Turn smoothing must be timestep independent"
	)
end
assert(not mathUtils.finite(0 / 0), "NaN must be rejected")
assert(not mathUtils.finite(math.huge), "Infinity must be rejected")
print("[Movement tests] PASS: 30/60/144 Hz convergence, no overshoot and finite input checks")

-- Regressions: sustained climbing, height taps, release/re-press and deliberate kicks.
local run = require(shared.Config).Traversal.WallRun
for _, fps in { 30, 60, 144 } do
	local vy = 0
	for frame = 1, fps * 12 do
		local target = mathUtils.wallRunVerticalTarget(run.Speed, true, 0, false, run)
		vy = mathUtils.approach(vy, target, run.VerticalAccel, 1 / fps)
		assert(vy > 0, `Held climb must stay upward at {frame / fps} seconds`)
	end
	assert(vy == run.Climb, "Long hold must retain full climb speed")
	for _, duration in { 0.05, 0.15, 0.3, 0.8 } do
		local target = mathUtils.wallRunVerticalTarget(run.Speed, true, 0, false, run)
		local lift = mathUtils.approach(-run.Slide, target, run.VerticalAccel, duration)
		assert(lift > -run.Slide, "A height tap must immediately increase upward velocity")
		assert(
			mathUtils.wallRunVerticalTarget(run.Speed, false, 0, false, run) == -run.Slide,
			"Release resumes slide"
		)
		assert(
			mathUtils.wallRunVerticalTarget(run.Speed, true, 0, false, run) == run.Climb,
			"Re-press restores climb"
		)
	end
end
assert(mathUtils.wallRunVerticalTarget(run.Speed, true, 0, true, run) == 0, "Top edge holds height")
assert(
	mathUtils.wallRunVerticalTarget(0, true, 0, false, run) == -run.Cling.Drag,
	"Stopped cling still drags"
)
assert(
	mathUtils.wallRunVerticalTarget(run.Speed, false, 100, false, run) == -run.SlideMax,
	"Released slide caps downward speed"
)
for _, away in { -1, -0.8, 0 } do
	assert(not mathUtils.wallRunKickIntent(away, run.KickAway), "No outward input must not kick")
end
for _, away in { 0.5, math.sqrt(0.5), 1 } do
	assert(
		mathUtils.wallRunKickIntent(away, run.KickAway),
		"Outward diagonals must kick without predominance"
	)
	assert(
		not mathUtils.wallRunMantleIntent(away, run.MantleInto),
		"Outward jump must never select mantle"
	)
end
assert(
	not mathUtils.wallRunKickIntent(1, run.KickAway, true),
	"Plain corner-following height tap stays attached"
)
assert(
	not mathUtils.wallRunMantleIntent(0, run.MantleInto),
	"Along-wall height tap must not mantle"
)
assert(
	not mathUtils.wallRunMantleIntent(-0.3, run.MantleInto),
	"A little inward drift must not mantle"
)
assert(
	mathUtils.wallRunMantleIntent(-1, run.MantleInto),
	"Deliberate into-wall press retains mantle"
)
assert(
	mathUtils.wallRunMantleIntent(-math.sqrt(0.5), run.MantleInto),
	"An inward diagonal can deliberately mantle"
)
print(
	"[Movement tests] PASS: sustained climb, height taps, diagonal kicks and deliberate mantle intent"
)

assert(
	mathUtils.wallRunKickIntent(1, run.KickAway, true, true),
	"Explicit outward strafe overrides corner following"
)
