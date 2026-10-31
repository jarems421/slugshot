--!strict
-- Original, compact draw/holster gestures. Degrees, no root motion or input locks.
-- time, wrist pitch/yaw/roll, shoulder pitch/yaw/roll, visibility.
local Motion = {}

Motion.Draw = {
	{ 0.00, -25, -20, -70, -12, -12, 8, 0 },
	{ 0.08, -12, -12, -115, -3, -8, 12, 1 },
	{ 0.18, 12, 22, -42, 12, 12, -6, 1 },
	{ 0.29, -4, -8, 18, 5, -4, -3, 1 },
	{ 0.42, 0, 0, 0, 0, 0, 0, 1 },
}

Motion.Holster = {
	{ 0.00, 0, 0, 0, 0, 0, 0, 1 },
	{ 0.08, -8, -14, 42, -8, -8, 10, 1 },
	{ 0.20, -20, 12, 100, -18, -10, 15, 1 },
	{ 0.27, -28, 8, 78, -12, -6, 8, 0 },
	{ 0.34, -28, 8, 78, 0, 0, 0, 0 },
}

export type Track = { { number } }

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

function Motion.sample(track: Track, elapsed: number): (CFrame, CFrame, number)
	local index = 1
	while index < #track - 1 and elapsed > track[index + 1][1] do
		index += 1
	end
	local first, last = track[index], track[index + 1]
	local x = math.clamp((elapsed - first[1]) / (last[1] - first[1]), 0, 1)
	local values = table.create(7)
	for column = 2, 8 do
		values[column] = interpolate(track, index, column, x)
	end
	return CFrame.Angles(math.rad(values[2]), math.rad(values[3]), math.rad(values[4])),
		CFrame.Angles(math.rad(values[5]), math.rad(values[6]), math.rad(values[7])),
		values[8]
end

return Motion
