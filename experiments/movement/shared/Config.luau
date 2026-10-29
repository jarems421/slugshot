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
			JumpPower = 50,
		},
		Athletic = {
			RunSpeed = 24,
			SprintSpeed = 30,
			Acceleration = 100,
			Braking = 145,
			TurnRate = 18,
			JumpPower = 52,
		},
		Precise = {
			RunSpeed = 21,
			SprintSpeed = 27,
			Acceleration = 130,
			Braking = 180,
			TurnRate = 24,
			JumpPower = 50,
		},
	},
	-- One context-sensitive button: grounded = directional roll, airborne = flip.
	Acrobatics = {
		Roll = {
			Distance = 12, -- studs covered by the clip's root motion
			Duration = 0.7, -- seconds to the clip's recover point; sets the playback rate
			MinRate = 0.8,
			MaxRate = 2.2,
			Cooldown = 0.5,
			JumpCancel = 0.65, -- fraction of the roll after which Jump cancels it
			FaceInput = false, -- true: always turn into a forward roll
			WallClearance = 1.5,
			MaxSpeed = 42,
		},
		Flip = {
			Lift = 14, -- minimum upward speed on a flip; 0 disables
			MinRate = 0.85,
			MaxRate = 2.6,
			BackInputDot = -0.35, -- input this far behind facing selects a backflip
			DropTime = 0.85, -- seconds to touchdown above which a drop flip (if present) plays
		},
		LandingRollWindow = 0.18, -- seconds before touchdown that buffer a roll
	},
	-- Jump-triggered traversal, adapted from the Place1 movement system (MIT):
	-- jump into a ledge to climb onto it, jump near a wall in the air to kick off it.
	Traversal = {
		Mantle = {
			Reach = 3.6, -- studs ahead of the root a wall is detected
			MinHeight = 0.7, -- ledge height above the feet, studs
			MaxHeight = 5.7,
			LowHeight = 3.2, -- below: one-hand step vault; above: two-hand climb
			ParkourHeight = 4.6, -- below: one-hand parkour mantle clip, when present
			Duration = { Base = 0.28, PerStud = 0.04, Min = 0.32, Max = 0.48 },
			MaxRate = 3.2, -- longer clips (motion capture) play up to this fast, then stretch the climb
			HangHeight = 5, -- at or above: hanging climb clip, when present
			HangGap = 0.8, -- root distance from the wall face while the hands plant
			ExitSpeed = 0.8, -- fraction of the approach speed kept on top
			ExitMin = 8,
			Cooldown = 0.34,
			CheckInterval = 0.055, -- ledge checks while jump is held
			JumpWindow = 0.34, -- seconds after a jump press that ledges still count
		},
		WallHop = {
			Reach = 3.8, -- from the root: about 2.8 studs of gap beside the body
			AwaySpeed = 30,
			UpSpeed = 54,
			TangentCarry = 0.55, -- fraction of along-wall speed kept
			MaxTangent = 24,
			MaxHops = 3, -- per airtime (wall-run jumps count)
			Cooldown = 0.15,
			GroundDelay = 0.13, -- no hop this soon after leaving the ground
			Buffer = 0.15, -- an airborne press too early or out of reach is retried this long
			LockTime = 0.22, -- seconds the kick owns movement before input resumes
			RefreshFlip = true, -- a hop restores the airborne flip
		},
		-- Jumping into a thin, low obstacle at speed vaults over it (needs a Vault clip).
		Vault = {
			MaxHeight = 3.6,
			MaxDepth = 3.2, -- obstacle thickness
			LandDistance = 2.4, -- beyond the far edge
			MinSpeed = 9,
			LookAhead = 0.12, -- seconds of approach: a jump pressed this early still vaults
			Clearance = 0.7, -- feet above the top at the peak
		},
		-- Jumping onto a wall while running along it attaches: run along the wall
		-- (slight rise, then a slow sink) until Jump kicks off, input lets go, the
		-- wall ends or time runs out. No clip needed; the kick uses WallJump clips.
		WallRun = {
			Reach = 4.2, -- from the root to the wall surface
			Hug = 1.6, -- root distance from the wall once attached (pulled in)
			MinAlong = 12, -- along-wall speed needed to attach
			MaxInto = 0.8, -- travel more head-on than this (dot into the wall) does not attach
			MinInput = 0.3, -- move input along the wall needed to attach and to stay on
			MinHeight = 2, -- feet above the ground needed to attach
			MaxTime = 1.6,
			Speed = 26, -- minimum run speed on the wall
			Rise = { Min = 4, Max = 13, Carry = 0.3 }, -- upward speed on attach: Carry of the jump's, clamped
			Gravity = 14, -- studs/s^2 on the wall (normal gravity is about 196)
			Stick = 3, -- speed held into the wall, plus a pull while further than Hug
			Release = 8, -- push away from the wall when dropping off
			Reattach = 0.45, -- seconds before the same wall can be run again
			JumpAway = 28,
			JumpUp = 46,
			JumpCarry = 0.85, -- fraction of the run speed kept on the kick
			Tilt = 0.35, -- presentation: body roll away from the wall, radians
			SettleTime = 0.35, -- presentation: observers' replicated body catches up before end checks
		},
	},
	Crouch = {
		Speed = 10,
	},
	Lab = {
		HurtAmount = 15, -- H: self-damage to preview hit reactions; no combat rules
		HurtCooldown = 0.5,
	},
	Camera = {
		Fov = 72,
		SprintFov = 74,
		AimFov = 68,
		BlendRate = 10,
		MinZoom = 7,
		MaxZoom = 18,
		Shoulder = Vector3.new(1.5, 0.45, 0),
	},
	Animation = {
		MaxCycleRate = 1.3, -- above this the feet slide instead of faster cadence (longer, calmer strides)
		MinCycleRate = 0.55,
		IdleBlendSpeed = 5,
		IdleBlendRate = 9, -- how fast the idle/moving mix follows speed
		GroundProbeRadius = 0.85, -- presentation ground check footprint (edges count)
		Fade = { ActionIn = 0.07, ActionOut = 0.2, Air = 0.12, Land = 0.08 },
		Land = {
			Duration = 0.42,
			MinImpact = 20,
			FullImpact = 75,
			MovingScale = 0.55,
			Rate = 1.3,
			-- Heavier tiers use their own clips when present: impact speed, hold time.
			Hard = { Impact = 70, Duration = 0.8 },
			Heavy = { Impact = 100, Duration = 1.5 },
		},
		-- One-shot transitions picked from motion, so every client sees them.
		Moves = {
			Fade = 0.25,
			FadeOut = 0.35, -- seconds before a transition ends that locomotion takes over
			Start = { Rate = 1.6, Offset = 0.1, Hold = 0.25, IdleTime = 0.25 },
			Stop = { MinSpeed = 14, Rate = 1.2, Offset = 0.15 },
			Turn = { MinSpeed = 14, Dot = -0.4, Rate = 1.5, Hold = 0.45, Window = 0.6 },
			Crouch = { Rate = 1.5, Fade = 0.3 },
			InjuredBelow = 0.35, -- health fraction for the injured idle
		},
		Lean = { Bank = 0.0016, MaxBank = 0.28, Pitch = 0.0025, MaxPitch = 0.18, Rate = 9 },
		-- Keeps feet (or the body, for rolls) at each clip's intended floor clearance.
		GroundContact = { Max = 1.6, Rate = 30 },
		AimWeightDuringAction = 0.25,
		AimRate = 14,
	},
	Validation = {
		RequestsPerSecond = 12,
		HorizontalSpeedLimit = 56,
		DisplacementSlack = 14,
		SpawnGrace = 3,
		StateSettle = 0.35, -- seconds the server waits for replicated ground state
		-- Clip variants (Name.2, Name.3) of each are also accepted.
		RollVariants = { "RollForward", "RollBack", "RollLeft", "RollRight", "RollLand" },
		FlipVariants = { "FlipFront", "FlipBack", "FlipDrop" },
		MantleVariants = { "MantleLow", "MantleVault", "MantleHigh", "MantleHang", "Vault" },
		WallHopVariants = { "WallHop", "WallJumpLeft", "WallJumpRight" },
		WallRunVariants = { "WallRunLeft", "WallRunRight" },
		TraversalSlack = 4, -- studs of replication lag allowed in traversal checks
	},
})
