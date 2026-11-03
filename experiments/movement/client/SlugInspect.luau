--!strict
-- Server-time cosmetic samples: toss, catch, reveal, contained reaction, lower.
local Inspect = {}
Inspect.Duration = 6.8
local TAU = 2 * math.pi

local function smooth(value: number): number
	local x = math.clamp(value, 0, 1)
	return x * x * (3 - 2 * x)
end

local function pulse(t: number, start: number, length: number): number
	local x = math.clamp((t - start) / length, 0, 1)
	return math.sin(math.pi * x) ^ 2
end

function Inspect.elapsed(character: Model): number?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local stamp = character:GetAttribute("SlugInspectAt")
	if not humanoid or humanoid.Health <= 0 or typeof(stamp) ~= "number" then
		return nil
	end
	local t = workspace:GetServerTimeNow() - stamp
	return if t >= 0 and t < Inspect.Duration then t else nil
end

function Inspect.weight(t: number): number
	return smooth(t / 0.55) * (1 - smooth((t - 5.9) / 0.75))
end

function Inspect.reveal(t: number): number
	return smooth((t - 0.98) / 0.48) * (1 - smooth((t - 5.45) / 0.4))
end

function Inspect.gunRotation(t: number?): CFrame
	local barrel = Vector3.new(-0.42, 0.89, 0.2).Unit
	local back = -barrel
	local right = (-Vector3.zAxis - back * back:Dot(-Vector3.zAxis)).Unit
	local side = CFrame.fromMatrix(Vector3.zero, right, back:Cross(right), back)
	-- Catch first, then rotate the wrist outward to reveal the chamber side.
	return side * CFrame.Angles(0, 0, math.rad(65) * (1 - Inspect.reveal(t or 2)))
end

function Inspect.spinAngle(t: number): number
	return TAU * (smooth((t - 0.18) / 0.64) - smooth((t - 5.9) / 0.75))
end

function Inspect.airborne(t: number): number
	return pulse(t, 0.18, 0.64)
end

function Inspect.flourish(t: number): CFrame
	local air = Inspect.airborne(t)
	local down = pulse(t, 5.9, 0.75)
	local rotation = Inspect.gunRotation(t)
	-- A visible toss clear of the fist; a complete end-over-end flip; catch at
	-- zero offset before the separate reveal. These translations are view axes.
	local travel = rotation:VectorToObjectSpace(
		Vector3.new(-1.5 * air - 1.2 * down, 1.1 * air + 0.9 * down, -0.65 * air - 0.5 * down)
	)
	local pivot = Vector3.new(0, 0.1, -0.3)
	local catch = -0.055 * pulse(t, 0.82, 0.16)
	return CFrame.new(travel + rotation:VectorToObjectSpace(Vector3.new(0, catch, 0)))
		* CFrame.new(pivot)
		* CFrame.Angles(Inspect.spinAngle(t), 0, 0)
		* CFrame.new(-pivot)
end

function Inspect.armFromGun(): CFrame
	local up = Vector3.new(0, 0.05, 1).Unit
	local right = Vector3.xAxis
	return CFrame.fromMatrix(Vector3.zero, right, up, right:Cross(up))
end

function Inspect.viewGun(t: number): CFrame
	local carry = pulse(t, 0, 0.95)
	return CFrame.new(0.5, -0.45 - 0.15 * carry, -2.7 - 1.25 * carry) * Inspect.gunRotation(t)
end

function Inspect.stand(t: number): number
	return smooth((t - 1.45) / 0.55) * (1 - smooth((t - 4.95) / 0.5))
end

function Inspect.hop(t: number): number
	-- A fast launch and softer descent; turning occurs during this flight only.
	local u = math.clamp((t - 2.86) / 0.5, 0, 1)
	return if u < 0.35 then smooth(u / 0.35) else 1 - smooth((u - 0.35) / 0.65)
end

function Inspect.compression(t: number): number
	return pulse(t, 2.62, 0.24) + 0.45 * pulse(t, 3.36, 0.2)
end

function Inspect.turn(t: number, slugId: string): number
	local angle = math.pi * smooth((t - 2.86) / 0.5)
	return if slugId == "Floppy" then angle * (1 - smooth((t - 4.95) / 0.5)) else angle
end

function Inspect.wiggle(t: number): number
	local u = math.clamp((t - 3.55) / 1.15, 0, 1)
	local envelope = smooth(u / 0.16) * (1 - smooth((u - 0.82) / 0.18))
	return math.rad(9) * math.sin(3 * math.pi * u) * envelope
end

return Inspect
