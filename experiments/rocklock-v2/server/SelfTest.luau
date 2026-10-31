--!strict
-- Runtime self-test for the Rocklock v2 destruction prototype (Studio only, test tool key Y).
-- Drives the real server code paths and prints PASS/FAIL lines, then resets the round.
local Workspace = game:GetService("Workspace")
local Config = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("RocklockV2")
		:WaitForChild("DestructionConfig")
)
local Destruction = require(script.Parent.Destruction)

local SelfTest = {}
local running = false

local function earthAt(point: Vector3, size: number): number
	local region = Region3.new(
		point - Vector3.new(size, size, size) / 2,
		point + Vector3.new(size, size, size) / 2
	):ExpandToGrid(4)
	local _, occupancy = Workspace.Terrain:ReadVoxels(region, 4)
	local total = 0
	for x = 1, #occupancy do
		for y = 1, #occupancy[x] do
			for z = 1, #occupancy[x][y] do
				total += occupancy[x][y][z]
			end
		end
	end
	return total
end

function SelfTest.run(map: Model, report: (string) -> ())
	if running then
		return
	end
	running = true
	local tally = { passed = 0, total = 0 }
	local function check(name: string, ok: boolean, detail: string?)
		tally.total += 1
		tally.passed += if ok then 1 else 0
		local line = `[RocklockV2 SelfTest] {if ok then "PASS" else "FAIL"} {name}{if detail
			then " - " .. detail
			else ""}`
		print(line)
		report(line)
	end
	Destruction.reset()
	local chunks, rubble, pristine = Destruction.counts()
	check(
		"pristine state",
		chunks == pristine and rubble == 0,
		`{chunks}/{pristine} chunks, {rubble} rubble`
	)

	local nonzero = true
	for _, archetype in Config.ArchetypeOrder do
		for material in Config.Materials :: { [string]: any } do
			nonzero = nonzero
				and Destruction.multiplier(material, archetype) >= Config.MinMultiplier
		end
	end
	check("every archetype damages every material", nonzero and Config.MinMultiplier > 0)

	local collision = map:FindFirstChild("Collision")
	local essential = collision and collision:FindFirstChildWhichIsA("BasePart")
	check(
		"essential terrain is not registered",
		essential ~= nil and Destruction.structureOf(essential :: BasePart) == nil
	)

	local pillar = Destruction.get("PillarWest_N")
	if pillar then
		Destruction.damage(pillar, Config.Tiers.Medium, "Blunt")
		local afterOne = pillar.broken
		while pillar.health > 0 do
			Destruction.damage(pillar, Config.Tiers.Weak, "Elemental")
		end
		check(
			"pillar breaks progressively",
			afterOne == 1 and pillar.broken == pillar.stages,
			`stage {afterOne} after one medium hit, {pillar.broken}/{pillar.stages} at zero`
		)
	else
		check("pillar breaks progressively", false, "PillarWest_N missing")
	end

	local _, rubbleBefore = Destruction.counts()
	local bridge = Destruction.get("BridgeCentre")
	if bridge then
		local hits = 0
		while bridge.health > 0 and hits < 10 do
			Destruction.damage(bridge, Config.Tiers.Heavy, "Blunt")
			hits += 1
		end
		task.wait(Config.Rubble.MaxFallTime + 0.6)
		local _, rubbleAfter = Destruction.counts()
		check(
			"bridge section falls as rubble",
			bridge.health <= 0 and rubbleAfter > rubbleBefore,
			`{hits} heavy hits, rubble {rubbleBefore} -> {rubbleAfter}`
		)
	else
		check("bridge section falls as rubble", false, "BridgeCentre missing")
	end

	local seal = Destruction.get("ShaftSeal")
	if seal then
		local sealFrame, sealSize = seal.model:GetBoundingBox()
		local hits = 0
		while seal.health > 0 and hits < 10 do
			Destruction.damage(seal, Config.Tiers.Medium, "Penetrating")
			hits += 1
		end
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = {
			map:FindFirstChild("Destructibles") :: Instance,
			map:FindFirstChild("Rubble") :: Instance,
		}
		local blocking =
			Workspace:GetPartBoundsInBox(sealFrame, sealSize * Vector3.new(0.5, 0.8, 0.8), params)
		check(
			"seal opens the shaft",
			seal.health <= 0 and #blocking == 0,
			`{hits} medium penetrating hits`
		)
	else
		check("seal opens the shaft", false, "ShaftSeal missing")
	end

	local hanging = Destruction.get("HangingKeystone")
	if hanging then
		local parts = table.clone(hanging.chunks)
		Destruction.damage(hanging, Config.Tiers.Heavy, "Blunt")
		local warned = hanging.collapsing
		task.wait(hanging.hazardWarning + Config.Rubble.MaxFallTime + 0.6)
		local lowest = math.huge
		for _, part in parts do
			lowest = math.min(lowest, part.Position.Y - part.Size.Y / 2)
		end
		local landed = parts[1].Parent ~= nil and parts[1]:GetAttribute("Rubble") == "Settled"
		check(
			"hanging rock warns, falls and settles",
			warned and landed and lowest < 25 and lowest > 14,
			`lowest point {math.floor(lowest * 10) / 10} (keystone top 20)`
		)
	else
		check("hanging rock warns, falls and settles", false, "HangingKeystone missing")
	end

	-- Probe open collapse floor between the keystone and the pit edge (from the zone marker).
	local zones = map:FindFirstChild("TerrainZones")
	local zone = zones and zones:FindFirstChild("PitFloor")
	local base = if zone and zone:IsA("BasePart")
		then zone.Position + Vector3.new(0, 0, zone.Size.Z * 0.33)
		else Vector3.new(0, -7.5, 16)
	local probe = base
	local before = earthAt(probe, 4)
	local dug = Destruction.excavate(base + Vector3.new(0, 1, 0), 3.4)
	local after = earthAt(probe, 4)
	check(
		"pit floor excavates",
		dug and after < before,
		`earth {math.floor(before)} -> {math.floor(after)}`
	)
	local outside = Destruction.excavate(Vector3.new(-30, 40, 0), 3)
	check("digging outside earth zones does nothing", not outside)
	task.wait(1.05)
	local accepted = 0
	for _ = 1, Config.Excavation.MaxPerSecond + 8 do
		if Destruction.excavate(base + Vector3.new(6, 0, 0), 1) then
			accepted += 1
		end
	end
	check(
		"rapid digging is rate-limited",
		accepted <= Config.Excavation.MaxPerSecond,
		`{accepted} accepted in one burst`
	)

	Destruction.reset()
	local chunks2, rubble2, pristine2 = Destruction.counts()
	local healthy = true
	for _, s in Destruction.all() do
		healthy = healthy and s.health == s.maxHealth and s.broken == 0
	end
	local refilled = earthAt(probe, 4)
	check(
		"reset restores everything",
		chunks2 == pristine2 and rubble2 == 0 and healthy and refilled >= before - 0.5,
		`{chunks2}/{pristine2} chunks, {rubble2} rubble, earth {math.floor(refilled)}`
	)
	local summary = `[RocklockV2 SelfTest] {tally.passed}/{tally.total} passed`
	print(summary)
	report(summary)
	running = false
end

return SelfTest
