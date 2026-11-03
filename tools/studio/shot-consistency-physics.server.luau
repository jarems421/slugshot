--!strict
-- Isolated numerical/collision regressions, excluded from normal places.
assert(game:GetService("RunService"):IsStudio())
local RS = game:GetService("ReplicatedStorage")
local Combat = (require :: any)(RS:WaitForChild("Combat"))
local slug = Combat.Slugs.Floppy
local H = game:GetService("HttpService")
local ok, problem = pcall(function()
	local origin = Vector3.new(800, 1000, 800)
	local velocity = Vector3.new(0.8, 0.3, -1).Unit * Combat.speed(slug, 0)
	local witness = Instance.new("Part")
	witness.Name = "CurvedFlightWitness"
	witness.Size = Vector3.one * 0.12
	witness.Anchored, witness.CanCollide, witness.CanQuery = true, false, true
	witness.Position = Combat.at(origin, velocity, slug, 0.2)
	witness.Parent = workspace
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { witness }
	local straightEnd = Combat.at(origin, velocity, slug, 0.4)
	local oldChord = workspace:Spherecast(origin, slug.Radius, straightEnd - origin, params)
	assert(oldChord == nil, "fixture does not expose the old chord miss")
	local contacts: { { number } } = {}
	for _, dt in { 1 / 240, 1 / 60, 1 / 30, 1 / 15, 0.4 } do
		local time, contact = 0, nil :: RaycastResult?
		repeat
			contact = Combat.sweep(origin, velocity, slug, time, math.min(time + dt, 0.4), params)
			time += dt
		until contact or time >= 0.4
		assert(
			contact and contact.Instance == witness,
			"render-rate/hitch sweep missed arc collider"
		)
		table.insert(contacts, {
			dt,
			(contact :: RaycastResult).Position.X,
			(contact :: RaycastResult).Position.Y,
			(contact :: RaycastResult).Position.Z,
		})
	end
	witness:Destroy()
	local previous: { [number]: Vector3 } = {}
	local maximum = { 0, 0, 0 }
	local maximumDown = { 0, 0, 0 }
	for i = 40, 680 do
		local distance = i / 4
		for level = 1, 3 do
			local direction = Combat.launchDirection(
				Vector3.zero,
				Vector3.new(distance, 0, 0),
				slug,
				level / 3,
				if level == 1 then 0.86 elseif level == 2 then 0.95 else 1
			)
			assert(
				direction.Magnitude == direction.Magnitude
					and math.abs(direction.Magnitude - 1) < 1e-5,
				"invalid launch direction"
			)
			local prior = previous[level]
			if prior then
				local angle = math.deg(math.acos(math.clamp(prior:Dot(direction), -1, 1)))
				maximum[level] = math.max(maximum[level], angle)
				maximumDown[level] = math.max(
					maximumDown[level],
					math.deg(math.asin(prior.Y) - math.asin(direction.Y))
				)
			end
			previous[level] = direction
		end
	end
	for level = 1, 3 do
		assert(maximum[level] < 5, "distance sweep has an angle cliff")
		assert(maximumDown[level] < 0.15, "distance sweep abruptly loses elevation")
	end
	-- Vertical, elevated and downhill roots: no accidental high/second root.
	for _, height in { -60, -10, 0, 10, 60 } do
		for _, distance in { 0.1, 10, 40, 80, 120, 240 } do
			for level = 1, 3 do
				local target = Vector3.new(distance, height, 0)
				local direction = Combat.launchDirection(Vector3.zero, target, slug, level / 3, 1)
				assert(
					direction.X > 0 and math.abs(direction.Z) < 1e-6 and direction.Y == direction.Y,
					"vertical/downhill solve flipped sideways"
				)
			end
		end
	end
	print("SHOOTCHECK physics " .. H:JSONEncode({
		oldChordMissed = true,
		contacts = contacts,
		maxStepDegrees = maximum,
		maxDownDegrees = maximumDown,
		samplesPerLevel = 641,
	}))
end)
RS:SetAttribute("ShotConsistencyPhysicsPass", ok)
if not ok then
	warn("SHOOTCHECK FAIL physics " .. tostring(problem))
end

local cover: Part? = nil
local coverFixture = Instance.new("RemoteFunction")
coverFixture.Name = "ShotConsistencyCover"
coverFixture.OnServerInvoke = function(player: Player, pose: any)
	if cover then
		cover:Destroy()
		cover = nil
	end
	if pose == nil then
		return
	end
	local root = (player.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
	assert(
		typeof(pose) == "CFrame" and (pose.Position - root.Position).Magnitude < 8,
		"cover fixture must stay beside shooter"
	)
	local part = Instance.new("Part")
	part.Name = "ShotConsistencyCover"
	part.Size = Vector3.new(4, 4, 0.12)
	part.CFrame = pose
	part.Anchored, part.CanCollide, part.CanQuery = true, false, true
	part.Transparency = 0.4
	part.Parent = workspace
	cover = part
end
coverFixture.Parent = RS
