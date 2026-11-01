--!strict
local Types = require(script.Parent.Types)
local Timeline = {}

-- Pure presentation. Estimates and impacts come from the future gameplay owner.
function Timeline.sample(
	profile: Types.Profile,
	elapsed: number,
	estimatedFlightSeconds: number,
	impacted: boolean,
	previousProgress: number?
): Types.Sample
	assert(elapsed == elapsed and elapsed >= 0 and elapsed < math.huge, "Invalid elapsed time")
	assert(
		estimatedFlightSeconds == estimatedFlightSeconds
			and estimatedFlightSeconds >= 0
			and estimatedFlightSeconds < math.huge,
		"Invalid flight estimate"
	)
	assert(profile.duration > 0 and profile.duration < math.huge, "Invalid visual duration")
	local duration = math.min(profile.duration, estimatedFlightSeconds)
	local progress = if impacted or duration <= 0 then 1 else math.clamp(elapsed / duration, 0, 1)
	progress = math.max(previousProgress or 0, progress)
	local transformed = profile.enabled and progress >= profile.transitionFraction
	local stage = "launch"
	if impacted then
		stage = "impact"
	elseif not profile.enabled then
		stage = if progress < 0.15 then "launch" else "spin"
	elseif progress >= profile.revealFraction then
		stage = "reveal"
	elseif transformed then
		stage = "transition"
	elseif progress >= 0.35 then
		stage = "energy"
	elseif progress >= 0.15 then
		stage = "spin"
	end
	return {
		stage = stage,
		progress = progress,
		transformed = transformed,
		spin = if transformed or impacted
			then 0
			else elapsed * profile.spinTurnsPerSecond * math.pi * 2,
		squash = if transformed then 0 else math.sin(progress * math.pi) * 0.18,
		energy = if profile.enabled then math.sin(progress * math.pi) else 0,
		reveal = if transformed
			then math.clamp(
				(progress - profile.transitionFraction) / (1 - profile.transitionFraction),
				0,
				1
			)
			else 0,
	}
end

return Timeline
