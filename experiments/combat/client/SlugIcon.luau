--!strict
-- A real slug model in a viewport, for the slot bar and inventory. The owner (2026-11-02) wants it
-- transitional, alive, emotional and smooth, like something gelatinous, not "choppy animations cutting
-- to each other". So nothing here plays a clip: a performance only moves targets, and springs carry
-- the body to them, which means one move always flows out of whatever the last one left behind.
-- FloppyFace handles the face and blinks, FloppyIdle the eye rings; this owns the body.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Combat = require(ReplicatedStorage:WaitForChild("Combat"))
local Visuals = require(script.Parent.SlugVisuals)

local SlugIcon = {}

type Spring = { x: number, v: number, target: number, freq: number, damp: number }
type BoneCopy = { bone: Bone, frame: CFrame }
type Rig = { [string]: { BoneCopy } }
type Move = (Icon, number) -> boolean

export type Icon = {
	frame: ViewportFrame,
	model: Model?,
	rig: Rig,
	base: CFrame,
	foot: Vector3,
	height: number,
	unit: number, -- one source unit of the rig, in studs
	animated: boolean,
	active: boolean,
	clock: number,
	leftover: number,
	move: Move?,
	moveTime: number,
	nextMove: number,
	lastMove: string,
	flying: boolean,
	hopStage: string, -- crouch, air, then landed
	y: Spring, -- height above the floor, in slug heights
	yVelocity: number,
	squash: Spring, -- 1 is flattened, -1 stretched
	sway: Spring, -- body leaning side to side
	lag: Spring, -- the head following the sway a moment later
	pitch: Spring, -- 1 looks up, -1 looks down
	flop: Spring, -- antennae, thrown around by the body
	away: boolean,
}

local DEFAULT_FLOOR_GAP = 0.04
local EYE_SPACING = 0.74 -- at source size
local TIME_STEP = 1 / 120 -- springs step at a fixed rate, so motion is the same at any frame rate
local TAU = 2 * math.pi

-- Expressions in FloppyFace.
local DROWSY, SMILING = 1, 2

-- How far the springs bend the rig, in source units and radians.
-- The torso takes the squash, so the face keeps its shape.
local SQUASH_UPPER, SQUASH_HEAD, SQUASH_FLANK = 0.38, 0.03, 0.28
local STRETCH_FLANK_SHARE = 0.6 -- a stretch pulls the flanks in less than a squash pushes them out
local SWAY_ANGLE, SWAY_UPPER, LAG_ANGLE = math.rad(11), 0.09, 0.3
-- Looking up bends mostly from the waist. Tilting the head alone shears the cheek, which is part
-- head-weighted, against the fully head-bound lids and smears his dark under-eyes into streaks
-- (owner, 2026-11-03 in the lobby; 2026-11-07 in the gun and the HUD). Was head 22, upper 6.
local PITCH_HEAD, PITCH_UPPER = math.rad(6), math.rad(14)
local FLOP_ANGLE = 0.5

-- Performances.
local FIRST_MOVE = 2.5
local MOVE_GAP_LOW, MOVE_GAP_HIGH = 5, 9
local BREATH_PERIOD, BREATH_AMOUNT = 3.6, 0.05
local HOP_HEIGHT = 0.38 -- slug heights
local HOP_GRAVITY = 10 -- slug heights/s^2: a touch floaty, like something soft
local HOP_SPEED = math.sqrt(2 * HOP_GRAVITY * HOP_HEIGHT)
local GONE = -1.2 -- below the frame while the slug is out of the gun

local random = Random.new()
local icons: { Icon } = {}

local function spring(freq: number, damp: number): Spring
	return { x = 0, v = 0, target = 0, freq = freq, damp = damp }
end

local function stepSpring(s: Spring, dt: number)
	local w = TAU * s.freq
	s.v += (w * w * (s.target - s.x) - 2 * s.damp * w * s.v) * dt
	s.x += s.v * dt
end

local function ease(share: number): number
	local t = math.clamp(share, 0, 1)
	return t * t * (3 - 2 * t)
end

local function setFace(icon: Icon, expression: number?, look: Vector2?, squint: number?)
	local model = icon.model
	if not model then
		return
	end
	if expression and model:GetAttribute("FaceExpression") ~= expression then
		model:SetAttribute("FaceExpression", expression)
	end
	if model:GetAttribute("FaceLook") ~= look then
		model:SetAttribute("FaceLook", look)
	end
	if model:GetAttribute("FaceSquint") ~= squint then
		model:SetAttribute("FaceSquint", squint)
	end
end

-- Moves return true when they have finished. Each only sets targets and gives kicks.

-- A side-to-side shimmy that swells, peaks and settles, the head following behind.
local WIGGLE_TIME, WIGGLE_RATE = 2.3, 1.7
local function wiggle(icon: Icon, t: number): boolean
	local swell = ease(t / 0.45) * (1 - ease((t - WIGGLE_TIME + 0.7) / 0.7))
	local beat = math.sin(TAU * WIGGLE_RATE * t)
	icon.sway.target = swell * beat
	icon.squash.target = 0.22 * swell * math.abs(math.cos(TAU * WIGGLE_RATE * t))
	icon.pitch.target = 0.15 * swell
	setFace(icon, SMILING, Vector2.new(beat * swell, 0.2), nil)
	return t >= WIGGLE_TIME
end

-- Gathers itself, springs up long and thin, lands flat with a big jelly wobble, then looks up and
-- smiles before sinking back to drowsy.
local CROUCH, LOOK_UP_DELAY, LOOK_UP_HOLD = 0.26, 0.5, 1.5
local function hop(icon: Icon, t: number): boolean
	if icon.hopStage == "crouch" and t < CROUCH then
		icon.squash.target = 0.8
		icon.pitch.target = -0.35
		setFace(icon, DROWSY, Vector2.new(0, -1), 0.03)
		return false
	end
	if icon.hopStage == "crouch" then
		icon.hopStage = "air"
		icon.flying = true
		icon.yVelocity = HOP_SPEED
		icon.squash.target = -0.6
		icon.squash.v -= 30
		icon.flop.v += 9
		icon.pitch.target = 0.25
		setFace(icon, SMILING, Vector2.new(0, 0.6), nil)
		return false
	end
	if icon.flying then
		-- The stretch relaxes at the top of the hop and returns as it falls.
		icon.squash.target = -0.6 * math.abs(icon.yVelocity / HOP_SPEED)
		return false
	end
	-- After the landing: the time restarts from it.
	if t < LOOK_UP_DELAY then
		icon.pitch.target = -0.15
		setFace(icon, DROWSY, Vector2.new(0, -0.4), 0.05)
	elseif t < LOOK_UP_DELAY + LOOK_UP_HOLD then
		icon.pitch.target = 1
		setFace(icon, SMILING, Vector2.new(0, 1), nil)
	else
		icon.pitch.target = 0
		setFace(icon, DROWSY, nil, nil)
		return t >= LOOK_UP_DELAY + LOOK_UP_HOLD + 0.8
	end
	return false
end

-- Back from a shot: rises out of the floor (the burrow's other end), stretched, overshoots, shakes
-- itself off, and gives a little smile.
local EMERGE_SHAKE, EMERGE_TIME = 0.4, 1.9
local function emerge(icon: Icon, t: number): boolean
	icon.y.target = 0
	icon.squash.target = if t < 0.3 then -0.5 else 0
	local shake = ease((t - EMERGE_SHAKE) / 0.1) * (1 - ease((t - EMERGE_SHAKE - 0.35) / 0.6))
	icon.sway.target = 0.55 * shake * math.sin(TAU * 3.6 * t)
	setFace(icon, if t > 0.55 then SMILING else DROWSY, Vector2.new(0, 0.5), nil)
	if t >= EMERGE_TIME then
		setFace(icon, DROWSY, nil, nil)
		return true
	end
	return false
end

local function start(icon: Icon, move: Move?, name: string)
	icon.move = move
	icon.moveTime = 0
	icon.lastMove = name
	icon.hopStage = "crouch"
end

local function chooseMove(icon: Icon)
	-- Mostly takes turns, so it does not feel like a timer running through a list.
	local useHop = if icon.lastMove == "hop"
		then random:NextNumber() < 0.2
		else random:NextNumber() < 0.7
	if useHop then
		start(icon, hop, "hop")
	else
		start(icon, wiggle, "wiggle")
	end
end

local function step(icon: Icon, dt: number)
	icon.clock += dt
	-- Always breathing, whatever else is happening.
	local breath = BREATH_AMOUNT * math.sin(TAU * icon.clock / BREATH_PERIOD)
	if icon.away then
		icon.y.target = GONE
	elseif icon.move then
		icon.moveTime += dt
		if (icon.move :: Move)(icon, icon.moveTime) then
			icon.move = nil
			icon.nextMove = icon.clock + random:NextNumber(MOVE_GAP_LOW, MOVE_GAP_HIGH)
		end
	else
		icon.sway.target = 0.06 * math.sin(TAU * icon.clock / 7.3)
		icon.squash.target = breath
		icon.pitch.target = 0.08 * math.sin(TAU * icon.clock / 11)
		if icon.clock >= icon.nextMove then
			chooseMove(icon)
		end
	end
	local steps = dt + icon.leftover
	while steps >= TIME_STEP do
		steps -= TIME_STEP
		if icon.flying then
			icon.yVelocity -= HOP_GRAVITY * TIME_STEP
			icon.y.x += icon.yVelocity * TIME_STEP
			if icon.y.x <= 0 then
				-- The landing's strength comes from the fall: flat, wobbling, antennae thrown down.
				icon.flying = false
				icon.hopStage = "landed"
				icon.y.x, icon.y.v = 0, 0
				icon.moveTime = 0
				icon.squash.target = 0
				icon.squash.v += 30
				icon.sway.v += if random:NextNumber() < 0.5 then -5 else 5
				icon.flop.v -= 14
			end
		else
			stepSpring(icon.y, TIME_STEP)
		end
		local before = icon.squash.v
		stepSpring(icon.squash, TIME_STEP)
		stepSpring(icon.sway, TIME_STEP)
		icon.lag.target = icon.sway.x
		stepSpring(icon.lag, TIME_STEP)
		stepSpring(icon.pitch, TIME_STEP)
		-- The antennae feel the body's jolts.
		icon.flop.v += (icon.squash.v - before) * 0.25
		stepSpring(icon.flop, TIME_STEP)
	end
	icon.leftover = steps
end

local function drive(rig: Rig, name: string, offset: Vector3, axis: Vector3?, angle: number?)
	local copies = rig[name]
	if not copies then
		return
	end
	for _, copy in copies do
		local frame = copy.frame
		local transform = CFrame.new(frame:VectorToObjectSpace(offset))
		if axis and angle then
			transform *= CFrame.fromAxisAngle(frame:VectorToObjectSpace(axis), angle)
		end
		copy.bone.Transform = transform
	end
end

-- Puts the rig where the springs are. Model space: +X sideways, +Y up, +Z toward the face.
local function pose(icon: Icon)
	local model = icon.model
	if not model then
		return
	end
	local rig, unit = icon.rig, icon.unit
	local squash, sway, lag, pitch = icon.squash.x, icon.sway.x, icon.lag.x, icon.pitch.x
	local flank = (if squash > 0 then squash else squash * STRETCH_FLANK_SHARE)
		* SQUASH_FLANK
		* unit
	drive(rig, "jelly_L", Vector3.new(-flank, 0, 0))
	drive(rig, "jelly_R", Vector3.new(flank, 0, 0))
	drive(rig, "jelly_F", Vector3.new(0, 0, flank))
	drive(rig, "jelly_B", Vector3.new(0, 0, -flank))
	drive(
		rig,
		"body_upper",
		Vector3.new(sway * SWAY_UPPER * unit, -squash * SQUASH_UPPER * unit, 0),
		Vector3.xAxis,
		-pitch * PITCH_UPPER
	)
	-- Rotating about +X by a positive angle tips the top toward the face, so looking up is negative.
	local headTilt = CFrame.fromAxisAngle(Vector3.zAxis, (lag - sway) * LAG_ANGLE)
		* CFrame.fromAxisAngle(Vector3.xAxis, -pitch * PITCH_HEAD)
	local axis, angle = headTilt:ToAxisAngle()
	drive(rig, "head", Vector3.new(0, -squash * SQUASH_HEAD * unit, 0), axis, angle)
	drive(rig, "antenna_L", Vector3.zero, Vector3.zAxis, icon.flop.x * FLOP_ANGLE)
	drive(rig, "antenna_R", Vector3.zero, Vector3.zAxis, -icon.flop.x * FLOP_ANGLE)
	local swing = CFrame.new(icon.foot)
		* CFrame.fromAxisAngle(Vector3.zAxis, -sway * SWAY_ANGLE)
		* CFrame.new(-icon.foot)
	model:PivotTo(CFrame.new(0, icon.y.x * icon.height, 0) * swing * icon.base)
end

local function place(icon: Icon, slugId: string, fill: number, gap: number)
	local model = Visuals.iconModel(slugId)
	local world = Instance.new("WorldModel")
	model.Parent = world
	world.Parent = icon.frame
	local camera = Instance.new("Camera")
	camera.FieldOfView = 24
	camera.Parent = icon.frame
	icon.frame.CurrentCamera = camera
	-- The flight model's pivot is the slug's true centre, with +Y up and its face toward -Z, and its
	-- height is known. GetBoundingBox is unreliable on imported skinned models (blender-lessons.md).
	local height = Combat.Slugs[slugId].Size
	-- The slug stands near the bottom of its frame, as if on a floor: aim above its centre.
	local look = Vector3.yAxis * (0.5 - fill / 2 - gap) * height / fill
	model:PivotTo(CFrame.Angles(0, math.pi, 0))
	local distance = (height / 2) / math.tan(math.rad(camera.FieldOfView / 2)) / fill
	camera.CFrame = CFrame.lookAt(look + Vector3.new(0.22, 0.08, 1).Unit * distance, look)
	-- Roblox can create one skeleton per skinned mesh, so every copy of a bone is driven.
	local rig: Rig = {}
	for _, item in model:GetDescendants() do
		if item:IsA("Bone") then
			rig[item.Name] = rig[item.Name] or {}
			table.insert(rig[item.Name], { bone = item, frame = item.WorldCFrame })
		end
	end
	local eyeL, eyeR = rig.eye_L, rig.eye_R
	if eyeL and eyeR then
		local spacing = (eyeR[1].bone.WorldPosition - eyeL[1].bone.WorldPosition).Magnitude
		icon.unit = spacing / EYE_SPACING
	end
	icon.rig = rig
	icon.model = model
	icon.base = model:GetPivot()
	icon.foot = -Vector3.yAxis * height / 2
	icon.height = height
	icon.nextMove = icon.clock + FIRST_MOVE
	model:SetAttribute("FaceExpression", DROWSY)
	-- FloppyFace and FloppyIdle drive tagged icons; other slugs have neither his eyes nor his rings.
	if slugId == "Floppy" then
		CollectionService:AddTag(model, "SlugIcon")
	end
end

-- fill is the share of the slot's height the slug takes up, and floorGap the share left under it.
-- headroom makes the view taller than its slot (1.7 is 70% more), so a hop can leave the top.
function SlugIcon.mount(
	parent: GuiObject,
	slugId: string,
	fill: number,
	animated: boolean,
	floorGap: number?,
	headroom: number?
): Icon
	local room = headroom or 1
	local frame = Instance.new("ViewportFrame")
	frame.Name = "SlugIcon"
	frame.AnchorPoint = Vector2.new(0, 1)
	frame.Position = UDim2.fromScale(0, 1)
	frame.Size = UDim2.fromScale(1, room)
	frame.BackgroundTransparency = 1
	frame.Ambient = Color3.fromRGB(200, 200, 200)
	frame.LightColor = Color3.fromRGB(255, 250, 240)
	frame.LightDirection = Vector3.new(-0.3, -1, -0.7)
	frame.Parent = parent
	local icon: Icon = {
		frame = frame,
		model = nil,
		rig = {},
		base = CFrame.identity,
		foot = Vector3.zero,
		height = 1,
		unit = 1,
		animated = animated,
		active = true,
		clock = random:NextNumber(0, 5),
		leftover = 0,
		move = nil,
		moveTime = 0,
		nextMove = math.huge,
		lastMove = "",
		flying = false,
		hopStage = "crouch",
		y = spring(3, 0.5),
		yVelocity = 0,
		squash = spring(5, 0.26), -- underdamped: it keeps wobbling after a jolt, like jelly
		sway = spring(3.4, 0.42),
		lag = spring(2.6, 0.34),
		pitch = spring(1.8, 0.8),
		flop = spring(3.2, 0.2),
		away = false,
	}
	table.insert(icons, icon)
	task.spawn(function()
		if ReplicatedStorage:WaitForChild("CombatAssets", 30) then
			place(icon, slugId, fill / room, (floorGap or DEFAULT_FLOOR_GAP) / room)
		end
	end)
	return icon
end

-- The slug has been fired: it stretches and sinks out of sight until it is back.
function SlugIcon.leave(icon: Icon)
	icon.away = true
	icon.move = nil
	icon.flying = false
	icon.squash.target = -0.5
	icon.squash.v -= 12
	setFace(icon, DROWSY, nil, nil)
end

function SlugIcon.back(icon: Icon)
	icon.away = false
	icon.y.x, icon.y.v = GONE, 0
	icon.y.freq, icon.y.damp = 2.6, 0.42 -- rises with a soft overshoot
	start(icon, emerge, "emerge")
	icon.nextMove = math.huge
end

-- A little hop of joy, if it is not already doing something.
function SlugIcon.hop(icon: Icon)
	if not icon.move and not icon.away and icon.model then
		start(icon, hop, "hop")
	end
end

-- Off-screen icons skip their work.
function SlugIcon.setActive(icon: Icon, active: boolean)
	icon.active = active
end

RunService.RenderStepped:Connect(function(dt: number)
	-- A long frame must not fling the springs.
	local bounded = math.min(dt, 1 / 20)
	for _, icon in icons do
		if icon.model and icon.active and icon.animated then
			step(icon, bounded)
			pose(icon)
		end
	end
end)

return SlugIcon
