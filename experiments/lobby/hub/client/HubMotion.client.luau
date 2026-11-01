--!strict
-- All the hub's motion, on each client and look-only: nothing here moves a collider or a player.
-- Costs are kept low for phones: whole parts move in one BulkMoveTo at a capped rate, the storm and debris skip work when
-- the frame rate drops, and a bridge's bones only update when that bridge is in view.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ORBIT = 0.12
local BRIDGE_UNIT = 2.55 -- studs per bridge unit
local MOVE_RATE = 1 / 30
local IDLE_BRIDGE_RATE = 1 / 15
local ACTIVE_BRIDGE_RATE = 1 / 30
local BONE_COUNT = 17
local BONE_SPAN = 10.6 -- bridge units, centre to end bone
local FALL_RATE = 1.1
local FALL_WIDE = 1.5 -- studs
local FALL_BULGE = 1.1 -- studs
local FALLS_RATE = 1 / 20

type Mover = {
	part: BasePart,
	base: CFrame,
	spin: number,
	height: number,
	rate: number,
	phase: number,
}
local movers: { Mover } = {}
local moverParts: { BasePart } = {}
local moverFrames: { CFrame } = {}

local function addMover(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	table.insert(movers, {
		part = instance,
		base = instance.CFrame,
		spin = (instance:GetAttribute("Spin") or 0) :: number,
		height = (instance:GetAttribute("BobHeight") or 0) :: number,
		rate = (instance:GetAttribute("BobRate") or 0) :: number,
		phase = (instance:GetAttribute("Phase") or 0) :: number,
	})
	table.insert(moverParts, instance)
	table.insert(moverFrames, instance.CFrame)
end

CollectionService:GetInstanceAddedSignal("HubMover"):Connect(addMover)
for _, instance in CollectionService:GetTagged("HubMover") do
	addMover(instance)
end

local function moveParts(t: number)
	for index, mover in movers do
		local frame = mover.base
		if mover.spin ~= 0 then
			frame = CFrame.Angles(0, mover.spin * t, 0) * frame
		end
		if mover.height ~= 0 then
			frame += Vector3.new(0, mover.height * math.sin(t * mover.rate + mover.phase), 0)
		end
		moverFrames[index] = frame
	end
	workspace:BulkMoveTo(moverParts, moverFrames, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Bridges: each bone carries a slice of the deck. Very slight sway always; under anyone crossing, the deck dips and the
-- nearby boards bounce and rock (owner: noticeable, not too much).
type BoneRef = { bone: Bone, up: Vector3, side: Vector3, along: Vector3 }
type Bridge = {
	frame: CFrame,
	seed: number,
	bones: { { BoneRef } },
	nextUpdate: number,
	centre: Vector3,
}
local bridges: { Bridge } = {}

local function boneX(index: number): number
	return -BONE_SPAN + 2 * BONE_SPAN * index / (BONE_COUNT - 1)
end

local function addBridge(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	local frame = instance:GetAttribute("Frame") :: CFrame?
	if not frame then
		return
	end
	local sets: { { BoneRef } } = {}
	for index = 1, BONE_COUNT do
		sets[index] = {}
	end
	local function count(): number
		local found = 0
		for _, item in instance:GetDescendants() do
			if item:IsA("Bone") then
				found += 1
			end
		end
		return found
	end
	local waited = 0
	while count() < BONE_COUNT and waited < 60 do
		waited += task.wait(0.25)
	end
	local function collect()
		local found = 0
		for _, item in instance:GetDescendants() do
			if item:IsA("Bone") then
				local number = tonumber(string.match(item.Name, "^B(%d+)$"))
				if number then
					found += 1
					local world = item.WorldCFrame
					table.insert(sets[number + 1], {
						bone = item,
						up = world:VectorToObjectSpace(frame.UpVector),
						side = world:VectorToObjectSpace(frame.LookVector * -1),
						along = world:VectorToObjectSpace(frame.RightVector),
					})
				end
			end
		end
		return found
	end
	if collect() == 0 then
		warn("HubMotion: bridge has no bones", instance.Name)
		return
	end
	print(`HubMotion: {instance.Name} ready, {count()} bones`)
	table.insert(bridges, {
		frame = frame,
		seed = #bridges * 41,
		bones = sets,
		nextUpdate = 0,
		centre = frame.Position,
	})
end

CollectionService:GetInstanceAddedSignal("HubBridge"):Connect(function(instance: Instance)
	task.spawn(addBridge, instance)
end)
for _, instance in CollectionService:GetTagged("HubBridge") do
	task.spawn(addBridge, instance)
end

-- Where anyone is along this bridge, in bridge units; up to three, nearest the deck.
local riders: { number } = {}
local function findRiders(bridge: Bridge)
	table.clear(riders)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local p = bridge.frame:PointToObjectSpace(root.Position)
			if math.abs(p.X) < 27 and math.abs(p.Z) < 7 and p.Y > -9 and p.Y < 9 then
				table.insert(riders, p.X / BRIDGE_UNIT)
				if #riders == 3 then
					return
				end
			end
		end
	end
	-- The check build's test rider stands in for a player.
	local rider = workspace:GetAttribute("HubTestRider") :: Vector3?
	if rider then
		local p = bridge.frame:PointToObjectSpace(rider)
		if math.abs(p.X) < 27 and math.abs(p.Z) < 7 then
			table.insert(riders, p.X / BRIDGE_UNIT)
		end
	end
end

local function updateBridge(bridge: Bridge, t: number)
	local spin = t * ORBIT
	for index, set in bridge.bones do
		local x = boneX(index - 1)
		local su = math.clamp(x / BONE_SPAN, -1, 1)
		local env = 1 - su * su
		local side = 0.09 * env * math.sin(spin * 3 + bridge.seed)
		local up = -0.045 * env * math.sin(spin * 5 + bridge.seed * 1.7)
		local near = 0
		local u = math.clamp(x / 10, -1, 1)
		for _, rider in riders do
			local dx = x - rider
			up -= 0.55 * math.exp(-dx * dx / 9) * (1 - u * u)
			near = math.max(near, math.exp(-dx * dx / 3.6))
		end
		-- Each board has its own rhythm, with a tiny settle even at rest.
		local rock = math.sin(t * (2.2 + (index % 5) * 0.24) + index * 2.3)
		local settle = 0.012 * env * math.sin(t * (0.5 + (index % 3) * 0.12) + index * 1.7)
		local bounce = settle + 0.075 * near * rock
		for _, ref in set do
			local offset = (ref.side * side + ref.up * (up + bounce)) * BRIDGE_UNIT
			ref.bone.Transform = CFrame.new(offset)
				* CFrame.fromAxisAngle(ref.along, 0.075 * near * rock)
		end
	end
end

-- The gloop: bulges travel down each fall by moving the bones along its two edges, as in the concept. Slow and thick.
type FallBone = {
	bone: Bone,
	level: number,
	fall: number,
	side: number,
	across: Vector3,
	inward: Vector3,
	centre: Vector3,
}
local fallBones: { FallBone } = {}

local function addFalls(instance: Instance)
	local byKey: { [string]: Bone } = {}
	local function scan(): number
		local found = 0
		for _, item in instance:GetDescendants() do
			if item:IsA("Bone") and string.match(item.Name, "^F%d") then
				byKey[item.Name] = item
				found += 1
			end
		end
		return found
	end
	local waited = 0
	while scan() < 64 and waited < 60 do
		waited += task.wait(0.25)
	end
	for name, bone in byKey do
		local fall, level, label = string.match(name, "^F(%d)_(%d)_([LR])$")
		local other = byKey[`F{fall}_{level}_{if label == "L" then "R" else "L"}`]
		if fall and other then
			local world = bone.WorldCFrame
			local position = world.Position
			local across = (position - other.WorldPosition).Unit
			local inward = -Vector3.new(position.X, 0, position.Z).Unit
			table.insert(fallBones, {
				bone = bone,
				level = tonumber(level) :: number,
				fall = tonumber(fall) :: number,
				side = if label == "L" then 1 else -1,
				across = world:VectorToObjectSpace(across),
				inward = world:VectorToObjectSpace(inward),
				centre = (position + other.WorldPosition) / 2,
			})
		end
	end
	print(`HubMotion: falls ready, {#fallBones} bones`)
end

CollectionService:GetInstanceAddedSignal("HubFalls"):Connect(function(instance: Instance)
	task.spawn(addFalls, instance)
end)
for _, instance in CollectionService:GetTagged("HubFalls") do
	task.spawn(addFalls, instance)
end

local function updateFalls(t: number)
	for _, item in fallBones do
		-- Pinned at the lip and where it lands; the wave runs downward.
		local along = item.level / 7
		local env = math.sin(along * math.pi) ^ 0.6
		local wave = math.sin(item.level * 1.5 + t * FALL_RATE + item.fall * 2)
		local swell =
			math.sin(item.level * 1.5 + t * FALL_RATE * 0.73 + item.fall * 3.1 + item.side)
		item.bone.Transform = CFrame.new(
			(item.across * item.side * wave * FALL_WIDE + item.inward * swell * FALL_BULGE) * env
		)
	end
end

local function inView(camera: Camera, centre: Vector3): boolean
	local to = centre - camera.CFrame.Position
	return to.Magnitude < 60 or to.Unit:Dot(camera.CFrame.LookVector) > 0.25
end

-- Lightning: mostly the cloud lighting from inside, with short zaps. Occasional and brief, so it costs almost nothing.
local nextFlash = 3
local function flash(t: number)
	if t < nextFlash then
		return
	end
	nextFlash = t + 1.2 + 3.2 * math.random()
	local art = workspace:FindFirstChild("HubArt")
	local holder = art and art:FindFirstChild("StormFlash")
	if not holder or not holder:IsA("BasePart") then
		return
	end
	local angle = math.random() * 2 * math.pi
	local radius = 26 + 50 * math.random()
	holder.Position =
		Vector3.new(radius * math.cos(angle), 255 + 75 * math.random(), radius * math.sin(angle))
	local glow = holder:FindFirstChild("Glow")
	if glow and glow:IsA("ParticleEmitter") then
		glow:Emit(1)
	end
	local zap = holder:FindFirstChild("Zap")
	if zap and zap:IsA("ParticleEmitter") and math.random() < 0.7 then
		zap:Emit(1)
	end
end

-- Phone tier: touch devices skip the ink on distant pieces and every other storm sheet. Any device that stays under
-- 24 frames a second takes the same step, so the look only gives way when it has to.
local reduced = false
local function reduceDetail()
	if reduced then
		return
	end
	reduced = true
	for _, part in CollectionService:GetTagged("HubDistantInk") do
		if part:IsA("BasePart") then
			part.Transparency = 1
		end
	end
	for _, part in CollectionService:GetTagged("HubSpareCloud") do
		if part:IsA("BasePart") then
			part.Transparency = 1
		end
	end
	print("HubMotion: reduced detail")
end
if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
	task.delay(25, reduceDetail)
end
workspace:GetAttributeChangedSignal("HubReduceDetail"):Connect(reduceDetail)

local slowFrames, frameTotal, frameWindow = 0, 0, 0
RunService.Heartbeat:Connect(function(dt: number)
	frameTotal += 1
	frameWindow += dt
	if frameWindow >= 5 then
		slowFrames = if frameTotal / frameWindow < 24 then slowFrames + 1 else 0
		frameTotal, frameWindow = 0, 0
		-- Asset loading makes the first seconds slow, so only sustained trouble counts.
		if slowFrames >= 3 and os.clock() > 45 then
			reduceDetail()
		end
	end
end)

local started = os.clock()
local nextMove = 0
local nextFalls = 0
RunService.RenderStepped:Connect(function()
	local t = os.clock() - started
	if t >= nextMove then
		nextMove = t + (if reduced then MOVE_RATE else 0)
		moveParts(t)
		flash(t)
	end
	if t >= nextFalls then
		nextFalls = t + FALLS_RATE
		updateFalls(t)
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	for _, bridge in bridges do
		if t >= bridge.nextUpdate and inView(camera, bridge.centre) then
			findRiders(bridge)
			bridge.nextUpdate = t + (if #riders > 0 then ACTIVE_BRIDGE_RATE else IDLE_BRIDGE_RATE)
			updateBridge(bridge, t)
		end
	end
end)
