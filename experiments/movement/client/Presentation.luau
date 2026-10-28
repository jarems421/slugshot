--!strict
-- Clip-driven R15 presentation for every character: directional locomotion whose
-- cadence follows ground speed, physics-driven jump/fall, landing absorption,
-- roll/flip actions, lean and ground-contact correction. Physics root and camera
-- never rotate. Clips come from Clips.load (original, optionally private overrides).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("MovementExperiment")
local Config = require(shared.Config)
local Math = require(shared.MotionMath)
local Clips = require(shared.Clips)
local Presentation = {}

type Pose = { [string]: CFrame }
type AnimationJoint = Motor6D | AnimationConstraint
type Link = {
	joint: string,
	parent: string,
	child: string,
	c0: CFrame,
	c1: CFrame,
	half: Vector3,
	foot: boolean,
}

local A = Config.Animation
local IDENTITY = CFrame.identity
local DEBUG_POSES = RunService:IsStudio()

local function parts(joint: AnimationJoint): (Instance?, Instance?)
	if joint:IsA("Motor6D") then
		return joint.Part0, joint.Part1
	end
	local constraint = joint :: AnimationConstraint
	return constraint.Attachment0 and constraint.Attachment0.Parent,
		constraint.Attachment1 and constraint.Attachment1.Parent
end

-- Joint chain ordered from the root so forward kinematics needs one pass.
local function buildChain(joints: { [string]: AnimationJoint }): { Link }
	local byParent: { [string]: { Link } } = {}
	for name, joint in joints do
		local parent, child = parts(joint)
		if parent and child and child:IsA("BasePart") then
			local link: Link = {
				joint = name,
				parent = parent.Name,
				child = child.Name,
				c0 = Clips.attachmentFrame(joint, "0"),
				c1 = Clips.attachmentFrame(joint, "1"):Inverse(),
				half = child.Size / 2,
				foot = child.Name:sub(-4) == "Foot",
			}
			byParent[link.parent] = byParent[link.parent] or {}
			table.insert(byParent[link.parent], link)
		end
	end
	local chain: { Link } = {}
	local queue = { "HumanoidRootPart" }
	while #queue > 0 do
		local part = table.remove(queue, 1) :: string
		for _, link in byParent[part] or {} do
			table.insert(chain, link)
			table.insert(queue, link.child)
		end
	end
	return chain
end

-- Lowest point of the posed rig in root space (box approximation per part).
local framesScratch: { [string]: CFrame } = {}
local function lowestPoint(chain: { Link }, pose: Pose, feetOnly: boolean): number
	framesScratch.HumanoidRootPart = IDENTITY
	local lowest = math.huge
	for _, link in chain do
		local parent = framesScratch[link.parent]
		if parent then
			local frame = parent * link.c0 * (pose[link.joint] or IDENTITY) * link.c1
			framesScratch[link.child] = frame
			if link.foot or not feetOnly then
				local h = link.half
				local extent = h.X * math.abs(frame.XVector.Y)
					+ h.Y * math.abs(frame.YVector.Y)
					+ h.Z * math.abs(frame.ZVector.Y)
				lowest = math.min(lowest, frame.Y - extent)
			end
		end
	end
	return lowest
end

local function smoothstep(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function signedYaw(from: Vector3, to: Vector3): number
	return math.atan2(from.Z * to.X - from.X * to.Z, from.X * to.X + from.Z * to.Z)
end

function Presentation.start(clips: Clips.Library)
	local rigs: { [Model]: any } = {}
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local function refreshFilter()
		local list = {}
		for character in rigs do
			table.insert(list, character)
		end
		params.FilterDescendantsInstances = list
	end

	-- (Re)reads joints and proportions; remote characters stream in piece by piece.
	local function scan(rig: any)
		local joints: { [string]: AnimationJoint } = {}
		local count = 0
		for _, item in rig.character:GetDescendants() do
			if item:IsA("Motor6D") or item:IsA("AnimationConstraint") then
				joints[item.Name] = item
				count += 1
			end
		end
		rig.joints = joints
		rig.chain = buildChain(joints)
		-- Rest feet rest on the floor, so this is the floor height in root space.
		rig.ground = lowestPoint(rig.chain, {}, true)
		rig.unit = Clips.hipUnit(rig.character)
		rig.character:SetAttribute("PresentationJointCount", count)
	end

	local function watch(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
		if not humanoid or not root or not character.Parent then
			return
		end
		local rig = {
			character = character,
			humanoid = humanoid,
			root = root,
			phase = 0,
			grounded = true,
			airStart = 0,
			airState = "",
			jumped = false,
			airVy0 = 0,
			apexTime = 0,
			lastVy = 0,
			landStart = -math.huge,
			landStrength = 0,
			actionStamp = character:GetAttribute("MovementActionTime"),
			action = nil,
			fade = nil,
			output = {},
			bank = 0,
			pitch = 0,
			lastLook = root.CFrame.LookVector,
			lastVelocity = Vector3.zero,
			aimWeight = 0,
			footOffset = 0,
			scratch = {},
		}
		scan(rig)
		rigs[character] = rig
		character:SetAttribute("PresentationMode", "Clips")
		refreshFilter()
		local pending = false
		character.DescendantAdded:Connect(function(item)
			if
				pending
				or not (
					item:IsA("JointInstance")
					or item:IsA("AnimationConstraint")
					or item:IsA("Attachment")
					or item:IsA("BasePart")
				)
			then
				return
			end
			pending = true
			task.delay(0.1, function()
				pending = false
				if rigs[character] == rig then
					scan(rig)
				end
			end)
		end)
	end
	local function watchPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.defer(watch, character)
		end)
		if player.Character then
			task.defer(watch, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end

	local function scratch(rig: any, index: number): Pose
		local pose = rig.scratch[index]
		if not pose then
			pose = {}
			rig.scratch[index] = pose
		end
		return pose
	end

	local function startFade(rig: any, duration: number, now: number)
		rig.fade = { from = table.clone(rig.output), start = now, duration = duration }
	end

	-- Directional locomotion: run/sprint/back/strafe share one normalized phase so
	-- foot contacts line up; cadence follows ground speed within a clamped range.
	local function locomotion(rig: any, dt: number, now: number, flat: Vector3): (Pose, number)
		local speed = flat.Magnitude
		local localVelocity = rig.root.CFrame:VectorToObjectSpace(flat)
		local profile = Config.Profiles[rig.character:GetAttribute("MovementProfile") or ""]
			or Config.Profiles[Config.DefaultProfile]
		local sprintStart = profile.RunSpeed * 0.92
		local sprintMix = if profile.SprintSpeed > sprintStart + 0.1
			then math.clamp((speed - sprintStart) / (profile.SprintSpeed - sprintStart), 0, 1)
			else 0
		local inverse = if speed > 0.01 then 1 / speed else 0
		local forward, side = -localVelocity.Z * inverse, localVelocity.X * inverse
		local entries: { { any } } = {}
		local total = 0
		local function add(name: string, weight: number)
			if weight <= 1e-3 then
				return
			end
			local clip = clips[name] or clips.Run or clips.Sprint
			if clip then
				table.insert(entries, { clip, weight })
				total += weight
			end
		end
		if speed <= 0.01 then
			forward = 1
		end
		add("Run", math.max(0, forward) * (1 - sprintMix))
		add("Sprint", math.max(0, forward) * sprintMix)
		add("RunBack", math.max(0, -forward))
		add("StrafeRight", math.max(0, side))
		add("StrafeLeft", math.max(0, -side))
		local natural, cycle = 0, 0
		for _, entry in entries do
			entry[2] /= total
			natural += entry[1].speed * rig.unit * entry[2]
			cycle += entry[1].duration * entry[2]
		end
		local rate = if natural > 0.01
			then math.clamp(speed / natural, A.MinCycleRate, A.MaxCycleRate)
			else 1
		if cycle > 0 then
			rig.phase = (rig.phase + dt * rate / cycle) % 1
		end
		local poses, weights = {}, {}
		local floor = 0
		for index, entry in entries do
			local clip = entry[1]
			local time = rig.phase * clip.duration
			table.insert(poses, Clips.sample(clip, time, scratch(rig, index)))
			table.insert(weights, entry[2])
			floor += Clips.floor(clip, time) * entry[2]
		end
		local moving = Clips.blend(poses, weights, scratch(rig, 10))
		local idle = clips.Idle
		local moveWeight = smoothstep(speed / A.IdleBlendSpeed)
		if not idle or moveWeight >= 0.999 then
			return moving, floor
		end
		local idlePose = Clips.sample(idle, now, scratch(rig, 11))
		local idleFloor = Clips.floor(idle, now)
		if #poses == 0 then
			return idlePose, idleFloor
		end
		return Clips.blend({ idlePose, moving }, { 1 - moveWeight, moveWeight }, scratch(rig, 12)),
			idleFloor + (floor - idleFloor) * moveWeight
	end

	-- Airborne: rise through the jump clip as vertical speed decays, carry the
	-- apex, then reach for the ground over the clip's final air time.
	local function airborne(rig: any, now: number, vy: number, height: number): (Pose?, string)
		local jump = clips.Jump
		local events = if jump then jump.events else {}
		local takeoff, apex, land = events.takeoff, events.apex, events.land
		if jump and takeoff and apex and land then
			local gravity = workspace.Gravity
			local timeToLand = (
				vy + math.sqrt(math.max(0, vy * vy + 2 * gravity * math.max(0, height)))
			) / gravity
			local reach = land - apex
			if rig.jumped and vy > 0 then
				local progress = math.clamp(1 - vy / math.max(rig.airVy0, 1), 0, 1)
				return Clips.sample(jump, takeoff + progress * (apex - takeoff), scratch(rig, 13)),
					"rise"
			end
			if timeToLand < reach then
				return Clips.sample(jump, land - timeToLand, scratch(rig, 13)), "reach"
			end
			if rig.jumped and now - rig.apexTime < reach then
				return Clips.sample(jump, apex + (now - rig.apexTime) * 0.5, scratch(rig, 13)),
					"apex"
			end
		end
		if clips.Fall then
			return Clips.sample(clips.Fall, now - rig.airStart, scratch(rig, 14)), "fall"
		end
		return nil, "none"
	end

	local function startAction(rig: any, stamp: number, now: number)
		local character = rig.character
		local kind = character:GetAttribute("MovementAction")
		local clip = clips[character:GetAttribute("MovementVariant") or ""]
		if not clip or (kind ~= "Roll" and kind ~= "Flip") or now - stamp > 1.5 then
			return
		end
		local yaw = 0
		if kind == "Roll" then
			local direction = character:GetAttribute("MovementDirection")
			if typeof(direction) == "Vector3" then
				local localDirection = rig.root.CFrame:VectorToObjectSpace(direction)
				yaw = signedYaw(clip.direction, Vector3.new(localDirection.X, 0, localDirection.Z))
			end
		end
		local rate = character:GetAttribute("MovementRate")
		rig.action = {
			kind = kind,
			clip = clip,
			-- Observers start on receipt: replicated bodies are interpolated behind the
			-- owner's clock, and the attributes arrive about as late as the motion.
			start = if character == Players.LocalPlayer.Character then stamp else now,
			rate = if typeof(rate) == "number" then rate else 1,
			offset = if kind == "Flip" then clip.events.takeoff or 0 else 0,
			yaw = yaw,
		}
		startFade(rig, A.Fade.ActionIn, now)
	end

	local aimPose: Pose = {}
	local function evaluate(rig: any, dt: number, now: number)
		local character, root, humanoid = rig.character, rig.root, rig.humanoid
		local velocity = root.AssemblyLinearVelocity
		local flat = Vector3.new(velocity.X, 0, velocity.Z)
		local stand = humanoid.HipHeight + root.Size.Y / 2
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -(stand + 12), 0), params)
		local height = if hit then root.Position.Y - hit.Position.Y - stand else math.huge
		local grounded = height < 0.4 and velocity.Y < 6

		-- Ground/air transitions.
		if grounded ~= rig.grounded then
			if grounded then
				local impact = -rig.lastVy
				if now - rig.airStart > 0.08 and impact >= A.Land.MinImpact then
					rig.landStart = now
					rig.landStrength = math.clamp(
						0.35
							+ 0.65
								* (impact - A.Land.MinImpact)
								/ (A.Land.FullImpact - A.Land.MinImpact),
						0,
						1
					)
				end
				startFade(rig, A.Fade.Land, now)
			else
				rig.airStart = now
				rig.jumped = velocity.Y > 10
				rig.airVy0 = velocity.Y
				rig.airState = ""
			end
			rig.grounded = grounded
		end
		if not grounded and rig.lastVy > 0 and velocity.Y <= 0 then
			rig.apexTime = now
		end
		rig.lastVy = velocity.Y

		local stamp = character:GetAttribute("MovementActionTime")
		if typeof(stamp) == "number" and stamp ~= rig.actionStamp then
			rig.actionStamp = stamp
			startAction(rig, stamp, now)
		end

		-- Base layer.
		local pose: Pose
		local floor = 0
		local contact: string? = nil
		if grounded then
			pose, floor = locomotion(rig, dt, now, flat)
			contact = "feet"
			local land = clips.Land
			local landTime = now - rig.landStart
			if land and landTime < A.Land.Duration then
				local moveWeight = smoothstep(flat.Magnitude / A.IdleBlendSpeed)
				local weight = rig.landStrength
					* (1 - smoothstep(landTime / A.Land.Duration))
					* (1 - moveWeight * A.Land.MovingScale)
				local landPose =
					Clips.sample(land, (land.events.contact or 0) + landTime, scratch(rig, 15))
				pose = Clips.blend({ pose, landPose }, { 1 - weight, weight }, scratch(rig, 16))
				floor += (Clips.floor(land, (land.events.contact or 0) + landTime) - floor) * weight
			end
		else
			local airPose, state = airborne(rig, now, velocity.Y, height)
			if state ~= rig.airState then
				if rig.airState ~= "" then
					startFade(rig, A.Fade.Air, now)
				end
				rig.airState = state
			end
			pose = airPose or locomotion(rig, dt, now, flat)
		end

		-- Action layer (roll/flip) replaces the base pose; fades cover entry/exit.
		local action = rig.action
		local actionWeight = 0
		if action then
			local clip = action.clip
			local t = action.offset + (now - action.start) * action.rate
			local finished
			if action.kind == "Roll" then
				local recover = clip.events.recover or clip.duration
				finished = t >= clip.duration
					or (t >= recover and flat.Magnitude > A.IdleBlendSpeed)
					or not grounded and now - action.start > 0.25
			else
				action.airborne = action.airborne or not grounded
				finished = t >= (clip.events.land or clip.duration)
					or (grounded and action.airborne)
					or (grounded and now - action.start > 0.5)
			end
			if finished then
				rig.action = nil
				startFade(rig, A.Fade.ActionOut, now)
			else
				local actionPose = Clips.sample(clip, t, scratch(rig, 17))
				if action.yaw ~= 0 then
					actionPose.Root = CFrame.Angles(0, action.yaw, 0) * actionPose.Root
				end
				pose = actionPose
				actionWeight = 1
				floor, contact = Clips.floor(clip, t), clip.contact
			end
		end

		-- Studio-only inspection hook: hold any clip at a fixed time.
		local debugClip = if DEBUG_POSES
			then clips[character:GetAttribute("DebugClip") or ""]
			else nil
		if debugClip then
			local t = character:GetAttribute("DebugTime") or 0
			pose = Clips.sample(debugClip, t, scratch(rig, 18))
			floor, contact, actionWeight = Clips.floor(debugClip, t), debugClip.contact, 1
			rig.fade = nil
		end

		-- Aim layer: arms only, reduced while acrobatics play.
		local aimTarget = if character:GetAttribute("Aiming") then 1 else 0
		if actionWeight > 0 then
			aimTarget *= A.AimWeightDuringAction
		end
		rig.aimWeight += (aimTarget - rig.aimWeight) * Math.alpha(A.AimRate, dt)
		if rig.aimWeight > 0.01 then
			local pitch = character:GetAttribute("AimPitch") or 0
			aimPose.RightShoulder = CFrame.Angles(1.35 - pitch, 0, 0.05)
			aimPose.LeftShoulder = CFrame.Angles(1.15 - pitch, 0, -0.25)
			aimPose.RightElbow = CFrame.Angles(0.2, 0, 0)
			aimPose.LeftElbow = CFrame.Angles(0.5, 0, 0)
			for name, value in aimPose do
				pose[name] = (pose[name] or IDENTITY):Lerp(value, rig.aimWeight)
			end
		end

		-- Lean into turns and acceleration while running (not during actions).
		local look = root.CFrame.LookVector
		local yawRate = signedYaw(rig.lastLook, look) / math.max(dt, 1e-3)
		local acceleration = (flat - rig.lastVelocity) / math.max(dt, 1e-3)
		rig.lastLook, rig.lastVelocity = look, flat
		local leanActive = grounded and actionWeight == 0
		local bankTarget = if leanActive
			then math.clamp(yawRate * flat.Magnitude * A.Lean.Bank, -A.Lean.MaxBank, A.Lean.MaxBank)
			else 0
		local pitchTarget = if leanActive
			then math.clamp(
				-acceleration:Dot(look) * A.Lean.Pitch,
				-A.Lean.MaxPitch,
				A.Lean.MaxPitch
			)
			else 0
		local leanAlpha = Math.alpha(A.Lean.Rate, dt)
		rig.bank += (bankTarget - rig.bank) * leanAlpha
		rig.pitch += (pitchTarget - rig.pitch) * leanAlpha

		-- Root: clip translation is in hip units.
		local rootPose = pose.Root or IDENTITY
		rootPose = CFrame.new(rootPose.Position * rig.unit) * rootPose.Rotation
		rootPose = CFrame.Angles(rig.pitch, 0, rig.bank) * rootPose

		-- Ground contact: keep the feet (or, for rolls, the whole body) at the clip's
		-- intended clearance using the real rig's proportions.
		pose.Root = rootPose
		local correction = 0
		if contact then
			local lowest = lowestPoint(rig.chain, pose, contact == "feet")
			correction = math.clamp(
				rig.ground + floor * rig.unit - lowest,
				-A.GroundContact.Max,
				A.GroundContact.Max
			)
		end
		rig.footOffset += (correction - rig.footOffset) * Math.alpha(A.GroundContact.Rate, dt)
		pose.Root = CFrame.new(0, rig.footOffset, 0) * rootPose

		-- Apply with an optional crossfade from the last rendered pose.
		local fade = rig.fade
		local fadeAlpha = 1
		if fade then
			fadeAlpha = smoothstep((now - fade.start) / fade.duration)
			if fadeAlpha >= 1 then
				rig.fade = nil
			end
		end
		for name, joint in rig.joints do
			local value = pose[name] or IDENTITY
			if fade and fadeAlpha < 1 then
				value = (fade.from[name] or IDENTITY):Lerp(value, fadeAlpha)
			end
			rig.output[name] = value
			joint.Transform = value
		end
		character:SetAttribute("RenderedAction", if action and rig.action then action.kind else "")
		character:SetAttribute("RenderedAirState", if grounded then "ground" else rig.airState)
		character:SetAttribute("RenderedCyclePhase", rig.phase)
		character:SetAttribute("RenderedFootOffset", rig.footOffset)
	end

	RunService.PreSimulation:Connect(function(dt)
		local now = workspace:GetServerTimeNow()
		for character, rig in rigs do
			if not character.Parent then
				rigs[character] = nil
				refreshFilter()
				continue
			end
			if rig.humanoid.Health > 0 then
				evaluate(rig, dt, now)
			end
		end
	end)
end

return Presentation
