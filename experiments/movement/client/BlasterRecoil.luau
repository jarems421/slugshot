--!strict
-- A quick kick, a readable peak, and a shaped recovery; sampled without accumulation.
local Motion = require(script.Parent.BlasterMotion)
local Tuning = require(script.Parent.Tuning)
local Recoil = {}

Recoil.Default = "Kick"

function Recoil.style(value: any): string
	return if value == "Flip" then "Flip" else "Kick"
end

local function motion(started: any, now: number, charge: any): (number, number)
	local power = if typeof(charge) == "number" and charge == charge
		then math.clamp(charge, 0, 1)
		else 0
	if typeof(started) ~= "number" then
		return 0, power
	end
	local age = now - started
	if age < 0 or age >= 0.4 then
		return 0, power
	end
	local amount: number
	if age < 0.035 then
		amount = 1 - (1 - age / 0.035) ^ 3
	elseif age < 0.08 then
		amount = 1
	elseif age < 0.3 then
		amount = (1 + math.cos(math.pi * (age - 0.08) / 0.22)) / 2
	else
		amount = -0.06 * math.sin(math.pi * (age - 0.3) / 0.1) ^ 2
	end
	return amount, power
end

local function toss(started: any, now: number, style: any): (CFrame, CFrame)
	if Recoil.style(style) ~= "Flip" or typeof(started) ~= "number" then
		return CFrame.identity, CFrame.identity
	end
	local age = now - started - 0.06
	local track = Motion.Styles.Toss.Draw
	if age < 0 or age * Motion.Speed >= Motion.length(track) then
		return CFrame.identity, CFrame.identity
	end
	-- Reuse the accepted draw toss: flick, airborne turn, catch dip, rebound.
	local values = Motion.sample(track, track, age * Motion.Speed, 0)
	local wrist = Motion.frames(values)
	local hand = CFrame.Angles(math.rad(values[7]) * 0.22, 0, 0)
	return wrist, hand
end

function Recoil.sample(started: any, now: number, charge: any, style: any): CFrame
	local amount, power = motion(started, now, charge)
	local flourish = toss(started, now, style)
	return CFrame.new(0, (0.12 + 0.08 * power) * amount, (0.2 + 0.08 * power) * amount)
		* CFrame.Angles(
			math.rad(Tuning.values.kickBase + Tuning.values.kickCharge * power) * amount,
			0,
			0
		)
		* flourish
end

function Recoil.follow(started: any, now: number, charge: any, style: any): CFrame
	local amount, power = motion(started, now, charge)
	local _, hand = toss(started, now, style)
	return CFrame.new(0, (0.055 + 0.045 * power) * amount, 0.05 * amount)
		* CFrame.Angles(math.rad(3 + 2 * power) * amount, 0, 0)
		* hand
end

return Recoil
