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
local ACTION_VARIANTS = {
	Roll = Config.Validation.RollVariants,
	Flip = Config.Validation.FlipVariants,
	Mantle = Config.Validation.MantleVariants,
	WallHop = Config.Validation.WallHopVariants,
	WallRun = Config.Validation.WallRunVariants,
}

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
	state.lastMantle = -math.huge
	state.lastHop = -math.huge
	state.hops = 0
	state.history = {}
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

local function vectorOf(value: any): Vector3?
	if
		typeof(value) ~= "Vector3"
		or not Math.finite(value.X)
		or not Math.finite(value.Y)
		or not Math.finite(value.Z)
	then
		return nil
	end
	return value
end

-- Traversal requests name a world point (ledge stand point or wall contact).
-- Check it against server geometry and against any server-observed position in
-- the recent history: replicated positions trail fast traversal by 0.1-0.2 s.
local function traversalValid(
	kind: string,
	variant: string,
	character: Model,
	positions: { Vector3 },
	target: Vector3
): boolean
	local slack = Config.Validation.TraversalSlack
	local vault = Config.Traversal.Vault
	-- A vault lands beyond the obstacle; a wall run's contact trails along the wall.
	local reach = if variant == "Vault"
		then Config.Traversal.Mantle.Reach
			+ vault.LookAhead * Config.Validation.HorizontalSpeedLimit
			+ vault.MaxDepth
			+ vault.LandDistance
		else Config.Traversal.Mantle.Reach + 2
	local near = false
	for _, position in positions do
		local offset = target - position
		local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
		if kind == "Mantle" then
			local settings = Config.Traversal.Mantle
			near = flat <= reach + slack
				and offset.Y >= -2
				and offset.Y <= settings.MaxHeight + 1 + slack
		else
			local wallReach =
				math.max(Config.Traversal.WallHop.Reach, Config.Traversal.WallRun.Reach)
			near = flat <= wallReach + slack and math.abs(offset.Y) <= 2 + slack
		end
		if near then
			break
		end
	end
	if not near then
		return false
	end
	local function solid(part: Instance): boolean
		return part:IsA("BasePart") and part.Anchored and part.CanCollide
	end
	if kind == "Mantle" then
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = { character }
		params.RespectCanCollide = true
		local hit = workspace:Raycast(target, Vector3.new(0, -8, 0), params)
		return hit ~= nil
			and hit.Normal.Y > 0.7
			and solid(hit.Instance)
			and target.Y - hit.Position.Y < 4.5
	end
	local overlap = OverlapParams.new()
	overlap.FilterDescendantsInstances = { character }
	overlap.RespectCanCollide = true
	for _, part in workspace:GetPartBoundsInRadius(target, 0.75, overlap) do
		if solid(part) then
			return true
		end
	end
	return false
end

local function grounded(character: Model, root: BasePart, humanoid: Humanoid): boolean
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character }
	local distance = humanoid.HipHeight + root.Size.Y / 2 + 0.65
	return math.abs(root.AssemblyLinearVelocity.Y) < 8
		and workspace:Raycast(root.Position, Vector3.new(0, -distance, 0), params) ~= nil
end

-- Validates a Roll/Flip/Mantle/WallHop/WallRun request against server-observed state and
-- publishes it for every client. Returns a rejection reason, or nil on success.
local function validateAction(
	player: Player,
	state: any,
	packet: any,
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	now: number
): string?
	if player.Character ~= character or humanoid.Health <= 0 then
		return "character-changed" -- changed while queued behind another action
	end
	local kind = packet.kind
	local direction = directionOf(packet.direction)
	local limits = Config.Acrobatics.Flip
	local rate = packet.rate
	if not direction then
		return "direction"
	end
	-- Clip variants (Name.2) are presentation choices of the same action.
	local base = if typeof(packet.value) == "string" and #packet.value <= 40
		then string.match(packet.value, "^(.-)%.%d$") or packet.value
		else nil
	if not base or not table.find(ACTION_VARIANTS[kind], base) then
		return "variant"
	end
	local roll = Config.Acrobatics.Roll
	if
		typeof(rate) ~= "number"
		or not Math.finite(rate)
		or (kind == "Roll" and (rate < roll.MinRate - 1e-3 or rate > roll.MaxRate + 1e-3))
		or (kind == "Flip" and (rate < limits.MinRate - 1e-3 or rate > limits.MaxRate + 1e-3))
		or (kind == "Mantle" and (rate < 0.5 or rate > Config.Traversal.Mantle.MaxRate + 1e-3))
		or ((kind == "WallHop" or kind == "WallRun") and rate ~= 1)
	then
		return "rate"
	end
	local target = vectorOf(packet.target)
	local traversal = kind == "Mantle" or kind == "WallHop" or kind == "WallRun"
	if traversal and not target then
		return "target"
	end
	-- Native character replication trails the immediately sent action (jump
	-- start, landing roll, a kick off a wall). Poll server-observed physics for a
	-- bounded window; never accept a client grounded flag or position. Mantles
	-- start grounded or airborne.
	local wantGround = kind == "Roll"
	local onGround, placed
	local function observe()
		onGround = grounded(character, root, humanoid)
		placed = not traversal
			or traversalValid(
				kind,
				base :: string,
				character,
				{ root.Position, table.unpack(state.history) },
				target :: Vector3
			)
	end
	observe()
	local deadline = os.clock() + Config.Validation.StateSettle
	while (not placed or (kind ~= "Mantle" and onGround ~= wantGround)) and os.clock() < deadline do
		task.wait()
		if player.Character ~= character or humanoid.Health <= 0 then
			return "character-changed"
		end
		observe()
	end
	if not placed then
		return "geometry-" .. kind
	end
	if kind == "Roll" then
		if not onGround or now - state.lastRoll < Config.Acrobatics.Roll.Cooldown * 0.9 then
			return "roll-state"
		end
		state.lastRoll = now
	elseif kind == "Flip" then
		if onGround or state.airUsed then
			return "flip-state"
		end
		state.airUsed = true
	elseif kind == "Mantle" then
		if now - state.lastMantle < Config.Traversal.Mantle.Cooldown * 0.9 then
			return "mantle-state"
		end
		state.lastMantle = now
	elseif kind == "WallRun" then
		-- Attaching needs no hop; jumping off it is a WallHop request.
		if onGround or now - (state.lastWallRun or -math.huge) < 0.2 then
			return "wallrun-state"
		end
		state.lastWallRun = now
	else
		local settings = Config.Traversal.WallHop
		if
			onGround
			or state.hops >= settings.MaxHops
			or now - state.lastHop < settings.Cooldown * 0.9
		then
			return "wallhop-state"
		end
		state.hops += 1
		state.lastHop = now
		if settings.RefreshFlip then
			state.airUsed = false
		end
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
	return nil
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
	elseif ACTION_VARIANTS[packet.kind] then
		-- One action at a time per player, in arrival order: a request still waiting
		-- for replication must not be overtaken (a flip straight after a wall hop).
		while state.acting do
			task.wait()
		end
		state.acting = true
		local ok, reason =
			pcall(validateAction, player, state, packet, character, humanoid, root, now)
		state.acting = false
		if not ok or reason then
			reject(if ok then reason :: string else "error")
			return
		end
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
	elseif packet.kind == "Crouch" then
		if typeof(packet.value) ~= "boolean" then
			reject("crouch")
			return
		end
		character:SetAttribute("Crouching", packet.value)
	elseif packet.kind == "Hurt" then
		-- Lab-only preview of hit reactions and the injured idle; not combat.
		if now - (state.lastHurt or -math.huge) < Config.Lab.HurtCooldown then
			reject("hurt-rate")
			return
		end
		state.lastHurt = now
		humanoid:TakeDamage(Config.Lab.HurtAmount)
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
				state.hops = 0
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
			table.insert(state.history, root.Position)
			if #state.history > 8 then
				table.remove(state.history, 1)
			end
			if root.Position.Y < -40 and not state.spawning then
				task.spawn(spawnCharacter, player)
			end
		end
	end
end)
