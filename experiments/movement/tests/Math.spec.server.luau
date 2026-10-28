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
