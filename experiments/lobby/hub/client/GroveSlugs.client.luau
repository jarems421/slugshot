--!strict
-- Client presentation only: supported landings inside each exhibition habitat.
-- Decisions/rays are infrequent; positions and poses run on every rendered frame.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local random = Random.new()
local WINDUP, HOLD, AIR, LAND = 0.30, 0.10, 0.58, 0.38
local HOME_REACH = 7
local NOTICE = 14
local SHOW_NEAR = 140
local WATER_Y = -0.3
local rays = RaycastParams.new()
rays.FilterType = Enum.RaycastFilterType.Exclude

type Driven = { bone: Bone, up: Vector3, side: Vector3 }
type Slug = {
	model: Model,
	parts: { BasePart },
	position: Vector3,
	home: Vector3,
	origin: Vector3,
	up: Vector3,
	fromUp: Vector3,
	toUp: Vector3,
	heading: number,
	aim: number,
	nextHop: number,
	hopAt: number?,
	from: Vector3,
	to: Vector3,
	lookAt: number,
	lookUntil: number,
	lookAgain: number,
	lookBlend: number,
	mood: number,
	inferno: boolean,
	size: number,
	shown: boolean,
	lastFrame: CFrame,
	lastPress: number,
	lastLook: number,
	squash: { Driven },
	head: { Driven },
	spread: { Driven },
}
local slugs: { Slug } = {}
local group: Instance
local nextDecision = 0
local renderedFrames = 0

local function ease(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function frame(position: Vector3, up: Vector3, yaw: number): CFrame
	local forward = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
	forward = (forward - up * forward:Dot(up)).Unit
	return CFrame.lookAt(position, position + forward, up)
end

-- Nine contacts cover the belly, not only the pivot. All must belong to the
-- same gentle plane: an edge, rounded tip, steep slope or water rejects it.
local function support(spot: Vector3, yaw: number, size: number): (Vector3?, Vector3?)
	local hit = workspace:Raycast(spot + Vector3.yAxis * 5, -Vector3.yAxis * 12, rays)
	if not hit or hit.Normal.Y < 0.94 or hit.Position.Y < WATER_Y then
		return nil, nil
	end
	local basis = CFrame.Angles(0, yaw, 0)
	for index = 0, 7 do
		local a = index * math.pi / 4
		local delta = basis:VectorToWorldSpace(
			Vector3.new(math.cos(a) * size * 0.42, 0, math.sin(a) * size * 0.42)
		)
		local foot = hit.Position + delta
		local sample = workspace:Raycast(foot + Vector3.yAxis * 2, -Vector3.yAxis * 4, rays)
		if not sample or sample.Normal.Y < 0.9 or sample.Position.Y < WATER_Y then
			return nil, nil
		end
		local planeY = hit.Position.Y
			- (hit.Normal.X * delta.X + hit.Normal.Z * delta.Z) / hit.Normal.Y
		if math.abs(sample.Position.Y - planeY) > 0.12 then
			return nil, nil
		end
	end
	return hit.Position + hit.Normal * 0.015, hit.Normal
end

local function landing(slug: Slug, initial: boolean): (Vector3?, Vector3?)
	for attempt = 1, (if initial then 180 else 10) do
		local radius = if initial and attempt == 1
			then 0
			else random:NextNumber(1, if initial then 12 else HOME_REACH - 1)
		local angle = random:NextNumber(0, math.pi * 2)
		local candidate = slug.home
			+ Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local habitat = candidate - slug.origin
		if Vector2.new(habitat.X, habitat.Z).Magnitude > 68 then
			continue
		end
		local direction = candidate - slug.position
		local yaw = if direction.Magnitude > 0.1
			then math.atan2(-direction.X, -direction.Z)
			else slug.heading
		local point, normal = support(candidate, yaw, slug.size)
		if
			not point
			or not normal
			or (not initial and math.abs(point.Y - slug.position.Y) > 1.4)
		then
			continue
		end
		-- The whole body remains inside the authored habitat, including during a hop.
		local occupied = false
		for _, other in slugs do
			if other ~= slug and (other.to - point).Magnitude < slug.size * 1.1 then
				occupied = true
				break
			end
		end
		if not occupied then
			return point, normal
		end
	end
	return nil, nil
end

local function prepare(model: Model): Slug?
	local root = model:FindFirstChild("root", true) :: Bone?
	local head = model:FindFirstChild("head", true) :: Bone?
	if not root or not head then
		return nil
	end
	local pivot = model:GetPivot()
	local _, yaw = pivot:ToOrientation()
	local up = pivot.UpVector
	local side = pivot.RightVector
	local squash: { Driven } = {}
	local heads: { Driven } = {}
	local parts: { BasePart } = {}
	local spread: { Driven } = {}
	local outward =
		{ jelly_L = -side, jelly_R = side, jelly_F = pivot.LookVector, jelly_B = -pivot.LookVector }
	for _, item in model:GetDescendants() do
		if item:IsA("Bone") and outward[item.Name] then
			table.insert(spread, {
				bone = item,
				up = item.WorldCFrame:VectorToObjectSpace(outward[item.Name]),
				side = Vector3.zero,
			})
		end
		if item:IsA("Bone") and (item.Name == "head" or item.Name == "body_upper") then
			local driven = {
				bone = item,
				up = item.WorldCFrame:VectorToObjectSpace(up),
				side = item.WorldCFrame:VectorToObjectSpace(side),
			}
			table.insert(if item.Name == "head" then heads else squash, driven)
		elseif item:IsA("BasePart") then
			table.insert(parts, item)
		end
	end
	local inferno = model:GetAttribute("Slug") == "Inferno"
	local slug: Slug = {
		model = model,
		parts = parts,
		position = pivot.Position,
		home = pivot.Position,
		origin = model:GetAttribute("GroveOrigin") :: Vector3,
		up = Vector3.yAxis,
		fromUp = Vector3.yAxis,
		toUp = Vector3.yAxis,
		heading = yaw,
		aim = yaw,
		nextHop = os.clock() + random:NextNumber(1, 4),
		hopAt = nil,
		from = pivot.Position,
		to = pivot.Position,
		lookAt = 0,
		lookUntil = 0,
		lookAgain = os.clock() + random:NextNumber(0, 3),
		lookBlend = 0,
		mood = 0,
		inferno = inferno,
		size = model:GetAttribute("WorldSlugSize") :: number,
		shown = true,
		lastFrame = pivot,
		lastPress = math.huge,
		lastLook = math.huge,
		squash = squash,
		head = heads,
		spread = spread,
	}
	local point, normal = landing(slug, true)
	if not point or not normal then
		-- Prefer omitting a resident to displaying one balanced over a ledge.
		model:Destroy()
		warn(`GroveSlugs: no fully supported landing near {model.Name}`)
		return nil
	end
	slug.position, slug.home, slug.from, slug.to = point, point, point, point
	slug.up, slug.fromUp, slug.toUp = normal, normal, normal
	model:PivotTo(frame(point, normal, yaw))
	model:SetAttribute("GroveReady", true)
	return slug
end

local function decide(now: number, player: Vector3)
	local looking = 0
	for _, slug in slugs do
		if now < slug.lookUntil then
			looking += 1
		end
	end
	for _, slug in slugs do
		if not slug.shown or slug.hopAt then
			continue
		end
		local away = player - slug.position
		if
			now > slug.lookAgain
			and now > slug.lookUntil
			and away.Magnitude < NOTICE
			and looking < 3
		then
			slug.lookAgain = now + random:NextNumber(10, 20)
			if random:NextNumber() < 0.7 then
				slug.lookAt = now
				slug.lookUntil = now + random:NextNumber(1.8, 3)
				slug.mood = if random:NextNumber() < 0.5 then 0 else 1
				slug.model:SetAttribute("ReviewMood", slug.mood)
				looking += 1
			end
		end
		if now > slug.nextHop and now > slug.lookUntil + 0.45 then
			local point, normal = landing(slug, false)
			if point and normal then
				local direction = point - slug.position
				-- An annoyed Inferno turns away after looking, where ground permits.
				if
					slug.inferno
					and slug.mood == 1
					and now < slug.lookUntil + 2
					and direction:Dot(away) > 0
				then
					slug.nextHop = now + 0.2
					continue
				end
				slug.hopAt, slug.from, slug.to = now, slug.position, point
				slug.fromUp, slug.toUp = slug.up, normal
				slug.aim = math.atan2(-direction.X, -direction.Z)
			else
				slug.nextHop = now + random:NextNumber(0.8, 1.6)
			end
		end
	end
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local now = os.clock()
	renderedFrames += 1
	if RunService:IsStudio() then
		workspace:SetAttribute("GroveRenderedFrames", renderedFrames)
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local player = if root then root.Position else camera.CFrame.Position
	rays.FilterDescendantsInstances = if character then { character, group } else { group }
	local limit = if workspace:GetAttribute("HubDetailLow") then 70 else SHOW_NEAR
	for _, slug in slugs do
		local show = (slug.position - camera.CFrame.Position).Magnitude
			< limit + (if slug.shown then 12 else 0)
		if show ~= slug.shown then
			slug.shown = show
			for _, part in slug.parts do
				part.LocalTransparencyModifier = if show then 0 else 1
			end
		end
	end
	if now >= nextDecision then
		nextDecision = now + 0.12
		decide(now, player)
	end
	for _, slug in slugs do
		if not slug.shown then
			continue
		end
		local looking = now < slug.lookUntil
		slug.lookBlend += ((if looking then 1 else 0) - slug.lookBlend) * (1 - math.exp(-7 * dt))
		local away = player - slug.position
		local yaw = if looking then math.atan2(-away.X, -away.Z) else slug.aim
		local turn = math.atan2(math.sin(yaw - slug.heading), math.cos(yaw - slug.heading))
		slug.heading += turn * (1 - math.exp(-8 * dt))
		local position = slug.position
		local up = slug.up
		local press, lean = 0, 0
		local stage = "rest"
		if slug.hopAt then
			local elapsed = now - slug.hopAt
			if elapsed < WINDUP then
				stage = "windup"
				press = 0.36 * ease(elapsed / WINDUP)
			elseif elapsed < WINDUP + HOLD then
				stage = "tension"
				press = 0.36
			elseif elapsed < WINDUP + HOLD + AIR then
				stage = "flight"
				local t = (elapsed - WINDUP - HOLD) / AIR
				position = slug.from:Lerp(slug.to, t)
					+ Vector3.yAxis * (if slug.inferno then 2.5 else 1.9) * 4 * t * (1 - t)
				up = slug.fromUp:Lerp(slug.toUp, ease(t)).Unit
				press = 0.36 * (1 - ease(t / 0.14))
					- 0.18 * math.sin(math.pi * math.min(t / 0.5, 1))
					+ 0.05 * ease((t - 0.88) / 0.12)
				lean = math.rad(9) * math.sin(math.pi * t)
			elseif elapsed < WINDUP + HOLD + AIR + LAND then
				stage = "landing"
				local t = (elapsed - WINDUP - HOLD - AIR) / LAND
				position, up = slug.to, slug.toUp
				press = if t < 0.18
					then 0.05 + 0.45 * ease(t / 0.18)
					else 0.5 * (1 - ease((t - 0.18) / 0.82))
			else
				slug.position, slug.up = slug.to, slug.toUp
				position, up = slug.position, slug.up
				slug.hopAt = nil
				slug.nextHop = now
					+ random:NextNumber(
						if slug.inferno then 1.4 else 2.8,
						if slug.inferno then 3.6 else 6
					)
			end
		end
		local pose = frame(position, up, slug.heading)
		if
			(pose.Position - slug.lastFrame.Position).Magnitude > 0.0001
			or (pose.LookVector - slug.lastFrame.LookVector).Magnitude > 0.0001
		then
			slug.model:PivotTo(pose)
			slug.lastFrame = pose
		end
		slug.model:SetAttribute("GrovePress", press)
		slug.model:SetAttribute("GroveLook", slug.lookBlend)
		local poseChanged = slug.hopAt ~= nil
			or math.abs(press - slug.lastPress) > 0.0001
			or math.abs(slug.lookBlend - slug.lastLook) > 0.0001
		if not slug.inferno and poseChanged then
			slug.model:SetAttribute("FaceExpression", 1)
			slug.model:SetAttribute("FaceLook", Vector2.new(0, 0.8 * slug.lookBlend))
			for _, item in slug.head do
				item.bone.Transform = CFrame.new(item.up * -press * 0.55 * slug.size / 2.72)
					* CFrame.fromAxisAngle(item.side, 0.22 * slug.lookBlend + lean)
			end
		end
		if poseChanged then
			for _, item in slug.squash do
				item.bone.Transform = CFrame.new(item.up * -press * slug.size / 2.72)
			end
			for _, item in slug.spread do
				item.bone.Transform = CFrame.new(item.up * press * slug.size * 0.10)
			end
			slug.lastPress, slug.lastLook = press, slug.lookBlend
		end
		if RunService:IsStudio() then
			slug.model:SetAttribute("GroveStage", stage)
			slug.model:SetAttribute(
				"GrovePhase",
				if slug.hopAt then "hop" elseif looking then "look" else "rest"
			)
			slug.model:SetAttribute("GroveHomeDistance", (position - slug.home).Magnitude)
		end
	end
end

task.spawn(function()
	while not workspace:GetAttribute("HubSolid") do
		task.wait(0.2)
	end
	group = workspace:WaitForChild("HubArt"):WaitForChild("GroveSlugs")
	task.wait(1)
	rays.FilterDescendantsInstances = { group }
	for _, model in group:GetChildren() do
		if model:IsA("Model") then
			local slug = prepare(model)
			if slug then
				table.insert(slugs, slug)
			end
		end
	end
	RunService:BindToRenderStep("GroveResidents", Enum.RenderPriority.Character.Value + 1, step)
end)
