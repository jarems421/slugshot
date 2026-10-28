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

return table.freeze(MotionMath)
