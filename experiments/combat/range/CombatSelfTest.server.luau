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
