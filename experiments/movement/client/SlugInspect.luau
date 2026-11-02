--!strict
-- Cosmetic samples use server time so owner and observers share the gesture.
local Inspect = {}
Inspect.Duration = 5.8

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

-- Raise, settle, hop/look, turn/wiggle, settle, lower. All joins ease to rest.
function Inspect.weight(t: number): number
	return smooth(t / 0.85) * (1 - smooth((t - 4.85) / 0.8))
end

function Inspect.gunRotation(): CFrame
	-- Barrel and forearm rise together, angled diagonally back toward the holder.
	local barrel = Vector3.new(-0.28, 0.94, 0.2).Unit
	local back = -barrel
	local right = (-Vector3.zAxis - back * back:Dot(-Vector3.zAxis)).Unit
	return CFrame.fromMatrix(Vector3.zero, right, back:Cross(right), back)
end

function Inspect.armFromGun(): CFrame
	local up = Vector3.new(0, 0.05, 1).Unit
	local right = Vector3.xAxis
	return CFrame.fromMatrix(Vector3.zero, right, up, right:Cross(up))
end

function Inspect.viewGun(t: number): CFrame
	local settle = math.sin(t * 2.2) * 0.008 * Inspect.weight(t)
	return CFrame.new(0.5, -0.45 + settle, -2.7) * Inspect.gunRotation()
end

function Inspect.stand(t: number): number
	return smooth((t - 1.0) / 0.65) * (1 - smooth((t - 4.15) / 0.6))
end

function Inspect.hop(t: number): number
	local u = math.clamp((t - 1.0) / 0.65, 0, 1)
	local jump = math.sin(math.pi * u) ^ 2
	local anticipate = math.sin(math.pi * math.clamp((t - 0.82) / 0.18, 0, 1)) ^ 2
	return 0.75 * jump - 0.12 * anticipate
end

function Inspect.turn(t: number, slugId: string): number
	local turn = smooth((t - 2.65) / 0.65)
	if slugId == "Floppy" then
		turn *= 1 - smooth((t - 4.15) / 0.6)
	end
	return math.pi * turn
end

function Inspect.wiggle(t: number): number
	local window = smooth((t - 3.3) / 0.2) * (1 - smooth((t - 4.0) / 0.25))
	return math.sin((t - 3.3) * math.pi * 5) * math.rad(13) * window
end

return Inspect
