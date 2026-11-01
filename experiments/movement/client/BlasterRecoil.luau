--!strict
-- A quick kick, a readable peak, and a shaped recovery; sampled without accumulation.
local Motion = require(script.Parent.BlasterMotion)
local Tuning = require(script.Parent.Tuning)
local FirstPerson = require(script.Parent.FirstPerson)
local Ads = require(script.Parent.Ads)
local Recoil = {}
local STAGES = 3
local STAGE_SHAKE = { 0, 0.4, 0.7, 1 }
local CLUNK_SIZE = { 0.8, 1, 1.4 }
local KICK_ATTACK, KICK_LENGTH = 0.025, 0.17
local VIEW_RATE = 8 -- the view's held tighten stays gradual; snapping it read as zooming
local STEP_RATE = 60 -- held level snaps at each step; a slow ease reads as drawing a bow
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
-- vibration grows. A hard kick marks each step. Aim and crosshair never move.
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
	local toward = 1 - math.exp(-STEP_RATE * dt)
	shakeLevel += (STAGE_SHAKE[stage + 1] - shakeLevel) * toward
	heldLevel += (stage / STAGES - heldLevel) * toward
	viewLevel += (stage / STAGES - viewLevel) * (1 - math.exp(-VIEW_RATE * dt))
	moving += (math.clamp(movement, 0, 1) - moving) * (1 - math.exp(-8 * dt))
	-- Slower and larger on the move, where a fine fast shake is lost in the arm swing.
	shakePhase += (42 + (24 - 42) * moving) * dt
end

-- A hard hit: snaps to its peak almost at once, then is gone well before the next step.
local function clunk(now: number): number
	local age = now - clunkAt
	if age < 0 or age > KICK_LENGTH then
		return 0
	end
	if age < KICK_ATTACK then
		return (age / KICK_ATTACK) * (CLUNK_SIZE[clunkStage] or 0)
	end
	local fall = 1 - (age - KICK_ATTACK) / (KICK_LENGTH - KICK_ATTACK)
	return fall * fall * (CLUNK_SIZE[clunkStage] or 0)
end

-- Kicks alternate sides, so consecutive hits read as separate blows.
local function kickSide(): number
	return if clunkStage % 2 == 0 then 1 else -1
end

-- Through the sight only a very slight tremor is left, still growing with each step.
local function shakeAmount(moveShare: number): number
	local aimed = Ads.weight()
	local boost = 1 + (Tuning.values.chargeMoveShake - 1) * moving * moveShare * (1 - aimed)
	local sight = 1 + (Tuning.values.adsShake - 1) * aimed
	return shakeLevel * Tuning.values.chargeShake * boost * sight
end

-- The gun's own motion. In third person it is further away, so the notch and swell are larger.
function Recoil.vibration(now: number): CFrame
	local amount = shakeAmount(1)
	local free = 1 - Ads.weight() -- the sight holds its place: no steps or swells while aiming
	local jolt = clunk(now)
		* Tuning.values.chargeClunk
		* free
		* (1 + (Tuning.values.chargeMoveStep - 1) * moving)
	local held = heldLevel * free
	if jolt == 0 and amount < 1e-3 and held < 1e-3 then
		return CFrame.identity
	end
	local far = if FirstPerson.active() then 1 else 2.2
	local at = shakePhase
	return CFrame.new(
		math.noise(at, 1.3) * 0.032 * amount,
		math.noise(at, 7.1) * 0.032 * amount + (0.06 * held + 0.05 * jolt) * far,
		math.noise(at, 13.7) * 0.02 * amount + (0.2 * held + 0.16 * jolt) * far
	) * CFrame.Angles(
		math.noise(at, 21.9) * math.rad(1.2) * amount + math.rad(2.5 * held + 7 * jolt),
		math.noise(at, 29.3) * math.rad(1.2) * amount + math.rad(1.5 * jolt) * kickSide(),
		math.rad(3 * jolt) * kickSide()
	)
end

-- The arm takes the same motion, so the shake is not only in the gun.
function Recoil.armWindup(now: number): CFrame
	-- The arm stays much calmer on the move: a shaking arm throws the whole gun off the aim.
	local amount = shakeAmount(0.2)
	local jolt = clunk(now) * Tuning.values.chargeClunk * (1 - Ads.weight())
	if jolt == 0 and amount < 1e-3 then
		return CFrame.identity
	end
	local at = shakePhase + 40
	return CFrame.new(
		math.noise(at, 3.1) * 0.022 * amount,
		math.noise(at, 5.7) * 0.022 * amount + 0.03 * jolt,
		0.08 * jolt
	) * CFrame.Angles(
		math.noise(at, 9.3) * math.rad(1) * amount + math.rad(3 * jolt),
		0,
		math.noise(at, 11.9) * math.rad(0.8) * amount
	)
end

-- The whole view's share: it tightens a little with each stage and holds, in every camera view.
function Recoil.viewPunch(): number
	-- Each step hits the view too, in every state, so it reads even when the gun is not watched.
	local hit = clunk(os.clock()) * (1 - Ads.weight())
	return -Tuning.values.chargeViewTighten * viewLevel - Tuning.values.chargeStepPulse * hit
end

-- Each step shoves the eye back and rolls the view. Both leave the crosshair's direction alone.
function Recoil.viewKick(): CFrame
	local hit = clunk(os.clock()) * (1 - Ads.weight())
	if hit == 0 then
		return CFrame.identity
	end
	return CFrame.new(0, 0, Tuning.values.chargeStepShove * hit)
		* CFrame.Angles(0, 0, math.rad(Tuning.values.chargeStepRoll * hit) * kickSide())
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
