--!strict
-- Floppy's face on this client (Bone.Transform does not replicate): three expressions
-- cycling automatically with smooth transitions, plus blinks, wandering eyes and small
-- mouth movements. Runs on every Floppy in the workspace, including fired ones. Amounts are
-- authored at source size and scaled by eye spacing, like FloppyIdle.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local movement = Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("MovementSandbox")
local Inspect = (require :: any)(movement:WaitForChild("SlugInspect"))
local T = ((require :: any)(movement:WaitForChild("Tuning"))).values

local EYE_SPACING = 0.74
local HOLD = 3.5 -- seconds on each expression
local BLEND_RATE = 7 -- 1/s; how quickly a new expression eases in
local GAZE_RATE = 2.5 -- a lazy drift, not a dart
-- Eyes slide within the socket (they are too flat to rotate), easing back so they clear the lids.
local GAZE_SIDE, GAZE_UP, GAZE_BACK = 0.018, 0.008, 0.03
-- Closed, each rim lies along its lower lid. Upper rims sit at +0.03 (L) and -0.03 (R) and slope 0.24; lower rims sit at
-- -0.15 and slope -0.05 the other way. So each eye travels its own distance and turns by the difference in slope.
local CLOSED_DEPTH = { [1] = 0.172, [-1] = 0.112 }
local CLOSED_TURN = math.atan(0.29)
local FAR = 90 -- studs; no face work on a Floppy too far away to read

-- Lid amounts are relative to the tired resting lids in Tuning (faceLid).
-- His mouth already slants up on one side, so the corners move separately: the low side
-- does most of a smile, and the raised side must stay out of the eyelid.
type Expression = {
	low: number, -- low mouth corner up
	high: number, -- raised mouth corner up
	wide: number, -- mouth corners outward
	jaw: number, -- lower lip down
	lid: number, -- upper lids down; negative opens them
}
local EXPRESSIONS: { Expression } = {
	{ low = 0, high = 0, wide = 0, jaw = 0.012, lid = 0 }, -- drowsy
	{ low = 0.09, high = 0.03, wide = 0.03, jaw = 0.02, lid = -0.025 }, -- smiling
	{ low = 0.015, high = -0.06, wide = -0.045, jaw = 0.085, lid = -0.09 }, -- surprised
}

type FaceBone = { bone: Bone, side: Vector3, up: Vector3, front: Vector3, sign: number }
type Face = {
	model: Model,
	head: Bone,
	scale: number,
	gaze: { FaceBone },
	lids: { FaceBone },
	left: { FaceBone },
	right: { FaceBone },
	lip: { FaceBone },
	clock: number,
	low: number,
	high: number,
	wide: number,
	jaw: number,
	lid: number,
	squint: number,
	lookX: number,
	lookY: number,
	lookXTarget: number,
	lookYTarget: number,
	nextLook: number,
	nextBlink: number,
	blinkAt: number,
}
local random = Random.new()
local faces: { [Model]: Face } = {}

local function setup(model: Model)
	if faces[model] or not model.Parent then
		return
	end
	local eyeL = model:FindFirstChild("eye_L", true)
	local eyeR = model:FindFirstChild("eye_R", true)
	local root = model:FindFirstChild("root", true)
	local head = model:FindFirstChild("head", true)
	if
		not (
			eyeL
			and eyeR
			and root
			and head
			and eyeL:IsA("Bone")
			and eyeR:IsA("Bone")
			and root:IsA("Bone")
			and head:IsA("Bone")
			and model:FindFirstChild("gaze_L", true)
		)
	then
		return
	end
	local sideways = (eyeR.WorldPosition - eyeL.WorldPosition).Unit
	local rough = (head.WorldPosition - root.WorldPosition).Unit
	local up = (rough - sideways * rough:Dot(sideways)).Unit
	local front = sideways:Cross(up)
	local face: Face = {
		model = model,
		head = head,
		scale = (eyeR.WorldPosition - eyeL.WorldPosition).Magnitude / EYE_SPACING,
		gaze = {},
		lids = {},
		left = {},
		right = {},
		lip = {},
		clock = random:NextNumber(0, HOLD * #EXPRESSIONS), -- so several Floppies don't move in unison
		low = 0,
		high = 0,
		wide = 0,
		jaw = 0,
		lid = 0,
		squint = 0,
		lookX = 0,
		lookY = 0,
		lookXTarget = 0,
		lookYTarget = 0,
		nextLook = 0,
		nextBlink = random:NextNumber(1, 3),
		blinkAt = -math.huge,
	}
	local groups: { [string]: { FaceBone } } = {
		gaze_L = face.gaze,
		gaze_R = face.gaze,
		lid_L = face.lids,
		lid_R = face.lids,
		mouth_L = face.left,
		mouth_R = face.right,
		mouth_low = face.lip,
	}
	-- Roblox can create one skeleton per skinned mesh, each with its own axes: drive every copy.
	for _, item in model:GetDescendants() do
		if item:IsA("Bone") then
			local group = groups[item.Name]
			if group then
				local frame = item.WorldCFrame
				table.insert(group, {
					bone = item,
					side = frame:VectorToObjectSpace(sideways),
					up = frame:VectorToObjectSpace(up),
					front = frame:VectorToObjectSpace(front),
					sign = if string.sub(item.Name, -2) == "_L" then 1 else -1,
				})
			end
		end
	end
	faces[model] = face
end

local function consider(instance: Instance)
	if instance:IsA("Model") and (instance.Name == "Floppy" or instance.Name == "FloppyFlight") then
		task.defer(setup, instance)
	end
end
for _, item in workspace:GetDescendants() do
	consider(item)
end
workspace.DescendantAdded:Connect(consider)
-- Inventory and slot icons live in viewports, outside the workspace.
for _, icon in CollectionService:GetTagged("SlugIcon") do
	task.defer(setup, icon :: Model)
end
CollectionService:GetInstanceAddedSignal("SlugIcon"):Connect(function(icon: Instance)
	task.defer(setup, icon :: Model)
end)

local function step(face: Face, dt: number, camera: Vector3)
	face.clock += dt
	local clock = face.clock
	-- An icon chooses its own expression through this attribute.
	local tool = face.model:FindFirstAncestorOfClass("Tool")
	local character = tool and tool.Parent
	local inspectTime = if character and character:IsA("Model")
		then Inspect.elapsed(character)
		else nil
	local inspecting = inspectTime ~= nil
	local chosen = if inspecting then 2 else face.model:GetAttribute("FaceExpression")
	local want = EXPRESSIONS[if typeof(chosen) == "number"
		then chosen
		else math.floor(clock / HOLD) % #EXPRESSIONS + 1]
	if inspectTime then
		local squeeze = Inspect.compression(inspectTime)
		local spring = Inspect.hop(inspectTime)
		-- Sleepy recognition, a deliberate squint before the jump, then a
		-- brighter cheeky smile on takeoff. No random mouth chatter in this act.
		local awake = Inspect.stand(inspectTime)
		want = {
			low = 0.09 * awake,
			high = 0.035 * awake,
			wide = 0.03 * awake,
			jaw = 0.015 + 0.035 * spring,
			lid = -0.035 * awake + 0.07 * squeeze - 0.035 * spring,
		}
	end
	local blend = 1 - math.exp(-BLEND_RATE * dt)
	face.low += (want.low - face.low) * blend
	face.high += (want.high - face.high) * blend
	face.wide += (want.wide - face.wide) * blend
	face.jaw += (want.jaw - face.jaw) * blend
	face.lid += (want.lid - face.lid) * blend
	-- An icon can also narrow its eyes and choose where to look.
	local squint = face.model:GetAttribute("FaceSquint")
	face.squint += ((if typeof(squint) == "number" then squint else 0) - face.squint) * blend
	local icon = CollectionService:HasTag(face.model, "SlugIcon")
	if not icon and (face.head.WorldPosition - camera).Magnitude > FAR then
		return
	end
	-- Eyes dart to a new spot, then rest there.
	local chosenLook = if inspectTime
		then Vector2.new(
			-0.3 * Inspect.wiggle(inspectTime),
			0.65 * Inspect.stand(inspectTime) - 0.6 * Inspect.compression(inspectTime)
		)
		else face.model:GetAttribute("FaceLook")
	if typeof(chosenLook) == "Vector2" then
		face.lookXTarget, face.lookYTarget = chosenLook.X, chosenLook.Y
		face.nextLook = clock + random:NextNumber(0.5, 2)
	elseif clock >= face.nextLook then
		face.nextLook = clock + random:NextNumber(2.5, 6)
		face.lookXTarget = random:NextNumber(-1, 1)
		face.lookYTarget = random:NextNumber(-1, 0.3) -- mostly gazing low
	end
	local dart = 1 - math.exp(-GAZE_RATE * dt)
	face.lookX += (face.lookXTarget - face.lookX) * dart
	face.lookY += (face.lookYTarget - face.lookY) * dart
	-- Heavy, slow blinks: the lids sink, rest a moment and drag back up.
	if clock >= face.nextBlink then
		face.blinkAt = clock
		-- Now and then a second blink follows straight after, so the rhythm isn't mechanical.
		face.nextBlink = clock
			+ if random:NextNumber() < 0.2 then T.faceBlinkTime * 1.15 else random:NextNumber(3, 7)
	end
	local blink = 0
	local since = (clock - face.blinkAt) / T.faceBlinkTime
	if since < 1 then
		-- Sinks over 40%, rests briefly and lifts more slowly; a cosine has no corners, so the lid never jerks.
		local amount = if since < 0.4
			then since / 0.4
			elseif since < 0.5 then 1
			else 1 - (since - 0.5) / 0.5
		blink = 0.5 - 0.5 * math.cos(amount * math.pi)
	end
	local chosenBlink = face.model:GetAttribute("FaceBlink")
	if typeof(chosenBlink) == "number" then
		blink = chosenBlink
	end
	if inspecting then
		blink = 0
	end
	-- A small, slow mouthing so the face is never fully still.
	local mouthing = 0.5 + 0.5 * math.sin(clock * 2.3) * math.sin(clock * 5.7)
	local jaw = face.jaw + (if inspecting then 0 else 0.014 * mouthing)
	local lift = if inspecting then 0 else 0.006 * math.sin(clock * 1.7)
	local open = face.lid + face.squint
	local rest = T.faceLid + open
	-- The rims slope down toward the nose, which reads as anger: turn them so the outer corners
	-- droop instead. Opening wide (surprise) relaxes this.
	local droop = math.rad(T.faceTilt) * math.clamp(1 + face.lid / 0.09, 0, 1)
	droop += (CLOSED_TURN - droop) * blink
	local s = face.scale
	for _, item in face.gaze do
		item.bone.Transform = CFrame.new(
			(
				item.side * face.lookX * GAZE_SIDE
				+ item.up * face.lookY * GAZE_UP
				- item.front * GAZE_BACK * math.max(math.abs(face.lookX), math.abs(face.lookY))
			) * s
		)
	end
	for _, item in face.lids do
		local lid = rest + (CLOSED_DEPTH[item.sign] - rest) * blink
		item.bone.Transform = CFrame.new(
			(item.up * -lid + item.front * math.max(lid, 0) * 0.15) * s
		) * CFrame.fromAxisAngle(item.front, droop * item.sign)
	end
	for _, item in face.left do
		item.bone.Transform = CFrame.new((item.up * (face.low + lift) - item.side * face.wide) * s)
	end
	for _, item in face.right do
		item.bone.Transform = CFrame.new((item.up * (face.high + lift) + item.side * face.wide) * s)
	end
	for _, item in face.lip do
		item.bone.Transform = CFrame.new(item.up * -jaw * s)
	end
end

RunService:BindToRenderStep(
	"SlugshotFloppyFace",
	Enum.RenderPriority.Character.Value + 3,
	function(dt: number)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local eye = camera.CFrame.Position
		for model, face in faces do
			if model:IsDescendantOf(workspace) or CollectionService:HasTag(model, "SlugIcon") then
				step(face, dt, eye)
			else
				faces[model] = nil
			end
		end
	end
)
