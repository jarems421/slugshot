--!strict
-- A quick kick, a readable peak, and a shaped recovery; sampled without accumulation.
local Motion = require(script.Parent.BlasterMotion)
local Tuning = require(script.Parent.Tuning)
local FirstPerson = require(script.Parent.FirstPerson)
local Recoil = {}
local STAGES = 3
local STAGE_SHAKE = { 0, 0.4, 0.7, 1 }
local CLUNK_SIZE = { 0.8, 1, 1.35 }
local stage, clunkStage, clunkAt = 0, 0, -math.huge
local shakeLevel, heldLevel, viewLevel, moving, shakePhase = 0, 0, 0, 0, 0
local clunkListeners: { (number) -> () } = {}

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

-- Three-stage wind-up, this player only. Each third of the charge is a smooth step that holds, so
-- power can be read at any moment: the gun eases back and up, the view tightens slightly and the
-- vibration grows. A soft swell marks each step. Aim and crosshair never move.
function Recoil.onClunk(listener: (number) -> ())
	table.insert(clunkListeners, listener)
end

function Recoil.stage(): number
	return stage
end

function Recoil.setCharging(value: number, movement: number, dt: number)
	local reached = math.min(math.floor(value * STAGES), STAGES)
	if reached > stage then
		clunkAt, clunkStage = os.clock(), reached
		for _, listener in clunkListeners do
			listener(reached)
		end
	end
	stage = reached
	local toward = 1 - math.exp(-20 * dt)
	shakeLevel += (STAGE_SHAKE[stage + 1] - shakeLevel) * toward
	heldLevel += (stage / STAGES - heldLevel) * toward
	viewLevel += (stage / STAGES - viewLevel) * toward
	moving += (math.clamp(movement, 0, 1) - moving) * (1 - math.exp(-8 * dt))
	-- Slower and larger on the move, where a fine fast shake is lost in the arm swing.
	shakePhase += (42 + (24 - 42) * moving) * dt
end

-- A soft swell with no sharp edge, larger for later stages.
local function clunk(now: number): number
	local age = now - clunkAt
	if age < 0 or age > 0.3 then
		return 0
	end
	local rise = math.min(age / 0.1, 1)
	local fall = math.clamp((age - 0.1) / 0.2, 0, 1)
	local eased = rise * rise * (3 - 2 * rise) * (1 - fall * fall * (3 - 2 * fall))
	return eased * (CLUNK_SIZE[clunkStage] or 0)
end

local function shakeAmount(): number
	local boost = 1 + (Tuning.values.chargeMoveShake - 1) * moving
	return shakeLevel * Tuning.values.chargeShake * boost
end

-- The gun's own motion. In third person it is further away, so the notch and jolt are larger.
function Recoil.vibration(now: number): CFrame
	local jolt = clunk(now) * Tuning.values.chargeClunk
	local amount = shakeAmount()
	if jolt == 0 and amount < 1e-3 and heldLevel < 1e-3 then
		return CFrame.identity
	end
	local far = if FirstPerson.active() then 1 else 2.2
	local at = shakePhase
	return CFrame.new(
		math.noise(at, 1.3) * 0.032 * amount,
		math.noise(at, 7.1) * 0.032 * amount + (0.06 * heldLevel + 0.015 * jolt) * far,
		math.noise(at, 13.7) * 0.02 * amount + (0.2 * heldLevel + 0.04 * jolt) * far
	) * CFrame.Angles(
		math.noise(at, 21.9) * math.rad(1.2) * amount + math.rad(5 * heldLevel + 3 * jolt) * far,
		math.noise(at, 29.3) * math.rad(1.2) * amount,
		0
	)
end

-- The arm takes the same motion, so the shake is not only in the gun.
function Recoil.armWindup(now: number): CFrame
	local jolt = clunk(now) * Tuning.values.chargeClunk
	local amount = shakeAmount()
	if jolt == 0 and amount < 1e-3 then
		return CFrame.identity
	end
	local at = shakePhase + 40
	return CFrame.new(
		math.noise(at, 3.1) * 0.022 * amount,
		math.noise(at, 5.7) * 0.022 * amount + 0.012 * jolt,
		0.03 * jolt
	) * CFrame.Angles(
		math.noise(at, 9.3) * math.rad(1) * amount + math.rad(2 * jolt),
		0,
		math.noise(at, 11.9) * math.rad(0.8) * amount
	)
end

-- The whole view's share: it tightens a little with each stage and holds, in every camera view.
function Recoil.viewPunch(): number
	return -Tuning.values.chargeViewTighten * viewLevel
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
