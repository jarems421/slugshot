--!strict
-- Dummies for the TEMPORARY target range: R6 training dummies with 100 HP (as players), one strafing
-- side to side and one on a raised tower. Each keeps its damage statistics as
-- attributes for the range client's readout: the current session's damage, hits and
-- first/last hit times (a session ends after IdleReset seconds without a hit, when
-- the dummy also heals). At 0 HP a dummy counts a knock-out and resets.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Combat = require(ReplicatedStorage:WaitForChild("Combat"))
local Arena = (require :: any)(
	ServerScriptService:WaitForChild("MovementSandbox"):WaitForChild("Arena")
)

local IDLE_RESET = 4
local KO_RESET = 0.8

local folder = Instance.new("Folder")
folder.Name = "RangeDummies"
folder.Parent = workspace

local function dummy(name: string, feet: Vector3): Model
	local model = Instance.new("Model")
	model.Name = name
	local face = CFrame.lookAt(feet, feet + Vector3.zAxis) -- toward the firing line
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CFrame = face * CFrame.new(0, 3, 0)
	root.Parent = model
	model.PrimaryPart = root
	local straw = Color3.fromRGB(196, 170, 112)
	local cloth = Color3.fromRGB(150, 74, 58)
	type Limb = { name: string, size: Vector3, offset: CFrame, color: Color3 }
	local limbs: { Limb } = {
		{
			name = "Torso",
			size = Vector3.new(2, 2, 1),
			offset = CFrame.new(0, 0, 0),
			color = cloth,
		},
		{
			name = "Head",
			size = Vector3.new(2, 1, 1),
			offset = CFrame.new(0, 1.5, 0),
			color = straw,
		},
		{
			name = "Left Arm",
			size = Vector3.new(1, 2, 1),
			offset = CFrame.new(-1.5, 0, 0),
			color = straw,
		},
		{
			name = "Right Arm",
			size = Vector3.new(1, 2, 1),
			offset = CFrame.new(1.5, 0, 0),
			color = straw,
		},
		{
			name = "Left Leg",
			size = Vector3.new(1, 2, 1),
			offset = CFrame.new(-0.5, -2, 0),
			color = straw,
		},
		{
			name = "Right Leg",
			size = Vector3.new(1, 2, 1),
			offset = CFrame.new(0.5, -2, 0),
			color = straw,
		},
	}
	for _, limb in limbs do
		local part = Instance.new("Part")
		part.Name = limb.name
		part.Size = limb.size
		part.CFrame = root.CFrame * limb.offset
		part.Color = limb.color
		part.Material = Enum.Material.Fabric
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		part.Anchored = false
		part.CanCollide = true
		part.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = root, part
		weld.Parent = part
		part.Parent = model
	end
	-- A target ring on the chest.
	local torso = model:FindFirstChild("Torso") :: BasePart
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(100, 100)
	type Ring = { scale: number, color: Color3 }
	local rings: { Ring } = {
		{ scale = 0.9, color = Color3.fromRGB(240, 236, 220) },
		{ scale = 0.6, color = Color3.fromRGB(196, 58, 46) },
		{ scale = 0.3, color = Color3.fromRGB(240, 236, 220) },
	}
	for i, ring in rings do
		local disc = Instance.new("Frame")
		disc.AnchorPoint = Vector2.new(0.5, 0.5)
		disc.Position = UDim2.fromScale(0.5, 0.5)
		disc.Size = UDim2.fromScale(ring.scale, ring.scale)
		disc.BackgroundColor3 = ring.color
		disc.ZIndex = i
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = disc
		disc.Parent = surface
	end
	surface.Parent = torso
	local humanoid = Instance.new("Humanoid")
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.MaxHealth = Combat.MaxHealth
	humanoid.Health = Combat.MaxHealth
	humanoid.Parent = model
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
	model:SetAttribute("SessionDamage", 0)
	model:SetAttribute("Hits", 0)
	model:SetAttribute("KOs", 0)
	CollectionService:AddTag(model, "RangeDummy")
	model.Parent = folder
	-- Knock-out: count it and stand back up at full health.
	local knocked = false
	humanoid.HealthChanged:Connect(function(health)
		if health <= 0 and not knocked then
			knocked = true
			model:SetAttribute("KOs", ((model:GetAttribute("KOs") or 0) :: number) + 1)
			task.delay(KO_RESET, function()
				humanoid.Health = humanoid.MaxHealth
				knocked = false
			end)
		end
	end)
	return model
end

local spawnZ = Arena.Spawn.Z
for index, lane in Arena.Lanes do
	dummy(`Dummy{index} ({lane.distance} studs)`, Vector3.new(lane.side, 0, spawnZ - lane.distance))
end
local tower = Arena.Tower
dummy(
	`Tower dummy ({tower.distance} studs)`,
	Vector3.new(tower.side, tower.height, spawnZ - tower.distance)
)
local strafe = Arena.Strafe
local mover =
	dummy(`Strafing dummy ({strafe.distance} studs)`, Vector3.new(0, 0, spawnZ - strafe.distance))
local moverRoot = mover.PrimaryPart :: BasePart
local moverHome = moverRoot.CFrame

-- Statistics from the authoritative hit feed.
local hitFeed = ServerStorage:WaitForChild("SlugshotCombatHit") :: BindableEvent
hitFeed.Event:Connect(function(_shooter: Player, victim: Model, damage: number, distance: number)
	if not CollectionService:HasTag(victim, "RangeDummy") then
		return
	end
	local now = workspace:GetServerTimeNow()
	local last = victim:GetAttribute("LastHit") :: number?
	if not last or now - last > IDLE_RESET then
		victim:SetAttribute("SessionStart", now)
		victim:SetAttribute("SessionDamage", 0)
		victim:SetAttribute("Hits", 0)
	end
	victim:SetAttribute(
		"SessionDamage",
		((victim:GetAttribute("SessionDamage") or 0) :: number) + damage
	)
	victim:SetAttribute("Hits", ((victim:GetAttribute("Hits") or 0) :: number) + 1)
	victim:SetAttribute("LastHit", now)
	victim:SetAttribute("LastDamage", damage)
	victim:SetAttribute("LastDistance", distance)
end)

local clock = 0
RunService.Heartbeat:Connect(function(dt)
	clock += dt
	local swing = strafe.width * math.sin(clock * strafe.speed / strafe.width)
	moverRoot.CFrame = moverHome + Vector3.new(swing, 0, 0)
	local now = workspace:GetServerTimeNow()
	for _, model in CollectionService:GetTagged("RangeDummy") do
		local last = model:GetAttribute("LastHit") :: number?
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if
			last
			and now - last > IDLE_RESET
			and humanoid
			and humanoid.Health < humanoid.MaxHealth
			and humanoid.Health > 0
		then
			humanoid.Health = humanoid.MaxHealth
		end
	end
end)

print(`[Range] {#CollectionService:GetTagged("RangeDummy")} dummies ready`)
