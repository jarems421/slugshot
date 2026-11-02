--!strict
-- Slug shooting, shared by server and clients (owner brief, 2026-10-31). A shot is
-- fully described by origin, launch velocity and slug, and flies on a closed-form
-- path, so every client draws the same arc the server judges hits on. Feel values
-- are first proposals for owner playtest tuning; Floppy is the weakest slug.
local Combat = {}

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
	Blurb: string, -- one line for the inventory
}

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
Combat.Loadout = { "Floppy" }
Combat.SlotCount = 5 -- owner, 2026-11-02: five carried slugs
Combat.SlugTotal = 13 -- owner, 2026-11-01: Floppy plus twelve planned models

Combat.Slugs = {
	-- Weakest slug: a droopy, tumbling flop that lands short of other slugs. 7 damage, no
	-- knockback (owner).
	Floppy = {
		Label = "Floppy",
		Damage = 7,
		Speed = { 65, 88, 115 },
		Gravity = 70,
		Drag = 1,
		Radius = 0.3,
		Tumble = 2,
		Size = 1, -- owner, 2026-11-01: permanent Floppy size outside the gun
		Transforms = false,
		Blurb = "A drowsy, soft little slug.",
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

-- First thing the slug's sphere touches between two flight times, if any.
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
	-- Earliest arrival at this speed gives the flat arc rather than a high lob.
	local before = 0.005
	local t = before
	while t < Combat.MaxFlight do
		t += 0.01
		if needed(t).Magnitude <= speed then
			for _ = 1, 12 do
				local middle = (before + t) / 2
				if needed(middle).Magnitude <= speed then
					t = middle
				else
					before = middle
				end
			end
			return needed(t).Unit
		end
		before = t
	end
	return nil
end

function Combat.sweep(
	origin: Vector3,
	velocity: Vector3,
	slug: Slug,
	from: number,
	to: number,
	params: RaycastParams
): RaycastResult?
	local a = Combat.at(origin, velocity, slug, from)
	local b = Combat.at(origin, velocity, slug, to)
	local step = b - a
	if step.Magnitude < 1e-4 then
		return nil
	end
	return workspace:Spherecast(a, slug.Radius, step, params)
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
