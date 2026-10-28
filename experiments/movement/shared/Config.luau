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
	},
})
