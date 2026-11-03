--!strict
-- Rocklock v2 server: boots the destruction system on the map, hands every player the
-- temporary Terrain Tester (weak/medium/heavy simulated slug attacks) and validates its
-- requests. The server raycasts from the player's own head; clients only send an aim
-- direction, a tier and an archetype, so they cannot pick what breaks or how much.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPack = game:GetService("StarterPack")

local Config =
	require(ReplicatedStorage:WaitForChild("RocklockV2"):WaitForChild("DestructionConfig"))
local Destruction = require(script.Destruction)
local SelfTest = require(script.SelfTest)

local map = workspace:WaitForChild("Rocklock") :: Model
local remotes = Instance.new("Folder")
remotes.Name = "RocklockV2Remotes"
local request = Instance.new("RemoteEvent")
request.Name = "DestructionRequest"
request.Parent = remotes
local fx = Instance.new("RemoteEvent")
fx.Name = "DestructionFx"
fx.Parent = remotes
remotes.Parent = ReplicatedStorage

Destruction.init(map, fx)

local tester = Instance.new("Tool")
tester.Name = "TerrainTester"
tester.ToolTip = "Terrain Tester (temporary): simulated slug impacts"
tester.RequiresHandle = false
tester.CanBeDropped = false
tester:SetAttribute("RocklockTester", true)
tester.Parent = StarterPack
for _, player in Players:GetPlayers() do
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack and not backpack:FindFirstChild(tester.Name) then
		tester:Clone().Parent = backpack
	end
end

type Budget = { tokens: number, stamp: number, cooldown: { [string]: number } }
local budgets: { [Player]: Budget } = {}
Players.PlayerRemoving:Connect(function(player)
	budgets[player] = nil
end)

local function allowed(player: Player, tier: string?): boolean
	local now = os.clock()
	local budget = budgets[player]
	if not budget then
		budget = { tokens = Config.Requests.PerSecond, stamp = now, cooldown = {} }
		budgets[player] = budget
	end
	budget.tokens = math.min(
		Config.Requests.PerSecond,
		budget.tokens + (now - budget.stamp) * Config.Requests.PerSecond
	)
	budget.stamp = now
	if budget.tokens < 1 then
		return false
	end
	if tier then
		local ready = budget.cooldown[tier] or 0
		if now < ready then
			return false
		end
		budget.cooldown[tier] = now + ((Config.Requests.Cooldown :: any)[tier] or 1)
	end
	budget.tokens -= 1
	return true
end

local function reply(player: Player, text: string)
	fx:FireClient(player, { kind = "Result", text = text })
end

request.OnServerEvent:Connect(function(player: Player, packet: any)
	if typeof(packet) ~= "table" or typeof(packet.kind) ~= "string" then
		return
	end
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (character and head and humanoid and humanoid.Health > 0) then
		return
	end
	local equipped = character:FindFirstChild(tester.Name)
	local kind = packet.kind
	if kind == "Attack" or kind == "Raise" then
		local direction = packet.direction
		if
			not equipped
			or typeof(direction) ~= "Vector3"
			or direction.Magnitude < 0.1
			or direction.Magnitude ~= direction.Magnitude
		then
			return
		end
		if kind == "Raise" then
			if allowed(player, "Heavy") then
				reply(
					player,
					if Destruction.raise(player, head.Position, direction)
						then "raised a slab wall"
						else "slab limit reached"
				)
			end
			return
		end
		local tier, archetype = packet.tier, packet.archetype
		if
			typeof(tier) ~= "string"
			or (Config.Tiers :: any)[tier] == nil
			or typeof(archetype) ~= "string"
			or not table.find(Config.ArchetypeOrder, archetype)
			or not allowed(player, tier)
		then
			return
		end
		local result = Destruction.attack(
			head.Position,
			direction,
			(Config.Tiers :: any)[tier],
			archetype,
			tier,
			{ character }
		)
		local health = if result.health and result.maxHealth
			then ` ({math.floor(result.health)}/{result.maxHealth})`
			else ""
		reply(player, `{tier} {archetype} -> {result.target}: -{math.floor(result.dealt)}{health}`)
	elseif kind == "Reset" and RunService:IsStudio() then
		if allowed(player, nil) then
			Destruction.reset()
			reply(player, "terrain reset to the round start")
		end
	elseif kind == "SelfTest" and RunService:IsStudio() then
		if allowed(player, nil) then
			task.spawn(SelfTest.run, map, function(line)
				reply(player, line)
			end)
		end
	end
end)

print("[RocklockV2] destruction ready")
