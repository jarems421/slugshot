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
			Duration = { Base = 0.3, PerStud = 0.045, Min = 0.34, Max = 0.55 },
			MaxRate = 2.1, -- longer clips (motion capture) stretch the climb instead of rushing
			HangHeight = 5, -- at or above: hanging climb clip, when present
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
		-- Jumping into a thin, low obstacle at speed vaults over it (needs a Vault clip).
		Vault = {
			MaxHeight = 3.6,
			MaxDepth = 3.2, -- obstacle thickness
			LandDistance = 2.4, -- beyond the far edge
			MinSpeed = 9,
			LookAhead = 0.12, -- seconds of approach: a jump pressed this early still vaults
			Clearance = 0.7, -- feet above the top at the peak
		},
		-- A wall hop taken along a wall at speed runs up it first (needs WallRun clips).
		WallRun = {
			MinAlong = 13, -- along-wall speed
			MaxInto = 0.55, -- approach steeper than this (dot into the wall) hops instead
			Time = 0.42,
			UpSpeed = 22,
			Speed = 26,
			KickUp = 0.7, -- fraction of the hop's up speed on the closing kick
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
		MaxCycleRate = 1.6, -- above this the feet slide instead of faster cadence
		MinCycleRate = 0.55,
		IdleBlendSpeed = 5,
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
			Fade = 0.18,
			Start = { Rate = 1.6, Offset = 0.1, Hold = 0.25, IdleTime = 0.25 },
			Stop = { MinSpeed = 14, Rate = 1.2, Offset = 0.15 },
			Turn = { MinSpeed = 14, Dot = -0.4, Rate = 1.5, Hold = 0.45, Window = 0.6 },
			Crouch = { Rate = 1.5 },
			Fidget = { After = 9, Spread = 6 },
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
		MantleVariants = { "MantleLow", "MantleHigh", "MantleHang", "Vault" },
		WallHopVariants = { "WallHop", "WallRunLeft", "WallRunRight" },
		TraversalSlack = 4, -- studs of replication lag allowed in traversal checks
	},
})
