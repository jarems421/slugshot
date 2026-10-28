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
	Evade = { Duration = 0.36, Speed = 34, EndSpeed = 20, Cooldown = 0.72, WallClearance = 1.5 },
	Flourish = { Duration = 0.44, Cooldown = 0.55 },
	Camera = {
		Fov = 72,
		SprintFov = 74,
		AimFov = 68,
		BlendRate = 10,
		MinZoom = 7,
		MaxZoom = 18,
		Shoulder = Vector3.new(1.5, 0.45, 0),
	},
	Presentation = { StrideLength = 12, HipSwing = 0.85, ArmSwing = 0.55, BlendRate = 16 },
	Validation = {
		RequestsPerSecond = 12,
		HorizontalSpeedLimit = 56,
		DisplacementSlack = 14,
		SpawnGrace = 3,
	},
})
