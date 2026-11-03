--!strict
-- Inferno's motion on this client (Bone.Transform does not replicate). He is the opposite of drowsy Floppy: restless,
-- cocky and always performing at you. Each moment a move sets a target pose; every channel then springs toward it, so
-- any move can flow into any other with no snap. Big moves wind up first, overshoot, then settle, and the body, head
-- and antennae lag behind the turn. He never blinks (owner, 2026-11-02). Amounts are in concept units, scaled by size.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")

local asset = (require :: any)(ReplicatedStorage:WaitForChild("InfernoAsset"))
local random = Random.new()
local TAU = 2 * math.pi

type Item = { bone: Bone, x: Vector3, y: Vector3, z: Vector3 }
type Eye = { items: { Item }, ax: Vector3, w: Vector3, side: number }
type Spring = { value: number, speed: number }
type FireGlowLayer = {
	beam: Beam,
	finish: Attachment,
	width: number,
}
type FireGlow = {
	tail: Bone,
	last: Bone,
	startAt: Vector3,
	startWay: Vector3,
	finishAt: Vector3,
	finishWay: Vector3,
	unit: number,
	start: Attachment,
	layers: { FireGlowLayer },
}
type Rig = {
	model: Model,
	dragon: boolean,
	flight: boolean,
	scale: number,
	sideways: Vector3,
	up: Vector3,
	front: Vector3,
	bones: { [string]: { Item } },
	eyes: { Eye },
	mouthLine: { BasePart },
	mouth: { [string]: Vector3 },
	clock: number,
	channels: { [string]: Spring },
	lookYaw: number,
	lookPitch: number,
	moodTarget: number,
	nextMood: number,
	move: string,
	moveAt: number,
	nextMove: number,
	moveIndex: number,
	wingClock: number,
	lastFlip: number,
	lastSpin: number,
	lastRoll: number,
	glow: FireGlow?,
}
local rigs: { [Model]: Rig } = {}
-- Ready before the first shot, so the first flame shows.
task.spawn(function()
	ContentProvider:PreloadAsync({ `rbxassetid://{asset.flame}` })
end)
-- The soft flame behind the tail flame: widths of its layers, and where it starts and ends along the flame from the
-- tail tip, all in concept units.
local FIRE_GLOW_WIDTHS = { 2.1, 1.6 }
local FIRE_GLOW_START, FIRE_GLOW_END = 0.35, 1.85

local ANTENNA_SPACING = { base = 0.72, dragon = 0.60 }
local BASE_CENTRE = 1.2 -- turns happen about the middle of the body, in concept units above the root
local MAX_YAW, MAX_PITCH = 0.8, 0.45
-- How far anger pulls each upper lid down and turns it toward the nose. The lid is the skin itself, so this stretches the face.
local LID_DROP, LID_TURN = 0.085, 0.3
-- The dragon's head is smaller and rounder, so it takes less stretch. His eyes sit closer behind the skin, so his
-- lids come further forward to clear them.
local DRAGON_LID_DROP, DRAGON_LID_TURN = 0.065, 0.18
local LID_FORWARD, DRAGON_LID_FORWARD = 0.012, 0.032
-- The flame's sides, in concept axes, and where each sits round it: the swell rolls from one to the next.
local FLAME_SIDES = {
	{ name = "flame_L", way = Vector3.new(1, 0, 0), phase = 0 },
	{ name = "flame_up", way = Vector3.new(0, 1, 0), phase = math.pi / 2 },
	{ name = "flame_R", way = Vector3.new(-1, 0, 0), phase = math.pi },
	{ name = "flame_down", way = Vector3.new(0, -1, 0), phase = math.pi * 1.5 },
}

-- Seconds each move lasts. A bounce is the resting state between them.
local BASE_MOVES = { backflip = 1.8, spin = 1.5, lean = 2.2, taunt = 1.8, leap = 1.1 }
local BASE_ORDER = { "lean", "backflip", "taunt", "spin", "leap", "lean", "backflip" }
local DRAGON_MOVES = { roll = 1.6, swoop = 2.0, snap = 1.2 }
local DRAGON_ORDER = { "swoop", "roll", "snap" }

local function ease(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function arc(t: number): number
	return math.sin(math.clamp(t, 0, 1) * math.pi)
end

-- A spring with some bounce: stiffness in 1/s, damping 1 settles without overshoot.
local function spring(
	rig: Rig,
	name: string,
	target: number,
	stiffness: number,
	damping: number,
	dt: number
): number
	local s = rig.channels[name]
	if not s then
		s = { value = target, speed = 0 }
		rig.channels[name] = s
	end
	local steps = math.max(1, math.ceil(dt * 240))
	local h = dt / steps
	for _ = 1, steps do
		s.speed += (stiffness * stiffness * (target - s.value) - 2 * damping * stiffness * s.speed) * h
		s.value += s.speed * h
	end
	return s.value
end

-- The soft flame behind the mesh flame. A beam attached to an animated bone does not follow it, so its ends are free
-- attachments placed from the moved bones every frame, curved to leave and arrive the way the bones point. They live on
-- the part the bones hang from, so the fire rides on the model at any speed, scales with it and goes when it goes.
-- It starts on the tail bone, since the flame bones pivot at the tail tip and would swing that end the wrong way.
local function addFireGlow(rig: Rig)
	local first = (rig.bones.flame_1 or {})[1]
	local root = (rig.bones.tail_3 or {})[1]
	local second = (rig.bones.flame_2 or {})[1]
	local last = (rig.bones.flame_3 or {})[1]
	if not (root and first and second and last) then
		warn(`{rig.model.Name}: no flame bones`)
		return
	end
	local a, b, c = first.bone :: Bone, second.bone :: Bone, last.bone :: Bone
	local tail = root.bone :: Bone
	local part = a:FindFirstAncestorWhichIsA("BasePart")
	if not part then
		warn(`{rig.model.Name}: flame bones have no part`)
		return
	end
	-- Bones flame_1 and flame_2 are 0.6 concept units apart, which gives the flame's axis and its scale in studs.
	local along = (b.WorldPosition - a.WorldPosition).Unit
	local unit = (b.WorldPosition - a.WorldPosition).Magnitude / 0.6
	local start = Instance.new("Attachment")
	start.Parent = part
	local layers: { FireGlowLayer } = {}
	for _, width in FIRE_GLOW_WIDTHS do
		local finish = Instance.new("Attachment")
		finish.Parent = part
		local beam = Instance.new("Beam")
		beam.Name = "FireGlow"
		beam.Enabled = false
		beam.Attachment0 = start
		beam.Attachment1 = finish
		beam.Texture = `rbxassetid://{asset.flame}`
		beam.TextureMode = Enum.TextureMode.Stretch
		beam.TextureLength = 1
		-- Beams scroll their image by default, which would slide the glow out through the end of its strip.
		beam.TextureSpeed = 0
		beam.FaceCamera = true
		beam.Segments = 16
		beam.Transparency = NumberSequence.new(0)
		beam.LightEmission = 0.25
		beam.LightInfluence = 0
		beam.Parent = part
		table.insert(layers, { beam = beam, finish = finish, width = width * unit })
		-- An unloaded beam image draws as a white strip.
		task.spawn(function()
			ContentProvider:PreloadAsync({ beam })
			beam.Enabled = true
		end)
	end
	rig.glow = {
		tail = tail,
		last = c,
		startAt = tail.WorldCFrame:PointToObjectSpace(
			a.WorldPosition - along * (FIRE_GLOW_START * unit)
		),
		startWay = tail.WorldCFrame:VectorToObjectSpace(along),
		finishAt = c.WorldCFrame:PointToObjectSpace(
			a.WorldPosition + along * (FIRE_GLOW_END * unit)
		),
		finishWay = c.WorldCFrame:VectorToObjectSpace(along),
		unit = unit,
		start = start,
		layers = layers,
	}
end

-- Any direction square to `way`, in the part's axes, which can point anywhere after import.
local function sideOf(way: Vector3): Vector3
	return way:Cross(if math.abs(way.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis).Unit
end

-- An attachment at a point, its X axis along the way the beam travels there.
local function beamEnd(position: Vector3, way: Vector3): CFrame
	local side = sideOf(way)
	local up = side:Cross(way)
	return CFrame.fromMatrix(position, way, up, way:Cross(up))
end

-- A bone's frame against its part, with this frame's motion already in it. Bone.TransformedWorldCFrame only catches up
-- a frame later, which left the fire trailing the tail.
local function movedFrame(bone: Instance): CFrame
	local parent = bone.Parent
	if bone:IsA("Bone") then
		return (if parent then movedFrame(parent) else CFrame.identity)
			* bone.CFrame
			* bone.Transform
	end
	return CFrame.identity
end

local function stepFireGlow(rig: Rig, t: number)
	local glow = rig.glow
	if not glow then
		return
	end
	local firstFrame = movedFrame(glow.tail)
	local lastFrame = movedFrame(glow.last)
	local from = firstFrame * glow.startAt
	local leaving = firstFrame:VectorToWorldSpace(glow.startWay)
	glow.start.CFrame = beamEnd(from, leaving)
	local arriving = lastFrame:VectorToWorldSpace(glow.finishWay)
	local side = sideOf(arriving)
	local up = side:Cross(arriving)
	for i, layer in glow.layers do
		-- The layers move together, so the fire stays one shape stuck to the tail. Each stretches a little on its own, and
		-- both ends of each flicker in width.
		local to = lastFrame * glow.finishAt
			+ side * (0.07 * math.sin(t * 6.7) + 0.03 * math.sin(t * 13.1)) * glow.unit
			+ up * (0.06 * math.sin(t * 8.3) + 0.03 * math.sin(t * 15.3)) * glow.unit
			+ arriving
				* (0.07 * math.sin(t * 5.7) + 0.03 * math.sin(t * 9.7 + i * 2))
				* glow.unit
		layer.finish.CFrame = beamEnd(to, arriving)
		local reach = (to - from).Magnitude / 3
		layer.beam.CurveSize0 = reach
		layer.beam.CurveSize1 = -reach
		layer.beam.Width0 = layer.width
			* (1 + 0.12 * math.sin(t * 9.1 + i * 2) + 0.07 * math.sin(t * 16.7 + i))
		layer.beam.Width1 = layer.width
			* (1 + 0.14 * math.sin(t * 7.3 + i) + 0.08 * math.sin(t * 19.1 + i * 3))
	end
end

local function setup(model: Model)
	if rigs[model] then
		return
	end
	local flight = model.Name == "InfernoFlight"
	local dragon = flight or model.Name == "InfernoDragon"
	local spec = if dragon then asset.dragon else asset.base
	local antennaL, antennaR
	for _, d in model:GetDescendants() do
		if d:IsA("Bone") then
			d.Transform = CFrame.identity
			if d.Name == "antenna_L" then
				antennaL = d
			elseif d.Name == "antenna_R" then
				antennaR = d
			end
		end
	end
	if not (antennaL and antennaR) then
		warn(`{model.Name}: no antenna bones`)
		return
	end
	local sideways = (antennaR.WorldPosition - antennaL.WorldPosition).Unit
	local up = (Vector3.yAxis - sideways * sideways.Y).Unit
	local front = sideways:Cross(up)
	if model:GetAttribute("GroveResident") == true then
		local pivot = model:GetPivot()
		sideways, up, front = pivot.RightVector, pivot.UpVector, pivot.LookVector
	end
	local scale = (antennaR.WorldPosition - antennaL.WorldPosition).Magnitude
		/ (if dragon then ANTENNA_SPACING.dragon else ANTENNA_SPACING.base)
	-- Roblox can create one skeleton per skinned mesh: every copy is driven, each through its own axes.
	local bones: { [string]: { Item } } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Bone") then
			local frame = d.WorldCFrame
			local list = bones[d.Name] or {}
			bones[d.Name] = list
			table.insert(list, {
				bone = d,
				x = frame:VectorToObjectSpace(sideways),
				y = frame:VectorToObjectSpace(up),
				z = frame:VectorToObjectSpace(front),
			})
		end
	end
	local eyes: { Eye } = {}
	for _, s in { -1, 1 } do
		local a = spec.eyeAxis
		local ax = Vector3.new(s * a.X, a.Y, a.Z).Unit
		local u = Vector3.new(0, 1, 0):Cross(ax).Unit
		table.insert(eyes, {
			items = bones[if s < 0 then "lid_L" else "lid_R"] or {},
			ax = ax,
			w = ax:Cross(u),
			side = s,
		})
	end
	local mouthLine: { BasePart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and string.sub(d.Name, -9) == "MouthLine" then
			table.insert(mouthLine, d)
		end
	end
	rigs[model] = {
		model = model,
		mouthLine = mouthLine,
		mouth = spec.mouth,
		dragon = dragon,
		flight = flight,
		scale = scale,
		sideways = sideways,
		up = up,
		front = front,
		bones = bones,
		eyes = eyes,
		clock = 0,
		channels = {},
		lookYaw = 0,
		lookPitch = 0,
		moodTarget = 0,
		nextMood = random:NextNumber(4, 6),
		move = "",
		moveAt = -math.huge,
		nextMove = random:NextNumber(1.5, 2.5),
		moveIndex = 0,
		wingClock = 0,
		lastFlip = 0,
		lastSpin = 0,
		lastRoll = 0,
	}
	if dragon then
		addFireGlow(rigs[model])
	end
end

local function consider(instance: Instance)
	if
		instance:IsA("Model")
		and (
			instance.Name == "Inferno"
			or instance.Name == "InfernoDragon"
			or (
				instance:GetAttribute("GroveResident") == true
				and instance:GetAttribute("Slug") == "Inferno"
			)
		)
	then
		task.delay(0.5, setup, instance)
	end
end
for _, item in workspace:GetDescendants() do
	consider(item)
end
workspace.DescendantAdded:Connect(consider)

local function toBone(item: Item, v: Vector3): Vector3
	return item.x * v.X + item.y * v.Y + item.z * v.Z
end

-- Offset in concept units along (sideways, up, front), then rotations about those axes.
local function drive(
	rig: Rig,
	name: string,
	offset: Vector3,
	pitch: number?,
	yaw: number?,
	roll: number?
)
	for _, item in (rig.bones[name] or {}) :: { Item } do
		item.bone.Transform = CFrame.new(toBone(item, offset) * rig.scale)
			* CFrame.fromAxisAngle(item.y, yaw or 0)
			* CFrame.fromAxisAngle(item.x, pitch or 0)
			* CFrame.fromAxisAngle(item.z, roll or 0)
	end
end

local function pickMove(rig: Rig, moves: { [string]: number }, order: { string }): (string, number)
	if rig.clock >= rig.nextMove then
		rig.moveIndex = rig.moveIndex % #order + 1
		rig.move = order[rig.moveIndex]
		rig.moveAt = rig.clock
		rig.nextMove = rig.clock + moves[rig.move] + random:NextNumber(0.7, 1.8)
	end
	local duration = moves[rig.move]
	if not duration then
		return "", 0
	end
	local since = (rig.clock - rig.moveAt) / duration
	if since >= 1 then
		return "", 0
	end
	return rig.move, since
end

-- Bring a finished turn back near zero, so the next one starts clean.
local function wrapTurn(rig: Rig, name: string)
	local s = rig.channels[name]
	if s then
		s.value = (s.value + math.pi) % TAU - math.pi
	end
end

local function stepFace(rig: Rig, dt: number, camera: Vector3, wantLook: number): number
	local clock = rig.clock
	local head = rig.bones.head and rig.bones.head[1]
	if head then
		local to = camera - head.bone.TransformedWorldCFrame.Position
		local x, y, z = to:Dot(rig.sideways), to:Dot(rig.up), to:Dot(rig.front)
		local yawTarget = math.clamp(math.atan2(x, z), -MAX_YAW, MAX_YAW) * wantLook
		local pitchTarget = math.clamp(
			math.atan2(y, math.sqrt(x * x + z * z)),
			-MAX_PITCH,
			MAX_PITCH
		) * wantLook
		if z < 0 then
			yawTarget, pitchTarget = 0, 0 -- behind him: he faces forward rather than twisting round
		end
		rig.lookYaw = spring(rig, "lookYaw", yawTarget, 6, 0.8, dt)
		rig.lookPitch = spring(rig, "lookPitch", pitchTarget, 6, 0.8, dt)
	end
	if clock >= rig.nextMood then
		if rig.moodTarget == 0 then
			rig.moodTarget = 1
			rig.nextMood = clock + random:NextNumber(2.6, 3.2)
		else
			rig.moodTarget = 0
			rig.nextMood = clock + random:NextNumber(4, 7)
		end
	end
	local reviewMood = rig.model:GetAttribute("ReviewMood")
	local angry = spring(
		rig,
		"mood",
		if typeof(reviewMood) == "number" then reviewMood else rig.moodTarget,
		5.5,
		1,
		dt
	)
	angry = math.clamp(angry, 0, 1)
	-- One mouth: every lip bone travels from the grin to the gritted shape, so it morphs with nothing swapped.
	for name, delta in rig.mouth do
		drive(rig, name, delta * angry)
	end
	-- The wavy line where the teeth meet comes in once the lips have closed up.
	for _, part in rig.mouthLine do
		part.Transparency = 1 - ease((angry - 0.55) / 0.4)
	end
	-- The lids are the skin above the eyes, so he never blinks: anger furrows them, with a little overshoot and tremble.
	local furrow = spring(rig, "furrow", angry, 7, 0.6, dt) + 0.04 * angry * math.sin(clock * 19)
	for _, eye in rig.eyes do
		-- In concept axes, which are (sideways, up, front).
		local offset = (
			eye.ax * (if rig.dragon then DRAGON_LID_FORWARD else LID_FORWARD)
			- eye.w * (if rig.dragon then DRAGON_LID_DROP else LID_DROP)
		) * furrow
		local turn = eye.side * (if rig.dragon then DRAGON_LID_TURN else LID_TURN) * furrow
		for _, item in eye.items do
			item.bone.Transform = CFrame.new(toBone(item, offset) * rig.scale)
				* CFrame.fromAxisAngle(toBone(item, eye.ax), turn)
		end
	end
	return angry
end

-- Antennae lag behind how fast the body is moving, so every hop and flip whips them.
local function antennae(rig: Rig, dt: number, push: number)
	local t = rig.clock
	local whip = spring(rig, "antennaWhip", push, 9, 0.35, dt)
	local whipTip = spring(rig, "antennaTip", whip, 7, 0.4, dt)
	for _, s in { -1, 1 } do
		local tag = if s < 0 then "L" else "R"
		local drift = 0.05 * math.sin(t * 2.7 + s * 0.8)
		drive(rig, "antenna_" .. tag, Vector3.zero, whip + drift, 0, s * 0.3 * math.abs(whip))
		drive(
			rig,
			"antenna_tip_" .. tag,
			Vector3.zero,
			whipTip * 1.5 + 0.09 * math.sin(t * 2.7 + s * 0.8 - 0.9)
		)
	end
end

local function stepBase(rig: Rig, dt: number)
	local t = rig.clock
	local hold = rig.model:GetAttribute("ReviewHold") == true
	local move, since = pickMove(rig, BASE_MOVES, BASE_ORDER)
	if hold then
		move, since = "", 0
	end
	local bounce = if hold then 0 else math.abs(math.sin(t * 3.0))
	local sway = if hold then 0 else math.sin(t * 1.5)
	local rise, forward, side = 0.07 * bounce, 0, 0.03 * sway
	local flip, spin, tilt = 0, 0, 0
	local crouch = if hold then 0 else 0.35 * (1 - bounce) ^ 3
	local chin, lean, wag = 0.05, 0, 0
	local look = 1
	if move == "backflip" then
		if since < 0.24 then
			-- Wind-up: sinks, tips slightly forward and looks at you.
			local c = ease(since / 0.24)
			crouch, rise, flip = 1.2 * c, 0, 0.14 * c
		elseif since < 0.8 then
			-- Up and over, slowing at the top so the turn hangs for a moment.
			local f = (since - 0.24) / 0.56
			local turn = f - 0.1 * math.sin(f * TAU)
			rise = 1.7 * 4 * f * (1 - f)
			forward = -0.2 * arc(f)
			flip = 0.14 + (-TAU - 0.3) * ease(turn)
			crouch = 0
			look = 1 - arc(f)
		else
			-- Lands past upright, squashes and rocks back with a chin-up grin.
			local l = (since - 0.8) / 0.2
			flip = -TAU - 0.16 * (1 - ease(l))
			crouch = 1.3 * arc(l)
			chin = 0.05 + 0.2 * arc(l)
			rise = 0
		end
	elseif move == "spin" then
		if since < 0.25 then
			local c = ease(since / 0.25)
			spin, crouch, rise = -0.6 * c, 0.8 * c, 0
		else
			local f = (since - 0.25) / 0.75
			spin = -0.6 + (TAU + 0.6) * ease(f)
			rise = 0.45 * arc(f * 1.15)
			crouch = 0.5 * arc(math.max(f - 0.8, 0) / 0.2)
			look = 0.3
		end
	elseif move == "lean" then
		-- Leans right in at you, chin up, and holds the grin.
		local e = ease(since / 0.2) * ease((1 - since) / 0.2)
		lean, forward, chin, rise = 0.22 * e, 0.2 * e, 0.05 + 0.1 * e, rise * (1 - e)
	elseif move == "taunt" then
		local e = ease(since / 0.15) * ease((1 - since) / 0.15)
		wag = 0.3 * e * math.sin(since * math.pi * 6)
		tilt = 0.1 * e * math.sin(since * math.pi * 6)
		chin = 0.05 + 0.14 * e
	elseif move == "leap" then
		if since < 0.28 then
			crouch, rise = 1.0 * ease(since / 0.28), 0
		else
			local f = (since - 0.28) / 0.72
			rise = 1.0 * 4 * f * (1 - f)
			crouch = 0.9 * arc(math.max(f - 0.82, 0) / 0.18)
			tilt = 0.16 * arc(f) * (if math.sin(rig.moveAt * 7) > 0 then 1 else -1)
		end
	end
	if move ~= "backflip" then
		wrapTurn(rig, "flip")
	end
	if move ~= "spin" then
		wrapTurn(rig, "spin")
	end
	local cRise = spring(rig, "rise", rise, 20, 0.8, dt)
	local cForward = spring(rig, "forward", forward, 12, 0.8, dt)
	local cSide = spring(rig, "side", side, 10, 0.9, dt)
	local cFlip = spring(rig, "flip", flip, 26, 0.9, dt)
	local cSpin = spring(rig, "spin", spin, 26, 0.85, dt)
	local cTilt = spring(rig, "tilt", tilt, 12, 0.7, dt)
	local cCrouch = spring(rig, "crouch", crouch, 18, 0.6, dt)
	local cLean = spring(rig, "lean", lean, 10, 0.75, dt)
	-- How fast the body is turning, for the arch and the lag below. A wrapped turn is not a real change in speed.
	local function rate(now: number, last: number): number
		local change = (now - last + math.pi) % TAU - math.pi
		return math.clamp(change / math.max(dt, 1e-3), -14, 14)
	end
	local flipSpeed, spinSpeed = rate(cFlip, rig.lastFlip), rate(cSpin, rig.lastSpin)
	rig.lastFlip, rig.lastSpin = cFlip, cSpin
	local arch = spring(rig, "arch", flipSpeed * 0.035, 14, 0.7, dt)
	local twist = spring(rig, "twist", spinSpeed * 0.04, 14, 0.7, dt)
	-- The base never goes through the floor: lifted by however far the turn swings it down.
	local swing = math.abs(math.sin(cFlip)) * 0.7
		+ math.max(-math.cos(cFlip), 0) * 1.6
		+ math.abs(math.sin(cTilt)) * 0.7
	local height = math.max(cRise, swing, 0)
	for _, item in (rig.bones.root or {}) :: { Item } do
		local c = toBone(item, Vector3.new(0, BASE_CENTRE, 0)) * rig.scale
		item.bone.Transform = CFrame.new(
			toBone(item, Vector3.new(cSide, height, cForward)) * rig.scale
		) * CFrame.new(c) * CFrame.fromAxisAngle(item.y, cSpin) * CFrame.fromAxisAngle(
			item.x,
			cFlip
		) * CFrame.fromAxisAngle(item.z, cTilt) * CFrame.new(-c)
	end
	-- Crouching squashes the upper body into the base, which stays on the ground. The body arches into a flip and
	-- twists behind a spin, with the head a beat further behind.
	drive(
		rig,
		"body_lower",
		Vector3.zero,
		cLean * 0.25 + arch * 0.4,
		twist * 0.3,
		0.04 * cSide / 0.03
	)
	drive(
		rig,
		"body_upper",
		Vector3.new(0, -0.1 * cCrouch, 0.03 * cCrouch),
		cLean * 0.5 + arch * 0.7,
		twist * 0.5,
		-0.05 * cSide / 0.03
	)
	local angry = stepFace(rig, dt, (workspace.CurrentCamera :: Camera).CFrame.Position, look)
	local cChin = spring(rig, "chin", chin + 0.08 * cCrouch - 0.12 * angry, 12, 0.6, dt)
	local cWag = spring(rig, "wag", wag, 16, 0.7, dt)
	for _, item in (rig.bones.head or {}) :: { Item } do
		item.bone.Transform = CFrame.new(
			toBone(item, Vector3.new(0, -0.07 * cCrouch, 0)) * rig.scale
		) * CFrame.fromAxisAngle(item.y, rig.lookYaw + cWag + twist) * CFrame.fromAxisAngle(
			item.x,
			-rig.lookPitch - cChin + cLean * 0.3 + arch
		) * CFrame.fromAxisAngle(
			item.z,
			cWag * 0.4 + (if hold then 0 else 0.05 * math.sin(t * 0.9))
		)
	end
	antennae(rig, dt, 0.5 * cCrouch - 0.3 * cRise + flipSpeed * 0.07 + math.abs(spinSpeed) * 0.03)
end

local function stepDragon(rig: Rig, dt: number)
	local t = rig.clock
	if rig.flight and rig.model:GetAttribute("Landed") then
		stepFireGlow(rig, t)
		return
	end
	local hold = rig.model:GetAttribute("ReviewHold") == true
	local move, since = pickMove(rig, DRAGON_MOVES, DRAGON_ORDER)
	if hold or rig.flight then
		move, since = "", 0
	end
	local beatRate, beatSize, fold = 5.5, 0.42, 0
	local rise, forward, side = 0.08 * math.sin(t * 2.6), 0, 0.05 * math.sin(t * 1.3)
	local bank, pitch, roll, snap = 0.08 * math.sin(t * 1.3), 0, 0, 0
	local look = 1
	if move == "roll" then
		if since < 0.2 then
			-- Wind-up: banks the other way and draws the wings in.
			local c = ease(since / 0.2)
			roll, fold = -0.5 * c, 0.3 * c
		else
			local f = (since - 0.2) / 0.8
			roll = -0.5 + (TAU + 0.5) * ease(f)
			fold = 0.3 + 0.2 * arc(f)
			look = 0.3
			forward = 0.25 * arc(f)
		end
		beatSize = 0.15
	elseif move == "swoop" then
		local e = arc(since)
		rise = -0.35 * math.sin(since * TAU)
		forward = 0.5 * e
		bank = 0.5 * math.sin(since * TAU)
		pitch = 0.3 * math.cos(since * TAU) * e
		beatRate = 8
	elseif move == "snap" then
		local e = arc(since)
		forward = 0.35 * e
		snap = 0.35 * e * math.sin(since * math.pi * 5)
		beatRate = 8
	end
	if hold then
		rise, side, bank, beatSize = 0, 0, 0, 0
	elseif rig.flight then
		rise, side, bank = 0, 0, 0
	end
	if move ~= "roll" then
		wrapTurn(rig, "roll")
	end
	-- Wing beats keep their own phase, so changing speed never jumps.
	rig.wingClock += spring(rig, "beatRate", beatRate, 4, 1, dt) * dt
	local beat = math.sin(rig.wingClock)
	local size = spring(rig, "beatSize", beatSize, 6, 1, dt)
	local cFold = spring(rig, "fold", fold, 10, 0.9, dt)
	local cRise = spring(rig, "rise", rise, 16, 0.8, dt)
	local cForward = spring(rig, "forward", forward, 9, 0.85, dt)
	local cSide = spring(rig, "side", side, 8, 0.9, dt)
	local cBank = spring(rig, "bank", bank, 9, 0.8, dt)
	local cPitch = spring(rig, "pitch", pitch, 9, 0.8, dt)
	local cRoll = spring(rig, "roll", roll, 24, 0.9, dt)
	local rollSpeed =
		math.clamp(((cRoll - rig.lastRoll + math.pi) % TAU - math.pi) / math.max(dt, 1e-3), -14, 14)
	rig.lastRoll = cRoll
	drive(
		rig,
		"root",
		Vector3.new(cSide, cRise - 0.025 * beat * size / 0.42, cForward),
		cPitch,
		0,
		cBank + cRoll
	)
	for _, s in { -1, 1 } do
		local tag = if s < 0 then "L" else "R"
		drive(rig, "wing_" .. tag, Vector3.zero, 0, 0, -s * (size * beat - cFold))
		drive(
			rig,
			"wing_tip_" .. tag,
			Vector3.zero,
			0,
			0,
			-s * (size * 0.9 * math.sin(rig.wingClock - 0.9) - cFold)
		)
	end
	-- The tail whips with the turns, each joint a beat behind the last.
	local push = -0.45 * cBank - 0.05 * rollSpeed
	local wave = if hold then 0 else 1
	drive(rig, "tail_1", Vector3.zero, 0, wave * 0.16 * math.sin(t * 3.0) + push)
	drive(
		rig,
		"tail_2",
		Vector3.zero,
		0,
		wave * 0.24 * math.sin(t * 3.0 - 0.8) + spring(rig, "tail2", push, 8, 0.6, dt)
	)
	drive(
		rig,
		"tail_3",
		Vector3.zero,
		0,
		wave * 0.32 * math.sin(t * 3.0 - 1.6) + spring(rig, "tail3", push, 6, 0.55, dt)
	)
	-- The flame never holds still: a wave runs down its chain, growing toward the point, while the swell rolls round it.
	for i = 1, 3 do
		drive(
			rig,
			`flame_{i}`,
			Vector3.new(0, 0, -0.025 * math.sin(t * 7.7 - i)),
			(0.08 + 0.06 * i) * math.sin(t * 4.9 - i * 1.3 + 1)
				+ 0.04 * math.sin(t * 12.3 - i * 2.3),
			(0.10 + 0.07 * i) * math.sin(t * 6.3 - i * 1.1) + 0.05 * math.sin(t * 10.7 - i * 1.9)
		)
	end
	for _, swell in FLAME_SIDES do
		drive(
			rig,
			swell.name,
			swell.way
				* (
					0.055 * math.sin(t * 6.3 - swell.phase)
					+ 0.02 * math.sin(t * 10.3 + swell.phase * 2)
				)
		)
	end
	local angry = stepFace(
		rig,
		dt,
		(workspace.CurrentCamera :: Camera).CFrame.Position,
		if rig.flight then 0 else look
	)
	local cSnap = spring(rig, "snap", snap, 18, 0.65, dt)
	local headLag = spring(rig, "headLag", rollSpeed * 0.03, 12, 0.7, dt)
	for _, item in (rig.bones.head or {}) :: { Item } do
		item.bone.Transform = CFrame.fromAxisAngle(item.y, rig.lookYaw + cSnap)
			* CFrame.fromAxisAngle(item.x, -rig.lookPitch - cPitch * 0.6 + 0.08 * angry)
			* CFrame.fromAxisAngle(item.z, -cBank * 0.5 - headLag)
	end
	antennae(rig, dt, -0.12 * beat * size / 0.42 + 0.5 * cForward + math.abs(rollSpeed) * 0.04)
	-- Last, so it sees every bone where this frame put it.
	stepFireGlow(rig, t)
end

RunService.RenderStepped:Connect(function(dt: number)
	if not workspace.CurrentCamera then
		return
	end
	dt = math.min(dt, 1 / 15)
	for model, rig in rigs do
		if not model:IsDescendantOf(workspace) then
			rigs[model] = nil
			continue
		end
		rig.clock += dt
		if model:GetAttribute("GroveResident") == true then
			if
				model:GetAttribute("GroveReady") ~= true
				or (
						model:GetPivot().Position
						- (workspace.CurrentCamera :: Camera).CFrame.Position
					).Magnitude
					> 24
			then
				continue
			end
			local pivot = model:GetPivot()
			rig.sideways, rig.up, rig.front = pivot.RightVector, pivot.UpVector, pivot.LookVector
			local character = Players.LocalPlayer.Character
			local head = character and character:FindFirstChild("Head")
			local target = if head and head:IsA("BasePart")
				then head.Position
				else (workspace.CurrentCamera :: Camera).CFrame.Position
			local look = (model:GetAttribute("GroveLook") or 0) :: number
			local press = (model:GetAttribute("GrovePress") or 0) :: number
			stepFace(rig, dt, target, look)
			local heads: { Item } = rig.bones.head or {}
			for _, item in heads do
				item.bone.Transform = CFrame.new(item.y * -press * 0.55 * rig.scale)
					* CFrame.fromAxisAngle(item.y, -rig.lookYaw)
					* CFrame.fromAxisAngle(item.x, rig.lookPitch)
			end
			antennae(rig, dt, press * 0.6)
			continue
		end
		if rig.dragon then
			stepDragon(rig, dt)
		else
			stepBase(rig, dt)
		end
	end
end)
