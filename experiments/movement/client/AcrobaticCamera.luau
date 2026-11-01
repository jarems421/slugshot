--!strict
-- Owner-selected Spot default with local Settings alternatives. Physics/actions stay intact.
local Players = game:GetService("Players")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("MovementExperiment")
local Clips = require(shared.Clips)
local Config = require(shared.Config)
local Flip = require(script.Parent.FirstPersonFlip)
local CameraLab = {}
local IDENTITY = CFrame.identity
local player = Players.LocalPlayer
local library: Clips.Library = {}
local requested, selected =
	Config.Camera.FirstPerson.FlipCameraDefault, Config.Camera.FirstPerson.FlipCameraDefault
local stamp, suppressed = -math.huge, -math.huge
local activeCharacter: Model? = nil
local lastKind = ""
local wallSide, wallRelease = 0, -math.huge
local recovery, base = CFrame.identity, CFrame.identity
local lastFov = 0

CameraLab.Options = {
	{ name = "Anchor", description = "Steady view with expressive arm and leg movement." },
	{ name = "Spot", description = "A directional tilt that settles early for aiming." },
	{ name = "Ride", description = "Follow the body's full flip rotation." },
}

local function ramp(t: number, a: number, b: number): number
	local x = math.clamp((t - a) / (b - a), 0, 1)
	return x * x * (3 - 2 * x)
end

function CameraLab.start(clips: Clips.Library)
	library = clips
end

function CameraLab.enabled(): boolean
	local override = player:GetAttribute("FirstPersonFlipCameraEnabled")
	return if typeof(override) == "boolean"
		then override
		else Config.Camera.FirstPerson.FlipCameraEnabled
end

-- Normal changes latch outside a flip; immediate return cancels the current gesture.
function CameraLab.select(index: number, immediate: boolean?)
	requested = math.clamp(math.round(index), 1, #CameraLab.Options)
	if immediate then
		selected, suppressed = requested, stamp
	end
end

function CameraLab.status(): (number, number)
	return selected, requested
end

function CameraLab.setBase(view: CFrame)
	base = view
end

function CameraLab.base(): CFrame
	return base
end

local function bodyRotation(clip: Clips.Clip, time: number): CFrame
	local pose = Clips.sample(clip, time)
	return (pose.Root or CFrame.identity).Rotation
		* (pose.Waist or CFrame.identity).Rotation
		* (pose.Neck or CFrame.identity).Rotation
end

function CameraLab.step(dt: number, character: Model?, first: boolean): (CFrame, number)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if
		not CameraLab.enabled()
		or not first
		or not character
		or not humanoid
		or humanoid.Health <= 0
	then
		recovery, lastFov = CFrame.identity, 0
		activeCharacter, lastKind = nil, ""
		stamp, suppressed, wallRelease = -math.huge, -math.huge, -math.huge
		selected = requested
		return CFrame.identity, 0
	end
	if activeCharacter ~= character then
		recovery, lastFov = CFrame.identity, 0
		lastKind, stamp, suppressed, wallRelease = "", -math.huge, -math.huge, -math.huge
		activeCharacter = character
	end
	local now = workspace:GetServerTimeNow()
	local kind = (character:GetAttribute("FirstPersonAction") or "") :: string
	local actionStamp = (character:GetAttribute("MovementActionTime") or 0) :: number
	local flipping = kind == "Flip"
	if not flipping then
		selected = requested
	elseif actionStamp ~= stamp then
		selected, stamp = requested, actionStamp
	end
	if lastKind:sub(1, 7) == "WallRun" and kind:sub(1, 7) ~= "WallRun" then
		wallRelease = now
		wallSide = if lastKind == "WallRunLeft" then -1 else 1
	end
	lastKind = kind
	if flipping and actionStamp ~= suppressed then
		local duration = (character:GetAttribute("FirstPersonFlipDuration") or 0.6) :: number
		local side = (character:GetAttribute("FirstPersonFlipSide") or 0) :: number
		local front = (character:GetAttribute("FirstPersonFlipForward") or 1) :: number
		local t = (now - actionStamp) / math.max(duration, 1e-3)
		local cue = Flip.sample(now, actionStamp, duration, side)
		local rotation, offset, fov = CFrame.identity, cue.offset, 0
		if selected == 2 then
			-- Wind against the move, carry into it, then spot the target by 68%.
			local wind = ramp(t, 0, 0.07) * (1 - ramp(t, 0.07, 0.2))
			local bank = ramp(t, 0.08, 0.27) * (1 - ramp(t, 0.36, 0.68))
			rotation = CFrame.Angles(
				math.rad(front * (3 * wind - 8 * bank)),
				0,
				math.rad(side * (4 * wind - 19 * bank))
			)
			offset = cue.offset * 2.2 + Vector3.new(0, -0.025 * wind, 0)
			fov = 2.5 * bank
		elseif selected == 3 then
			-- Sample the authored path. Lerp(identity, 360 degrees) loses the turn.
			-- Live look input is underneath this rotation, never locked to a head.
			local variant = (character:GetAttribute("MovementVariant") or "") :: string
			local clip = library[variant]
			if clip then
				local rate = (character:GetAttribute("MovementRate") or 1) :: number
				local takeoff = clip.events.takeoff or 0
				local body = bodyRotation(clip, takeoff + math.max(0, now - actionStamp) * rate)
					* bodyRotation(clip, takeoff):Inverse()
				rotation = IDENTITY:Lerp(body, ramp(t, 0, 0.08))
					:Lerp(CFrame.identity, ramp(t, 0.84, 1))
			end
			offset, fov = cue.offset * 2.8, 3 * cue.tuck
		end
		recovery, lastFov = CFrame.new(offset) * rotation, fov
		return recovery, fov
	end
	local target = CFrame.identity
	if selected > 1 then
		local elapsed = now - wallRelease
		local kick = ramp(elapsed, 0, 0.07) * (1 - ramp(elapsed, 0.08, 0.36))
		local gain = if selected == 2 then 1 else 2
		target = CFrame.new(0, -0.035 * kick * gain, 0)
			* CFrame.Angles(math.rad(-3 * kick * gain), 0, math.rad(wallSide * 6 * kick * gain))
		if kind == "Mantle" then
			local clip = library[(character:GetAttribute("MovementVariant") or "") :: string]
			if clip then
				local rate = (character:GetAttribute("MovementRate") or 1) :: number
				local phase = (now - actionStamp) * rate / clip.duration
				local pull = ramp(phase, 0, 0.2) * (1 - ramp(phase, 0.4, 0.9))
				target *= CFrame.Angles(math.rad(-3 * pull * gain), 0, 0)
			end
		end
	end
	-- Interrupted/cancelled flips unwind once, without replaying a revolution.
	local alpha = 1 - math.exp(-18 * dt)
	recovery = recovery:Lerp(target, alpha)
	lastFov += (0 - lastFov) * alpha
	return recovery, lastFov
end

return CameraLab
