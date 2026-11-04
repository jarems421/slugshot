--!strict
-- Runs once in the target range when it starts: checks the shared flight model
-- against step-by-step integration, checks a sweep lands on a dummy, and logs the
-- Floppy's ranges and flight times as a tuning reference. Output goes to the Studio
-- log ([CombatSelfTest] PASS/FAIL lines).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Combat = require(ReplicatedStorage:WaitForChild("Combat"))

local failures = 0
local function check(ok: boolean, message: string)
	print(`[CombatSelfTest] {if ok then "PASS" else "FAIL"} {message}`)
	if not ok then
		failures += 1
	end
end

local floppy = Combat.Slugs.Floppy
local MUZZLE = Vector3.new(0, 4.5, 0)

-- A transforming slug's clock: full speed at launch, slowing and never speeding up. Slugs without one keep real time.
do
	local inferno = Combat.Slugs.Inferno
	local shape = inferno.Transformation :: Combat.Transformation
	local slowing, before, last = true, 0, math.huge
	for step = 1, 600 do
		local now = Combat.flightTime(inferno, step / 600)
		local rate = (now - before) * 600
		slowing = slowing and rate <= last + 1e-6 and rate >= shape.Cruise - 1e-6
		before, last = now, rate
	end
	check(slowing, "transformation flight slows smoothly down to its cruise speed")
	check(
		(Combat.flightTime(inferno, 0.001) / 0.001) > 0.97,
		"transformation flight starts at full speed"
	)
	check(Combat.flightTime(floppy, 0.7) == 0.7, "non-transforming slug keeps real time")
end

-- Closed form against small-step integration of dv/dt = g - k v.
for _, charge in { 0, 1 } do
	local velocity = Vector3.new(0, 0.3, -1).Unit * Combat.speed(floppy, charge)
	local position, current = MUZZLE, velocity
	local dt = 1 / 2000
	for _ = 1, 2000 do
		current += (Vector3.new(0, -floppy.Gravity, 0) - current * floppy.Drag) * dt
		position += current * dt
	end
	local exact = Combat.at(MUZZLE, velocity, floppy, 1)
	check(
		(exact - position).Magnitude < 0.05,
		string.format(
			"flight model matches integration at charge %d (error %.4f studs)",
			charge,
			(exact - position).Magnitude
		)
	)
end

-- At a target plane, integrate the exact shared flight until forward distance matches.
local function atPlane(
	origin: Vector3,
	target: Vector3,
	charge: number,
	correction: number
): Vector3?
	local flat = Vector3.new(target.X - origin.X, 0, target.Z - origin.Z)
	local axis = flat.Unit
	local velocity = Combat.launchDirection(origin, target, floppy, charge, correction)
		* Combat.speed(floppy, charge)
	if
		(Combat.at(origin, velocity, floppy, Combat.MaxFlight) - origin):Dot(axis) < flat.Magnitude
	then
		return nil
	end
	local low, high = 0, Combat.MaxFlight
	for _ = 1, 28 do
		local time = (low + high) / 2
		if (Combat.at(origin, velocity, floppy, time) - origin):Dot(axis) < flat.Magnitude then
			low = time
		else
			high = time
		end
	end
	return Combat.at(origin, velocity, floppy, (low + high) / 2)
end
for _, distance in { 10, 25, 45, 65, 85, 100, 120 } do
	for _, yaw in { 0, 0.7, 2.4 } do
		local heights: { number } = if distance == 120 then { -5, 0 } else { -5, 0, 5 }
		for _, height in heights do
			local target = MUZZLE
				+ Vector3.new(math.cos(yaw) * distance, height, math.sin(yaw) * distance)
			local hit = atPlane(MUZZLE, target, 1, 1)
			check(
				hit ~= nil and (hit :: Vector3 - target).Magnitude < 0.01,
				string.format(
					"full charge %.0f studs/yaw %.1f/height %.0f matches aim",
					distance,
					yaw,
					height
				)
			)
		end
	end
end
for _, distance in { 25, 45, 65, 85 } do
	local target = MUZZLE + Vector3.new(distance, 0, 0)
	local first = atPlane(MUZZLE, target, 1 / 3, 0.86)
	local second = atPlane(MUZZLE, target, 2 / 3, 0.95)
	local full = atPlane(MUZZLE, target, 1, 1)
	check(first ~= nil and second ~= nil and full ~= nil, `all levels reach {distance} stud plane`)
	if first and second and full then
		local dropOne, dropTwo = target.Y - first.Y, target.Y - second.Y
		check(
			dropOne > dropTwo and dropTwo > 0,
			string.format(
				"progressive level-dependent drop at %d: %.3f/%.3f/%.3f",
				distance,
				dropOne,
				dropTwo,
				target.Y - full.Y
			)
		)
		check(math.abs(first.Z) < 0.001 and math.abs(second.Z) < 0.001, "no lateral spread")
	end
end
check(
	Combat.aimedDirection(MUZZLE, MUZZLE + Vector3.new(500, 0, 0), floppy, 1) == nil,
	"impossible full-charge target is explicit"
)
local nearReach =
	Combat.launchDirection(MUZZLE, MUZZLE + Vector3.new(110, 0, 0), floppy, 1 / 3, 0.86)
check(
	nearReach.Y > 0 and math.abs(nearReach.Magnitude - 1) < 1e-5,
	"out-of-reach weak shot keeps a finite raised arc"
)
check(
	Combat.level(1 / 3) == 1 and Combat.level(2 / 3) == 2 and Combat.level(1) == 3,
	"three kick thresholds"
)

-- How far a level or raised shot travels before reaching the floor (y = 0).
local function reach(charge: number, degrees: number): (number, number)
	local direction = Vector3.new(0, math.sin(math.rad(degrees)), -math.cos(math.rad(degrees)))
	local velocity = direction * Combat.speed(floppy, charge)
	local t = 0
	while t < Combat.MaxFlight do
		t += 1 / 240
		local position = Combat.at(MUZZLE, velocity, floppy, t)
		if position.Y <= 0 then
			return -position.Z, t
		end
	end
	return -Combat.at(MUZZLE, velocity, floppy, t).Z, t
end
for _, charge in { 0, 1 } do
	local parts = {}
	for _, degrees in { 0, 10, 20, 30 } do
		local distance, time = reach(charge, degrees)
		table.insert(parts, string.format("%d deg %.0f studs/%.2fs", degrees, distance, time))
	end
	print(
		`[CombatSelfTest] Floppy {if charge == 0 then "tap" else "full charge"} reach: {table.concat(
			parts,
			", "
		)}`
	)
end

-- A level shot at a dummy's chest from 8 studs lands on that dummy.
local dummy: Model? = nil
for _ = 1, 100 do
	for _, model in CollectionService:GetTagged("RangeDummy") do
		if string.find(model.Name, "^Dummy1 ") then
			dummy = model
		end
	end
	if dummy then
		break
	end
	task.wait(0.1)
end
if dummy then
	local torso = dummy:WaitForChild("Torso") :: BasePart
	local origin = torso.Position + Vector3.new(0, 0, 8)
	local velocity = (torso.Position - origin).Unit * Combat.speed(floppy, 1)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {}
	local hitModel: Model? = nil
	local t = 0
	while t < 1 and not hitModel do
		local hit = Combat.sweep(origin, velocity, floppy, t, t + 1 / 60, params)
		t += 1 / 60
		if hit then
			hitModel = Combat.victim(hit.Instance)
			break
		end
	end
	check(hitModel == dummy, `sweep from 8 studs hits {dummy.Name}`)
else
	check(false, "range dummies exist")
end

print(`[CombatSelfTest] {if failures == 0 then "ALL PASS" else `{failures} FAILED`}`)
