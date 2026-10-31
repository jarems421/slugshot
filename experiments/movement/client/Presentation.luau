--!strict
-- Clip-driven R15 presentation for every character: directional locomotion whose
-- cadence follows ground speed, physics-driven jump/fall, tiered landings,
-- one-shot transitions (settle, fidget, flinch), flip/mantle/vault/
-- wall-hop/wall-run/slide actions, lean and ground-contact correction.
-- Physics root and camera never rotate. Clips come from Clips.load (original,
-- optionally private overrides and variants).
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
	hidden: boolean,
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

-- Joint chain ordered from the root so forward kinematics needs one pass. Poses
-- rotate parts about each joint's pivot in the parent's axes, so only the pivot
-- positions enter here; see jointFrames for R6's rotated joint frames.
local function buildChain(joints: { [string]: AnimationJoint }): { Link }
	local byParent: { [string]: { Link } } = {}
	for name, joint in joints do
		local parent, child = parts(joint)
		if parent and child and child:IsA("BasePart") then
			local link: Link = {
				joint = name,
				parent = parent.Name,
				child = child.Name,
				c0 = CFrame.new(Clips.attachmentFrame(joint, "0").Position),
				c1 = CFrame.new(-Clips.attachmentFrame(joint, "1").Position),
				half = child.Size / 2,
				foot = child.Name:sub(-4) == "Foot"
					or child.Name == "Left Leg"
					or child.Name == "Right Leg",
				hidden = child.Transparency >= 1,
			}
			byParent[link.parent] = byParent[link.parent] or {}
			table.insert(byParent[link.parent], link)
		end
	end
	local chain: { Link } = {}
	local queue = { "HumanoidRootPart" }
	while #queue > 0 do
		local part = table.remove(queue, 1) :: string
		local links: { Link } = byParent[part] or {}
		for _, link in links do
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
			if link.foot or not (feetOnly or link.hidden) then
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

-- R6 joints carry a 90-degree turn in both C0 and C1 (R15's are pure offsets), so a
-- pose rotation is wrapped into each joint's own frame: Transform = C0r^-1 * pose * C1r.
local function jointFrames(joint: AnimationJoint): { CFrame }
	return {
		Clips.attachmentFrame(joint, "0").Rotation:Inverse(),
		Clips.attachmentFrame(joint, "1").Rotation,
	}
end

-- A two-segment limb as one block: aim it from its root to its end (segments of
-- equal length), turning the upper segment by the least rotation so it keeps its twist.
local DOWN = Vector3.new(0, -1, 0)
local function chord(upper: CFrame?, lower: CFrame?): CFrame
	local u = (upper or IDENTITY).Rotation
	if not lower then
		return u
	end
	local along = u:VectorToWorldSpace(DOWN)
	local target = along + (u * lower.Rotation):VectorToWorldSpace(DOWN)
	if target.Magnitude < 1e-6 then
		return u
	end
	target = target.Unit
	local axis = along:Cross(target)
	if axis.Magnitude < 1e-9 then
		return u
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(along:Dot(target), -1, 1))) * u
end

-- Clips stay in R15 terms. R6 has one torso and no elbows, knees, wrists or ankles:
-- the torso takes Root then Waist, turning about the hips and waist as on R15 (the R6
-- joint pivots at the torso's centre); the legs are re-expressed against that torso;
-- arms and neck carry over. Points are in torso space.
local R6_HIPS = Vector3.new(0, -1, 0)
local R6_WAIST = Vector3.new(0, -0.6, 0)
local function about(rotation: CFrame, point: Vector3): CFrame
	return CFrame.new(point) * rotation * CFrame.new(-point)
end
local function toR6(pose: Pose, out: Pose): Pose
	local root = pose.Root or IDENTITY
	local waist = (pose.Waist or IDENTITY).Rotation
	local unwaist = waist:Inverse()
	out.RootJoint = CFrame.new(root.Position)
		* about(root.Rotation, R6_HIPS)
		* about(waist, R6_WAIST)
	out.Neck = pose.Neck or IDENTITY
	out["Left Shoulder"] = pose.LeftShoulder or IDENTITY
	out["Right Shoulder"] = pose.RightShoulder or IDENTITY
	out["Left Hip"] = unwaist * (pose.LeftHip or IDENTITY).Rotation
	out["Right Hip"] = unwaist * (pose.RightHip or IDENTITY).Rotation
	return out
end

local function signedYaw(from: Vector3, to: Vector3): number
	return math.atan2(from.Z * to.X - from.X * to.Z, from.X * to.X + from.Z * to.Z)
end

function Presentation.start(clips: Clips.Library)
	local rigs: { [Model]: any } = {}
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	local function refreshFilter()
		local list: { Instance } = {}
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
		rig.r6 = joints.RootJoint ~= nil
		rig.frames = {}
		for name, joint in joints do
			rig.frames[name] = jointFrames(joint)
		end
		rig.chain = buildChain(joints)
		-- Rest feet rest on the floor, so this is the floor height in root space.
		rig.ground = lowestPoint(rig.chain, {}, true)
		rig.unit = Clips.hipUnit(rig.character)
		-- Rest shoulder (sideways, height) in root space and arm length, for the
		-- wall-run hand.
		for _, link in rig.chain do
			local parent = framesScratch[link.parent]
			if (link.joint == "LeftShoulder" or link.joint == "Left Shoulder") and parent then
				local shoulder = (parent * link.c0).Position
				rig.shoulder = Vector2.new(math.abs(shoulder.X), shoulder.Y)
			end
		end
		local character = rig.character
		local upper = character:FindFirstChild("LeftUpperArm") :: BasePart?
		local lower = character:FindFirstChild("LeftLowerArm") :: BasePart?
		local hand = character:FindFirstChild("LeftHand") :: BasePart?
		local arm = character:FindFirstChild("Left Arm") :: BasePart?
		local shoulderJoint = joints["Left Shoulder"]
		if upper and lower and hand then
			rig.armLength = upper.Size.Y
				+ lower.Size.Y
				+ (if hand.Transparency < 1 then hand.Size.Y * 0.5 else 0)
		elseif arm and shoulderJoint then
			-- R6: from the pivot, a quarter of the way down, to the arm's end.
			rig.armLength = arm.Size.Y / 2 + Clips.attachmentFrame(shoulderJoint, "1").Y
		end
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
			landClip = nil,
			landDuration = 0,
			jumpClip = nil,
			move = nil,
			health = humanoid.Health,
			aiming = false,
			fidgetAt = workspace:GetServerTimeNow() + A.Moves.Fidget.After,
			fidgets = 0,
			moveMix = 0,
			directionWeights = {},
			actionStamp = character:GetAttribute("MovementActionTime"),
			action = nil,
			fade = nil,
			output = {},
			bank = 0,
			pitch = 0,
			lastLook = root.CFrame.LookVector,
			lastVelocity = Vector3.zero,
			aimWeight = 0,
			holdWeight = 0,
			holdStill = 0,
			holdOn = 0,
			holdVy = 0,
			holdSpring = { x = Vector2.zero, v = Vector2.zero },
			holding = false,
			drawStart = -math.huge,
			wrist = 0,
			holdStyle = {
				arm = CFrame.identity,
				waist = CFrame.identity,
				neck = CFrame.identity,
				wrist = 0,
				follow = 0.3,
				sway = 0,
			},
			gripWeld = nil,
			gripBase = CFrame.identity,
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

	-- Forward clips by speed: run -> sprint.
	local function forwardTier(speed: number, profile: any): { { any } }
		local run, sprint = clips.Run, clips.Sprint
		local points = {}
		if run then
			table.insert(points, { profile.RunSpeed * 0.92, run })
		end
		if sprint and profile.SprintSpeed > profile.RunSpeed + 0.1 then
			table.insert(points, { profile.SprintSpeed, sprint })
		end
		if #points == 0 then
			return {}
		end
		if speed <= points[1][1] then
			return { { points[1][2], 1 } }
		end
		for index = 1, #points - 1 do
			local a, b = points[index], points[index + 1]
			if speed < b[1] then
				local mix = (speed - a[1]) / (b[1] - a[1])
				return { { a[2], 1 - mix }, { b[2], mix } }
			end
		end
		return { { points[#points][2], 1 } }
	end

	-- Directional anchors (degrees from facing, + right) with the clips each blends.
	local function anchors(front: { { any } }): { { any } }
		local list: { { any } } = {}
		local function add(angle: number, name: string)
			local clip = clips[name]
			if clip then
				table.insert(list, { angle, { { clip, 1 } :: { any } } } :: { any })
			end
		end
		if #front > 0 then
			table.insert(list, { 0, front } :: { any })
		end
		add(90, "StrafeRight")
		add(-90, "StrafeLeft")
		add(180, "RunBack")
		return list
	end

	-- Directional locomotion: every direction clip shares one normalized phase so
	-- foot contacts line up; the two anchors around the travel direction blend by
	-- angle, and cadence follows ground speed within a clamped range.
	local function locomotion(rig: any, dt: number, now: number, flat: Vector3): (Pose, number)
		local speed = flat.Magnitude
		local localVelocity = rig.root.CFrame:VectorToObjectSpace(flat)
		local profile = Config.Profiles[rig.character:GetAttribute("MovementProfile") or ""]
			or Config.Profiles[Config.DefaultProfile]
		local angle = if speed > 0.01
			then math.deg(math.atan2(localVelocity.X, -localVelocity.Z))
			else 0
		local list = anchors(forwardTier(speed, profile))
		table.sort(list, function(a, b)
			return a[1] < b[1]
		end)
		local entries: { { any } } = {}
		local total = 0
		local function addAnchor(anchor: { any }, weight: number)
			if weight <= 1e-3 then
				return
			end
			for _, entry in anchor[2] do
				table.insert(entries, { entry[1], entry[2] * weight })
				total += entry[2] * weight
			end
		end
		if #list > 0 then
			-- The anchors either side of the travel angle, wrapping around behind.
			local before, after = list[#list], list[1]
			for _, anchor in list do
				if anchor[1] <= angle then
					before = anchor
				end
			end
			for index = #list, 1, -1 do
				if list[index][1] > angle then
					after = list[index]
				end
			end
			local span = (after[1] - before[1]) % 360
			local into = (angle - before[1]) % 360
			local mix = if span > 1e-3 then into / span else 0
			addAnchor(before, 1 - mix)
			addAnchor(after, mix)
		end
		-- Each clip's weight eases toward its target instead of jumping with the travel
		-- angle (owner: strafing left then right cut straight across, since reversing
		-- flips the direction in one frame). Clips no longer wanted fade out.
		local smoothed = rig.directionWeights
		local follow = Math.alpha(A.DirectionBlendRate, dt)
		local targets: { [any]: number } = {}
		local order: { any } = {}
		for _, entry in entries do
			if not targets[entry[1]] then
				table.insert(order, entry[1])
			end
			targets[entry[1]] = (targets[entry[1]] or 0) + entry[2] / total
		end
		for clip in smoothed do
			if not targets[clip] then
				targets[clip] = 0
				table.insert(order, clip)
			end
		end
		entries, total = {}, 0
		for _, clip in order do
			local current = smoothed[clip] or 0
			local weight = current + (targets[clip] - current) * follow
			if targets[clip] == 0 and weight < 0.01 then
				smoothed[clip] = nil
			else
				smoothed[clip] = weight
				table.insert(entries, { clip, weight })
				total += weight
			end
		end
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
		local humanoid = rig.humanoid
		local injured = humanoid.Health < humanoid.MaxHealth * A.Moves.InjuredBelow
		local idle = if injured and clips.IdleInjured then clips.IdleInjured else clips.Stand
		-- Braking reaches zero in a fraction of a second, so the idle mix eases
		-- toward its speed-based target instead of snapping with it.
		local target = smoothstep(speed / A.IdleBlendSpeed)
		rig.moveMix += (target - rig.moveMix) * Math.alpha(A.IdleBlendRate, dt)
		local moveWeight = rig.moveMix
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
	-- Real jumps play the mocap running jump (owner's choice); walking off an edge uses
	-- the calm original R6 Air clip instead of the jump's arm-up apex.
	local function airborne(rig: any, now: number, vy: number, height: number): (Pose?, string)
		local jump = if rig.jumped
			then rig.jumpClip or clips.Jump
			else clips.Air or rig.jumpClip or clips.Jump
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
			local sway = A.FallFromJump
			if sway then
				-- Long falls stay in the jump's own look: a slow sway about its apex.
				local fallTime = now - rig.airStart
				local phase = fallTime * 2 * math.pi / sway.Period
				local pose =
					Clips.sample(jump, apex + sway.Swing * math.sin(phase), scratch(rig, 13))
				-- Only long falls flail (owner: short drops looked like skyscraper falls).
				local flail = if clips.FallLong and not rig.jumped
					then smoothstep((fallTime - A.LongFall.After) / A.LongFall.Blend)
					else 0
				if flail > 0 then
					local long =
						Clips.sample(clips.FallLong :: Clips.Clip, fallTime, scratch(rig, 23))
					pose = Clips.blend({ pose, long }, { 1 - flail, flail }, scratch(rig, 25))
				end
				return pose, "fall"
			end
		end
		if clips.Fall then
			return Clips.sample(clips.Fall, now - rig.airStart, scratch(rig, 14)), "fall"
		end
		return nil, "none"
	end

	-- Takeoff clip from the run-up: running or standing.
	local function chooseJump(flat: Vector3, now: number): Clips.Clip?
		if flat.Magnitude > 8 then
			return Clips.pick(clips, "JumpRun", now * 7) or clips.Jump
		end
		return clips.Jump
	end

	-- One-shot transitions over grounded locomotion.
	local Moves = A.Moves
	local function startMove(rig: any, kind: string, clip: Clips.Clip?, now: number, rate: number?)
		if not clip then
			return
		end
		rig.move = {
			kind = kind,
			clip = clip,
			start = now,
			rate = rate or 1,
		}
		startFade(rig, Moves.Fade, now)
	end

	-- Picks transitions from what the body is doing (aim, health, standing
	-- still), so observers derive the same ones from replicated state.
	local function watchMoves(rig: any, now: number, flat: Vector3, grounded: boolean)
		local character, humanoid = rig.character, rig.humanoid
		local speed = flat.Magnitude
		local aiming = character:GetAttribute("Aiming") == true
		local seed = now * 13
		local health = humanoid.Health
		local hurt = health < rig.health - 0.5
		rig.health = health
		local wasAiming = rig.aiming
		rig.aiming = aiming
		local fidget = Moves.Fidget
		local injured = health < humanoid.MaxHealth * Moves.InjuredBelow
		if speed > 1 or aiming or injured or not grounded or rig.action then
			rig.fidgetAt = now + fidget.After + math.random() * fidget.Spread
		end
		if not grounded or rig.action then
			rig.move = nil
			return
		end
		if hurt then
			startMove(rig, "Flinch", Clips.pick(clips, "Flinch", seed), now)
		elseif wasAiming and not aiming and speed < 1 then
			startMove(rig, "Settle", clips.AimSettle, now)
		elseif speed < 0.5 and not rig.move and now > rig.fidgetAt then
			-- The idle fidgets take turns, layered on the live idle so it keeps going.
			rig.fidgets += 1
			local clip = clips[fidget.Clips[(rig.fidgets - 1) % #fidget.Clips + 1]]
			startMove(rig, "Fidget", clip, now)
			if clip and rig.move then
				rig.move.fadeIn, rig.move.fadeOut = fidget.FadeIn, fidget.FadeOut
				rig.move.additive = true
			end
			rig.fidgetAt = now
				+ (if clip then clip.duration else 0)
				+ fidget.After
				+ math.random() * fidget.Spread
		end
	end

	-- Plays the current transition over the base pose; returns the blended pose.
	local function applyMove(
		rig: any,
		now: number,
		speed: number,
		pose: Pose,
		floor: number
	): (Pose, number)
		local move = rig.move
		if not move then
			return pose, floor
		end
		local character = rig.character
		local elapsed = now - move.start
		local t = elapsed * move.rate
		local kind = move.kind
		local cancel = (kind == "Settle" and (speed > 1.5 or character:GetAttribute("Aiming")))
			or (kind == "Fidget" and (speed > 1.5 or character:GetAttribute("Aiming")))
		local weight = 1
		if kind == "Flinch" then
			weight = 1 - 0.5 * smoothstep(speed / A.IdleBlendSpeed)
		end
		if move.fadeIn then
			weight *= smoothstep(elapsed / move.fadeIn)
		end
		-- Hand back to locomotion over the clip's last moments instead of at its end.
		local remaining = (move.clip.duration - t) / move.rate
		weight *= smoothstep(remaining / (move.fadeOut or Moves.FadeOut))
		if cancel or t >= move.clip.duration or (weight <= 0 and elapsed > (move.fadeIn or 0)) then
			rig.move = nil
			if weight > 0 then
				startFade(rig, Moves.Fade, now)
			end
			return pose, floor
		end
		if move.additive then
			return Clips.layer(pose, move.clip, t, weight, scratch(rig, 20)), floor
		end
		local movePose = Clips.sample(move.clip, t, scratch(rig, 19))
		local result = Clips.blend({ pose, movePose }, { 1 - weight, weight }, scratch(rig, 20))
		return result, floor + (Clips.floor(move.clip, t) - floor) * weight
	end

	local ACTIONS = { Flip = true, Mantle = true, WallHop = true, Slide = true }
	local Slide = Config.Acrobatics.Slide
	local function startAction(rig: any, stamp: number, now: number)
		local character = rig.character
		local kind = character:GetAttribute("MovementAction")
		local variant = character:GetAttribute("MovementVariant") or ""
		-- A leap up a wall plays the jump's rise.
		local clip = clips[variant] or if variant == "WallKickUp" then clips.Jump else nil
		if kind == "WallRun" and now - stamp <= 1.5 then
			-- Procedural: the run cycle against the wall (see wallRunPose).
			rig.action = {
				kind = kind,
				start = now,
				side = if variant == "WallRunLeft" then -1 else 1,
			}
			rig.cling = 0
			startFade(rig, A.Fade.ActionIn * 2, now)
			return
		end
		if not clip or not ACTIONS[kind] or now - stamp > 1.5 then
			-- A stale stamp means the action was cancelled (rejected request).
			if rig.action then
				rig.action = nil
				startFade(rig, A.Fade.ActionOut, now)
			end
			return
		end
		if kind == "WallHop" then
			-- The kick is a fresh rise: hand the jump clip's rise/apex logic over.
			rig.jumped, rig.airVy0, rig.apexTime = true, Config.Traversal.WallHop.UpSpeed, now
		end
		local rate = character:GetAttribute("MovementRate")
		rig.action = {
			kind = kind,
			clip = clip,
			-- Observers start on receipt: replicated bodies are interpolated behind the
			-- owner's clock, and the attributes arrive about as late as the motion.
			start = if character == Players.LocalPlayer.Character then stamp else now,
			rate = if typeof(rate) == "number" then rate else 1,
			offset = if kind == "Flip" or kind == "WallHop" then clip.events.takeoff or 0 else 0,
		}
		startFade(rig, A.Fade.ActionIn, now)
	end

	local clingPose: Pose = {}
	local CLING_STRAIGHT = {
		"LeftElbow",
		"RightElbow",
		"LeftWrist",
		"RightWrist",
		"LeftKnee",
		"RightKnee",
		"LeftAnkle",
		"RightAnkle",
	}
	-- Wall run: the forward run cycle, body rolled away from the wall (feet toward
	-- it) and the wall-side hand reaching out to the wall. side: -1 wall on the left.
	local WallRun = Config.Traversal.WallRun
	local function wallRunPose(
		rig: any,
		dt: number,
		now: number,
		speed: number,
		side: number,
		gap: number
	): Pose
		-- The run cycle follows the real speed along the wall, and its legs slow to a
		-- stop in a cling instead of running in place.
		local forward = rig.root.CFrame.LookVector * speed
		local stride = dt * math.clamp(speed / WallRun.Cling.Below, 0, 1)
		local pose = locomotion(rig, stride, now, Vector3.new(forward.X, 0, forward.Z))
		-- A short brace follows the actual turn, including on replicated peers.
		local facing = rig.root.CFrame.LookVector
		local previous = rig.wallFacing or facing
		local yawRate = math.atan2(previous:Cross(facing).Y, previous:Dot(facing))
			/ math.max(dt, 0.001)
		rig.wallFacing = facing
		local turn = math.clamp(yawRate / WallRun.Surface.CornerRate, -1, 1)
		rig.wallBrace = (rig.wallBrace or 0) + (turn - (rig.wallBrace or 0)) * Math.alpha(16, dt)
		local brace = math.abs(rig.wallBrace)
		pose.Root = CFrame.new(0, -0.18 * brace, 0)
			* CFrame.Angles(-0.12 * brace, 0, -0.14 * rig.wallBrace)
			* (pose.Root or IDENTITY)
		pose.Neck = CFrame.Angles(0, 0.22 * rig.wallBrace, 0) * (pose.Neck or IDENTITY)
		local tilt = WallRun.Tilt
		pose.Root = CFrame.Angles(0, 0, side * tilt) * (pose.Root or IDENTITY)
		-- Spread the wall arm just enough for the hand to meet the wall (gap: root to
		-- wall surface). The roll already leans the arm toward the wall by tilt.
		local shoulder = rig.shoulder or Vector2.new(1, 1.4)
		local swing = WallRun.ArmForward
		local lateral = shoulder.X * math.cos(tilt) - shoulder.Y * math.sin(tilt)
		local reach = (gap - lateral - WallRun.HandGap) / ((rig.armLength or 2.3) * math.cos(swing))
		local spread = math.max(math.asin(math.clamp(reach, 0, 1)) - tilt, 0)
		local prefix = if side < 0 then "Left" else "Right"
		pose[prefix .. "Shoulder"] = CFrame.Angles(0, side * swing, side * spread)
		pose[prefix .. "Elbow"] = CFrame.Angles(0.35, 0, 0)
		pose[prefix .. "Wrist"] = CFrame.Angles(0, 0, -side * 0.6)
		-- Drag: lean away from the wall, brace with one raised arm and the wall-side
		-- leg. Both legs angle toward the wall instead of kicking forward; R6 limbs
		-- are straight blocks and cannot bend at the knee.
		local x = math.clamp(speed / WallRun.Cling.Below, 0, 1)
		local target = 1 - x * x * (3 - 2 * x)
		rig.cling = (rig.cling or 0) + (target - (rig.cling or 0)) * Math.alpha(20, dt)
		local cling = rig.cling
		if cling > 0.001 then
			local sway = math.sin(now * 2.6)
			local wall, free =
				if side > 0 then "Right" else "Left", if side > 0 then "Left" else "Right"
			clingPose.Root = CFrame.Angles(0, side * math.rad(25), side * math.rad(12))
			clingPose.Waist = CFrame.Angles(math.rad(-5), 0, 0)
			clingPose.Neck = CFrame.Angles(math.rad(-5), -side * math.rad(12), 0)
			clingPose[wall .. "Shoulder"] = CFrame.Angles(math.rad(-30), 0, side * math.rad(110))
			clingPose[free .. "Shoulder"] =
				CFrame.Angles(math.rad(65 + 2 * sway), 0, -side * math.rad(30))
			clingPose[wall .. "Hip"] = CFrame.Angles(math.rad(10), 0, side * math.rad(15))
			-- Keep the legs side-on without driving the free leg through the wall-side leg.
			clingPose[free .. "Hip"] = CFrame.Angles(0, 0, side * math.rad(10 + 2 * sway))
			for _, joint in CLING_STRAIGHT do
				clingPose[joint] = IDENTITY
			end
			pose = Clips.blend({ pose, clingPose }, { 1 - cling, cling }, scratch(rig, 27))
		end
		return pose
	end

	local aimPose: Pose = {}
	local Hold = A.Hold
	local holdPose: Pose = { RightElbow = IDENTITY, RightWrist = IDENTITY }
	local function euler(v: { number }): CFrame
		return CFrame.fromEulerAnglesYXZ(v[1], v[2], v[3])
	end
	type HoldStyle = {
		arm: CFrame,
		waist: CFrame,
		neck: CFrame,
		wrist: number,
		weight: number,
		follow: number,
		sway: number,
	}
	local holdStyles: { [string]: HoldStyle } = {}
	for name, style in Hold.Styles :: { [string]: any } do
		holdStyles[name] = {
			arm = euler(style.Arm),
			waist = euler(style.Waist),
			neck = euler(style.Neck),
			wrist = style.Wrist,
			weight = style.Weight,
			follow = style.TorsoFollow,
			sway = style.Sway,
		}
	end
	local function evaluate(rig: any, dt: number, now: number)
		local character, root, humanoid = rig.character, rig.root, rig.humanoid
		local velocity = root.AssemblyLinearVelocity
		local flat = Vector3.new(velocity.X, 0, velocity.Z)
		local stand = Clips.standHeight(humanoid, root)
		-- A sphere about the body's footprint, so standing on an edge (centre over
		-- the drop) still finds the ledge under the feet.
		local hit = workspace:Spherecast(
			root.Position,
			A.GroundProbeRadius,
			Vector3.new(0, -(stand + 12), 0),
			params
		)
		local height = if hit then root.Position.Y - hit.Position.Y - stand else math.huge
		-- Stairs and slopes lift the body without a jump (owner: an arm stuck up running
		-- upstairs, from the jump pose): stay grounded while rising slower than a launch.
		local grounded = height < 0.4
			and (velocity.Y < 6 or (rig.grounded and velocity.Y < A.StepRise))

		-- Ground/air transitions.
		if grounded ~= rig.grounded then
			if grounded then
				local impact = -rig.lastVy
				if now - rig.airStart > 0.08 and impact >= A.Land.MinImpact then
					local land = A.Land
					rig.landStart = now
					rig.landStrength = math.clamp(
						0.35 + 0.65 * (impact - land.MinImpact) / (land.FullImpact - land.MinImpact),
						0,
						1
					)
					rig.landClip, rig.landDuration = clips.Land, land.Duration
					if impact >= land.Heavy.Impact and clips.LandHeavy then
						rig.landClip, rig.landDuration, rig.landStrength =
							clips.LandHeavy, land.Heavy.Duration, 1
					elseif impact >= land.Hard.Impact and clips.LandHard then
						rig.landClip, rig.landDuration, rig.landStrength =
							clips.LandHard, land.Hard.Duration, 1
					end
				end
				-- Landing on the run blends from the air pose into the stride (owner: a
				-- running landing showed spread legs and cut to the run).
				startFade(
					rig,
					if flat.Magnitude > A.IdleBlendSpeed then A.Fade.LandMoving else A.Fade.Land,
					now
				)
			else
				rig.airStart = now
				-- A launch, not stairs: stepping off the top of a staircase can rise past 10.
				rig.jumped = velocity.Y > A.StepRise
				rig.airVy0 = velocity.Y
				rig.airState = ""
				rig.jumpClip = if rig.jumped then chooseJump(flat, now) else nil
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
		watchMoves(rig, now, flat, grounded)
		if grounded then
			pose, floor = locomotion(rig, dt, now, flat)
			contact = "feet"
			pose, floor = applyMove(rig, now, flat.Magnitude, pose, floor)
			local land = rig.landClip or clips.Land
			local landTime = now - rig.landStart
			local duration = if rig.landClip then rig.landDuration else A.Land.Duration
			if land and landTime < duration then
				local moveWeight = smoothstep(flat.Magnitude / A.IdleBlendSpeed)
				local weight = rig.landStrength
					* (1 - smoothstep(landTime / duration) ^ 2)
					* (1 - moveWeight * A.Land.MovingScale)
				local landAt = (land.events.contact or 0) + landTime * A.Land.Rate
				local landPose = Clips.sample(land, landAt, scratch(rig, 15))
				pose = Clips.blend({ pose, landPose }, { 1 - weight, weight }, scratch(rig, 16))
				floor += (Clips.floor(land, landAt) - floor) * weight
			end
		else
			local airPose, state = airborne(rig, now, velocity.Y, height)
			if state ~= rig.airState then
				-- A jump's takeoff eases in too; walk-offs blend from the run below.
				if rig.airState ~= "" or rig.jumped then
					startFade(rig, A.Fade.Air, now)
				end
				rig.airState = state
			end
			pose = airPose or locomotion(rig, dt, now, flat)
			-- Walking off an edge keeps running for a moment and eases into the fall
			-- (owner: stepping off stairs cut straight to falling; wall-run kicks are
			-- smooth). Short drops down stairs stay in the run.
			local walkOff = now - rig.airStart
			if airPose and not rig.jumped and walkOff < A.WalkOff then
				local running = locomotion(rig, dt, now, flat)
				local weight = smoothstep(walkOff / A.WalkOff)
				pose = Clips.blend({ running, airPose }, { 1 - weight, weight }, scratch(rig, 26))
			end
		end

		-- Action layer (flip, mantle, kick, slide) replaces the base pose; fades cover entry/exit.
		local action = rig.action
		if not action or action.kind ~= "WallRun" then
			rig.wallFacing, rig.wallBrace = nil, 0
		end
		local actionWeight = 0
		if action and action.kind == "WallRun" then
			-- Ends on the ground or once the wall is no longer beside the body.
			-- Observers can receive the action before the replicated body leaves the
			-- ground, so those checks wait a moment.
			local elapsed = now - action.start
			-- The wall's side is found each frame: a run can turn round (steering).
			local right = rig.root.CFrame.RightVector * (WallRun.Reach + 1)
			local onRight = workspace:Raycast(root.Position, right, params)
			local onLeft = workspace:Raycast(root.Position, -right, params)
			local wall = onRight
			if onLeft and (not onRight or onLeft.Distance < onRight.Distance) then
				wall, action.side = onLeft, -1
			elseif onRight then
				action.side = 1
			end
			if wall then
				action.lastWall = now
			end
			local lostWall = not wall
				and now - (action.lastWall or action.start) > WallRun.Surface.Grace + 0.2
			if elapsed > WallRun.SettleTime and (grounded or lostWall) then
				rig.action = nil
				startFade(rig, A.Fade.ActionOut, now)
			else
				local gap = if wall then wall.Distance else WallRun.Hug
				-- Speed along the wall only: the pull toward the wall is not running.
				local normal = if wall
					then Vector3.new(wall.Normal.X, 0, wall.Normal.Z)
					else root.CFrame.RightVector
				normal = if normal.Magnitude > 0.01 then normal.Unit else root.CFrame.RightVector
				local along = (flat - normal * flat:Dot(normal)).Magnitude
				pose = wallRunPose(rig, dt, now, along, action.side, gap)
				actionWeight = 1
				floor, contact = 0, nil
			end
		elseif action then
			local clip = action.clip
			local t = action.offset + (now - action.start) * action.rate
			local finished
			if action.kind == "Mantle" then
				finished = t >= clip.duration
			elseif action.kind == "WallHop" then
				finished = t >= clip.duration or (grounded and now - action.start > 0.1)
			elseif action.kind == "Slide" then
				-- The owner's client marks its own end (jump or Shift cancel); observers end
				-- on leaving the ground or slowing down.
				local elapsed = now - action.start
				local ended = character:GetAttribute("MovementActionEnd")
				finished = elapsed >= Slide.Duration
					or (typeof(ended) == "number" and ended >= action.start)
					or (not grounded and elapsed > 0.12)
					or (elapsed > 0.2 and flat.Magnitude < Slide.EndSpeed * 0.6)
			else
				action.airborne = action.airborne or not grounded
				finished = t >= (clip.events.land or clip.duration)
					or (grounded and action.airborne)
					or (grounded and now - action.start > 0.5)
			end
			if finished then
				rig.action = nil
				-- A mantle ends mid-motion on top, so it hands over more gently.
				startFade(
					rig,
					if action.kind == "Mantle" then A.Fade.MantleOut else A.Fade.ActionOut,
					now
				)
			else
				pose = Clips.sample(clip, t, scratch(rig, 17))
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

		-- Held pistol in the selected style (HoldVariant, cycled on G), layered over the
		-- body's own motion (Hold.Carry): full when standing, looser when running, sprinting
		-- or airborne, and light in actions, so runs, slides and flips keep their swing. A
		-- standing arm is partly steadied against the torso; a moving one rides it. A spring
		-- adds follow-through from turns, take-offs and landings. Style changes ease in.
		local tool = character:FindFirstChildOfClass("Tool")
		local holding = tool ~= nil and tool:GetAttribute("HoldStyle") == "Pistol"
		if holding and not rig.holding then
			rig.drawStart = now
		end
		rig.holding = holding
		local style = holdStyles[character:GetAttribute("HoldVariant") or ""]
			or holdStyles[Hold.Default]
		local carry = Hold.Carry
		local running = math.clamp(flat.Magnitude / carry.RunSpeed, 0, 1)
		local sprinting = math.clamp(
			(flat.Magnitude - carry.RunSpeed) / (carry.SprintSpeed - carry.RunSpeed),
			0,
			1
		)
		local presence, still = 0, 0
		if holding then
			if actionWeight > 0 and action then
				presence = (carry.Actions :: { [string]: number })[action.kind] or carry.Air
			elseif not grounded then
				presence = carry.Air
			else
				presence = carry.Idle
					+ (carry.Run - carry.Idle) * running
					+ (carry.Sprint - carry.Run) * sprinting
				still = 1 - running
			end
			presence *= style.weight
		end
		local holdAlpha = Math.alpha(Hold.Rate, dt)
		rig.holdWeight += (presence - rig.holdWeight) * holdAlpha
		rig.holdStill += (still - rig.holdStill) * holdAlpha
		rig.holdOn += ((if holding then 1 else 0) - rig.holdOn) * holdAlpha
		local current = rig.holdStyle
		current.arm = current.arm:Lerp(style.arm, holdAlpha)
		current.waist = current.waist:Lerp(style.waist, holdAlpha)
		current.neck = current.neck:Lerp(style.neck, holdAlpha)
		current.wrist += (style.wrist - current.wrist) * holdAlpha
		current.follow += (style.follow - current.follow) * holdAlpha
		current.sway += (style.sway - current.sway) * holdAlpha
		-- Follow-through spring (pitch, yaw): turns push the gun behind, take-offs kick it
		-- up and landings dip it; it settles back with a little bounce.
		local spring = rig.holdSpring
		local dVy = if holding then velocity.Y - rig.holdVy else 0
		rig.holdVy = velocity.Y
		spring.v += Vector2.new(-dVy * carry.Dip, -yawRate * carry.Lag * dt)
		local k = carry.Spring
		spring.v += (-k * spring.x - 2 * math.sqrt(k) * carry.Damping * spring.v) * dt
		spring.x += spring.v * dt
		spring.x = Vector2.new(
			math.clamp(spring.x.X, -carry.MaxSway, carry.MaxSway),
			math.clamp(spring.x.Y, -carry.MaxSway, carry.MaxSway)
		)
		-- Draw: the blaster spins about the trigger finger (ease-out, ending a whole turn
		-- round so it settles without a jump) while the arm flourishes up.
		local externalDraw = tool ~= nil and tool:GetAttribute("BlasterMotionDriver") == true
		local draw = if externalDraw
			then 1
			else math.clamp((now - rig.drawStart) / Hold.DrawTime, 0, 1)
		local spin = if holding then -2 * math.pi * Hold.DrawSpins * (1 - (1 - draw) ^ 3) else 0
		local lift = if holding then Hold.DrawLift * math.sin(math.pi * draw) else 0
		rig.wrist = current.wrist * math.min(rig.holdWeight, 1) + spin
		if rig.holdWeight > 0.001 then
			local styled = rig.holdWeight * rig.holdStill
			local waist = pose.Waist or IDENTITY
			pose.Waist = waist:Lerp(current.waist * waist, styled)
			local neck = pose.Neck or IDENTITY
			pose.Neck = neck:Lerp(current.neck * neck, styled)
			local torso = CFrame.Angles(rig.pitch, 0, rig.bank)
				* (pose.Root or IDENTITY).Rotation
				* (pose.Waist or IDENTITY).Rotation
			local level = IDENTITY:Lerp(torso:Inverse(), rig.holdStill * (1 - current.follow))
			local drift = CFrame.Angles(
				math.sin(now * 2.1) * current.sway * rig.holdStill + lift,
				math.sin(now * 1.3 + 1) * current.sway * rig.holdStill,
				0
			)
			holdPose.RightShoulder = level * drift * current.arm
			for name, value in holdPose do
				pose[name] = (pose[name] or IDENTITY):Lerp(value, rig.holdWeight)
			end
		end
		if rig.holdOn > 0.001 then
			local x = spring.x * rig.holdOn
			pose.RightShoulder = CFrame.Angles(x.X, x.Y, 0) * (pose.RightShoulder or IDENTITY)
		end

		for _, limb in A.FoldLimbs do
			pose[limb[1]] = chord(pose[limb[1]], pose[limb[2]])
			pose[limb[2]], pose[limb[3]] = nil, nil
		end

		-- Root: clip translation is in hip units.
		local rootPose = pose.Root or IDENTITY
		rootPose = CFrame.new(rootPose.Position * rig.unit) * rootPose.Rotation
		rootPose = CFrame.Angles(rig.pitch, 0, rig.bank) * rootPose

		-- Ground contact: keep the feet (or, for a slide, the whole body) at the clip's
		-- intended clearance using the real rig's proportions.
		pose.Root = rootPose
		local rigPose = if rig.r6 then toR6(pose, scratch(rig, 24)) else pose
		if rig.r6 and action and action.kind == "WallRun" and rig.cling then
			-- The R6 shoulder pivot is inside the block arm: at the raised drag angle
			-- it sinks into the torso. Ease the arm outward and slightly up/forward as
			-- the drag pose takes over; keep the wall-side reach and torso unchanged.
			local side, weight = action.side, rig.cling
			local shoulderName = if side < 0 then "Left Shoulder" else "Right Shoulder"
			rigPose[shoulderName] = CFrame.new(side * 0.35 * weight, 0.15 * weight, -0.3 * weight)
				* (rigPose[shoulderName] or IDENTITY)
		end
		local rootJoint = if rig.r6 then "RootJoint" else "Root"
		local correction = 0
		if contact then
			local lowest = lowestPoint(rig.chain, rigPose, contact == "feet")
			local pullDown = contact ~= "feet" or A.GroundContact.PullDown
			correction = math.clamp(
				rig.ground + floor * rig.unit - lowest,
				if pullDown then -A.GroundContact.Max else 0,
				A.GroundContact.Max
			)
		end
		rig.footOffset += (correction - rig.footOffset) * Math.alpha(A.GroundContact.Rate, dt)
		rigPose[rootJoint] = CFrame.new(0, rig.footOffset, 0) * (rigPose[rootJoint] or IDENTITY)

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
			local value = rigPose[name] or IDENTITY
			if fade and fadeAlpha < 1 then
				value = (fade.from[name] or IDENTITY):Lerp(value, fadeAlpha)
			end
			rig.output[name] = value
			local frames = rig.frames[name]
			joint.Transform = frames[1] * value * frames[2]
		end
		-- Wrist: R6 has none, so the tool's grip weld turns the held blaster about the hand.
		local arm = character:FindFirstChild("Right Arm")
		local grip = arm and arm:FindFirstChild("RightGrip")
		if grip and grip:IsA("Weld") then
			if rig.gripWeld ~= grip then
				rig.gripWeld, rig.gripBase = grip, grip.C0
			end
			grip.C0 = rig.gripBase * CFrame.Angles(if holding then rig.wrist else 0, 0, 0)
		end
		-- What was rendered, for the Studio probe only: attribute writes every frame for
		-- every character are wasted work in a live game.
		if DEBUG_POSES then
			character:SetAttribute(
				"RenderedAction",
				if action and rig.action then action.kind else ""
			)
			character:SetAttribute("RenderedMove", if rig.move then rig.move.kind else "")
			character:SetAttribute(
				"RenderedLand",
				if rig.landClip and now - rig.landStart < rig.landDuration
					then rig.landClip.name
					else ""
			)
			character:SetAttribute("RenderedJump", if rig.jumpClip then rig.jumpClip.name else "")
			character:SetAttribute(
				"RenderedClip",
				if rig.action
					then (if rig.action.clip then rig.action.clip.name else rig.action.kind)
					else ""
			)
			character:SetAttribute("RenderedAirState", if grounded then "ground" else rig.airState)
			character:SetAttribute("RenderedCyclePhase", rig.phase)
			character:SetAttribute("RenderedFootOffset", rig.footOffset)
		end
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
