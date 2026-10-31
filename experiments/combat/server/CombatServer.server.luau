--!strict
-- Authoritative slug shots. A client fires instantly on its own screen and sends the
-- shot; the server checks it (blaster equipped, cooldown, muzzle near the shooter),
-- flies it on the shared path, decides hits and applies damage, and tells every
-- client so they draw the same arc. No knockback (owner).
local InsertService = game:GetService("InsertService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Combat = require(ReplicatedStorage:WaitForChild("Combat"))

local remote = Instance.new("RemoteEvent")
remote.Name = "SlugshotCombat"
remote.Parent = ReplicatedStorage
-- Server-side hit feed for local systems (target range statistics).
local hitFeed = Instance.new("BindableEvent")
hitFeed.Name = "SlugshotCombatHit"
hitFeed.Parent = ServerStorage

-- The in-flight Floppy every client clones: the shared model at Size, pivoted on its
-- body centre with +Y its back and -Z its face, so clients can orient it directly.
local function buildFlightModel()
	local asset = require(ReplicatedStorage:WaitForChild("FloppyAsset")) :: { model: number }
	local appearance = ServerScriptService:WaitForChild("FloppyIntegration")
		:WaitForChild("FloppyAppearance")
	local Appearance = (require :: any)(appearance)
	local container = InsertService:LoadAsset(asset.model)
	local model = Instance.new("Model")
	model.Name = "FloppyFlight"
	for _, child in container:GetChildren() do
		child.Parent = model
	end
	container:Destroy()
	Appearance.apply(model, 0.08)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide, item.CanQuery, item.CanTouch = false, false, false
			item.CastShadow = false
		elseif item:IsA("Bone") then
			item.Transform = CFrame.identity
		end
	end
	local eyeL = model:FindFirstChild("eye_L", true) :: Bone
	local eyeR = model:FindFirstChild("eye_R", true) :: Bone
	local root = model:FindFirstChild("root", true) :: Bone
	local head = model:FindFirstChild("head", true) :: Bone
	assert(eyeL and eyeR and root and head, "Floppy reference bones missing")
	-- Source Floppy is 2.72 units long between root and antenna; scale from the eyes.
	local sourceScale = (eyeR.WorldPosition - eyeL.WorldPosition).Magnitude / 0.74
	model:ScaleTo(model:GetScale() * Combat.Slugs.Floppy.Size / (2.72 * sourceScale))
	local up = (head.WorldPosition - root.WorldPosition).Unit
	local face = (eyeL.WorldPosition + eyeR.WorldPosition) / 2 - head.WorldPosition
	local front = (face - up * face:Dot(up)).Unit
	-- Centre from the bones and known length: GetBoundingBox is unreliable on imported
	-- skinned models (blender-lessons.md).
	local centre = root.WorldPosition + up * (Combat.Slugs.Floppy.Size / 2)
	-- Slug space: +Y up out of its back, -Z the way its face points.
	model.WorldPivot = CFrame.fromMatrix(centre, up:Cross(-front), up, -front)
	local folder = Instance.new("Folder")
	folder.Name = "CombatAssets"
	model.Parent = folder
	folder.Parent = ReplicatedStorage
end
local ok, problem = pcall(buildFlightModel :: () -> any)
if not ok then
	warn(`[Combat] Floppy flight model unavailable, shots draw a stand-in: {problem}`)
end

type Shot = {
	shooter: Player,
	id: number,
	slug: Combat.Slug,
	slugId: string,
	origin: Vector3,
	velocity: Vector3,
	t: number,
	params: RaycastParams,
}
type Shooter = { ready: { [number]: number }, window: number, count: number }
local shots: { Shot } = {}
local shooters: { [Player]: Shooter } = {}

Players.PlayerRemoving:Connect(function(player)
	shooters[player] = nil
end)

local function blasterOf(character: Model): Tool?
	for _, item in character:GetChildren() do
		if Combat.isBlaster(item) then
			return item :: Tool
		end
	end
	return nil
end

local function reject(player: Player, id: any, reason: string)
	remote:FireClient(player, "Rejected", { id = id, reason = reason })
end

remote.OnServerEvent:Connect(function(player: Player, kind: any, payload: any)
	if kind ~= "Fire" or typeof(payload) ~= "table" then
		return
	end
	local id, slot, origin, direction, charge =
		payload.id, payload.slot, payload.origin, payload.direction, payload.charge
	if
		typeof(id) ~= "number"
		or typeof(slot) ~= "number"
		or typeof(origin) ~= "Vector3"
		or typeof(direction) ~= "Vector3"
		or typeof(charge) ~= "number"
		or charge ~= charge
		or direction.Magnitude < 0.5
		or direction.Magnitude > 1.5
	then
		return reject(player, id, "shape")
	end
	local slugId = Combat.Loadout[slot]
	local slug = if slugId then Combat.Slugs[slugId] else nil
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local torso = character
		and (character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso"))
	if
		not slug
		or not character
		or not humanoid
		or humanoid.Health <= 0
		or not torso
		or not torso:IsA("BasePart")
	then
		return reject(player, id, "state")
	end
	local tool = blasterOf(character)
	if not tool then
		return reject(player, id, "unarmed")
	end
	if (origin - torso.Position).Magnitude > Combat.MaxOriginOffset then
		return reject(player, id, "origin")
	end
	local now = os.clock()
	local state = shooters[player]
	if not state then
		state = { ready = {}, window = now, count = 0 }
		shooters[player] = state
	end
	if now - state.window > 1 then
		state.window, state.count = now, 0
	end
	state.count += 1
	if state.count > Combat.ShotRate then
		return reject(player, id, "rate")
	end
	if now < (state.ready[slot] or 0) - Combat.CooldownTolerance then
		return reject(player, id, "cooldown")
	end
	local readyAt = now + Combat.Cooldown
	state.ready[slot] = readyAt
	-- The canister shows empty until the slug is back (every client reads this).
	tool:SetAttribute("SlugReady", false)
	task.delay(Combat.Cooldown, function()
		if tool.Parent and (state.ready[slot] or 0) <= os.clock() + 0.01 then
			tool:SetAttribute("SlugReady", true)
		end
	end)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local velocity = direction.Unit * Combat.speed(slug, charge)
	table.insert(shots, {
		shooter = player,
		id = id,
		slug = slug,
		slugId = slugId,
		origin = origin,
		velocity = velocity,
		t = 0,
		params = params,
	})
	remote:FireAllClients("Shot", {
		shooter = player,
		id = id,
		slug = slugId,
		origin = origin,
		velocity = velocity,
	})
end)

local function impact(shot: Shot, hit: RaycastResult)
	local victim, humanoid = Combat.victim(hit.Instance)
	local damage = 0
	local distance = (hit.Position - shot.origin).Magnitude
	if victim and humanoid and victim ~= shot.shooter.Character and humanoid.Health > 0 then
		damage = shot.slug.Damage
		humanoid:TakeDamage(damage)
		hitFeed:Fire(shot.shooter, victim, damage, distance)
	end
	remote:FireAllClients("Impact", {
		shooter = shot.shooter,
		id = shot.id,
		position = hit.Position,
		normal = hit.Normal,
		victim = victim,
		damage = damage,
		distance = distance,
	})
end

RunService.Heartbeat:Connect(function(dt)
	for index = #shots, 1, -1 do
		local shot = shots[index]
		local from = shot.t
		shot.t = math.min(shot.t + dt, Combat.MaxFlight)
		local hit = Combat.sweep(shot.origin, shot.velocity, shot.slug, from, shot.t, shot.params)
		if hit then
			impact(shot, hit)
			table.remove(shots, index)
		elseif shot.t >= Combat.MaxFlight then
			table.remove(shots, index)
		end
	end
end)

print("[Combat] slug shots ready")
