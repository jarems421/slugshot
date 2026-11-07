--!strict
local MotionMath = {}

function MotionMath.approach(value: number, target: number, rate: number, dt: number): number
	local delta = math.max(0, rate) * math.max(0, dt)
	return value + math.clamp(target - value, -delta, delta)
end

function MotionMath.alpha(rate: number, dt: number): number
	return 1 - math.exp(-math.max(0, rate) * math.max(0, dt))
end

function MotionMath.finite(value: number): boolean
	return value == value and math.abs(value) < math.huge
end

-- Any clear outward component includes ordinary 45-degree diagonals.
function MotionMath.wallRunKickIntent(
	away: number,
	threshold: number,
	followingCorner: boolean?,
	lateral: boolean?
): boolean
	return (not followingCorner or lateral == true) and away > threshold
end

function MotionMath.wallRunMantleIntent(away: number, threshold: number): boolean
	return -away >= threshold
end

type WallRunSettings = typeof(require(script.Parent.Config).Traversal.WallRun)

-- A wall run holds its height (owner, 2026-11-06: a straight line); stopping along the wall clings and drags down.
function MotionMath.wallRunVerticalTarget(speed: number, settings: WallRunSettings): number
	return if speed < settings.Cling.Below then -settings.Cling.Drag else 0
end

return table.freeze(MotionMath)
