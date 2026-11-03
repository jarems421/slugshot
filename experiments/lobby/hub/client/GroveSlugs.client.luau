--!strict
-- The slug grove's Floppies and Infernos, on each client and look-only. Inferno hops more often and higher; otherwise
-- they share Floppy's acting: slow, spread-out hops round where they live, a drowsy idle up
-- close, and about one in four that notices a passing player, looks for a couple of seconds, then looks away for a while.
-- Never all of them, so the place doesn't feel like it's staring (owner). A slug is thousands of triangles and only a stud
-- or so tall, so those too far off to make out aren't drawn at all.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local RATE = 1 / 30
local SHOW_NEAR = 130 -- studs from the camera within which slugs are drawn
local SHOW_NEAR_LOW = 60 -- the same at low detail
local SHOW_MARGIN = 10 -- so one at the limit doesn't flicker
local IDLE_NEAR = 45 -- and within which their faces move
local HOP_TIME = 0.6
local HOP_HEIGHT = 1.5
local HOP_REACH = 3
local HOP_GAP = NumberRange.new(4, 11)
local LANDING = 0.28 -- seconds of squash after a hop
local NOTICE_NEAR = 15
local LOOK_TIME = NumberRange.new(1.8, 2.8)
local LOOK_AGAIN = NumberRange.new(20, 40)
local TURN_RATE = 5
local EYE_RATE = 2 * math.pi / 12
local EYE_SPACING = 0.74 -- at source; a slug's size comes from it, as in FloppyIdle
local ANTENNA_SPACING = 0.72 -- the same for Inferno, who has no eye rings, as in InfernoMotion
-- Inferno is restless where Floppy is drowsy: he hops more often and higher.
local INFERNO_HOP_GAP = NumberRange.new(1.5, 4.5)
local INFERNO_HOP_HEIGHT = 2.2
local WATER_Y = -0.3

type Driven = { bone: Bone, up: Vector3, axis: Vector3 }
type Slug = {
	model: Model,
	position: Vector3,
	rest: number,
	home: Vector3,
	heading: number,
	aim: number,
	nextHop: number,
	hopStart: number?,
	hopFrom: Vector3,
	hopTo: Vector3,
	shown: boolean,
	glances: boolean,
	hopGap: NumberRange,
	hopHeight: number,
	lookUntil: number,
	lookAgain: number,
	size: number,
	eyes: { Driven },
	squash: { Driven },
}

local random = Random.new()
local slugs: { Slug } = {}
local group: Instance
local shelf = Instance.new("Folder")
shelf.Name = "GroveSlugsFar"
local rays = RaycastParams.new()
rays.FilterType = Enum.RaycastFilterType.Exclude

local function pick(range: NumberRange): number
	return random:NextNumber(range.Min, range.Max)
end

local function frame(slug: Slug, position: Vector3)
	slug.model:PivotTo(CFrame.new(position) * CFrame.Angles(0, slug.heading, 0))
end

-- Roblox can create one skeleton per skinned mesh, so every copy of a bone is driven.
local function prepare(model: Model): Slug?
	local bones: { [string]: { Bone } } = {}
	for _, item in model:GetDescendants() do
		if item:IsA("Bone") then
			bones[item.Name] = bones[item.Name] or {}
			table.insert(bones[item.Name], item)
		end
	end
	local inferno = model:GetAttribute("Slug") == "Inferno"
	local eyeL, eyeR = bones.eye_L, bones.eye_R
	local left, right = bones.antenna_L, bones.antenna_R
	if not inferno then
		left, right = eyeL, eyeR
	end
	local root, head = bones.root, bones.head
	if not (left and right and root and head) then
		return nil
	end
	local spacing = (right[1].WorldPosition - left[1].WorldPosition).Magnitude
	local sideways = (right[1].WorldPosition - left[1].WorldPosition).Unit
	local rough = (head[1].WorldPosition - root[1].WorldPosition).Unit
	local up = (rough - sideways * rough:Dot(sideways)).Unit
	local front = sideways:Cross(up)
	local function drive(list: { Bone }?, axis: Vector3): { Driven }
		local out = {}
		for _, bone in list or {} do
			table.insert(out, {
				bone = bone,
				up = bone.WorldCFrame:VectorToObjectSpace(up),
				axis = bone.WorldCFrame:VectorToObjectSpace(axis),
			})
		end
		return out
	end
	local eyes: { Driven } = {}
	if not inferno then
		eyes = drive(eyeL, (sideways * -0.4 + up * 0.05 + front).Unit)
		for _, item in drive(eyeR, (sideways * 0.4 + up * 0.05 + front).Unit) do
			-- The two eyes' rings spin in opposite directions.
			item.axis = -item.axis
			table.insert(eyes, item)
		end
	end
	local hopGap = if inferno then INFERNO_HOP_GAP else HOP_GAP
	local squash = drive(head, up)
	for _, item in drive(bones.body_upper, up) do
		table.insert(squash, item)
	end
	local pivot = model:GetPivot()
	local _, yaw = pivot:ToOrientation()
	return {
		model = model,
		position = pivot.Position,
		rest = pivot.Position.Y,
		home = pivot.Position,
		heading = yaw,
		aim = yaw,
		nextHop = os.clock() + pick(hopGap),
		hopStart = nil,
		hopFrom = pivot.Position,
		hopTo = pivot.Position,
		shown = true,
		glances = model:GetAttribute("GroveGlances") == true,
		hopGap = hopGap,
		hopHeight = if inferno then INFERNO_HOP_HEIGHT else HOP_HEIGHT,
		lookUntil = 0,
		lookAgain = 0,
		size = spacing / (if inferno then ANTENNA_SPACING else EYE_SPACING),
		eyes = eyes,
		squash = squash,
	}
end

-- Somewhere near home that is solid, dry and about level. The slug stays put if not.
local function chooseHop(slug: Slug): Vector3?
	local angle = random:NextNumber(0, 2 * math.pi)
	local reach = random:NextNumber(HOP_REACH * 0.5, HOP_REACH)
	local spot = slug.home + Vector3.new(math.cos(angle) * reach, 0, math.sin(angle) * reach)
	local hit = workspace:Raycast(spot + Vector3.new(0, 5, 0), Vector3.new(0, -12, 0), rays)
	if
		not hit
		or hit.Normal.Y < 0.75
		or hit.Position.Y < WATER_Y
		or math.abs(hit.Position.Y - slug.position.Y) > 2
	then
		return nil
	end
	return hit.Position
end

local function step(now: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	local character = Players.LocalPlayer.Character
	local body = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local player = if body then body.Position else eye
	rays.FilterDescendantsInstances = if character then { character } else {}
	local limit = if workspace:GetAttribute("HubDetailLow") then SHOW_NEAR_LOW else SHOW_NEAR
	for _, slug in slugs do
		local distance = (slug.position - eye).Magnitude
		local show = if slug.shown then distance < limit + SHOW_MARGIN else distance < limit
		if show ~= slug.shown then
			slug.shown = show
			slug.model.Parent = if show then group else shelf
		end
		if not show then
			continue
		end
		local moved = false
		local away = player - slug.position
		if
			slug.glances
			and now > slug.lookAgain
			and now > slug.lookUntil
			and not slug.hopStart
			and away.Magnitude < NOTICE_NEAR
		then
			local look = pick(LOOK_TIME)
			slug.lookUntil = now + look
			slug.lookAgain = now + look + pick(LOOK_AGAIN)
		end
		local aim = slug.aim
		if now < slug.lookUntil then
			-- A slug's -Z is its face.
			aim = math.atan2(-away.X, -away.Z)
		end
		local turn = math.atan2(math.sin(aim - slug.heading), math.cos(aim - slug.heading))
		if math.abs(turn) > 0.01 then
			slug.heading += turn * math.min(RATE * TURN_RATE, 1)
			moved = true
		end
		local hopStart = slug.hopStart
		local position = slug.position
		if hopStart then
			local t = (now - hopStart) / HOP_TIME
			if t >= 1 then
				slug.hopStart = nil
				slug.position = slug.hopTo
				slug.nextHop = now + pick(slug.hopGap)
				position = slug.position
			else
				position = slug.hopFrom:Lerp(slug.hopTo, t)
					+ Vector3.new(0, slug.hopHeight * 4 * t * (1 - t), 0)
			end
			moved = true
		elseif now > slug.nextHop and now > slug.lookUntil then
			local target = chooseHop(slug)
			if target then
				slug.hopStart, slug.hopFrom, slug.hopTo = now, slug.position, target
				local face = target - slug.position
				slug.aim = math.atan2(-face.X, -face.Z)
			else
				slug.nextHop = now + pick(slug.hopGap)
			end
		end
		if moved then
			frame(slug, position)
		end
		if distance < IDLE_NEAR then
			for index, item in slug.eyes do
				item.bone.Transform = CFrame.fromAxisAngle(item.axis, now * EYE_RATE + index)
			end
			local since = if slug.hopStart then -1 else now - (slug.nextHop - slug.hopGap.Min)
			local press = if since >= 0 and since < LANDING
				then math.sin(math.pi * since / LANDING) * 0.14
				else 0.012 * math.sin(now * 1.57 + slug.heading)
			for _, item in slug.squash do
				item.bone.Transform = CFrame.new(item.up * -press * slug.size)
			end
		end
	end
end

task.spawn(function()
	while not workspace:GetAttribute("HubSolid") do
		task.wait(1)
	end
	local art = workspace:WaitForChild("HubArt")
	local found = art:WaitForChild("GroveSlugs", 30)
	if not found then
		return
	end
	group = found
	shelf.Parent = script
	-- Models stream in after their folder.
	task.wait(1)
	for _, item in group:GetChildren() do
		if item:IsA("Model") then
			local slug = prepare(item)
			if slug then
				table.insert(slugs, slug)
			end
		end
	end
	local waited = 0
	RunService.Heartbeat:Connect(function(dt)
		waited += dt
		if waited >= RATE then
			waited = 0
			step(os.clock())
		end
	end)
end)
