--!strict
-- Slug shooting, shared by server and clients (owner brief, 2026-10-31). A shot is
-- fully described by origin, launch velocity and slug, and flies on a closed-form
-- path, so every client draws the same arc the server judges hits on. Feel values
-- are first proposals for owner playtest tuning; Floppy is the weakest slug.
local Combat = {}

-- How a transforming slug's flight is timed. The path never changes: the slug leaves at full speed and slows along it,
-- so the big form can be seen before it hits.
export type Transformation = {
	Spin: number, -- seconds
	Flash: number,
	Cruise: number, -- share of launch speed it slows to
	Slowdown: number, -- seconds; how sharply
}

export type Slug = {
	Label: string,
	Damage: number,
	-- Launch speed (studs/s) at each of the three shot levels.
	Speed: { number },
	Gravity: number, -- studs/s^2; slugs droop on their own curve, not world gravity
	Drag: number, -- 1/s; linear drag makes weak slugs fall short
	Radius: number, -- hit radius (studs)
	Tumble: number, -- end-over-end turns per second in flight
	Size: number, -- visual height outside the barrel (studs); used through flight and recovery
	Transforms: boolean, -- Floppy is the one slug that never transforms
	Transformation: Transformation?,
	ExactFrom: number, -- first shot level that lands exactly where it is aimed
	Expires: number?, -- seconds after firing that an unlanded shot disappears; without this it falls until it lands
	Blurb: string, -- one line for the inventory
}

Combat.WorldSlugSize = 2 -- owner, 2026-11-03: every slug outside the gun
Combat.MaxHealth = 100
Combat.Cooldown = 1.5 -- from the moment of firing, hit or miss
-- Local creature recovery finishes naturally, independently of ammo readiness.
Combat.Recovery = {
	-- Shares of the owner's total window (Tuning recoveryTime, 1.5 s from impact).
	ImpactTime = 0.06,
	SkidTime = 0.24,
	WriggleTime = 0.5,
	CrouchTime = 0.07,
	HopTime = 0.2,
	BurrowTime = 0.43,
	MinPace = 0.7, -- a long fall may overrun the window rather than rushing the creature
	HopHeight = 0.65,
	SkidPerSpeed = 0.035, -- studs of belly skid per stud/s of landing speed
	MaxSkid = 1.8,
	PilePieces = 24,
	GroundPieces = 7,
	FallGravity = 48,
	MaxFallTime = 3,
	StuckFallTime = 1.2, -- wedged between steep faces: burrow into the rock instead
}
Combat.MaxFlight = 3 -- seconds before an unlanded shot is dropped
Combat.MuzzleReach = 2.4 -- studs from the shoulder to the muzzle along the aim
-- Server checks: how far a claimed muzzle may sit from the shooter's movement root, and how
-- early a shot may arrive relative to the server's cooldown (network jitter).
Combat.MaxOriginOffset = 6
Combat.OriginGrace = 0.25 -- bounded wait for character physics to catch up with a firing message
Combat.CooldownTolerance = 0.15
Combat.ShotRate = 4 -- requests per second accepted before the cooldown check

-- Slot order; switching between slots comes with the second slug.
Combat.Loadout = { "Floppy", "Inferno" }
Combat.SlotCount = 5 -- owner, 2026-11-02: five carried slugs
Combat.SlugTotal = 13 -- owner, 2026-11-01: Floppy plus twelve planned models

Combat.Slugs = {
	-- Weakest slug: a droopy, tumbling flop that lands short of other slugs. 7 damage, no
	-- knockback (owner).
	Floppy = {
		Label = "Floppy",
		Damage = 7,
		Speed = { 85, 100, 115 },
		Gravity = 70,
		Drag = 0.35,
		Radius = 0.3,
		Tumble = 2,
		Size = Combat.WorldSlugSize,
		Transforms = false,
		ExactFrom = 3,
		Blurb = "A drowsy, soft little slug.",
	},
	-- Proposal for owner playtest (docs/slugs/catalog/inferno.md): far faster and flatter than Floppy, and exact from the
	-- second kick. Drag can't be 0 in the closed-form flight, so it's small enough not to matter at these speeds.
	Inferno = {
		Label = "Inferno",
		Damage = 25,
		Speed = { 300, 420, 500 },
		Gravity = 20,
		Drag = 0.05,
		Radius = 0.3,
		Tumble = 0,
		Size = Combat.WorldSlugSize,
		Transforms = true,
		Transformation = { Spin = 0.15, Flash = 0.05, Cruise = 0.4, Slowdown = 0.04 },
		Expires = Combat.Cooldown, -- gone as the next shot is ready; about 310 studs at full charge
		ExactFrom = 2,
		Blurb = "A cocky little menace. Fast, hot and hits hard.",
	},
} :: { [string]: Slug }

-- Shots have three levels (owner, 2026-11-01). A tap, and anything short of the second kick, is
-- level 1; the second kick reaches level 2 and only a full charge reaches level 3.
function Combat.level(charge: number): number
	return math.clamp(math.floor(math.clamp(charge, 0, 1) * 3), 1, 3)
end

function Combat.speed(slug: Slug, charge: number): number
	return slug.Speed[Combat.level(charge)]
end

-- Position and velocity t seconds after launch, under gravity with linear drag:
-- v(t) = vt + (v0 - vt) e^(-kt), x(t) = x0 + vt t + (v0 - vt)(1 - e^(-kt)) / k,
-- where vt = g / k is the terminal velocity.
function Combat.at(origin: Vector3, velocity: Vector3, slug: Slug, t: number): (Vector3, Vector3)
	local k = slug.Drag
	local terminal = Vector3.new(0, -slug.Gravity / k, 0)
	local decay = math.exp(-k * t)
	local position = origin + terminal * t + (velocity - terminal) * ((1 - decay) / k)
	return position, terminal + (velocity - terminal) * decay
end

-- How far along its path (in Combat.at's t) a slug is, `elapsed` real seconds after firing. Server and clients both go
-- through this, so they still agree on where a shot is.
function Combat.flightTime(slug: Slug, elapsed: number): number
	local shape = slug.Transformation
	if not shape then
		return elapsed
	end
	return shape.Cruise * elapsed
		+ (1 - shape.Cruise) * shape.Slowdown * (1 - math.exp(-elapsed / shape.Slowdown))
end

-- The launch direction whose arc passes through `target`, so a shot lands where it is aimed
-- even though it droops. Returns nil when the target is beyond this speed's reach.
function Combat.aimedDirection(
	origin: Vector3,
	target: Vector3,
	slug: Slug,
	charge: number
): Vector3?
	local speed = Combat.speed(slug, charge)
	local k = slug.Drag
	local terminal = Vector3.new(0, -slug.Gravity / k, 0)
	local offset = target - origin
	-- The launch velocity that arrives at the target after t seconds.
	local function needed(t: number): Vector3
		return (offset - terminal * t) * k / (1 - math.exp(-k * t)) + terminal
	end
	if offset.Magnitude < 1e-4 then
		return nil
	end
	-- Find the minimum required speed first. A fixed time scan can miss the
	-- narrow feasible interval near maximum range and incorrectly switch arcs.
	local low, high = 1e-5, Combat.MaxFlight
	for _ = 1, 32 do
		local a, b = low + (high - low) / 3, high - (high - low) / 3
		if needed(a).Magnitude < needed(b).Magnitude then
			high = b
		else
			low = a
		end
	end
	local peak = (low + high) / 2
	if needed(peak).Magnitude > speed then
		return nil
	end
	-- Earliest arrival is the low arc; never choose the second/high root.
	low, high = 1e-5, peak
	for _ = 1, 28 do
		local middle = (low + high) / 2
		if needed(middle).Magnitude <= speed then
			high = middle
		else
			low = middle
		end
	end
	return needed(high).Unit
end

-- Lower charge loses speed and retains incomplete gravity correction. Saturating
-- its own reachable arc must not introduce discrete distance or angle switches.
function Combat.launchDirection(
	origin: Vector3,
	target: Vector3,
	slug: Slug,
	charge: number,
	correction: number
): Vector3
	local offset = target - origin
	if offset.Magnitude < 1e-4 then
		return Vector3.new(0, 0, -1)
	end
	local straight = offset.Unit
	local arc = Combat.aimedDirection(origin, target, slug, charge)
	if not arc then
		-- Saturate continuously at the reachable point on this same line. The old
		-- 10% distance steps and the client's 45-stud fallback produced hard cliffs.
		local near, far = 0, 1
		for _ = 1, 24 do
			local scale = (near + far) / 2
			local candidate = Combat.aimedDirection(origin, origin + offset * scale, slug, charge)
			if candidate then
				near, arc = scale, candidate
			else
				far = scale
			end
		end
	end
	local amount = if Combat.level(charge) >= slug.ExactFrom
		then 1
		else math.clamp(correction, 0, 1)
	return if arc then straight:Lerp(arc, amount).Unit else straight
end

function Combat.sweep(
	origin: Vector3,
	velocity: Vector3,
	slug: Slug,
	from: number,
	to: number,
	params: RaycastParams
): RaycastResult?
	-- Both rendering and authority sweep the curved flight in short segments.
	-- A rendering hitch must not replace a whole arc by one long straight chord.
	local time = from
	local a = Combat.at(origin, velocity, slug, time)
	while time < to do
		local nextTime = math.min(to, time + 1 / 120)
		local b = Combat.at(origin, velocity, slug, nextTime)
		local step = b - a
		if step.Magnitude >= 1e-4 then
			local hit = workspace:Spherecast(a, slug.Radius, step, params)
			if hit then
				return hit
			end
		end
		time, a = nextTime, b
	end
	return nil
end

-- The character or dummy a hit part belongs to (a model with a living Humanoid).
function Combat.victim(part: Instance): (Model?, Humanoid?)
	local model = part:FindFirstAncestorWhichIsA("Model")
	while model do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return model, humanoid
		end
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	return nil, nil
end

function Combat.isBlaster(item: Instance?): boolean
	return item ~= nil and item:IsA("Tool") and item:GetAttribute("BlasterMotionDriver") == true
end

return table.freeze(Combat)
