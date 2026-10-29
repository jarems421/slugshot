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
			PlaybackRate = 1.15,
			Cooldown = 0.5,
			JumpCancel = 0.65, -- fraction of the roll after which Jump cancels it
			FaceInput = false, -- true: always turn into a forward roll
			WallClearance = 1.5,
			MaxSpeed = 42,
		},
		Flip = {
			Lift = 14, -- minimum upward speed on a flip; 0 disables
			MinRate = 0.85,
			MaxRate = 1.8,
			BackInputDot = -0.35, -- input this far behind facing selects a backflip
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
			Duration = { Base = 0.3, PerStud = 0.045, Min = 0.34, Max = 0.55 },
			HangGap = 0.8, -- root distance from the wall face while the hands plant
			ExitSpeed = 0.8, -- fraction of the approach speed kept on top
			ExitMin = 8,
			Cooldown = 0.34,
			CheckInterval = 0.055, -- ledge checks while jump is held
			JumpWindow = 0.34, -- seconds after a jump press that ledges still count
		},
		WallHop = {
			Reach = 3.25,
			AwaySpeed = 30,
			UpSpeed = 54,
			TangentCarry = 0.55, -- fraction of along-wall speed kept
			MaxTangent = 24,
			MaxHops = 2, -- per airtime
			Cooldown = 0.15,
			GroundDelay = 0.13, -- no hop this soon after leaving the ground
			Buffer = 0.15, -- an airborne press too early or out of reach is retried this long
			LockTime = 0.22, -- seconds the kick owns movement before input resumes
			RefreshFlip = true, -- a hop restores the airborne flip
		},
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
		MaxCycleRate = 1.4, -- above this the stride lengthens instead of faster cadence
		MinCycleRate = 0.55,
		IdleBlendSpeed = 5,
		Fade = { ActionIn = 0.07, ActionOut = 0.2, Air = 0.12, Land = 0.08 },
		Land = { Duration = 0.42, MinImpact = 20, FullImpact = 75, MovingScale = 0.55 },
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
		RollVariants = { "RollForward", "RollBack", "RollLeft", "RollRight" },
		FlipVariants = { "FlipFront", "FlipBack" },
		MantleVariants = { "MantleLow", "MantleHigh" },
		WallHopVariants = { "WallHop" },
		TraversalSlack = 4, -- studs of replication lag allowed in traversal checks
	},
})
