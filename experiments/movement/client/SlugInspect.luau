--!strict
-- Cosmetic samples use server time so owner and observers share the gesture.
local Inspect = {}
Inspect.Duration = 4.4

local function smooth(value: number): number
	local x = math.clamp(value, 0, 1)
	return x * x * (3 - 2 * x)
end

function Inspect.elapsed(character: Model): number?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local stamp = character:GetAttribute("SlugInspectAt")
	if typeof(stamp) ~= "number" then
		return nil
	end
	local t = workspace:GetServerTimeNow() - stamp
	return if t >= 0 and t < Inspect.Duration then t else nil
end

function Inspect.weight(t: number): number
	return smooth(t / 0.65) * (1 - smooth((t - 3.7) / 0.7))
end

function Inspect.arm(t: number): CFrame
	local w = Inspect.weight(t)
	return CFrame.new(0, 0.18 * w, -0.12 * w)
		* CFrame.Angles(math.rad(58) * w, math.rad(-18) * w, math.rad(-12) * w)
end

function Inspect.wrist(t: number): CFrame
	local w = Inspect.weight(t)
	return CFrame.Angles(math.rad(-16) * w, math.rad(12) * w, math.rad(-24) * w)
end

function Inspect.turn(t: number, slugId: string): number
	local turn = smooth((t - 0.5) / 0.65)
	if slugId == "Floppy" then
		turn *= 1 - smooth((t - 2) / 0.55)
	end
	return math.pi * turn * Inspect.weight(t)
end

function Inspect.wiggle(t: number): number
	local window = smooth((t - 2.5) / 0.2) * (1 - smooth((t - 3.4) / 0.3))
	return math.sin((t - 2.5) * math.pi * 4) * math.rad(11) * window
end

return Inspect
