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

-- Wall runs are a straight line (owner, 2026-11-06): level while running, a drag down when stopped along the wall.
local run = require(shared.Config).Traversal.WallRun
assert(mathUtils.wallRunVerticalTarget(run.Speed, run) == 0, "A running wall run holds its height")
assert(
	mathUtils.wallRunVerticalTarget(run.Cling.Below, run) == 0,
	"Running at the cling threshold stays level"
)
assert(mathUtils.wallRunVerticalTarget(0, run) == -run.Cling.Drag, "Stopped cling still drags")
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
	"A plain corner-following press does not kick"
)
assert(not mathUtils.wallRunMantleIntent(0, run.MantleInto), "An along-wall press must not mantle")
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
	"[Movement tests] PASS: level wall run, cling drag, diagonal kicks and deliberate mantle intent"
)

assert(
	mathUtils.wallRunKickIntent(1, run.KickAway, true, true),
	"Explicit outward strafe overrides corner following"
)
