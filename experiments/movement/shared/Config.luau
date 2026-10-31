--!strict
-- Experimental profiles, not final game balance or controls.
return table.freeze({
	DefaultProfile = "Athletic",
	Profiles = {
		Baseline = {
			RunSpeed = 16,
			SprintSpeed = 16,
			Acceleration = 180,
			Braking = 220,
			TurnRate = 30,
			JumpPower = 51,
			JumpGravity = 1, -- stock Roblox jump
		},
		Athletic = {
			RunSpeed = 22, -- owner (2026-10-30): was 24; a clearer step up to the 30 sprint
			SprintSpeed = 30,
			Acceleration = 100,
			Braking = 145,
			TurnRate = 18,
			-- Slightly higher and a longer arc for more horizontal reach (owner, 2026-10-30).
			JumpPower = 60.5,
			JumpGravity = 1,
		},
		Precise = {
			RunSpeed = 21,
			SprintSpeed = 27,
			Acceleration = 130,
			Braking = 180,
			TurnRate = 24,
			JumpPower = 58.5,
			JumpGravity = 1,
		},
	},
	-- Space again in the air is a double-jump flip; Shift is a slide. There is no
	-- ground roll (owner, 2026-10-30: removed).
	Acrobatics = {
		-- Owner (2026-10-30): jumping off the edge of a ledge sometimes did the double-jump
		-- flip, because the Humanoid's floor check missed the ledge under the feet. A jump
		-- press is a ground jump while anything is under the body's footprint (radius,
		-- studs; the server's touchdown check uses it too), or within Coyote seconds of
		-- walking off without jumping.
		Jump = { Footprint = 1, Coyote = 0.15, AirSpeedScale = 1.08 },
		Flip = {
			MinRate = 0.85,
			MaxRate = 2.6,
			-- Owner: a second Space press in the air is a double jump that flips toward
			-- the keys held (eight ways, as seen on screen). Upward speed it launches with,
			-- and how soon after leaving the ground it is allowed.
			DoubleJump = 44,
			DoubleJumpDelay = 0.1,
			Buffer = 0.35, -- a second press sooner than the delay is held this long, then fires
		},
		-- Owner (2026-10-29): Shift is a slide, CoD/Rivals style: low and fast, keeping
		-- momentum, quick to cancel. Jump during it leaps out with its speed; Shift again
		-- stands up.
		Slide = {
			MinSpeed = 12, -- ground speed needed to start
			Boost = 15, -- start speed: current (at least RunSpeed) plus this
			MaxSpeed = 46,
			EndSpeed = 20, -- speed it slows to by Duration
			Duration = 0.8,
			Steer = 1.2, -- radians per second it can turn toward the input
			Cooldown = 0.25, -- between slide starts
			Buffer = 0.4, -- a press that cannot start yet (airborne, busy, cooldown) waits this long
			AirDecay = 10, -- studs/s^2 that speed above the run target bleeds in the air
			CameraDrop = 1.4,
			WallClearance = 1.2, -- ends the slide this close to a wall ahead
		},
	},
	-- Jump-triggered traversal, adapted from the Place1 movement system (MIT):
	-- jump into a ledge to climb onto it, jump near a wall in the air to kick off it.
	Traversal = {
		Mantle = {
			Reach = 3.6, -- studs ahead of the root a wall is detected
			MinHeight = 0.7, -- ledge height above the feet, studs
			MaxHeight = 5.7,
			LowHeight = 3.2, -- below: one-hand step-up; above: two-hand climb-up
			-- Pop-up (MantleVault) when the jump brings the feet within this of the ledge
			-- top at its face; further below, a step-up or climb-up by height.
			ParkourReach = 2,
			-- Owner (2026-10-30): 0.2-0.3 s was over before it could be seen; visible and
			-- frictionless, not slow.
			Duration = { Base = 0.32, PerStud = 0.05, Min = 0.38, Max = 0.6 },
			MaxRate = 5, -- a clip longer than Duration plays up to this fast, then stretches the climb
			HangGap = 0.8, -- root distance from the wall face while the hands plant
			ExitSpeed = 1, -- fraction of the approach speed kept on top
			ExitMin = 14,
			Cooldown = 0.2,
			CheckInterval = 0.055, -- ledge checks while jump is held
			JumpWindow = 0.34, -- seconds after a jump press that ledges still count
			-- Only ledges the jump would not clear are mantled: if the feet are predicted
			-- to pass ClearMargin over the top before reaching the face, it is a plain jump.
			ClearMargin = 0.4,
			MinGroundHeight = 2.2, -- ledges lower than this above the ground below are jumped or stepped onto
			ClearApproach = 8, -- minimum approach speed assumed for that prediction
		},
		WallHop = {
			Reach = 4.5, -- from the root: about 3.5 studs of gap beside the body
			-- Owner (2026-10-30): kicks off a wall should go further, carrying the momentum.
			AwaySpeed = 40,
			UpSpeed = 54,
			TangentCarry = 0.8, -- fraction of along-wall speed kept
			MaxTangent = 32,
			-- Horizontal speed kept once a kick hands back control (it then bleeds in the air
			-- at Slide.AirDecay, as a slide-jump does), instead of dropping to sprint speed.
			MaxCarry = 44,
			MaxHops = 8, -- per airtime (wall-run jumps count); enough to climb between two walls
			Cooldown = 0.15,
			-- Owner (2026-10-30): wall jumps were not responsive. No hop this soon after leaving
			-- the ground (was 0.13). An air press with a wall in Reach, or one the body will
			-- reach within Buffer at its approach speed (looking at most LookAhead further),
			-- waits for the kick instead of being spent on the flip.
			GroundDelay = 0.06,
			LookAhead = 4,
			Buffer = 0.35, -- an airborne press too early or out of reach is retried this long
			LockTime = 0.22, -- seconds the kick owns movement before input resumes
			RefreshFlip = true, -- a hop restores the airborne flip
			-- The kick goes where the input points (camera relative; the camera's facing
			-- with none), leaving the wall at least asin(MinOut) = 30 degrees out (owner:
			-- full control of the direction). Input more straight into the wall than UpInto
			-- (about 32 degrees) leaps up it instead, once per wall per airtime.
			MinOut = 0.5,
			UpInto = 0.85,
			Up = { Speed = 58, Away = 3, Carry = 0.3 },
		},
		-- Jumping into a thin, low obstacle at speed kong-vaults over it.
		Vault = {
			MaxHeight = 3.6,
			MaxDepth = 3.2, -- obstacle thickness
			LandDistance = 2.4, -- beyond the far edge, at least
			-- Owner (2026-10-30): the vault lost the run's momentum. It keeps the approach
			-- speed: timed so the hands plant (PlantAt, the clip's plant time over its
			-- length) as the body reaches the wall, landing as far past it as that speed
			-- carries (up to MaxLand, on open ground), within Time seconds.
			PlantAt = 0.15 / 0.58,
			Time = { Min = 0.4, Max = 0.7 },
			MaxLand = 8,
			MinSpeed = 9,
			LookAhead = 0.12, -- seconds of approach: a jump pressed this early still vaults
			Clearance = 0.7, -- feet above the top at the peak
		},
		-- Jumping onto a wall while running along it attaches and locks on: run along
		-- the wall, climbing while Jump is held and sliding down otherwise, until a
		-- Jump tap kicks off, the feet reach the ground or the wall ends. No clip
		-- needed; the kick uses WallJump clips.
		WallRun = {
			Reach = 4.2, -- from the root to the wall surface
			Hug = 2.1, -- root distance from the wall held while attached
			MinAlong = 12, -- along-wall speed needed to attach
			MaxInto = 0.8, -- travel more head-on than this (dot into the wall) does not attach
			MinInput = 0.3, -- move input along the wall needed to attach
			MinHeight = 2, -- feet above the ground needed to attach
			Speed = 34, -- run speed on the wall with input along it (owner, 2026-10-30: was 26)
			-- Steering (studs/s^2): toward the input's speed along the wall (Steer), or down to
			-- it from a faster attach (Bleed); TurnRate turns the body when it reverses.
			Steer = 120, -- toward the input's speed along the wall
			Stop = 400, -- owner: letting go stops at once (34 to 0 in under 0.1 s)
			-- Clinging (owner, 2026-10-30): jumping into a wall (moving into it faster than
			-- Into, or holding into it) attaches without running; below Below studs/s along
			-- the wall it turns into the drag pose, held Hug studs from the wall, and drags
			-- down at Drag, reaching it at Accel (studs/s^2), including with Space held.
			Cling = { Into = 4, Below = 6, Drag = 4, Hug = 1.85, Accel = 200 },
			Bleed = 12,
			TurnRate = 14,
			-- Owner (2026-10-30): attaching was delayed and stuck lower than the jump was
			-- heading. It can attach this soon after leaving the ground (MinHeight still keeps
			-- it off the floor), keeping more of the jump's rise.
			GroundDelay = 0.03,
			Rise = { Min = 4, Max = 20, Carry = 0.55 }, -- upward speed on attach: Carry of the jump's, clamped
			-- Jump on a wall run: a press climbs at once and a release within TapTime is a tap
			-- that kicks off (0.3 s covers ordinary taps; the old 0.2 s needed double taps).
			-- Held, it climbs at Climb for ClimbTime of holding (owner: the old 2 s taper
			-- stopped the climb after about a second), then eases over ClimbFade into a
			-- HeldSlide.
			TapTime = 0.3,
			-- A press while holding away from the wall (move input dot the wall normal over
			-- this) kicks off at once, without waiting for the release.
			KickAway = 0.35,
			-- Studs above the root that must still be beside the wall to keep climbing; above
			-- this the run holds its height along the top edge.
			TopMargin = 1,
			Climb = 11,
			ClimbTime = 3,
			ClimbFade = 1,
			HeldSlide = 2, -- downward speed reached while still holding Jump
			Slide = 1.5, -- downward speed once Jump is released, growing by SlideGrow per second since
			SlideGrow = 5,
			SlideMax = 20,
			VerticalAccel = 40, -- studs/s^2 toward the climb or slide speed
			Pull = { Rate = 8, Max = 14, Away = 6 }, -- speed holding the root at Hug distance
			Release = 8, -- push away from the wall when dropping off
			Reattach = 0.45, -- seconds before the same wall can be run again
			JumpAway = 38,
			JumpUp = 46,
			JumpCarry = 1, -- fraction of the run speed kept on the kick
			Tilt = 0.35, -- presentation: body roll away from the wall, radians
			ArmForward = 0.5, -- presentation: wall hand's swing ahead of the shoulder, radians
			HandGap = 0.1, -- presentation: hand stops this far from the wall surface
			SettleTime = 0.35, -- presentation: observers' replicated body catches up before end checks
		},
	},
	Lab = {
		HurtAmount = 15, -- H: self-damage to preview hit reactions; no combat rules
		HurtCooldown = 0.5,
		Aim = false, -- RMB aim pose and click marker; off until aiming is in scope (owner, 2026-10-29)
		SprintDoubleTap = 0.3, -- seconds between W presses that start a sprint
	},
	Avatar = {
		-- Owner (2026-10-29): the classic R6 rig, as in the reference game. Its limbs are
		-- single blocks (no hands, elbows or knees) and its arms pivot a quarter of the way
		-- down, so they swing loose of the shoulder. Clips stay in R15 terms and are
		-- converted when applied (see Presentation).
		RigType = "R6",
		ArmScale = 1.25, -- R15 only: longer upper and lower arms
		-- Owner (2026-10-30): the legs looked narrow. R6 only: each hip moves this far
		-- out (studs), so the legs stand apart but stay parallel (no splay). 0.15 looked
		-- disconnected; this keeps the outer edges nearly flush with the torso.
		LegSpread = 0.06,
	},
	Camera = {
		Fov = 72,
		SprintFov = 78, -- was 74: a clearer kick into the sprint
		SlideFov = 82,
		ShiftLock = Vector3.new(1.75, 0, 0), -- camera offset to the right (Roblox's own is 1.75)
		ShiftLockTurnRate = 30, -- how fast the body turns to the camera under shift lock
		AimFov = 68,
		BlendRate = 10,
		-- Owner (2026-10-30): make sprinting obvious, but the first shake (bounce, wobble and
		-- roll) was far too much: only a very subtle bounce on each step (studs), no tilt.
		-- Steps: footfalls per second; Rate: how fast it fades in and out.
		SprintShake = { Bounce = 0.05, Steps = 4.6, Rate = 6 },
		MinZoom = 7,
		MaxZoom = 18,
		Shoulder = Vector3.new(1.5, 0.45, 0),
	},
	Animation = {
		MaxCycleRate = 1.3, -- above this the feet slide instead of faster cadence (longer, calmer strides)
		MinCycleRate = 0.85, -- high so braking blends to idle without a slow-motion run (owner: snappy)
		IdleBlendSpeed = 5,
		IdleBlendRate = 7, -- how fast the idle/moving mix follows speed (owner: no cut into idle)
		-- Long falls sway gently about the jump clip's apex pose instead of playing a Fall
		-- clip (seconds of clip either side, and the sway period); nil uses the Fall clip.
		FallFromJump = { Swing = 0.06, Period = 1.4 },
		LongFall = { After = 0.6, Blend = 0.6 }, -- seconds falling before the flail fades in, and its fade
		WalkOff = 0.3, -- seconds over which walking off an edge eases from the run into the fall
		GroundProbeRadius = 0.85, -- presentation ground check footprint (edges count)
		StepRise = 30, -- studs/s: rising slower than this from the ground (stairs) stays grounded
		Fade = {
			ActionIn = 0.07,
			ActionOut = 0.2,
			MantleOut = 0.3,
			Air = 0.12,
			Land = 0.08,
			LandMoving = 0.22, -- from the air pose straight into the stride
		},
		-- How fast the run, strafe and back-run clips' weights follow the travel direction.
		DirectionBlendRate = 10,
		Land = {
			Duration = 0.42,
			MinImpact = 20,
			FullImpact = 75,
			MovingScale = 1, -- landing clip weight lost when moving (1: none on the run)
			Rate = 1.3,
			-- Heavier tiers use their own clips when present: impact speed, hold time.
			Hard = { Impact = 70, Duration = 0.8 },
			Heavy = { Impact = 100, Duration = 1.5 },
		},
		-- One-shot transitions picked from motion, so every client sees them.
		Moves = {
			Fade = 0.25,
			FadeOut = 0.35, -- seconds before a transition ends that locomotion takes over
			-- Idle fidgets, taking turns after standing still After + up to Spread
			-- seconds. Only their motion is layered on the live idle and eased in and
			-- out, so the idle never hands over to another stance (owner: no cut in).
			-- NeckStretch is the owner's Mixamo clip (private; skipped when absent).
			Fidget = {
				Clips = { "NeckStretch" },
				After = 6,
				Spread = 4,
				FadeIn = 0.5,
				FadeOut = 0.6,
			},
			InjuredBelow = 0.35, -- health fraction for the injured idle
		},
		-- Small caps: a quick reversal spikes both, which read as a skid (owner: sharp turns).
		Lean = { Bank = 0.0016, MaxBank = 0.1, Pitch = 0.0025, MaxPitch = 0.08, Rate = 9 },
		-- Keeps feet (or the body, for a slide) at each clip's intended floor clearance.
		-- Without PullDown, feet only push the body up out of the floor: straight legs
		-- lift clear in a stride instead of dragging the torso down (owner: steadier).
		GroundContact = { Max = 1.6, Rate = 30, PullDown = false },
		-- Owner style: block limbs with no elbows, knees or hands. After every clip, action
		-- and pose adjustment each limb (upper, lower, end joint) becomes one block aimed
		-- from its root to its end, so bent-knee stances keep the feet under the body
		-- instead of tipping the leg forward with the thigh; the lower joints are cleared.
		FoldLimbs = {
			{ "LeftShoulder", "LeftElbow", "LeftWrist" },
			{ "RightShoulder", "RightElbow", "RightWrist" },
			{ "LeftHip", "LeftKnee", "LeftAnkle" },
			{ "RightHip", "RightKnee", "RightAnkle" },
		},
		AimWeightDuringAction = 0.25,
		AimRate = 14,
		-- One-handed pistol hold for a Tool with HoldStyle "Pistol" (Rocklock blaster,
		-- owner 2026-10-30: smooth, clean, a large pistol, not "basic", and not stiff; styles
		-- on G). The tool's grip tilts the barrel GripTilt above the arm's line and sets the
		-- grip's centre GripInset studs inside the R6 hand block, so the fist closes round it.
		-- Per style, in character (root) space:
		--   Arm   = raise from hanging, inward yaw, roll (fromEulerAnglesYXZ order)
		--   Wrist = extra barrel pitch about the hand (R6 has no wrist: the grip weld turns)
		--   Waist / Neck = torso turn and head counter-turn, shown mostly when standing
		--   Weight = scales the whole hold; TorsoFollow = how much a standing arm rides the
		--   torso instead of being steadied (a moving arm always rides it); Sway = idle drift.
		-- Carry layers the hold over the body's own motion the way action games layer a
		-- weapon pose over full-body locomotion: full when standing, less when running,
		-- sprinting and airborne, and little in actions so slides and flips keep their swing.
		-- A spring adds follow-through: turning swings the gun behind (Lag per rad/s of turn),
		-- take-offs kick it and landings dip it (Dip per stud/s change of vertical speed).
		-- Taking it out spins the blaster DrawSpins times about the trigger finger.
		Hold = {
			GripTilt = 0.2,
			GripInset = 0.14,
			Rate = 10,
			Default = "Gunslinger",
			Order = { "Gunslinger", "Hero", "Bladed" },
			Carry = {
				Idle = 1,
				Run = 0.6,
				Sprint = 0.4,
				Air = 0.45,
				RunSpeed = 22,
				SprintSpeed = 30,
				Actions = { Slide = 0.3, WallRun = 0.2, WallHop = 0.2, Mantle = 0.12, Flip = 0.1 },
				Spring = 90,
				Damping = 0.35, -- fraction of critical damping: lower bounces more
				Lag = 3,
				Dip = 0.05,
				MaxSway = 0.45,
			},
			Styles = {
				-- Low and loose at the hip, barrel angled at the floor ahead.
				Gunslinger = {
					Arm = { 0.7, 0.14, -0.08 },
					Wrist = 0.32,
					Waist = { 0, -0.1, 0 },
					Neck = { 0, 0.08, 0 },
					Weight = 0.9,
					TorsoFollow = 0.85,
					Sway = 0.025,
				},
				-- Blaster up beside the face, barrel to the sky.
				Hero = {
					Arm = { 1.95, 0.55, 0.18 },
					Wrist = 0.8,
					Waist = { 0.04, 0.12, 0 },
					Neck = { 0, -0.12, 0 },
					Weight = 1,
					TorsoFollow = 0.7,
					Sway = 0.015,
				},
				-- Side-on stance, right shoulder forward, arm on the target line.
				Bladed = {
					Arm = { 1.37, 0, 0 },
					Wrist = 0,
					Waist = { 0, 0.7, 0 },
					Neck = { 0, -0.55, 0 },
					Weight = 1,
					TorsoFollow = 0.6,
					Sway = 0.012,
				},
			},
			DrawTime = 0.45,
			DrawSpins = 1,
			DrawLift = 0.35, -- extra arm raise at the middle of the spin
		},
	},
	Validation = {
		RequestsPerSecond = 12,
		HorizontalSpeedLimit = 56,
		DisplacementSlack = 14,
		SpawnGrace = 3,
		StateSettle = 0.35, -- seconds the server waits for replicated ground state
		-- Clip variants (Name.2, Name.3) of each are also accepted.
		FlipVariants = {
			"FlipFront",
			"FlipFrontRight",
			"FlipRight",
			"FlipBackRight",
			"FlipBack",
			"FlipBackLeft",
			"FlipLeft",
			"FlipFrontLeft",
		},
		MantleVariants = { "MantleLow", "MantleVault", "MantleHigh", "Vault" },
		WallHopVariants = { "WallHop", "WallJumpLeft", "WallJumpRight", "WallKickUp" },
		WallRunVariants = { "WallRunLeft", "WallRunRight" },
		SlideVariants = { "Slide" },
		-- Light server authority (owner, 2026-10-30). An air boost is a rise in upward speed
		-- over Gain between 0.1 s samples while off the ground for GroundGrace; it needs an
		-- action accepted within Window of it. A wall pass (the path between samples crossing
		-- an anchored, collidable part) needs a mantle or vault within Window. Upward speed
		-- over MaxRise is clamped (the fastest launch is a 62 jump). Unexplained cases snap
		-- the character back to where they started; each kind can be switched off.
		AirBoost = { Gain = 25, GroundGrace = 0.35, Window = 0.6, MaxRise = 75 },
		Corrections = { AirBoost = true, Walls = true, Rise = true },
		TraversalSlack = 4, -- studs of replication lag allowed in traversal checks
		FlipInterval = 0.8, -- a flip this long after the last is accepted even with no landing seen (a double-jump cycle is about 0.9 s)
	},
})
