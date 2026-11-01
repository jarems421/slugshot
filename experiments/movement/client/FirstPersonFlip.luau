--!strict
-- Presentation envelope shared by the first-person hands and positional camera cue.
-- The body clip and its playback duration remain the timing source; no look rotation.
local Flip = {}
export type Cue = { weight: number, drive: number, tuck: number, offset: Vector3 }
export type ArmCue = { frame: CFrame, weight: number }

local function ramp(t: number, a: number, b: number): number
	local x = math.clamp((t - a) / (b - a), 0, 1)
	return x * x * (3 - 2 * x)
end

function Flip.sample(now: number, start: number, duration: number, side: number): Cue
	local t = (now - start) / math.max(duration, 1e-3)
	local drive = ramp(t, 0, 0.12) * (1 - ramp(t, 0.18, 0.34))
	local tuck = ramp(t, 0.08, 0.28) * (1 - ramp(t, 0.55, 0.88))
	local release = ramp(t, 0.62, 0.82) * (1 - ramp(t, 0.82, 1))
	return {
		weight = ramp(t, 0, 0.12) * (1 - ramp(t, 0.82, 1)),
		drive = drive,
		tuck = tuck,
		offset = Vector3.new(
			side * 0.035 * tuck,
			0.055 * tuck - 0.025 * drive - 0.02 * release,
			0.035 * tuck
		),
	}
end

-- Reframe the actual rendered shoulder choreography into the forward view. No
-- replacement front/back/side poses: the source clip supplies every sweep, wing,
-- overhead hold and windmill swap, including mirrored and diagonal variants.
function Flip.arm(
	now: number,
	start: number,
	duration: number,
	armSide: number,
	bodyPose: CFrame,
	viewPose: CFrame,
	mode: number
): ArmCue
	local phase = (now - start) / math.max(duration, 1e-3)
	-- Keep the shoulder articulation legible around a steady eye; a little of the
	-- actual whole-body turn remains, more in Spot where the view also participates.
	local sourceDirection = (-bodyPose.UpVector):Lerp(
		-viewPose.UpVector,
		if mode == 2 then 0.28 else 0.12
	)
	local direction =
		Vector3.new(sourceDirection.X * 0.4, sourceDirection.Y, sourceDirection.Z - 1.15).Unit
	local up = -direction
	local right = (Vector3.xAxis - up * up.X).Unit
	local rotation = CFrame.fromMatrix(Vector3.zero, right, up, right:Cross(up))
	return {
		frame = CFrame.new(armSide * 1.32, -0.72, 0.04) * rotation,
		weight = ramp(phase, 0, 0.08) * (1 - ramp(phase, 0.88, 1)),
	}
end

return Flip
