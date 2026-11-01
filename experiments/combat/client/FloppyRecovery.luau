--!strict
-- Floppy recovers where it lands, impact to gone inside the owner's window (Tuning
-- recoveryTime). This visual lifecycle never reads ammo readiness.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Combat = require(ReplicatedStorage:WaitForChild("Combat"))
local C = Combat.Recovery
local player = Players.LocalPlayer
local movement = player:WaitForChild("PlayerScripts"):WaitForChild("MovementSandbox")
local T = ((require :: any)(movement:WaitForChild("Tuning"))).values
local Recovery = {}

type Joint = { bone: Bone, side: Vector3, up: Vector3, front: Vector3 }
type Mound = {
	part: BasePart,
	angle: number,
	size: Vector3,
	tilt: CFrame,
	delay: number,
	crust: boolean,
	radius: number,
	pulse: number,
	height: number,
	offset: number,
	skip: boolean,
}
export type State = {
	model: Model,
	size: number,
	phase: string,
	started: number,
	born: number,
	last: number,
	pace: number,
	position: Vector3,
	velocity: Vector3,
	normal: Vector3,
	heading: Vector3,
	params: RaycastParams,
	grounded: boolean,
	joints: { Joint },
	pile: { Mound },
	mark: BasePart?,
	skidFrom: Vector3,
	skidDirection: Vector3,
	skidLength: number,
	skidSpeed: number,
	contact: Vector3?,
	contactNormal: Vector3?,
}
local BELLY = CFrame.Angles(-math.pi / 2, 0, 0)
local BACK = BELLY * CFrame.Angles(0, math.pi, 0)
local DIVE = CFrame.Angles(-math.pi, 0, 0)
local WIGGLE_RATE = 30 -- radians/s; one body wave lasts about 0.2 s

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function surface(position: Vector3, normal: Vector3, heading: Vector3): CFrame
	local forward = heading - normal * heading:Dot(normal)
	if forward.Magnitude < 1e-3 then
		forward = normal:Cross(if math.abs(normal.X) < 0.9 then Vector3.xAxis else Vector3.zAxis)
	end
	return CFrame.lookAt(position, position + forward.Unit, normal)
end

local function phase(state: State, name: string, now: number)
	state.phase, state.started = name, now
	state.model:SetAttribute("RecoveryPhase", name)
end

-- A wave runs up the body with each part late behind the last, so nothing moves as one
-- block. Negative squash stretches. Bones only rotate and translate on Roblox.
local function animate(state: State, clock: number, wiggle: number, squash: number)
	local w = wiggle * T.wiggle
	local at = clock * WIGGLE_RATE
	for _, joint in state.joints do
		local bone, name = joint.bone, joint.bone.Name
		local value = CFrame.identity
		if name == "body_lower" then
			value = CFrame.fromAxisAngle(joint.front, math.rad(12) * math.sin(at) * w)
				* CFrame.fromAxisAngle(joint.up, math.rad(8) * math.sin(at - 0.5) * w)
		elseif name == "body_upper" then
			value = CFrame.new(joint.up * (-state.size * 0.09 * squash))
				* CFrame.fromAxisAngle(joint.front, math.rad(24) * math.sin(at - 1) * w)
				* CFrame.fromAxisAngle(
					joint.side,
					math.rad(8) * squash + math.rad(8) * math.sin(at * 0.7) * w
				)
		elseif name == "head" then
			value = CFrame.new(joint.up * (-state.size * 0.045 * squash))
				* CFrame.fromAxisAngle(joint.front, math.rad(20) * math.sin(at - 2) * w)
				* CFrame.fromAxisAngle(joint.up, math.rad(16) * math.sin(at - 2.4) * w)
				* CFrame.fromAxisAngle(joint.side, math.rad(-12) * squash)
		elseif name == "tail" then
			value = CFrame.fromAxisAngle(joint.up, math.rad(42) * math.sin(at + 1) * w)
				* CFrame.fromAxisAngle(joint.side, math.rad(18) * math.sin(at * 0.7) * w)
		elseif name == "antenna_L" or name == "antenna_R" then
			local sign = if name == "antenna_L" then -1 else 1
			value = CFrame.fromAxisAngle(
				joint.front,
				math.rad(32) * math.sin(at - 2.6 + sign * 0.7) * w
			) * CFrame.fromAxisAngle(
				joint.side,
				math.rad(14) * squash + math.rad(22) * math.sin(at * 0.8 + sign) * w
			)
		end
		-- All duplicate skeletons, including eyes and ink, receive their own local axes.
		bone.Transform = value
	end
end

local function dirt(state: State)
	local ground = surface(state.position + state.normal * 0.012, state.normal, state.heading)
	local hit =
		workspace:Raycast(state.position + state.normal * 0.3, -state.normal * 0.8, state.params)
	local color = Color3.fromRGB(108, 97, 73)
	local material = Enum.Material.Ground
	if hit then
		material = hit.Material
		if hit.Instance:IsA("BasePart") then
			color = hit.Instance.Color
		elseif hit.Instance:IsA("Terrain") then
			color = workspace.Terrain:GetMaterialColor(material)
		end
	end
	local vegetation = material == Enum.Material.Grass or material == Enum.Material.LeafyGrass
	-- Ground and Rock materials render darker than their Color; start light so the
	-- pile still reads as brown soil and grey stone on a dark floor.
	local soil = color:Lerp(Color3.fromRGB(150, 112, 70), if vegetation then 0.85 else 0.4)
	local stone = color:Lerp(Color3.fromRGB(158, 150, 138), 0.55)
	local mark = Instance.new("Part")
	mark.Name = "FloppyBurrowSoil"
	mark.Shape = Enum.PartType.Cylinder
	mark.Size = Vector3.new(0.02, state.size * 0.2, state.size * 0.2)
	mark.Color = soil:Lerp(Color3.new(0, 0, 0), 0.35)
	mark.Material = Enum.Material.Slate
	mark.Anchored, mark.CanCollide, mark.CanQuery, mark.CanTouch = true, false, false, false
	mark.CFrame = ground * CFrame.Angles(0, 0, math.pi / 2)
	mark.Transparency = 1
	mark.Parent = state.model.Parent
	state.mark = mark
	Debris:AddItem(mark, C.BurrowTime + 1.2)
	local random = Random.new()
	for i = 1, C.PilePieces + C.GroundPieces do
		local crust = i > C.PilePieces
		local rock = not crust and random:NextNumber() < 0.45
		local shape = random:NextNumber()
		local bit: BasePart = if not rock
			then Instance.new("Part")
			elseif shape < 0.4 then Instance.new("WedgePart")
			elseif shape < 0.75 then Instance.new("CornerWedgePart")
			else Instance.new("Part")
		if not rock then
			-- A Ball part is forced uniform (a marble); this mesh stretches to the
			-- part, giving lumpy clods and soft swells of displaced ground.
			local lump = Instance.new("SpecialMesh")
			lump.MeshType = Enum.MeshType.Sphere
			lump.Parent = bit
		end
		bit.Name = if crust
			then "FloppyBurrowGround"
			elseif rock then "FloppyBurrowRock"
			else "FloppyBurrowMound"
		local scale = 0.5 + 0.8 * random:NextNumber() ^ 2
		local size = if crust
			then Vector3.new(
				random:NextNumber(0.36, 0.56),
				random:NextNumber(0.13, 0.22),
				random:NextNumber(0.3, 0.48)
			) * state.size
			else Vector3.new(
				random:NextNumber(0.13, 0.33),
				random:NextNumber(0.1, 0.26),
				random:NextNumber(0.12, 0.3)
			) * state.size * scale
		bit.Size = if crust then size else size * 0.15
		bit.Color = if crust
			then color
			else (if rock then stone else soil):Lerp(
				Color3.new(0, 0, 0),
				random:NextNumber(0, 0.14)
			)
		bit.Material = if crust
			then material
			elseif rock then Enum.Material.Rock
			elseif material == Enum.Material.Sand then Enum.Material.Sand
			else Enum.Material.Ground
		bit.Anchored, bit.CanCollide, bit.CanQuery, bit.CanTouch = true, false, false, false
		bit.Transparency = 1
		bit.CFrame = ground
		bit.Parent = mark.Parent
		local angle = if crust
			then (i - C.PilePieces) * math.pi * 2 / C.GroundPieces + random:NextNumber(-0.25, 0.25)
			else (i % 3) * math.pi * 2 / 3 + random:NextNumber(-0.85, 0.85)
		table.insert(state.pile, {
			part = bit,
			angle = angle,
			size = size,
			tilt = if crust
				then CFrame.Angles(0, angle, 0)
				else CFrame.Angles(
					random:NextNumber(-0.7, 0.7),
					random:NextNumber(-math.pi, math.pi),
					random:NextNumber(-0.5, 0.5)
				),
			delay = random:NextNumber(0, if crust then 0.06 else 0.25),
			crust = crust,
			radius = random:NextNumber(0.29, 0.49),
			pulse = random:NextNumber(-0.6, 0.6),
			offset = 0,
			skip = false,
			height = if crust then random:NextNumber(0.12, 0.22) else random:NextNumber(0.07, 0.14),
		})
		Debris:AddItem(bit, C.BurrowTime + 1.2)
		local mound = state.pile[#state.pile]
		local reach = state.size * (mound.radius + 0.12)
		local spot = ground * Vector3.new(math.cos(angle) * reach, 0, math.sin(angle) * reach)
		local under =
			workspace:Raycast(spot + state.normal * 0.35, -state.normal * 0.9, state.params)
		if under then
			mound.offset = (under.Position - spot):Dot(state.normal)
		else
			mound.skip = true
		end
	end
end

local function gather(state: State, progress: number)
	local ground = surface(state.position, state.normal, state.heading)
	if state.mark then
		local grow = smooth(progress * 2)
		state.mark.Size =
			Vector3.new(0.02, state.size * (0.2 + 0.45 * grow), state.size * (0.2 + 0.45 * grow))
		state.mark.Transparency = 1 - 0.75 * grow
	end
	local effort = smooth(progress / 0.12) * (1 - smooth((progress - 0.8) / 0.2))
	for _, mound in state.pile do
		if mound.skip then
			continue
		end
		local localProgress = math.clamp((progress - mound.delay) / (1 - mound.delay), 0, 1)
		local grow = smooth(localProgress / 0.8)
		-- Heave on each digging stroke, then shove the material outward. Patches
		-- match the floor so this reads as ground being disturbed, not a particle pop.
		local stroke = (0.5 + 0.5 * math.sin(progress * math.pi * 6 + mound.pulse)) ^ 2 * effort
		local radius: number
		local lift: number
		local tilt = mound.tilt
		if mound.crust then
			radius = state.size * (mound.radius + 0.09 * grow + 0.035 * stroke)
			-- Half-buried swells: each stroke heaves them up, and they stay mounded.
			lift = state.size * (mound.height * stroke + 0.05 * grow) - mound.size.Y * 0.55
			mound.part.Size = mound.size
			mound.part.Transparency = 1 - smooth(progress / 0.08)
			tilt *= CFrame.Angles(
				math.rad(14) * stroke,
				0,
				math.rad(8) * math.sin(mound.angle) * stroke
			)
		else
			local toss = math.sin(math.pi * math.clamp(localProgress / 0.75, 0, 1))
			radius = state.size * (mound.radius + 0.12 * grow + 0.035 * stroke)
			lift = mound.size.Y * 0.34 * grow
				- 0.025 * (1 - grow)
				+ state.size * (0.1 * toss + 0.035 * stroke)
			mound.part.Size = mound.size * (0.15 + 0.85 * grow)
			mound.part.Transparency = 1 - smooth(localProgress / 0.25)
			tilt *= CFrame.Angles(0.45 * (1 - grow) * stroke, 0, 0.35 * (1 - grow) * toss)
		end
		mound.part.CFrame = ground
			* CFrame.new(
				math.cos(mound.angle) * radius,
				lift + mound.offset,
				math.sin(mound.angle) * radius
			)
			* tilt
	end
end

local function settleDirt(state: State)
	local info =
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, false, 0.2)
	for _, mound in state.pile do
		if mound.skip then
			continue
		end
		TweenService:Create(
			mound.part,
			info,
			{ Transparency = 1, Position = mound.part.Position - state.normal * 0.04 }
		):Play()
	end
	if state.mark then
		TweenService:Create(state.mark, info, { Transparency = 1 }):Play()
	end
end

function Recovery.new(
	model: Model,
	size: number,
	position: Vector3,
	normal: Vector3,
	velocity: Vector3,
	params: RaycastParams,
	victim: Model?,
	now: number
): State
	local joints: { Joint } = {}
	local root = model:FindFirstChild("root", true)
	local head = model:FindFirstChild("head", true)
	local eyeL, eyeR = model:FindFirstChild("eye_L", true), model:FindFirstChild("eye_R", true)
	if
		root
		and head
		and eyeL
		and eyeR
		and root:IsA("Bone")
		and head:IsA("Bone")
		and eyeL:IsA("Bone")
		and eyeR:IsA("Bone")
	then
		local side = (eyeR.WorldPosition - eyeL.WorldPosition).Unit
		local up = (head.WorldPosition - root.WorldPosition).Unit
		local front = side:Cross(up).Unit
		for _, item in model:GetDescendants() do
			if item:IsA("Bone") then
				local frame = item.WorldCFrame
				table.insert(joints, {
					bone = item,
					side = frame:VectorToObjectSpace(side),
					up = frame:VectorToObjectSpace(up),
					front = frame:VectorToObjectSpace(front),
				})
			end
		end
	end
	local groundParams = RaycastParams.new()
	groundParams.FilterType = Enum.RaycastFilterType.Exclude
	groundParams.IgnoreWater = true
	local excluded = params.FilterDescendantsInstances
	if victim then
		table.insert(excluded, victim)
	end
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(excluded, other.Character)
		end
	end
	groundParams.FilterDescendantsInstances = excluded
	local grounded = normal.Y > 0.55 and victim == nil
	local steep = not grounded and victim == nil and normal.Magnitude > 0.5
	-- Off a wall or rock face it keeps a little slide; off a target it just drops away.
	local away = Vector3.new(normal.X, 0, normal.Z) * 1.5
	local state: State = {
		model = model,
		size = size,
		phase = "impact",
		started = now,
		born = now,
		last = now,
		pace = T.recoveryTime / 1.5,
		position = if grounded then position else position + normal * size * 0.32,
		velocity = if grounded
			then velocity
			elseif steep then (velocity - normal * velocity:Dot(normal)) * 0.25 + away
			else away,
		normal = if grounded then normal else Vector3.yAxis,
		heading = if velocity.Magnitude > 1e-3 then velocity.Unit else Vector3.zAxis,
		params = groundParams,
		grounded = grounded,
		joints = joints,
		pile = {},
		mark = nil,
		skidFrom = position,
		skidDirection = Vector3.zero,
		skidLength = 0,
		skidSpeed = 0,
		contact = if steep then position else nil,
		contactNormal = if steep then normal else nil,
	}
	phase(state, "impact", now)
	return state
end

-- On the floor: spend what remains of the window, and carry the landing speed into a skid.
local function land(state: State, now: number)
	local remaining = T.recoveryTime - (now - state.born)
	local shares = C.SkidTime + C.WriggleTime + C.CrouchTime + C.HopTime + C.BurrowTime
	state.pace = math.max(remaining / shares, C.MinPace)
	local along = state.velocity - state.normal * state.velocity:Dot(state.normal)
	local speed = along.Magnitude
	state.skidFrom, state.skidLength, state.skidSpeed = state.position, 0, speed
	if speed > 1 then
		local direction = along.Unit
		state.skidDirection, state.heading = direction, direction
		local wanted = math.min(speed * C.SkidPerSpeed, C.MaxSkid) * T.skidLength
		local clearance = state.size * 0.4
		local wall = workspace:Raycast(
			state.position + state.normal * state.size * 0.3,
			direction * (wanted + clearance),
			state.params
		)
		state.skidLength = if wall then math.max(wall.Distance - clearance, 0) else wanted
	end
	phase(state, "land", now)
end

function Recovery.step(state: State, now: number): boolean
	local dt = math.max(0, now - state.last)
	state.last = now
	local age = now - state.started
	local clock = now - state.born
	local pace = state.pace
	local wave = clock * WIGGLE_RATE
	local t, wiggle, squash = 0, 0, 0
	local position = state.position + state.normal * state.size * 0.28
	local rotation = BELLY
	if state.phase == "impact" then
		squash = 1 - smooth(age / (C.ImpactTime * pace))
		if age >= C.ImpactTime * pace then
			local nextStart = state.started + C.ImpactTime * pace
			if state.grounded then
				land(state, nextStart)
			else
				phase(state, "fall", nextStart)
			end
		end
	elseif state.phase == "fall" then
		local nextPosition = state.position
			+ state.velocity * dt
			- Vector3.yAxis * C.FallGravity * dt * dt / 2
		local hit = workspace:Raycast(state.position, nextPosition - state.position, state.params)
		if hit and hit.Normal.Y > 0.55 then
			state.position, state.normal, state.grounded = hit.Position, hit.Normal, true
			land(state, now)
		elseif hit then
			-- Too steep to stand on: glance off and keep sliding down the rock.
			state.contact, state.contactNormal = hit.Position, hit.Normal
			state.position = hit.Position + hit.Normal * state.size * 0.3
			local into = state.velocity:Dot(hit.Normal)
			if into < 0 then
				state.velocity -= hit.Normal * into * 1.3
			end
			state.velocity *= 0.85
		else
			state.position = nextPosition
			state.velocity -= Vector3.yAxis * C.FallGravity * dt
		end
		if state.phase == "fall" then
			local contact, contactNormal = state.contact, state.contactNormal
			if
				age >= C.StuckFallTime
				and contact
				and contactNormal
				and (contact - state.position).Magnitude < 2
			then
				-- Wedged with no floor in reach: dig into the rock it is stuck on.
				state.position, state.normal, state.grounded = contact, contactNormal, true
				state.velocity = Vector3.zero
				land(state, now)
			elseif
				age >= C.MaxFallTime or state.position.Y < workspace.FallenPartsDestroyHeight
			then
				return true -- bounded cleanup for a shot into the void; no disappearance VFX
			end
		end
		position = state.position + state.normal * state.size * 0.28
		wiggle = 0.8
		rotation *= CFrame.Angles(0, 0, math.rad(20) * math.sin(age * 16))
	elseif state.phase == "land" then
		t = math.clamp(age / (C.SkidTime * pace), 0, 1)
		-- Belly skid, then a jelly settle: squash swings through a stretch as it dies away.
		local slowing = 1 - t
		if state.skidLength > 0.02 then
			local target = state.skidFrom
				+ state.skidDirection * state.skidLength * (1 - slowing ^ 2.5)
			local floor =
				workspace:Raycast(target + state.normal * 0.6, -state.normal * 1.4, state.params)
			if floor and floor.Normal.Y > 0.55 then
				state.position = floor.Position
				state.normal = state.normal:Lerp(floor.Normal, 0.35).Unit
			else
				-- Skidded off a ledge.
				state.position, state.normal = target, Vector3.yAxis
				state.velocity = state.skidDirection * state.skidSpeed * slowing
				state.grounded = false
				phase(state, "fall", now)
			end
		end
		position = state.position + state.normal * state.size * 0.28
		squash = math.cos(t * 9) * slowing ^ 2
		wiggle = 0.3 + 0.7 * slowing
		position -= state.normal * state.size * 0.06 * math.max(squash, 0)
		rotation *= CFrame.Angles(
			0,
			math.rad(16) * math.sin(wave) * wiggle * T.wiggle,
			math.rad(10) * math.sin(wave * 1.3) * wiggle * T.wiggle
		)
		if t >= 1 and state.phase == "land" then
			phase(state, "wriggle", state.started + C.SkidTime * pace)
		end
	elseif state.phase == "wriggle" then
		t = math.clamp(age / (C.WriggleTime * pace), 0, 1)
		wiggle = math.max(0.45, math.sin(math.pi * t) ^ 0.5)
		-- Flops over with a slight overshoot rather than turning at an even rate.
		local back = t - 1
		local roll = 1 + 2.1 * back ^ 3 + 1.1 * back ^ 2
		local amount = wiggle * T.wiggle
		rotation = BELLY
			* CFrame.Angles(0, math.pi * roll, 0)
			* CFrame.Angles(
				math.rad(14) * math.sin(wave) * amount,
				math.rad(8) * math.sin(wave + 1) * amount,
				math.rad(16) * math.sin(wave * 1.2) * amount
			)
		position += state.normal * state.size * (0.05 * math.sin(math.pi * math.clamp(roll, 0, 1)) + 0.09 * math.abs(
			math.sin(math.pi * 3 * t)
		) * (1 - t))
		position += state.heading:Cross(state.normal) * state.size * 0.05 * math.sin(wave * 0.8) * amount
		if t >= 1 then
			phase(state, "crouch", state.started + C.WriggleTime * pace)
		end
	elseif state.phase == "crouch" then
		rotation = BACK
		t = smooth(age / (C.CrouchTime * pace))
		squash = t
		wiggle = 0.35
		position -= state.normal * state.size * 0.06 * t
		if age >= C.CrouchTime * pace then
			phase(state, "hop", state.started + C.CrouchTime * pace)
		end
	elseif state.phase == "hop" then
		t = math.clamp(age / (C.HopTime * pace), 0, 1)
		local crouched = 1 - smooth(t / 0.22)
		-- Launches stretched, then bunches up for the dive.
		squash = crouched - 0.8 * math.sin(math.pi * math.clamp(t / 0.7, 0, 1))
		wiggle = 0.55
		position -= state.normal * state.size * 0.06 * crouched
		position += state.normal * C.HopHeight * (4 * t * (1 - t))
		rotation = BACK:Lerp(DIVE, smooth((t - 0.1) / 0.6))
			* CFrame.Angles(0, math.rad(24) * math.sin(math.pi * t) * T.wiggle, 0)
		if t >= 1 then
			phase(state, "burrow", state.started + C.HopTime * pace)
			dirt(state)
			for _, item in state.model:GetDescendants() do
				if item:IsA("PointLight") then
					item.Enabled = false
				end
			end
		end
	elseif state.phase == "burrow" then
		local progress = math.clamp(age / (C.BurrowTime * pace), 0, 1)
		-- Three digging strokes, shared with the ground's heave in gather: it bites down
		-- on each stroke and almost stops between them, screwing side to side as it goes.
		local strokes = progress * math.pi * 6
		t = smooth(progress - 0.85 * math.sin(strokes) / (math.pi * 6))
		local effort = math.max(0.6, math.sin(math.pi * progress) ^ 0.5)
		local amount = effort * T.wiggle
		position -= state.normal * state.size * t * 1.02
		rotation = DIVE
			* CFrame.Angles(
				math.rad(12) * math.sin(progress * math.pi * 10) * amount,
				math.rad(38) * math.sin(strokes) * amount,
				math.rad(10) * math.sin(progress * math.pi * 8) * amount
			)
		wiggle = effort
		squash = 0.35 * (0.5 - 0.5 * math.cos(strokes)) * effort
		gather(state, progress)
		if age >= C.BurrowTime * pace then
			settleDirt(state)
			return true
		end
	end
	state.model:PivotTo(surface(position, state.normal, state.heading) * rotation)
	animate(state, clock, wiggle, squash)
	return false
end

return Recovery
