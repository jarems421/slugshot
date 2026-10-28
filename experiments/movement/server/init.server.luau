--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local shared = ReplicatedStorage:WaitForChild("MovementExperiment")
local Config = require(shared.Config)
local Math = require(shared.MotionMath)
require(script.Arena).create()

local request = Instance.new("RemoteEvent")
request.Name = "MovementRequest"
request.Parent = shared
local states: { [Player]: any } = {}
Players.CharacterAutoLoads = false

local function spawnCharacter(player: Player)
	local state = states[player]
	if not state or state.spawning then
		return
	end
	state.spawning = true
	local old = player.Character
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = Color3.fromRGB(224, 226, 232)
	description.TorsoColor = Color3.fromRGB(63, 137, 174)
	description.LeftArmColor, description.RightArmColor =
		Color3.fromRGB(201, 215, 225), Color3.fromRGB(201, 215, 225)
	description.LeftLegColor, description.RightLegColor =
		Color3.fromRGB(73, 88, 112), Color3.fromRGB(73, 88, 112)
	local ok, character = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(
			description,
			Enum.HumanoidRigType.R15
		)
	end)
	description:Destroy()
	if not ok then
		state.spawning = false
		warn("[Movement sandbox] R15 creation failed", character)
		return
	end
	if not player.Parent then
		character:Destroy()
		return
	end
	character.Name = player.Name
	character:SetAttribute("MovementProfile", state.profile)
	character:SetAttribute("PresentationMode", "OriginalProceduralR15")
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.UseJumpPower = true
	humanoid.JumpPower = Config.Profiles[state.profile].JumpPower
	humanoid.WalkSpeed = Config.Profiles[state.profile].RunSpeed
	character:PivotTo(CFrame.new((player.UserId % 3) * 6 - 6, 5, 30))
	character.Parent = workspace
	player.Character = character
	if old then
		old:Destroy()
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
	root:SetNetworkOwner(player)
	state.spawnedAt = workspace:GetServerTimeNow()
	state.position = root.Position
	state.lastRoll = -math.huge
	state.airUsed = false
	state.violations = 0
	state.spawning = false
	humanoid.Died:Once(function()
		task.delay(1.5, function()
			if player.Parent then
				spawnCharacter(player)
			end
		end)
	end)
end

local function addPlayer(player: Player)
	states[player] = { profile = Config.DefaultProfile, window = 0, count = 0, lastRespawn = 0 }
	player:SetAttribute("MovementProfile", Config.DefaultProfile)
	player:SetAttribute("RejectedRequests", 0)
	player:SetAttribute("AcceptedRequests", 0)
	task.spawn(spawnCharacter, player)
end
Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)
for _, player in Players:GetPlayers() do
	addPlayer(player)
end

local function directionOf(value: any): Vector3?
	if
		typeof(value) ~= "Vector3"
		or not Math.finite(value.X)
		or not Math.finite(value.Y)
		or not Math.finite(value.Z)
	then
		return nil
	end
	local flat = Vector3.new(value.X, 0, value.Z)
	return if flat.Magnitude > 0.01 then flat.Unit else nil
end

local function grounded(character: Model, root: BasePart, humanoid: Humanoid): boolean
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character }
	local distance = humanoid.HipHeight + root.Size.Y / 2 + 0.65
	return math.abs(root.AssemblyLinearVelocity.Y) < 8
		and workspace:Raycast(root.Position, Vector3.new(0, -distance, 0), params) ~= nil
end

request.OnServerEvent:Connect(function(player: Player, packet: any)
	local state = states[player]
	if not state then
		return
	end
	local now = workspace:GetServerTimeNow()
	if now - state.window >= 1 then
		state.window, state.count = now, 0
	end
	state.count += 1
	local function reject(reason: string)
		player:SetAttribute("RejectedRequests", (player:GetAttribute("RejectedRequests") or 0) + 1)
		if
			typeof(packet) == "table"
			and typeof(packet.sequence) == "number"
			and Math.finite(packet.sequence)
		then
			request:FireClient(player, packet.sequence, false, reason)
		end
	end
	if state.count > Config.Validation.RequestsPerSecond then
		reject("rate")
		return
	end
	if
		typeof(packet) ~= "table"
		or typeof(packet.kind) ~= "string"
		or typeof(packet.sequence) ~= "number"
		or not Math.finite(packet.sequence)
	then
		reject("shape")
		return
	end
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart else nil
	if not character or not humanoid or not root or humanoid.Health <= 0 then
		reject("character")
		return
	end
	if packet.kind == "Profile" then
		if typeof(packet.value) ~= "string" or not Config.Profiles[packet.value] then
			reject("profile")
			return
		end
		state.profile = packet.value
		player:SetAttribute("MovementProfile", state.profile)
		character:SetAttribute("MovementProfile", state.profile)
		humanoid.JumpPower = Config.Profiles[state.profile].JumpPower
	elseif packet.kind == "Roll" or packet.kind == "Flip" then
		local direction = directionOf(packet.direction)
		local isRoll = packet.kind == "Roll"
		local variants = if isRoll
			then Config.Validation.RollVariants
			else Config.Validation.FlipVariants
		local limits = Config.Acrobatics.Flip
		local rate = packet.rate
		if not direction then
			reject("direction")
			return
		end
		if typeof(packet.value) ~= "string" or not table.find(variants, packet.value) then
			reject("variant")
			return
		end
		if
			typeof(rate) ~= "number"
			or not Math.finite(rate)
			or (isRoll and math.abs(rate - Config.Acrobatics.Roll.PlaybackRate) > 1e-3)
			or (not isRoll and (rate < limits.MinRate - 1e-3 or rate > limits.MaxRate + 1e-3))
		then
			reject("rate")
			return
		end
		-- Native character replication can trail the immediately sent action (jump
		-- start or landing roll). Poll server-observed physics for a bounded window;
		-- never accept a client grounded flag.
		local onGround = grounded(character, root, humanoid)
		local deadline = os.clock() + Config.Validation.StateSettle
		while onGround ~= isRoll and os.clock() < deadline do
			task.wait()
			if player.Character ~= character or humanoid.Health <= 0 then
				reject("character-changed")
				return
			end
			onGround = grounded(character, root, humanoid)
		end
		if isRoll then
			if not onGround or now - state.lastRoll < Config.Acrobatics.Roll.Cooldown * 0.9 then
				reject("roll-state")
				return
			end
			state.lastRoll = now
		else
			if onGround or state.airUsed then
				reject("flip-state")
				return
			end
			state.airUsed = true
		end
		-- Reuse the client's start time when plausible so the owner's attributes match
		-- and its animation does not restart when the server values replicate back.
		local stamp = packet.time
		if
			typeof(stamp) ~= "number"
			or not Math.finite(stamp)
			or now - stamp < -0.05
			or now - stamp > 0.4
		then
			stamp = now
		end
		character:SetAttribute("MovementAction", packet.kind)
		character:SetAttribute("MovementVariant", packet.value)
		character:SetAttribute("MovementDirection", direction)
		character:SetAttribute("MovementRate", rate)
		character:SetAttribute("MovementActionTime", stamp)
	elseif packet.kind == "Aim" then
		if
			typeof(packet.value) ~= "boolean"
			or (packet.value and not directionOf(packet.direction))
		then
			reject("aim")
			return
		end
		character:SetAttribute("Aiming", packet.value)
		if packet.value then
			character:SetAttribute(
				"AimPitch",
				math.clamp(math.asin(math.clamp(packet.direction.Y, -1, 1)), -0.8, 0.8)
			)
		end
	elseif packet.kind == "Respawn" then
		if now - state.lastRespawn < 3 then
			reject("respawn-rate")
			return
		end
		state.lastRespawn = now
		task.spawn(spawnCharacter, player)
	else
		reject("kind")
		return
	end
	player:SetAttribute("AcceptedRequests", (player:GetAttribute("AcceptedRequests") or 0) + 1)
	request:FireClient(player, packet.sequence, true, packet.kind)
end)

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 0.1 then
		return
	end
	local sampleTime = elapsed
	elapsed = 0
	for player, state in states do
		local character = player.Character
		local root = if character
			then character:FindFirstChild("HumanoidRootPart") :: BasePart
			else nil
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if character and root and humanoid then
			if grounded(character, root, humanoid) then
				state.airUsed = false
			end
			local velocity = root.AssemblyLinearVelocity
			local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			local delta = root.Position - (state.position or root.Position)
			local travelled = Vector3.new(delta.X, 0, delta.Z).Magnitude
			local limit = Config.Validation.HorizontalSpeedLimit
			local invalid = speed > limit
				or travelled > limit * sampleTime + Config.Validation.DisplacementSlack
			state.violations = if invalid then (state.violations or 0) + 1 else 0
			if
				state.violations >= 2
				and workspace:GetServerTimeNow() - state.spawnedAt
					> Config.Validation.SpawnGrace
			then
				player:SetAttribute(
					"MotionCorrections",
					(player:GetAttribute("MotionCorrections") or 0) + 1
				)
				local flat = Vector3.new(velocity.X, 0, velocity.Z)
				root.AssemblyLinearVelocity = (
					if speed > 0.01 then flat.Unit * math.min(speed, limit) else Vector3.zero
				) + Vector3.new(0, velocity.Y, 0)
				if travelled > limit * sampleTime + Config.Validation.DisplacementSlack then
					character:PivotTo(CFrame.new(state.position) * character:GetPivot().Rotation)
				end
			end
			state.position = root.Position
			if root.Position.Y < -40 and not state.spawning then
				task.spawn(spawnCharacter, player)
			end
		end
	end
end)
