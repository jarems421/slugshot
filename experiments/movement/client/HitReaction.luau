--!strict
-- How a hit moves the body and the view (owner, 2026-11-02): more damage hits harder and takes longer to recover from,
-- in every state. A spring rather than a clip, so it layers over slides, jumps and flips, and quick hits stack.
-- The view only rolls about the crosshair and moves along its line, so being hit never moves the aim.
local Tuning = require(script.Parent.Tuning)

local HitReaction = {}

export type State = {
	amount: number,
	velocity: number,
	rate: number,
	direction: Vector3,
	twist: number,
}

local DAMPING = 0.6
local PEAK = 0.5 -- a spring with this damping peaks at this share of (kick speed / rate)
local RATE_LIGHT, RATE_HEAVY = 15, 7 -- the heavier the hit, the slower the body comes back
local STEP = 1 / 120
local IDENTITY = CFrame.identity

local mine: State? = nil

function HitReaction.new(): State
	return { amount = 0, velocity = 0, rate = RATE_LIGHT, direction = Vector3.zAxis, twist = 1 }
end

-- The local player's state, which drives the view.
function HitReaction.setMine(state: State)
	mine = state
end

-- Every point of damage adds the same amount, on a small base so the lightest hit still reads.
function HitReaction.severity(damage: number): number
	local T = Tuning.values
	return math.clamp(T.hitBase + damage / T.hitFull, 0, T.hitMax)
end

-- `direction` is the way the hit travels, in world space. Returns the hit's severity.
function HitReaction.hit(state: State, damage: number, direction: Vector3): number
	local severity = HitReaction.severity(damage)
	state.rate = RATE_LIGHT + (RATE_HEAVY - RATE_LIGHT) * math.min(severity, 1)
	state.velocity += severity * state.rate * Tuning.values.hitRecovery / PEAK
	state.direction = direction
	state.twist = if math.random() < 0.5 then -1 else 1
	return severity
end

function HitReaction.step(state: State, dt: number)
	if state.amount == 0 and state.velocity == 0 then
		return
	end
	local rate = state.rate * Tuning.values.hitRecovery
	local limit = Tuning.values.hitMax
	for _ = 1, math.ceil(dt / STEP) do
		state.velocity -= (rate * rate * state.amount + 2 * DAMPING * rate * state.velocity) * STEP
		state.amount += state.velocity * STEP
		-- Stacked hits drive the body to its limit rather than past it.
		if state.amount > limit then
			state.amount = limit
			state.velocity = math.min(state.velocity, 0)
		end
	end
	if math.abs(state.amount) < 1e-3 and math.abs(state.velocity) < 1e-2 then
		state.amount, state.velocity = 0, 0
	end
end

-- Layers the reaction onto a pose in R15 terms, before any rig conversion. `body` is the body's frame in the world;
-- `share` scales the whole reaction; `rightArm` scales the arm holding the blaster.
function HitReaction.pose(
	state: State,
	pose: { [string]: CFrame },
	body: CFrame,
	share: number,
	rightArm: number
)
	local amount = state.amount * share
	if amount == 0 then
		return
	end
	local T = Tuning.values
	local away = body:VectorToObjectSpace(state.direction)
	local flat = Vector3.new(away.X, 0, away.Z)
	flat = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
	local back, side = flat.Z, flat.X
	local shove = T.hitShove * amount
	pose.Root = CFrame.new(side * shove, 0, back * shove) * (pose.Root or IDENTITY)
	-- The chest takes it at the waist, so the legs stay on the ground, and the head snaps further.
	local lean = math.rad(T.hitLean) * amount
	pose.Waist = CFrame.Angles(back * lean, state.twist * lean * 0.35, -side * lean)
		* (pose.Waist or IDENTITY)
	local head = math.rad(T.hitHead) * amount
	pose.Neck = CFrame.Angles(back * head, -state.twist * head * 0.4, -side * head)
		* (pose.Neck or IDENTITY)
	-- The arms are left behind by the chest and thrown apart.
	local arm = math.rad(T.hitArms) * amount
	pose.LeftShoulder = CFrame.Angles(back * arm, 0, -side * arm - arm * 0.5)
		* (pose.LeftShoulder or IDENTITY)
	local right = arm * rightArm
	pose.RightShoulder = CFrame.Angles(back * right, 0, -side * right + right * 0.5)
		* (pose.RightShoulder or IDENTITY)
end

-- Rolls the view away from the hit and moves the eye along the view's line.
function HitReaction.viewKick(view: CFrame): CFrame
	local state = mine
	if not state or state.amount == 0 then
		return IDENTITY
	end
	local T = Tuning.values
	local away = view:VectorToObjectSpace(state.direction)
	-- A hit from dead ahead has no side to roll to, so it picks one.
	local roll = away.X + state.twist * (1 - math.abs(away.X)) * 0.6
	return CFrame.new(0, 0, away.Z * T.hitViewShove * state.amount)
		* CFrame.Angles(0, 0, -roll * math.rad(T.hitViewRoll) * state.amount)
end

-- Read-only level of the local player's reaction, for deterministic Studio checks.
function HitReaction.level(): number
	return if mine then mine.amount else 0
end

function HitReaction.viewPunch(): number
	local state = mine
	return if state then Tuning.values.hitViewLens * state.amount else 0
end

return HitReaction
