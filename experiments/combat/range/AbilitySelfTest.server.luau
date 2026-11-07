--!strict
-- Runs once in the target range when it starts: checks slug abilities (docs/slugs/ability-specs.md) in a test zone
-- high above the range, with its own dummies. The Red owner is a bare team, so nothing here needs a player. Output
-- goes to the Studio log ([AbilitySelfTest] PASS/FAIL lines).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local failures = 0
local function check(ok: boolean, message: string)
	print(`[AbilitySelfTest] {if ok then "PASS" else "FAIL"} {message}`)
	if not ok then
		failures += 1
	end
end

local CombatModule = ReplicatedStorage:WaitForChild("Combat")
local Abilities = require(CombatModule:WaitForChild("Abilities"))
local Runtime = require(CombatModule:WaitForChild("AbilityRuntime"))

check(Abilities.speedScale({ 0.6, 0.5 }) == 0.5, "only the strongest slow counts")
check(Abilities.speedScale({ 0.3 }) == Abilities.MinSpeedScale, "slows never go below the floor")
check(Abilities.speedScale({}) == 1, "no slows is full speed")

local zone = Instance.new("Folder")
zone.Name = "AbilitySelfTest"
zone.Parent = workspace
local TOP = 400
local function block(size: Vector3, centre: Vector3, name: string?): Part
	local part = Instance.new("Part")
	part.Name = name or "Block"
	part.Size = size
	part.Position = centre
	part.Anchored = true
	part.Parent = zone
	return part
end
block(Vector3.new(220, 2, 120), Vector3.new(0, TOP - 1, 0), "Floor")
local function target(name: string, x: number, z: number, lift: number?, team: string?): Model
	local model = Instance.new("Model")
	model.Name = name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Anchored = true
	root.Position = Vector3.new(x, TOP + 3 + (lift or 0), z)
	root.Parent = model
	local torso = root:Clone()
	torso.Name = "Torso"
	torso.Parent = model
	-- A Humanoid without a Head dies, so the stand-ins get one like a real character.
	local head = root:Clone()
	head.Name = "Head"
	head.Size = Vector3.new(2, 1, 1)
	head.Position = root.Position + Vector3.new(0, 1.5, 0)
	head.Parent = model
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = model
	model.PrimaryPart = root
	if team then
		model:SetAttribute("SlugshotTeam", team)
	end
	model.Parent = zone
	return model
end
local function health(model: Model): number
	return (model:FindFirstChildOfClass("Humanoid") :: Humanoid).Health
end
local red: Runtime.Owner = { team = "Red" }
local forward = Vector3.new(0, 0, -1)
local share = 30 * Abilities.Kits.Aquabeek.main.Share

-- Control effects share one immunity.
do
	local subject = target("Control subject", 100, 50)
	check(Runtime.applyControl(subject, "Snapbind", 1.5, "Red"), "a control effect applies")
	check(
		not Runtime.applyControl(subject, "Flash", 1, "Red"),
		"any control is blocked during immunity"
	)
	subject:SetAttribute("ControlImmuneUntil", workspace:GetServerTimeNow() - 0.1)
	check(
		Runtime.applyControl(subject, "Flash", 1, "Red"),
		"control works again after the immunity"
	)
end

-- Lane 1: the wave rolls 25 studs along the shot's line, hurting enemies once and never teammates.
local hitTarget = target("Wave target", -80, 0)
local behind8 = target("Behind 8", -80, -8)
local behind16 = target("Behind 16", -78, -16)
local outOfLine = target("Out of line", -72, -8)
local beyond = target("Beyond reach", -80, -32)
local teammate = target("Teammate", -80, -4, nil, "Red")
-- Lane 2: a wall stops it. Lane 3: it climbs a step. Lane 4: it falls from an airborne hit.
-- Lane 5: cover takes damage and stops it.
local walled = target("Wall target", -50, 0)
block(Vector3.new(10, 8, 1), Vector3.new(-50, TOP + 4, -6), "Wall")
local pastWall = target("Past wall", -50, -10)
local stepped = target("Step target", -20, 0)
block(Vector3.new(10, 1.5, 10), Vector3.new(-20, TOP + 0.75, -9), "Step")
local onStep = target("On step", -20, -9, 1.5)
local flying = target("Airborne target", 10, 0, 6)
local below = target("Below airborne", 10, -10)
local covered = target("Cover target", 40, 0)
local cover = block(Vector3.new(10, 6, 1), Vector3.new(40, TOP + 3, -6), "Cover")
cover:SetAttribute("Health", 8)
cover:SetAttribute("CrashwaveDamage", 2)
CollectionService:AddTag(cover, Abilities.CoverTag)
local pastCover = target("Past cover", 40, -10)

for _, start in { hitTarget, walled, stepped, flying, covered } do
	Runtime.crashwave(red, start, forward, 30)
end
task.wait(1.5)
check(
	math.abs(health(behind8) - (100 - share)) < 0.01,
	"Crashwave hits an enemy behind the target for a third"
)
check(
	math.abs(health(behind16) - (100 - share)) < 0.01,
	"Crashwave hits a second enemy further along"
)
check(health(outOfLine) == 100, "Crashwave misses an enemy out of line")
check(health(beyond) == 100, "Crashwave stops after 25 studs")
check(health(teammate) == 100, "Crashwave never hurts a teammate")
check(health(hitTarget) == 100, "the wave does not hit the player it started from again")
check(
	Abilities.hasStatus(behind8, "Soaked", workspace:GetServerTimeNow()),
	"Crashwave soaks who it hits"
)
check(health(pastWall) == 100, "a wall stops Crashwave")
check(math.abs(health(onStep) - (100 - share)) < 0.01, "Crashwave climbs a step")
check(math.abs(health(below) - (100 - share)) < 0.01, "an airborne hit's wave falls and rolls on")
check(
	cover:GetAttribute("Health") == 6 and health(pastCover) == 100,
	"cover takes the wave and stops it"
)

-- Mistbank: two at once per owner, soaks enemies inside, never teammates, goes when its surface goes.
local mistOwner: Runtime.Owner = { team = "Red" }
local function mine(): number
	local count = 0
	for _, object in Runtime.objects() do
		if object.name == "Mistbank" and object.part.Parent then
			count += 1
		end
	end
	return count
end
local before = mine()
local enemyInMist = target("Enemy in mist", 70, 30)
local allyInMist = target("Ally in mist", 72, 30, nil, "Red")
Runtime.mistbank(mistOwner, Vector3.new(70, TOP, 30), nil, nil)
Runtime.mistbank(mistOwner, Vector3.new(90, TOP, 30), nil, nil)
Runtime.mistbank(mistOwner, Vector3.new(110, TOP, 30), nil, nil)
check(mine() - before == 2, "a third Mistbank replaces the oldest (cap 2)")
-- The first one was replaced, so mist the pair again where they stand.
Runtime.mistbank(mistOwner, Vector3.new(70, TOP, 30), nil, nil)
-- A fresh Studio can stall for a moment, so give the billow and the soak tick time.
local soakBy = os.clock() + 2
while
	not Abilities.hasStatus(enemyInMist, "Soaked", workspace:GetServerTimeNow())
	and os.clock() < soakBy
do
	task.wait(0.1)
end
local nowTime = workspace:GetServerTimeNow()
check(Abilities.hasStatus(enemyInMist, "Soaked", nowTime), "Mistbank soaks an enemy inside")
check(not Abilities.hasStatus(allyInMist, "Soaked", nowTime), "Mistbank never soaks a teammate")
local surface = block(Vector3.new(4, 4, 4), Vector3.new(130, TOP + 2, 30), "Mist surface")
local attached = Runtime.mistbank({ team = "Green" }, surface.Position, surface, nil)
surface:Destroy()
task.wait(0.2)
check(
	not CollectionService:HasTag(attached, Abilities.MistTag),
	"a Mistbank goes when its surface goes"
)
task.wait(Abilities.Kits.Aquabeek.passive.Lifetime)
check(mine() == before, "Mistbanks fade after their lifetime")
zone:Destroy()

print(`[AbilitySelfTest] {if failures == 0 then "ALL PASS" else `{failures} FAILED`}`)
