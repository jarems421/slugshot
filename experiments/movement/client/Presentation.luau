--!strict
-- Clip-driven R15 presentation for every character: directional locomotion whose
-- cadence follows ground speed, crouch, physics-driven jump/fall, tiered landings,
-- one-shot transitions (start, stop, turn, crouch, settle, fidget, flinch),
-- roll/flip/mantle/vault/wall-hop actions, lean and ground-contact correction.
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
}

local A = Config.Animation
local IDENTITY = CFrame.identity
local BREATH_JOINTS = { "Waist", "Neck" }
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
		-- Rest shoulder (sideways, height) in root space and arm length, for the
		-- wall-run hand.
		for _, link in rig.chain do
			local parent = framesScratch[link.parent]
			if link.joint == "LeftShoulder" and parent then
				local shoulder = (parent * link.c0).Position
				rig.shoulder = Vector2.new(math.abs(shoulder.X), shoulder.Y)
			end
		end
		local character = rig.character
		local upper = character:FindFirstChild("LeftUpperArm") :: BasePart?
		local lower = character:FindFirstChild("LeftLowerArm") :: BasePart?
		local hand = character:FindFirstChild("LeftHand") :: BasePart?
		if upper and lower and hand then
			rig.armLength = upper.Size.Y + lower.Size.Y + hand.Size.Y * 0.5
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
			crouched = false,
			aiming = false,
			idleSince = 0,
			moveMix = 0,
			fastAt = -math.huge,
			fastBack = false,
			stopped = true,
			wasMoving = false,
			runDirection = nil,
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

	-- Forward clips by speed: jog (if present) -> run -> sprint.
	local function forwardTier(speed: number, profile: any): { { any } }
		local points = {}
		if clips.Jog then
			table.insert(points, { profile.RunSpeed * 0.45, clips.Jog })
		end
		if clips.Run then
			table.insert(points, { profile.RunSpeed * 0.92, clips.Run })
		end
		if clips.Sprint and profile.SprintSpeed > profile.RunSpeed + 0.1 then
			table.insert(points, { profile.SprintSpeed, clips.Sprint })
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
	local function anchors(crouched: boolean, front: { { any } }): { { any } }
		local list = {}
		local function add(angle: number, name: string)
			local clip = clips[name]
			if clip then
				table.insert(list, { angle, { { clip, 1 } } })
			end
		end
		if crouched then
			add(0, "CrouchForward")
			add(90, "CrouchRight")
			add(180, "CrouchBack")
			add(-90, "CrouchLeft")
			return list
		end
		if #front > 0 then
			table.insert(list, { 0, front })
		end
		add(45, "SprintForwardRight")
		add(-45, "SprintForwardLeft")
		add(90, "StrafeRight")
		add(-90, "StrafeLeft")
		add(135, "SprintBackRight")
		add(-135, "SprintBackLeft")
		if not (clips.SprintBackRight and clips.SprintBackLeft) then
			add(180, "RunBack")
		end
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
		local crouched = rig.character:GetAttribute("Crouching") == true and clips.CrouchIdle ~= nil
		local angle = if speed > 0.01
			then math.deg(math.atan2(localVelocity.X, -localVelocity.Z))
			else 0
		local list = anchors(crouched, forwardTier(speed, profile))
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
		local idle = if crouched
			then clips.CrouchIdle
			elseif injured and clips.IdleInjured then clips.IdleInjured
			else clips.Idle
		-- Braking reaches zero in a fraction of a second, so the idle mix eases
		-- toward its speed-based target instead of snapping with it.
		local target = smoothstep(speed / A.IdleBlendSpeed)
		rig.moveMix += (target - rig.moveMix) * Math.alpha(A.IdleBlendRate, dt)
		local moveWeight = rig.moveMix
		if not idle or moveWeight >= 0.999 then
			return moving, floor
		end
		local idlePose, idleFloor
		if crouched and clips.CrouchForward then
			-- The crouch idle sits lower and drops its hands to the floor: stand in the
			-- crouch walk's stance instead (same height and arms), breathing with the
			-- crouch idle's torso and head.
			idlePose = Clips.sample(clips.CrouchForward, 0, scratch(rig, 11))
			idleFloor = Clips.floor(clips.CrouchForward, 0)
			local breath = Clips.sample(idle, now, scratch(rig, 21))
			local rest = Clips.sample(idle, 0, scratch(rig, 22))
			for _, joint in BREATH_JOINTS do
				idlePose[joint] = (idlePose[joint] or IDENTITY)
					* (rest[joint] or IDENTITY):Inverse()
					* (breath[joint] or IDENTITY)
			end
		else
			idlePose = Clips.sample(idle, now, scratch(rig, 11))
			idleFloor = Clips.floor(idle, now)
		end
		if #poses == 0 then
			return idlePose, idleFloor
		end
		return Clips.blend({ idlePose, moving }, { 1 - moveWeight, moveWeight }, scratch(rig, 12)),
			idleFloor + (floor - idleFloor) * moveWeight
	end

	-- Airborne: rise through the jump clip as vertical speed decays, carry the
	-- apex, then reach for the ground over the clip's final air time.
	local function airborne(rig: any, now: number, vy: number, height: number): (Pose?, string)
		local jump = rig.jumpClip or clips.Jump
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
				local phase = (now - rig.airStart) * 2 * math.pi / sway.Period
				return Clips.sample(jump, apex + sway.Swing * math.sin(phase), scratch(rig, 13)),
					"fall"
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
	local function startMove(
		rig: any,
		kind: string,
		clip: Clips.Clip?,
		now: number,
		rate: number?,
		offset: number?,
		hold: number?
	)
		if not clip then
			return
		end
		rig.move = {
			kind = kind,
			clip = clip,
			start = now,
			rate = rate or 1,
			offset = offset or 0,
			hold = hold,
		}
		startFade(rig, Moves.Fade, now)
	end

	-- Picks transitions from what the body is doing (speed, turns, crouch, aim,
	-- health), so observers derive the same ones from replicated state.
	local function watchMoves(rig: any, now: number, flat: Vector3, grounded: boolean)
		local character, humanoid = rig.character, rig.humanoid
		local speed = flat.Magnitude
		local aiming = character:GetAttribute("Aiming") == true
		local crouched = character:GetAttribute("Crouching") == true
		local seed = now * 13
		local health = humanoid.Health
		local hurt = health < rig.health - 0.5
		rig.health = health
		local wasCrouched, wasAiming = rig.crouched, rig.aiming
		rig.crouched, rig.aiming = crouched, aiming
		local idleFor = now - rig.idleSince
		if speed > 1 or aiming or crouched or not grounded then
			rig.idleSince = now
		end
		if not grounded or rig.action then
			rig.move = nil
			rig.wasMoving = speed > 1
			return
		end
		if hurt then
			startMove(rig, "Flinch", Clips.pick(clips, "Flinch", seed), now)
		elseif crouched ~= wasCrouched then
			if crouched then
				-- Settling into the crouch set is a crossfade, not a clip.
				rig.move = nil
				startFade(rig, Moves.Crouch.Fade, now)
			elseif speed > 4 then
				startMove(rig, "Crouch", clips.CrouchExitRun, now, Moves.Crouch.Rate)
			else
				startMove(rig, "Crouch", clips.CrouchExit, now, Moves.Crouch.Rate)
			end
		elseif wasAiming and not aiming and speed < 1 and not crouched then
			startMove(rig, "Settle", clips.AimSettle, now)
		elseif not rig.wasMoving and speed > 1 and not crouched then
			if idleFor > Moves.Start.IdleTime then
				local start = Moves.Start
				startMove(rig, "Start", clips.Start, now, start.Rate, start.Offset, start.Hold)
			end
		elseif speed > Moves.Turn.MinSpeed and not aiming and not crouched then
			-- A reversal passes through a stop: compare with the last fast direction.
			local direction = flat.Unit
			if
				rig.runDirection
				and direction:Dot(rig.runDirection) < Moves.Turn.Dot
				and now - rig.fastAt < Moves.Turn.Window
			then
				local turn = Moves.Turn
				startMove(rig, "Turn", clips.Turn, now, turn.Rate, 0, turn.Hold)
				rig.runDirection = direction
			end
		elseif speed < 4 and now - rig.fastAt < 0.35 and not crouched and not rig.stopped then
			rig.stopped = true
			local stop = Moves.Stop
			local clip = if rig.fastBack and clips.StopBack
				then clips.StopBack
				elseif aiming and clips.StopAim then clips.StopAim
				else clips.Stop
			startMove(rig, "Stop", clip, now, stop.Rate, stop.Offset)
		end
		if speed > Moves.Stop.MinSpeed then
			rig.fastAt = now
			rig.stopped = false
			rig.fastBack = rig.root.CFrame.LookVector:Dot(flat) < -0.3 * speed
		end
		if speed > Moves.Turn.MinSpeed then
			local direction = flat.Unit
			rig.runDirection = if rig.runDirection
				then (rig.runDirection:Lerp(direction, 0.15)).Unit
				else direction
		elseif now - rig.fastAt > Moves.Turn.Window then
			rig.runDirection = nil
		end
		rig.wasMoving = speed > 1
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
		local t = move.offset + elapsed * move.rate
		local kind = move.kind
		local cancel = (kind == "Start" and speed < 1)
			or (kind == "Stop" and speed > 6)
			or (kind == "Settle" and (speed > 1.5 or character:GetAttribute("Aiming")))
		local weight = 1
		if move.hold then
			weight = 1 - smoothstep((elapsed - move.hold) / Moves.Fade)
		elseif kind == "Flinch" then
			weight = 1 - 0.5 * smoothstep(speed / A.IdleBlendSpeed)
		end
		-- Hand back to locomotion over the clip's last moments instead of at its end.
		local remaining = (move.clip.duration - t) / move.rate
		weight *= smoothstep(remaining / Moves.FadeOut)
		if cancel or t >= move.clip.duration or weight <= 0 then
			rig.move = nil
			if weight > 0 then
				startFade(rig, Moves.Fade, now)
			end
			return pose, floor
		end
		local movePose = Clips.sample(move.clip, t, scratch(rig, 19))
		local result = Clips.blend({ pose, movePose }, { 1 - weight, weight }, scratch(rig, 20))
		return result, floor + (Clips.floor(move.clip, t) - floor) * weight
	end

	local ACTIONS = { Roll = true, Flip = true, Mantle = true, WallHop = true }
	local function startAction(rig: any, stamp: number, now: number)
		local character = rig.character
		local kind = character:GetAttribute("MovementAction")
		local variant = character:GetAttribute("MovementVariant") or ""
		local clip = clips[variant]
		if kind == "WallRun" and now - stamp <= 1.5 then
			-- Procedural: the run cycle against the wall (see wallRunPose).
			rig.action = {
				kind = kind,
				start = now,
				side = if variant == "WallRunLeft" then -1 else 1,
			}
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
			offset = if kind == "Flip" or kind == "WallHop" then clip.events.takeoff or 0 else 0,
			yaw = yaw,
		}
		startFade(rig, A.Fade.ActionIn, now)
	end

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
		local forward = rig.root.CFrame.LookVector * math.max(speed, WallRun.Speed)
		local pose = locomotion(rig, dt, now, Vector3.new(forward.X, 0, forward.Z))
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
		return pose
	end

	local aimPose: Pose = {}
	local function evaluate(rig: any, dt: number, now: number)
		local character, root, humanoid = rig.character, rig.root, rig.humanoid
		local velocity = root.AssemblyLinearVelocity
		local flat = Vector3.new(velocity.X, 0, velocity.Z)
		local stand = humanoid.HipHeight + root.Size.Y / 2
		-- A sphere about the body's footprint, so standing on an edge (centre over
		-- the drop) still finds the ledge under the feet.
		local hit = workspace:Spherecast(
			root.Position,
			A.GroundProbeRadius,
			Vector3.new(0, -(stand + 12), 0),
			params
		)
		local height = if hit then root.Position.Y - hit.Position.Y - stand else math.huge
		local grounded = height < 0.4 and velocity.Y < 6

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
				startFade(rig, A.Fade.Land, now)
			else
				rig.airStart = now
				rig.jumped = velocity.Y > 10
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
		if action and action.kind == "WallRun" then
			-- Ends on the ground, on timeout, or once the wall is no longer beside the body.
			-- Observers can receive the action before the replicated body leaves the
			-- ground, so those checks wait a moment.
			local elapsed = now - action.start
			local sideways = rig.root.CFrame.RightVector * action.side
			local wall = workspace:Raycast(root.Position, sideways * (WallRun.Reach + 1), params)
			if
				elapsed > WallRun.MaxTime + 0.2
				or elapsed > WallRun.SettleTime and (grounded or not wall)
			then
				rig.action = nil
				startFade(rig, A.Fade.ActionOut, now)
			else
				local gap = if wall then wall.Distance else WallRun.Hug
				pose = wallRunPose(rig, dt, now, flat.Magnitude, action.side, gap)
				actionWeight = 1
				floor, contact = 0, nil
			end
		elseif action then
			local clip = action.clip
			local t = action.offset + (now - action.start) * action.rate
			local finished
			if action.kind == "Roll" then
				local recover = clip.events.recover or clip.duration
				finished = t >= clip.duration
					or (t >= recover and flat.Magnitude > A.IdleBlendSpeed)
					or not grounded and now - action.start > 0.25
			elseif action.kind == "Mantle" then
				finished = t >= clip.duration
			elseif action.kind == "WallHop" then
				finished = t >= clip.duration or (grounded and now - action.start > 0.1)
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
