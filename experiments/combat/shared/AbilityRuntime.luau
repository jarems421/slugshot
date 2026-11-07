--!strict
-- Server side of slug abilities (docs/slugs/ability-specs.md): arming, ability cooldowns, statuses, placed objects
-- with caps and cleanup, and each kit's effects. CombatServer arms and fires through it; it lives beside the shared
-- definitions so every place that runs CombatServer has it, but only the server may use it. Effects, the armed glow
-- and status markers are placeholder looks made here, so they replicate to every client.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Combat = require(script.Parent)
local Abilities = require(script.Parent:WaitForChild("Abilities"))

assert(RunService:IsServer(), "AbilityRuntime is server-only")

local Runtime = {}

-- Who an effect belongs to. Players have a Player; self-tests use a bare team.
export type Owner = { player: Player?, model: Model?, team: string? }

export type Impact = {
	owner: Owner,
	slugId: string,
	ability: Abilities.Kind?,
	position: Vector3,
	instance: Instance?,
	victim: Model?, -- an enemy the slug hit directly
	direction: Vector3,
	damage: number,
}

type DamageFn = (
	owner: Owner,
	victim: Model,
	humanoid: Humanoid,
	amount: number,
	position: Vector3,
	direction: Vector3
) -> ()

type Status = { ends: number, team: string?, scale: number? }

type Placed = {
	owner: Owner,
	key: any, -- the owner's Player, or the Owner table itself
	name: string,
	part: BasePart,
	ends: number,
	fade: number,
	removed: boolean,
	connections: { RBXScriptConnection },
}

type Wave = {
	owner: Owner,
	part: BasePart,
	position: Vector3, -- feet level
	flat: Vector3,
	vy: number,
	airborne: boolean,
	travelled: number,
	damage: number,
	hit: { [Model]: boolean },
}

type Arming = { armed: Abilities.Kind?, slugId: string?, ready: { [string]: number } }

local CRASHWAVE = Abilities.Kits.Aquabeek.main
local MISTBANK = Abilities.Kits.Aquabeek.passive
local WAVE_GRAVITY = 120
local ARMED_COLOUR: { [string]: Color3 } = {
	main = Color3.fromRGB(96, 206, 255),
	passive = Color3.fromRGB(236, 244, 255),
}

local remote: RemoteEvent? = nil
local function takeDamage(
	_owner: Owner,
	_victim: Model,
	humanoid: Humanoid,
	amount: number,
	_position: Vector3,
	_direction: Vector3
)
	humanoid:TakeDamage(amount)
end
local damageFn: DamageFn = takeDamage
local arming: { [Player]: Arming } = {}
local statuses: { [Model]: { [string]: Status } } = {}
local placed: { Placed } = {}
local waves: { Wave } = {}

local folder = Instance.new("Folder")
folder.Name = "SlugshotAbilityObjects"
folder.Parent = workspace

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.FilterDescendantsInstances = { folder }

local function now(): number
	return workspace:GetServerTimeNow()
end

function Runtime.ownerOf(player: Player): Owner
	return { player = player, model = player.Character, team = Abilities.teamOf(player) }
end

local function isAlly(owner: Owner, model: Model): boolean
	return owner.model == model or (owner.team ~= nil and Abilities.teamOf(model) == owner.team)
end

-- World geometry only: skips characters, dummies and ability objects.
local castParams = RaycastParams.new()
castParams.FilterType = Enum.RaycastFilterType.Exclude
local function worldCast(origin: Vector3, direction: Vector3): RaycastResult?
	local skip: { Instance } = { folder }
	for _ = 1, 6 do
		castParams.FilterDescendantsInstances = skip
		local hit = workspace:Raycast(origin, direction, castParams)
		local victim = hit and Combat.victim(hit.Instance)
		if not victim then
			return hit
		end
		table.insert(skip, victim)
	end
	return nil
end

local function rootOf(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function fadeOut(part: BasePart, seconds: number)
	for _, tag in part:GetTags() do
		part:RemoveTag(tag)
	end
	for _, item in part:GetDescendants() do
		if item:IsA("BasePart") then
			TweenService:Create(item, TweenInfo.new(seconds), { Transparency = 1 }):Play()
		end
	end
	local tween = TweenService:Create(part, TweenInfo.new(seconds), { Transparency = 1 })
	tween.Completed:Once(function()
		part:Destroy()
	end)
	tween:Play()
end

-- Statuses ----------------------------------------------------------------------------------
-- Kept here and mirrored to attributes for clients: Status<Name> is the server time it ends, Status<Name>Team the
-- team that caused it, and SpeedScale the strongest active slow.
local function marker(model: Model, name: string, on: boolean)
	if name ~= "Soaked" then
		return
	end
	local root = rootOf(model)
	local drips = root and root:FindFirstChild("SoakedDrips")
	if on and root and not drips then
		local made = Instance.new("ParticleEmitter")
		made.Name = "SoakedDrips"
		made.Color = ColorSequence.new(Color3.fromRGB(90, 170, 240))
		made.Size = NumberSequence.new(0.18)
		made.Lifetime = NumberRange.new(0.5, 0.7)
		made.Rate = 14
		made.Speed = NumberRange.new(0.5)
		made.Acceleration = Vector3.new(0, -30, 0)
		made.SpreadAngle = Vector2.new(30, 30)
		made.Parent = root
	elseif not on and drips then
		drips:Destroy()
	end
end

local function refreshSpeed(model: Model)
	local slows: { number } = {}
	local list: { [string]: Status } = statuses[model] or {}
	for _, status in list do
		if status.scale then
			table.insert(slows, status.scale)
		end
	end
	local scale = Abilities.speedScale(slows)
	model:SetAttribute("SpeedScale", if scale < 1 then scale else nil)
end

function Runtime.applyStatus(
	model: Model,
	name: string,
	seconds: number,
	team: string?,
	scale: number?
)
	local list = statuses[model]
	if not list then
		list = {}
		statuses[model] = list
	end
	local ends = math.max(if list[name] then list[name].ends else 0, now() + seconds)
	list[name] = { ends = ends, team = team, scale = scale }
	model:SetAttribute(`Status{name}`, ends)
	model:SetAttribute(`Status{name}Team`, team)
	marker(model, name, true)
	if scale then
		refreshSpeed(model)
	end
end

function Runtime.clearStatus(model: Model, name: string)
	local list = statuses[model]
	if list and list[name] then
		list[name] = nil
		model:SetAttribute(`Status{name}`, nil)
		model:SetAttribute(`Status{name}Team`, nil)
		marker(model, name, false)
		refreshSpeed(model)
	end
end

-- Control effects (Snapbind, Tangle, Flash, Jump Scare, Nausea): after one ends the target is immune to all of
-- them for Abilities.ControlImmunity seconds. Returns false when it didn't take.
function Runtime.applyControl(model: Model, name: string, seconds: number, team: string?): boolean
	local immuneUntil = model:GetAttribute("ControlImmuneUntil")
	local current = now()
	if typeof(immuneUntil) == "number" and immuneUntil > current then
		return false
	end
	Runtime.applyStatus(model, name, seconds, team)
	model:SetAttribute("ControlImmuneUntil", current + seconds + Abilities.ControlImmunity)
	return true
end

-- Slows never add up: movement reads SpeedScale, the strongest active one.
function Runtime.applySlow(
	model: Model,
	name: string,
	scale: number,
	seconds: number,
	team: string?
)
	Runtime.applyStatus(model, name, seconds, team, scale)
end

local function sweepStatuses()
	local current = now()
	for model, list in statuses do
		for name, status in list do
			if status.ends <= current or not model.Parent then
				Runtime.clearStatus(model, name)
			end
		end
		if next(list) == nil then
			statuses[model] = nil
		end
	end
end

-- Placed objects ------------------------------------------------------------------------------
local function remove(object: Placed)
	if object.removed then
		return
	end
	object.removed = true
	for _, connection in object.connections do
		connection:Disconnect()
	end
	local index = table.find(placed, object)
	if index then
		table.remove(placed, index)
	end
	fadeOut(object.part, object.fade)
end

-- Enforces the ability's cap for this owner (their oldest goes) and the team's object budget. Objects attached to a
-- part go when it does (a melted Ice Wall, a fallen spire); terrain never goes.
local function place(object: Placed, cap: number, surface: Instance?)
	local mine: { Placed } = {}
	local team: { Placed } = {}
	for _, other in placed do
		if other.key == object.key and other.name == object.name then
			table.insert(mine, other)
		end
		if object.owner.team and other.owner.team == object.owner.team then
			table.insert(team, other)
		end
	end
	for index = 1, #mine - cap + 1 do
		remove(mine[index])
	end
	for index = 1, #team - Abilities.TeamObjectBudget + 1 do
		remove(team[index])
	end
	if surface and surface:IsA("BasePart") and not surface:IsA("Terrain") then
		table.insert(
			object.connections,
			surface.AncestryChanged:Connect(function()
				if not surface:IsDescendantOf(workspace) then
					remove(object)
				end
			end)
		)
	end
	table.insert(placed, object)
end

function Runtime.objects(): { { name: string, part: BasePart, ends: number } }
	local list = {}
	for _, object in placed do
		table.insert(list, { name = object.name, part = object.part, ends = object.ends })
	end
	return list
end

-- Match end, or a test resetting.
function Runtime.clearAll()
	for index = #placed, 1, -1 do
		remove(placed[index])
	end
	for _, wave in waves do
		wave.part:Destroy()
	end
	table.clear(waves)
end

-- Aquabeek: Crashwave ------------------------------------------------------------------------
local function waveFrame(position: Vector3, flat: Vector3): CFrame
	local centre = position + Vector3.yAxis * (CRASHWAVE.Height / 2)
	return CFrame.lookAt(centre, centre + flat)
end

-- The wave starts at the hit player's feet (mid-air if they are airborne, then falls) and rolls along the shot's
-- line, climbing what a player could walk on and stopping at walls, ledges and cover.
function Runtime.crashwave(owner: Owner, victim: Model, direction: Vector3, damage: number): boolean
	local root = rootOf(victim)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if not root or flat.Magnitude < 1e-3 then
		return false
	end
	flat = flat.Unit
	local feet = root.Position - Vector3.yAxis * 3
	local ground = worldCast(root.Position, Vector3.new(0, -200, 0))
	local airborne = not ground or feet.Y - ground.Position.Y > 0.6
	if ground and not airborne then
		feet = Vector3.new(feet.X, ground.Position.Y, feet.Z)
	end
	local part = Instance.new("Part")
	part.Name = "Crashwave"
	part.Size = Vector3.new(CRASHWAVE.Width, CRASHWAVE.Height, 2)
	part.Color = Color3.fromRGB(64, 150, 222)
	part.Material = Enum.Material.SmoothPlastic
	part.Transparency = 0.35
	part.Anchored = true
	part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
	part.CastShadow = false
	part.CFrame = waveFrame(feet, flat)
	part.Parent = folder
	table.insert(waves, {
		owner = owner,
		part = part :: BasePart,
		position = feet,
		flat = flat,
		vy = 0,
		airborne = airborne,
		travelled = 0,
		damage = damage * CRASHWAVE.Share,
		hit = { [victim] = true },
	})
	return true
end

-- Cover the wave reaches takes heavy damage (its CrashwaveDamage, or two hits) and stops it.
local function damageCover(cover: BasePart)
	local health = cover:GetAttribute("Health")
	if typeof(health) ~= "number" then
		return
	end
	local amount = cover:GetAttribute("CrashwaveDamage")
	local left = health - (if typeof(amount) == "number" then amount else 2)
	cover:SetAttribute("Health", left)
	if left <= 0 then
		cover:Destroy()
	end
end

-- Damage and soak each enemy the wave reaches once; put out a teammate's burn caused by the other team. Returns
-- true when cover stopped the wave.
local function touch(wave: Wave, from: Vector3, to: Vector3): boolean
	local size = Vector3.new(CRASHWAVE.Width, CRASHWAVE.Height, (to - from).Magnitude + 1)
	for _, part in
		workspace:GetPartBoundsInBox(waveFrame((from + to) / 2, wave.flat), size, overlap)
	do
		if CollectionService:HasTag(part, Abilities.CoverTag) then
			damageCover(part)
			return true
		end
		local model, humanoid = Combat.victim(part)
		if model and humanoid and not wave.hit[model] and humanoid.Health > 0 then
			wave.hit[model] = true
			if not isAlly(wave.owner, model) then
				damageFn(wave.owner, model, humanoid, wave.damage, part.Position, wave.flat)
				Runtime.applyStatus(model, "Soaked", CRASHWAVE.Soak, wave.owner.team)
			elseif model:GetAttribute("StatusBurningTeam") ~= wave.owner.team then
				Runtime.clearStatus(model, "Burning")
			end
		end
	end
	return false
end

local function stepWave(wave: Wave, dt: number): boolean
	local move = math.min(CRASHWAVE.Speed * dt, CRASHWAVE.Reach - wave.travelled)
	local from = wave.position
	-- Anything taller than a step in the way is a wall; cover takes the wave's damage as it stops it.
	local wall =
		worldCast(from + Vector3.yAxis * (CRASHWAVE.StepUp + 0.3), wave.flat * (move + 0.6))
	if wall then
		if
			wall.Instance:IsA("BasePart")
			and CollectionService:HasTag(wall.Instance, Abilities.CoverTag)
		then
			damageCover(wall.Instance)
		end
		return false
	end
	local ahead = from + wave.flat * move
	local ground =
		worldCast(ahead + Vector3.yAxis * (CRASHWAVE.StepUp + 0.4), Vector3.new(0, -400, 0))
	local y: number
	if wave.airborne then
		wave.vy -= WAVE_GRAVITY * dt
		y = from.Y + wave.vy * dt
		if ground and y <= ground.Position.Y then
			y, wave.airborne = ground.Position.Y, false
		elseif not ground and y < from.Y - 200 then
			return false
		end
	elseif not ground or from.Y - ground.Position.Y > CRASHWAVE.Drop then
		return false -- a ledge
	else
		y = ground.Position.Y
	end
	local to = Vector3.new(ahead.X, y, ahead.Z)
	if touch(wave, from, to) then
		return false
	end
	wave.position = to
	wave.travelled += move
	wave.part.CFrame = waveFrame(to, wave.flat)
	return wave.travelled < CRASHWAVE.Reach - 1e-3
end

-- Aquabeek: Mistbank ---------------------------------------------------------------------------
-- A ball centred on the hit point: a dome on a floor, a half-ball on a wall, a hanging bubble under a ceiling. On a
-- player it forms at their feet.
function Runtime.mistbank(
	owner: Owner,
	position: Vector3,
	surface: Instance?,
	victim: Model?
): BasePart
	local centre = position
	local root = victim and rootOf(victim)
	if root then
		local ground = worldCast(root.Position, Vector3.new(0, -200, 0))
		centre = if ground then ground.Position else root.Position - Vector3.yAxis * 3
		surface = nil
	end
	-- Two layers of mist: one translucent shell still let the players inside show through.
	local part: BasePart
	for layer, scale in { 1, 0.85 } do
		local shell = Instance.new("Part")
		shell.Name = if layer == 1 then "Mistbank" else "MistbankCore"
		shell.Shape = Enum.PartType.Ball
		shell.Size = Vector3.one
		shell.Color = Color3.fromRGB(214, 226, 232)
		shell.Material = Enum.Material.SmoothPlastic
		shell.Transparency = 0.08
		shell.Anchored = true
		shell.CanCollide, shell.CanQuery, shell.CanTouch = false, false, false
		shell.CastShadow = false
		shell.Position = centre
		shell.Parent = if layer == 1 then folder else part
		if layer == 1 then
			part = shell
		end
		TweenService:Create(
			shell,
			TweenInfo.new(MISTBANK.Grow, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.one * MISTBANK.Diameter * scale }
		):Play()
	end
	part:SetAttribute("MistView", MISTBANK.View)
	CollectionService:AddTag(part, Abilities.MistTag)
	place({
		owner = owner,
		key = owner.player or owner,
		name = MISTBANK.Name,
		part = part,
		ends = now() + MISTBANK.Lifetime,
		fade = MISTBANK.Fade,
		removed = false,
		connections = {},
	}, MISTBANK.Cap, surface)
	return part
end

-- Enemies inside a Mistbank stay soaked while inside and for SoakAfter seconds after leaving.
local function soakInMist()
	for _, object in placed do
		if object.name == MISTBANK.Name then
			local seen: { [Model]: boolean } = {}
			for _, part in
				workspace:GetPartBoundsInRadius(
					object.part.Position,
					object.part.Size.X / 2,
					overlap
				)
			do
				local model, humanoid = Combat.victim(part)
				if model and humanoid and not seen[model] and humanoid.Health > 0 then
					seen[model] = true
					if not isAlly(object.owner, model) then
						Runtime.applyStatus(model, "Soaked", MISTBANK.SoakAfter, object.owner.team)
					end
				end
			end
		end
	end
end

-- Each slug's effects. An armed main only does something on an enemy hit; an armed passive forms where it lands.
local kits: { [string]: { main: (Impact) -> (), passive: (Impact) -> () } } = {
	Aquabeek = {
		main = function(info)
			Runtime.crashwave(info.owner, info.victim :: Model, info.direction, info.damage)
		end,
		passive = function(info)
			Runtime.mistbank(info.owner, info.position, info.instance, info.victim)
		end,
	},
}

function Runtime.impact(info: Impact)
	local kit = info.ability and kits[info.slugId]
	if not kit then
		return
	end
	if info.ability == "passive" then
		kit.passive(info)
	elseif info.victim and not isAlly(info.owner, info.victim) then
		kit.main(info)
	end
end

-- Arming ---------------------------------------------------------------------------------------
local function blasterOf(player: Player): Tool?
	local character = player.Character
	if character then
		for _, item in character:GetChildren() do
			if Combat.isBlaster(item) then
				return item :: Tool
			end
		end
	end
	return nil
end

-- A small light on an armed blaster, visible to anyone close by, and the owner's HUD state.
local function sendState(player: Player)
	local state = arming[player]
	local tool = blasterOf(player)
	local handle = tool and tool:FindFirstChild("Handle")
	if handle then
		local light = handle:FindFirstChild("ArmedGlow")
		local colour = state and state.armed and ARMED_COLOUR[state.armed]
		if colour and not light then
			local made = Instance.new("PointLight")
			made.Name = "ArmedGlow"
			made.Range = 7
			made.Brightness = 2
			made.Shadows = false
			made.Parent = handle
			light = made
		elseif not colour and light then
			light:Destroy()
			light = nil
		end
		if colour and light and light:IsA("PointLight") then
			light.Color = colour
		end
	end
	if remote and state then
		remote:FireClient(player, "AbilityState", { armed = state.armed, ready = state.ready })
	end
end

local function armingOf(player: Player): Arming
	local state = arming[player]
	if not state then
		state = { armed = nil, slugId = nil, ready = {} }
		arming[player] = state
	end
	return state
end

-- Arms that ability of the selected slug for the next shot, or disarms with nil. Arming costs nothing.
function Runtime.arm(player: Player, slugId: string?, kind: Abilities.Kind?): boolean
	local state = armingOf(player)
	local ability = Abilities.ability(slugId, kind or "")
	local ok = kind == nil
		or (ability ~= nil and (state.ready[`{slugId}:{kind}`] or 0) <= now() + 0.1)
	if ok then
		state.armed, state.slugId = kind, if kind then slugId else nil
	end
	sendState(player)
	return ok
end

-- Switching slug, holstering or dying cancels the arming.
function Runtime.cancel(player: Player)
	local state = arming[player]
	if state and state.armed then
		state.armed, state.slugId = nil, nil
		sendState(player)
	end
end

-- The armed ability rides on this shot: its cooldown starts now, hit or miss.
function Runtime.consume(player: Player, slugId: string): Abilities.Kind?
	local state = arming[player]
	local kind = state and state.armed
	local ability = Abilities.ability(slugId, kind or "")
	if not state or not kind or state.slugId ~= slugId or not ability then
		return nil
	end
	state.armed, state.slugId = nil, nil
	state.ready[`{slugId}:{kind}`] = now() + ability.Cooldown
	sendState(player)
	return kind
end

-- Setup ------------------------------------------------------------------------------------------
function Runtime.init(options: { remote: RemoteEvent?, damage: DamageFn? })
	remote = options.remote
	damageFn = options.damage or damageFn
end

local function watch(player: Player)
	local function onCharacter(model: Model)
		local humanoid = model:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				Runtime.cancel(player)
			end)
		end
		model.ChildRemoved:Connect(function(child)
			if Combat.isBlaster(child) then
				Runtime.cancel(player)
			end
		end)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
end
Players.PlayerAdded:Connect(watch)
for _, player in Players:GetPlayers() do
	watch(player)
end

-- An owner who leaves takes their objects with them.
Players.PlayerRemoving:Connect(function(player)
	arming[player] = nil
	for index = #placed, 1, -1 do
		if placed[index].key == player then
			remove(placed[index])
		end
	end
end)

local sinceTick = 0
RunService.Heartbeat:Connect(function(dt)
	for index = #waves, 1, -1 do
		local wave = waves[index]
		if not stepWave(wave, dt) then
			table.remove(waves, index)
			fadeOut(wave.part, 0.3)
		end
	end
	local current = now()
	for index = #placed, 1, -1 do
		if current >= placed[index].ends then
			remove(placed[index])
		end
	end
	sinceTick += dt
	if sinceTick >= 0.1 then
		sinceTick = 0
		soakInMist()
		sweepStatuses()
	end
end)

return Runtime
