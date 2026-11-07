--!strict
-- Playful Flame refinement: visible curl, warm heat and advected dissipation.
local Flow = {}
Flow.Inhale, Flow.Open = 0.78, 0.93
Flow.Start, Flow.End = 1.90, 3.65
Flow.Return = 3.95
Flow.Embers = 10
Flow.GameScale = 0.4218

function Flow.ease(value: number): number
	local x = math.clamp(value, 0, 1)
	return math.clamp(x * x * x * (10 - 15 * x + 6 * x * x), 0, 1)
end

function Flow.sample(t: number): any
	local ease = Flow.ease
	local mouth = ease((t - Flow.Open) / 0.72) * (1 - ease((t - Flow.End) / 0.32))
	local exhale = ease((t - Flow.Start) / 0.25) * (1 - ease((t - Flow.End) / 0.30))
	local inhale = ease((t - Flow.Inhale) / 0.82) * (1 - ease((t - Flow.Start) / 0.28))
	local breathHop = 0.42 * math.sin(math.pi * math.clamp((t - Flow.Start) / 0.50, 0, 1)) ^ 2
	local effort = exhale * (0.88 + 0.06 * math.sin((t - Flow.Start) * 8) ^ 2)
	-- Owner, 2026-11-07: the breath and the strain must read bigger and more alive. A small
	-- gathering dip before the inhale, and a shudder through the blow.
	local gather = math.sin(math.pi * math.clamp((t - Flow.Inhale + 0.24) / 0.36, 0, 1)) ^ 2
	local tremble = exhale
		* (0.6 * math.sin((t - Flow.Start) * 41) + 0.4 * math.sin((t - Flow.Start) * 29 + 1.3))
	-- A slow resting breath whenever he isn't drawing in or blowing.
	local resting = (1 - inhale) * (1 - exhale) * (0.5 + 0.5 * math.sin(t * 2.6 - 1.2))
	local elapsed = (t - Flow.Return) * 1.12 / 0.76
	local press, lift, turn = 0, 0, 0
	if elapsed >= 0 and elapsed < 0.22 then
		press = 0.70 * ease(elapsed / 0.22)
	elseif elapsed >= 0.22 and elapsed < 0.28 then
		press = 0.70
	elseif elapsed >= 0.28 and elapsed < 0.74 then
		local u = (elapsed - 0.28) / 0.46
		local flight = 1 - (1 - u) ^ 1.55
		lift = 4 * flight * (1 - flight)
		press = 0.70 * (1 - ease(u / 0.16))
			- 0.32 * math.sin(math.pi * math.min(u / 0.65, 1))
			+ 0.10 * ease((u - 0.86) / 0.14)
		turn = ease((u - 0.03) / 0.82)
	elseif elapsed >= 0.74 and elapsed < 1.12 then
		local u = (elapsed - 0.74) / 0.38
		press = if u < 0.14
			then 0.10 + 0.62 * ease(u / 0.14)
			else 0.72 * (1 - ease((u - 0.14) / 0.86))
		turn = 1
	elseif elapsed >= 1.12 then
		turn = 1
	end
	return {
		mouth = mouth,
		exhale = exhale,
		inhale = inhale,
		breathHop = breathHop,
		effort = effort,
		gather = gather,
		tremble = tremble,
		resting = resting,
		press = press,
		lift = lift,
		turn = turn,
		looking = 1 - turn,
		smug = ease((t - Flow.End - 0.08) / 0.20) * (1 - ease((t - Flow.Return) / 0.20)),
	}
end

local function centre(u: number, clock: number): Vector2
	if u < 0.60 then
		return Vector2.new(0.94 * u, 0.045 * math.sin(u * 9 - clock * 5) * u * u)
	end
	local q = (u - 0.60) / 0.40
	local angle = -math.pi / 2 + q * math.pi * 1.10 + 0.08 * q * math.sin(clock * 5 - u * 11)
	local curl = 0.22 * (1 + 0.08 * q * math.sin(clock * 5 - u * 8))
	local join = 0.045 * math.sin(0.60 * 9 - clock * 5) * 0.60 ^ 2
	return Vector2.new(
		0.564 + curl * math.cos(angle),
		join + curl * (1 + math.sin(angle)) + 0.015 * q * math.sin(clock * 6 + u * 4)
	)
end

function Flow.vertex(t: number, s: number, side: number): (Vector3, Color3, number)
	local head = Flow.ease((t - Flow.Start) / 0.34)
	local after = math.max(0, t - Flow.End)
	local dissolve = Flow.ease(after / 0.68)
	local u = head * s
	local clock = t * 1.17
	local p = centre(u, clock)
	local tangent = centre(math.min(u + 0.001, 1), clock) - p
	if tangent.Magnitude < 1e-7 then
		tangent = Vector2.xAxis
	end
	tangent = tangent.Unit
	local theta = side * 2 * math.pi
	local ending = math.max(0, math.sin(math.pi * s)) ^ 0.55
	local radius = (0.022 + 0.18 * math.max(0, math.sin(math.pi * u)) ^ 0.85) * ending
	radius *= 1 + 0.14 * math.sin(theta * 3 + u * 20 - clock * 10) + 0.065 * math.sin(
		theta * 5 - u * 17 + clock * 13
	)
	radius = math.max(0.0006, radius) * (1 + 0.20 * dissolve)
	local point = Vector3.new(
		p.X - tangent.Y * math.cos(theta) * radius,
		p.Y
			+ tangent.X * math.cos(theta) * radius
			+ 0.030 * u * math.sin(u * 16 - clock * 7) * ending,
		math.sin(theta) * radius * 0.76 / (1 + 0.20 * dissolve)
	)
	-- The last breath travels and loosens; it never collapses back into the lips.
	point += Vector3.new(
		0.16 * after,
		0.30 * after + 0.025 * dissolve * math.sin(u * 17 + clock * 6),
		0.025 * dissolve * math.sin(u * 13 - theta)
	)
	point += Vector3.new((point.X - 0.35) * 0.30 * dissolve, (point.Y - 0.05) * 0.25 * dissolve, 0)
	local roll = math.sin(u * 23 - clock * 11 + math.sin(theta * 3 + u * 5 - clock * 4) * 0.9)
	local ribbon = math.sin(theta * 2 - u * 14 + clock * 7)
	local heat = 0.32 + 0.21 * roll + 0.12 * ribbon + 0.11 * (1 - u)
	local colour = Color3.new(1, 0.27, 0.025)
		:Lerp(Color3.new(1, 0.47, 0.045), Flow.ease((heat - 0.10) / 0.28))
	colour = colour:Lerp(Color3.new(1, 0.74, 0.17), Flow.ease((heat - 0.38) / 0.23))
	colour = colour:Lerp(Color3.new(1, 0.92, 0.54), Flow.ease((heat - 0.64) / 0.15))
	local fray = 0.78 + 0.14 * math.sin(u * 22 - clock * 9 + theta * 2)
	local breakup =
		Flow.ease((after - 0.06 - s * 0.14 + 0.065 * math.sin(u * 25 + theta * 3)) / 0.43)
	local neck = 1 - Flow.ease(after / 0.12) * (1 - Flow.ease(s / 0.24))
	local tip = 1
		- 0.30
			* Flow.ease((s - 0.55) / 0.45)
			* (0.5 + 0.5 * math.sin(u * 29 - clock * 13 + theta * 3))
	local alpha = fray * tip * (1 - breakup) * neck * math.max(0, math.sin(math.pi * s)) ^ 0.22
	return point, colour, alpha
end

local corners =
	{ Vector3.xAxis, -Vector3.xAxis, Vector3.yAxis, -Vector3.yAxis, Vector3.zAxis, -Vector3.zAxis }
function Flow.ember(t: number, index: number, corner: number): (Vector3, Color3, number)
	local life = 0.48 + (index % 3) * 0.06
	local first = Flow.Start + (index - 1) / Flow.Embers * life
	local birth = first + math.floor((t - first) / life) * life
	local age = math.clamp((t - birth) / life, 0, 1)
	local point = Flow.vertex(birth, 0.38 + (index % 6) * 0.085, (index * 0.618) % 1)
	point += Vector3.new(
		0.15 * age,
		0.12 * age + 0.12 * age * age,
		0.008 * math.sin(index * 2.3) * age
	)
	local radius = 0.014 * (1 - age) * (0.8 + 0.2 * math.sin(index))
	local alpha = if birth < Flow.Start or birth > Flow.End
		then 0
		else Flow.ease(age / 0.12) * (1 - Flow.ease(age))
	return point + corners[corner] * radius, Color3.new(1, 0.48 + 0.18 * (1 - age), 0.065), alpha
end

return Flow
