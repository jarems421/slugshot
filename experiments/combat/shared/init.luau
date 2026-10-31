--!strict
-- Slug shooting, shared by server and clients (owner brief, 2026-10-31). A shot is
-- fully described by origin, launch velocity and slug, and flies on a closed-form
-- path, so every client draws the same arc the server judges hits on. Feel values
-- are first proposals for owner playtest tuning; Floppy is the weakest slug.
local Combat = {}

export type Slug = {
	Label: string,
	Damage: number,
	-- Launch speed (studs/s) for a tap and for a full charge.
	Speed: { number },
	Gravity: number, -- studs/s^2; slugs droop on their own curve, not world gravity
	Drag: number, -- 1/s; linear drag makes weak slugs fall short
	Radius: number, -- hit radius (studs)
	Tumble: number, -- end-over-end turns per second in flight
	Size: number, -- in-flight length (studs)
	Transforms: boolean, -- Floppy is the one slug that never transforms
}

Combat.MaxHealth = 100
Combat.ChargeTime = 0.8 -- seconds of holding for a full charge
Combat.Cooldown = 1.5 -- from the moment of firing, hit or miss
Combat.SplatTime = 0.25 -- the slug recovers from its splat
Combat.ReturnTime = 0.5 -- then hops back in this long, whatever the distance
Combat.MaxFlight = 3 -- seconds before an unlanded shot is dropped
Combat.MuzzleReach = 2.4 -- studs from the shoulder to the muzzle along the aim
-- Server checks: how far a claimed muzzle may sit from the shooter's torso, and how
-- early a shot may arrive relative to the server's cooldown (network jitter).
Combat.MaxOriginOffset = 6
Combat.CooldownTolerance = 0.15
Combat.ShotRate = 4 -- requests per second accepted before the cooldown check

-- Slot order; switching between slots comes with the second slug.
Combat.Loadout = { "Floppy" }

Combat.Slugs = {
	-- Weakest slug: a slow, droopy, tumbling flop that lands short. 5 damage, no
	-- knockback (owner).
	Floppy = {
		Label = "Floppy",
		Damage = 5,
		Speed = { 55, 100 },
		Gravity = 70,
		Drag = 1.2,
		Radius = 0.3,
		Tumble = 2,
		Size = 0.55,
		Transforms = false,
	},
} :: { [string]: Slug }

function Combat.speed(slug: Slug, charge: number): number
	local t = math.clamp(charge, 0, 1)
	return slug.Speed[1] + (slug.Speed[2] - slug.Speed[1]) * t
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
