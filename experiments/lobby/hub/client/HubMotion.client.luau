--!strict
-- All the hub's motion, on each client and look-only: nothing here moves a collider or a player. Also the Detail button.
-- Costs are kept low for phones: whole parts move in one BulkMoveTo, and a bridge's bones only update while someone is on
-- it and it is in view.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ORBIT = 0.12
local BRIDGE_UNIT = 2.55 -- studs per bridge unit
local MOVE_RATE = 1 / 30
local BRIDGE_EASE = 9 -- how quickly bones follow their targets
local WALK_SPEED = 16
local BRIDGE_SETTLE = 1.2 -- seconds for a bridge to come to rest after the last person leaves
local BONE_COUNT = 17
local BONE_SPAN = 10.6 -- bridge units, centre to end bone

type Mover = {
	part: BasePart,
	base: CFrame,
	spin: number,
	localSpin: number,
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
		localSpin = (instance:GetAttribute("LocalSpin") or 0) :: number,
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
		if mover.localSpin ~= 0 then
			frame *= CFrame.Angles(0, mover.localSpin * t, 0)
		end
		if mover.height ~= 0 then
			frame += Vector3.new(0, mover.height * math.sin(t * mover.rate + mover.phase), 0)
		end
		moverFrames[index] = frame
	end
	workspace:BulkMoveTo(moverParts, moverFrames, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Bridges rest perfectly still. Someone's weight dips the deck under them; only moving makes it sway and the boards rock
-- (owner: standing still on it should not wobble).
type BoneRef = { bone: Bone, up: Vector3, side: Vector3, along: Vector3 }
type Bridge = {
	frame: CFrame,
	seed: number,
	bones: { { BoneRef } },
	centre: Vector3,
	energy: number,
	resting: boolean,
	values: { { side: number, up: number, roll: number } },
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
	-- Bones replicate after the tag: wait for all of them.
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
	if count() == 0 then
		warn("HubMotion: bridge has no bones", instance.Name)
		return
	end
	local sets: { { BoneRef } } = {}
	for index = 1, BONE_COUNT do
		sets[index] = {}
	end
	for _, item in instance:GetDescendants() do
		if item:IsA("Bone") then
			local number = tonumber(string.match(item.Name, "^B(%d+)$"))
			if number then
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
	local values = {}
	for index = 1, BONE_COUNT do
		values[index] = { side = 0, up = 0, roll = 0 }
	end
	table.insert(bridges, {
		frame = frame,
		seed = #bridges * 41,
		bones = sets,
		centre = frame.Position,
		energy = 0,
		resting = true,
		values = values,
	})
end

CollectionService:GetInstanceAddedSignal("HubBridge"):Connect(function(instance: Instance)
	task.spawn(addBridge, instance)
end)
for _, instance in CollectionService:GetTagged("HubBridge") do
	task.spawn(addBridge, instance)
end

-- Where anyone is along this bridge, in bridge units, up to three; and how fast the quickest of them is moving.
local riders: { number } = {}
local riderSpeed = 0
local function findRiders(bridge: Bridge)
	table.clear(riders)
	riderSpeed = 0
	local function consider(position: Vector3, speed: number)
		local p = bridge.frame:PointToObjectSpace(position)
		if math.abs(p.X) < 26 and math.abs(p.Z) < 7 and p.Y > -9 and p.Y < 9 and #riders < 3 then
			table.insert(riders, p.X / BRIDGE_UNIT)
			riderSpeed = math.max(riderSpeed, speed)
		end
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			local velocity = root.AssemblyLinearVelocity
			consider(root.Position, Vector3.new(velocity.X, 0, velocity.Z).Magnitude)
		end
	end
	-- The check build's test rider stands in for a player.
	local rider = workspace:GetAttribute("HubTestRider") :: Vector3?
	if rider then
		consider(rider, WALK_SPEED)
	end
end

-- Runs every frame while a bridge is active, and every bone eases toward its target, so it can't step or stutter.
local function updateBridge(bridge: Bridge, t: number, dt: number)
	local spin = t * ORBIT
	local ease = 1 - math.exp(-dt * BRIDGE_EASE)
	local settled = true
	for index, set in bridge.bones do
		local x = boneX(index - 1)
		local su = math.clamp(x / BONE_SPAN, -1, 1)
		local env = (1 - su * su) * bridge.energy
		local side = 0.09 * env * math.sin(spin * 3 + bridge.seed)
		local up = -0.045 * env * math.sin(spin * 5 + bridge.seed * 1.7)
		local near = 0
		local u = math.clamp(x / 10, -1, 1)
		for _, rider in riders do
			local dx = x - rider
			-- Their weight, which stays while they stand still.
			up -= 0.38 * math.exp(-dx * dx / 9) * (1 - u * u)
			near = math.max(near, math.exp(-dx * dx / 3.6))
		end
		-- Each board has its own rhythm, but only while someone is moving on it.
		local rock = 0.05
			* near
			* bridge.energy
			* math.sin(t * (2.2 + (index % 5) * 0.24) + index * 2.3)
		local value = bridge.values[index]
		value.side += (side - value.side) * ease
		value.up += (up + rock - value.up) * ease
		value.roll += (rock - value.roll) * ease
		if math.abs(value.side) + math.abs(value.up) + math.abs(value.roll) > 0.001 then
			settled = false
		end
		for _, ref in set do
			local offset = (ref.side * value.side + ref.up * value.up) * BRIDGE_UNIT
			ref.bone.Transform = CFrame.new(offset) * CFrame.fromAxisAngle(ref.along, value.roll)
		end
	end
	return settled
end

local function inView(camera: Camera, centre: Vector3): boolean
	local to = centre - camera.CFrame.Position
	return to.Magnitude < 60 or to.Unit:Dot(camera.CFrame.LookVector) > 0.25
end

-- Lightning: the clouds themselves light up from inside, with short zaps in the gaps between the sheets. Occasional and brief.
local STORM_GLOW = 0.7
local STORM_FLASH = 1.5
local ZAP_LEVELS = { 245, 280, 325 } -- between the cloud sheets, so a zap never crosses one
local nextFlash = 3
local flashLeft = 0
local function flash(t: number, dt: number)
	if flashLeft > 0 then
		flashLeft = math.max(flashLeft - dt * 3.5, 0)
		local strength = STORM_GLOW + STORM_FLASH * flashLeft
		for _, item in CollectionService:GetTagged("HubStormCloud") do
			if item:IsA("SurfaceAppearance") then
				item.EmissiveStrength = strength
			end
		end
	end
	if t < nextFlash then
		return
	end
	nextFlash = t + 1.2 + 3.2 * math.random()
	flashLeft = 0.6 + 0.4 * math.random()
	local art = workspace:FindFirstChild("HubArt")
	local holder = art and art:FindFirstChild("StormFlash")
	if not holder or not holder:IsA("BasePart") then
		return
	end
	local angle = math.random() * 2 * math.pi
	local radius = 26 + 50 * math.random()
	holder.Position = Vector3.new(
		radius * math.cos(angle),
		ZAP_LEVELS[math.random(#ZAP_LEVELS)],
		radius * math.sin(angle)
	)
	local zap = holder:FindFirstChild("Zap")
	if zap and zap:IsA("ParticleEmitter") and math.random() < 0.7 then
		zap:Emit(1)
	end
end

-- Detail: Low skips the ink on distant pieces, every other storm sheet and twinkle, and half the mist. It starts Low on
-- touch devices and drops by itself on any device that stays under 24 frames a second. The button overrides both. Roblox's
-- own graphics level isn't something a game can change: that stays in the player's Roblox settings.
local low = false
local chosen = false
local button: TextButton? = nil

local function setDetail(value: boolean)
	low = value
	for _, tag in { "HubDistantInk", "HubSpareCloud" } do
		for _, part in CollectionService:GetTagged(tag) do
			if part:IsA("BasePart") then
				part.Transparency = if value then 1 else 0
			end
		end
	end
	for _, e in CollectionService:GetTagged("HubSpareTwinkle") do
		if e:IsA("ParticleEmitter") then
			e.Enabled = not value
		end
	end
	for _, e in CollectionService:GetTagged("HubMist") do
		if e:IsA("ParticleEmitter") then
			e.Rate = if value then 1.5 else 3
		end
	end
	if button then
		button.Text = `Detail: {if value then "Low" else "High"}`
	end
end

do
	local gui = Instance.new("ScreenGui")
	gui.Name = "HubDetail"
	gui.ResetOnSpawn = false
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	local made = Instance.new("TextButton")
	made.AnchorPoint = Vector2.new(0, 1)
	made.Position = UDim2.new(0, 12, 1, -12)
	made.Size = UDim2.fromOffset(120, 34)
	made.BackgroundColor3 = Color3.fromRGB(24, 26, 38)
	made.BackgroundTransparency = 0.2
	made.TextColor3 = Color3.fromRGB(230, 235, 245)
	made.Font = Enum.Font.GothamBold
	made.TextSize = 15
	made.Text = "Detail: High"
	made.Parent = gui
	made.Activated:Connect(function()
		chosen = true
		setDetail(not low)
	end)
	button = made
end

if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
	task.delay(25, function()
		if not chosen then
			setDetail(true)
		end
	end)
end
workspace:GetAttributeChangedSignal("HubReduceDetail"):Connect(function()
	setDetail(workspace:GetAttribute("HubReduceDetail") == true)
end)

local slowFrames, frameTotal, frameWindow = 0, 0, 0
RunService.Heartbeat:Connect(function(dt: number)
	frameTotal += 1
	frameWindow += dt
	if frameWindow >= 5 then
		slowFrames = if frameTotal / frameWindow < 24 then slowFrames + 1 else 0
		frameTotal, frameWindow = 0, 0
		-- Asset loading makes the first seconds slow, so only sustained trouble counts.
		if slowFrames >= 3 and os.clock() > 45 and not chosen and not low then
			setDetail(true)
		end
	end
end)

-- The volcano's eruption (owner: the old one wasn't animated enough). It builds, throws several waves of heavy blobs high in
-- long arcs, keeps spitting as it dies away, then rests. Particles are few and fired in bursts, so resting costs nothing.
local crater: BasePart? = nil
local volley: { { at: number, name: string, count: number } } = {}
local nextEruption = 5

local function startEruption(t: number)
	local scale = if low then 0.55 else 1
	table.clear(volley)
	local function add(at: number, name: string, count: number)
		table.insert(
			volley,
			{ at = t + at, name = name, count = math.max(1, math.floor(count * scale)) }
		)
	end
	-- The build-up: small spits, then a stronger one.
	for i = 0, 4 do
		add(i * 0.22, "Spits", 2 + i)
	end
	-- The main blast, then waves that lose strength.
	local waves = { 1.15, 1.42, 1.75, 2.15, 2.65, 3.3 }
	local sizes = { 20, 15, 11, 8, 5, 3 }
	for i, at in waves do
		add(at, "Blobs", sizes[i])
		add(at, "Spits", sizes[i] + 3)
	end
	add(1.15, "Flare", 1)
	add(1.15, "Blast", 4)
	add(1.75, "Flare", 1)
	add(1.75, "Blast", 2)
	add(2.65, "Blast", 1)
	-- A last few stragglers.
	for i = 0, 3 do
		add(4.0 + i * 0.5, "Spits", 2)
	end
	nextEruption = t + 9 + 6 * math.random()
end

local function eruptionStep(t: number)
	if not crater then
		local tagged = CollectionService:GetTagged("HubCrater")
		local first = tagged[1]
		if first and first:IsA("BasePart") then
			crater = first
		else
			return
		end
	end
	if t >= nextEruption then
		startEruption(t)
	end
	for index = #volley, 1, -1 do
		local shot = volley[index]
		if t >= shot.at then
			local e = (crater :: BasePart):FindFirstChild(shot.name)
			if e and e:IsA("ParticleEmitter") then
				e:Emit(shot.count)
			end
			table.remove(volley, index)
		end
	end
end
workspace:GetAttributeChangedSignal("HubErupt"):Connect(function()
	nextEruption = 0
end)

local started = os.clock()
local nextMove = 0
RunService.RenderStepped:Connect(function(dt: number)
	local t = os.clock() - started
	if t >= nextMove then
		nextMove = t + (if low then MOVE_RATE else 0)
		moveParts(t)
		flash(t, dt)
		eruptionStep(t)
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	for _, bridge in bridges do
		findRiders(bridge)
		local target = math.clamp(riderSpeed / WALK_SPEED, 0, 1)
		bridge.energy += (target - bridge.energy) * (1 - math.exp(-dt / BRIDGE_SETTLE * 3))
		if #riders > 0 or not bridge.resting then
			if inView(camera, bridge.centre) then
				local settled = updateBridge(bridge, t, dt)
				bridge.resting = settled and #riders == 0
			end
		end
	end
end)
