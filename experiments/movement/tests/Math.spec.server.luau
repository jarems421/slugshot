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
for _, along in { -1, -0.8, 0, 0.8, 1 } do
	assert(
		not mathUtils.wallRunKickIntent(0, along, run.KickAway),
		"Steering alone never kicks off"
	)
end
assert(
	not mathUtils.wallRunKickIntent(0.6, 0.8, run.KickAway),
	"Corner input mostly along is steering"
)
assert(not mathUtils.wallRunKickIntent(-1, 0, run.KickAway), "Into-wall input is not a kick")
assert(mathUtils.wallRunKickIntent(1, 0, run.KickAway), "Deliberate outward press still kicks")
print(
	"[Movement tests] PASS: sustained climb, height taps, top hold, cling and outward kick intent"
)

assert(
	not mathUtils.wallRunKickIntent(1, 0, run.KickAway, true),
	"Following the next corner face must not kick"
)
