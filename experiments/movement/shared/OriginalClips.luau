--!strict
-- Original keyframed movement clips (public, no third-party data), authored with R15
-- joint names and converted to the R6 rig when applied (Presentation). Poses are in
-- degrees per joint (CFrame.Angles X, Y, Z order), relative to the rest pose, and
-- sampled with Catmull-Rom/Hermite curves at 30 fps (or the spec's fps).
--
-- Joint axes: Hip/Shoulder +X swings the limb forward; Knee -X flexes; Elbow +X
-- flexes; Ankle +X lifts the toes; Root/Waist/Neck -X leans forward, +Y turns left,
-- +Z tilts left. Left limbs abduct with -Z, right limbs with +Z.
-- RootPos is in hip units (Root pivot height). floor is the clip's intended lowest
-- foot (or body, for a slide) clearance in hip units; motion is cumulative root travel
-- along the clip direction, in hip units.
local OriginalClips = {}

type Key = { [string]: any }

local JOINTS = {
	"Root",
	"Waist",
	"Neck",
	"LeftShoulder",
	"LeftElbow",
	"LeftWrist",
	"RightShoulder",
	"RightElbow",
	"RightWrist",
	"LeftHip",
	"LeftKnee",
	"LeftAnkle",
	"RightHip",
	"RightKnee",
	"RightAnkle",
}
local FPS = 30

local function swapSide(name: string): string
	if name:sub(1, 4) == "Left" then
		return "Right" .. name:sub(5)
	elseif name:sub(1, 5) == "Right" then
		return "Left" .. name:sub(6)
	end
	return name
end

-- Reflect across the character's X axis: swap sides, negate Y/Z rotations.
local function mirrorKey(key: Key): Key
	local result: Key = {}
	for field, value in key do
		if field == "RootPos" then
			result.RootPos = { -value[1], value[2], value[3] }
		elseif typeof(value) == "table" then
			result[swapSide(field)] = { value[1], -value[2], -value[3] }
		else
			result[field] = value
		end
	end
	return result
end

local function sampler(times: { number }, values: { number }, loop: boolean, duration: number)
	local n = #times
	local function at(i: number): (number, number)
		if loop then
			local k = (i - 1) % n + 1
			return times[k] + (i - k) // n * duration, values[k]
		end
		local k = math.clamp(i, 1, n)
		return times[k], values[k]
	end
	return function(t: number): number
		local i = 1
		while i < n and times[i + 1] <= t do
			i += 1
		end
		if not loop and i == n then
			return values[n]
		end
		local t0, v0 = at(i)
		local t1, v1 = at(i + 1)
		local tp, vp = at(i - 1)
		local tn, vn = at(i + 2)
		local m0 = if loop or i > 1 then (v1 - vp) / (t1 - tp) else 0
		local m1 = if loop or i + 1 < n then (vn - v0) / (tn - t0) else 0
		local h = t1 - t0
		local s = (t - t0) / h
		local s2, s3 = s * s, s * s * s
		return (2 * s3 - 3 * s2 + 1) * v0
			+ (s3 - 2 * s2 + s) * h * m0
			+ (-2 * s3 + 3 * s2) * v1
			+ (s3 - s2) * h * m1
	end
end

local function build(name: string, spec: any): any
	local keys: { Key } = table.clone(spec.keys)
	table.sort(keys, function(a, b)
		return a.t < b.t
	end)
	local loop = spec.loop == true
	local duration = spec.duration
	local fps = spec.fps or FPS
	local frames = if loop then math.round(duration * fps) else math.round(duration * fps) + 1
	local times = {}
	for index, key in keys do
		times[index] = key.t
	end
	local function channel(get: (Key) -> number)
		local values = {}
		for index, key in keys do
			values[index] = get(key)
		end
		return sampler(times, values, loop, duration)
	end
	local rotations = {}
	for _, joint in JOINTS do
		local axes = {}
		for axis = 1, 3 do
			axes[axis] = channel(function(key)
				local value = key[joint]
				return if value then value[axis] else 0
			end)
		end
		rotations[joint] = axes
	end
	local position = {}
	for axis = 1, 3 do
		position[axis] = channel(function(key)
			return if key.RootPos then key.RootPos[axis] else 0
		end)
	end
	local floor = channel(function(key)
		return key.floor or 0
	end)
	local hasMotion = spec.direction ~= nil
	local motionCurve = channel(function(key)
		return key.motion or 0
	end)
	local direction = spec.direction or { 0, -1 }
	local directionVector = Vector3.new(direction[1], 0, direction[2]).Unit
	local advance = channel(function(key)
		return key.advance or 0
	end)
	local rise = channel(function(key)
		return key.rise or 0
	end)
	-- Optional whole-body spin (degrees) about spec.spinAxis, before the Root angles.
	local spin = channel(function(key)
		return key.spin or 0
	end)
	local spinAxis = if spec.spinAxis
		then Vector3.new(spec.spinAxis[1], spec.spinAxis[2], spec.spinAxis[3]).Unit
		else nil
	-- Optional: the Root turns about a point spec.pivot hip units above its own pivot
	-- (R6: the hips), so a flip spins about the body's middle instead of the hips.
	local pivot = if spec.pivot then Vector3.new(0, spec.pivot, 0) else nil
	local joints, motion, floors, climb = {}, {}, {}, {}
	for _, joint in JOINTS do
		joints[joint] = table.create(frames)
	end
	for frame = 1, frames do
		local t = (frame - 1) / fps
		for _, joint in JOINTS do
			local axes = rotations[joint]
			local value =
				CFrame.Angles(math.rad(axes[1](t)), math.rad(axes[2](t)), math.rad(axes[3](t)))
			if joint == "Root" then
				if spinAxis then
					value = CFrame.fromAxisAngle(spinAxis, math.rad(spin(t))) * value
				end
				local offset = Vector3.new(position[1](t), position[2](t), position[3](t))
				if pivot then
					offset += pivot - value:VectorToWorldSpace(pivot)
				end
				value = CFrame.new(offset) * value
			end
			joints[joint][frame] = value
		end
		floors[frame] = floor(t)
		motion[frame] = directionVector * motionCurve(t)
		climb[frame] = Vector2.new(advance(t), rise(t))
	end
	return {
		name = name,
		fps = fps,
		frames = frames,
		duration = (if loop then frames else frames - 1) / fps,
		loop = loop,
		speed = spec.speed or 0,
		direction = directionVector,
		events = spec.events or {},
		joints = joints,
		motion = if hasMotion then motion else nil,
		floor = floors,
		contact = spec.contact,
		climb = if spec.climb then climb else nil,
	}
end

-- Continuous R6 run (v7.0; owner: the v5 pose-to-pose run looked stiff, robotic and
-- choppy, with arms, legs and lean all off). No holds: each leg sweeps back at a near-
-- steady rate while planted, flicks up behind, then swings through fast to strike;
-- arms swing opposite the legs (leading a little), cross in slightly going forward
-- and flare out going back; the chest twists against the hips and rolls toward the
-- planted leg while the head steadies; the body drops onto the planted foot and rises
-- in flight. Leg angles are from vertical (the hips add the lean back); arm angles are
-- world angles from vertical, converted to the chest. The owner picked the Power style
-- of three, then asked for it bouncier and more energetic (v7.1): a springy rise in
-- flight with a sharp dip onto each foot, the chest pumping forward on the dip, a
-- higher heel kick and punchier arms. The sprint is a more extreme version.
local FINE_FPS = 60 -- runs, flips and the slide: quick snaps need 60 fps keys
type FlowRun = {
	duration: number, -- two steps
	lean: number, -- whole body
	bend: number, -- chest, at the waist
	head: number, -- share of the lean the head takes back
	front: number, -- leg forward at foot strike
	back: number, -- leg behind at toe-off
	flick: number, -- extra back kick after toe-off
	stance: number, -- fraction of the cycle a foot is planted
	reach: number, -- arm at its forward extreme (negative: arms held back)
	swing: number, -- arm at its back extreme
	lead: number, -- arm phase lead, cycles
	across: number, -- inward angle at the forward swing
	out: number, -- arms away from the sides
	flare: number, -- extra outward angle at the back swing
	twist: number, -- chest turn against the hips
	roll: number, -- chest tilt toward the planted leg
	bob: number, -- rise in flight, hip units
	spring: number, -- bounce shape: under 1 rounds the top and sharpens the dip
	pump: number, -- chest pitch forward at the bottom of each bounce
	snap: number, -- arm wave shape: under 1 dwells at the ends for punchier swings
	speed: number, -- hip units per second at playback rate 1
	turn: number?, -- strafes: hips turned toward the travel (+ left; needs spinAxis up)
	chestBack: number?, -- share of the turn the chest takes back toward the camera
	reverse: boolean?, -- played backwards (the back-run)
}

-- Leg angle (+ forward) over a cycle; phi 0 is this foot's strike.
local function flowLeg(p: FlowRun, phi: number): number
	phi %= 1
	if phi < p.stance then
		local u = phi / p.stance
		local eased = u + 0.12 * math.sin(2 * math.pi * u) / (2 * math.pi)
		return p.front - (p.front + p.back) * eased
	end
	local u = (phi - p.stance) / (1 - p.stance)
	local flick = if u < 0.45 then p.flick * math.sin(math.pi * u / 0.45) else 0
	local eased = (0.5 - 0.5 * math.cos(math.pi * u)) ^ 0.85
	return -p.back + (p.front + p.back) * eased - flick
end

-- Arm angle (+ forward, world); phi 0 is the same-side arm's forward extreme.
local function flowArm(p: FlowRun, phi: number): number
	local c = math.cos(2 * math.pi * (phi + p.lead))
	c = math.sign(c) * math.abs(c) ^ p.snap
	return (p.reach + p.swing) / 2 + (p.reach - p.swing) / 2 * c
end

local function flowRun(p: FlowRun): { Key }
	local keys = {}
	local steps = math.round(p.duration * FINE_FPS)
	local chest = p.lean + p.bend
	local turn = p.turn or 0
	local chestTurn = -turn * (p.chestBack or 0)
	local headTurn = -turn - chestTurn -- the head faces the camera
	local function armOut(angle: number): number
		local back = math.clamp(-angle / math.max(math.abs(p.swing), 1), 0, 1)
		local forward = if p.reach > 0 then math.clamp(angle / p.reach, 0, 1) else 0
		return p.out + p.flare * back - p.across * forward
	end
	for step = 0, steps - 1 do
		local x = step / steps
		local left, right = flowLeg(p, x), flowLeg(p, x + 0.5)
		-- The left arm is forward when the right foot strikes (x = 0.5).
		local leftArm, rightArm = flowArm(p, x + 0.5), flowArm(p, x)
		local c = math.cos(2 * math.pi * x) -- +1 at the left strike
		local planted = math.min(math.abs(left), math.abs(right))
		local drop = 1 - math.cos(math.rad(planted))
		local flight = (0.5 - 0.5 * math.cos(4 * math.pi * (x - p.stance / 2))) ^ p.spring
		local pump = p.pump * (1 - flight)
		table.insert(keys, {
			t = (if p.reverse then (steps - step) % steps else step) / FINE_FPS,
			spin = turn,
			Root = { -p.lean, 0, 0 },
			RootPos = { 0, p.bob * flight - drop * 0.95, 0 },
			Waist = { -p.bend - pump, p.twist * c + chestTurn, p.roll * c },
			Neck = { chest * p.head + pump * 0.5, -p.twist * c + headTurn, -p.roll * c },
			LeftHip = { p.lean + left, 0, -2 },
			RightHip = { p.lean + right, 0, 2 },
			LeftShoulder = { chest + leftArm, 0, -armOut(leftArm) },
			RightShoulder = { chest + rightArm, 0, armOut(rightArm) },
		})
	end
	return keys
end

local RUN: FlowRun = {
	duration = 28 / FINE_FPS,
	lean = 16,
	bend = 14,
	head = 0.5,
	front = 48,
	back = 56,
	flick = 34,
	stance = 0.34,
	reach = 115,
	swing = -75,
	lead = 0.03,
	across = 18,
	out = 4,
	flare = 24,
	twist = 16,
	roll = 5,
	bob = 0.16,
	spring = 0.6,
	pump = 6,
	snap = 0.7,
	speed = 12,
}
-- Sprint (owner: more extreme than the run): more lean, reach, swing and kick, quicker.
local SPRINT: FlowRun = table.clone(RUN)
SPRINT.duration = 26 / FINE_FPS
SPRINT.lean = 22
SPRINT.bend = 18
SPRINT.front = 55
SPRINT.back = 68
SPRINT.flick = 40
SPRINT.stance = 0.32
SPRINT.reach = 130
SPRINT.swing = -85
SPRINT.across = 20
SPRINT.flare = 28
SPRINT.twist = 18
SPRINT.bob = 0.18
SPRINT.pump = 8
SPRINT.speed = 15
-- Strafes and the back-run (owner: they looked underwhelming and slow next to the run;
-- the old strafe was a short-stride cycle for 16 studs/s played at 24). Both come from
-- the run, at its cadence: strafes turn the hips 60 degrees into the travel with the
-- chest turned most of the way back to the camera and the head facing it; the back-run
-- is the run played backwards, upright, with a shorter reach.
local function strafeRun(turn: number): FlowRun
	local p = table.clone(RUN)
	p.turn, p.chestBack = turn, 0.75
	p.lean, p.bend = 12, 10
	p.front, p.back, p.flick = 42, 50, 28
	p.reach, p.swing, p.twist, p.bob = 100, -65, 12, 0.13
	return p
end
local BACK_RUN: FlowRun = table.clone(RUN)
BACK_RUN.reverse = true
BACK_RUN.lean, BACK_RUN.bend, BACK_RUN.head = 4, 6, 0.3
BACK_RUN.front, BACK_RUN.back, BACK_RUN.flick, BACK_RUN.stance = 34, 40, 12, 0.38
BACK_RUN.reach, BACK_RUN.swing, BACK_RUN.across, BACK_RUN.flare = 75, -55, 10, 14
BACK_RUN.twist, BACK_RUN.roll, BACK_RUN.bob = 10, 3, 0.1
BACK_RUN.spring, BACK_RUN.pump, BACK_RUN.snap, BACK_RUN.speed = 0.7, 3, 0.8, 11

-- R6 idle (owner, 2026-10-30: picked "Restless" of three, then asked for it more
-- animated). The weight rocks foot to foot (the hips counter the body's roll so the
-- feet stay planted) while the head looks around, once back over the shoulder, and
-- the chest lifts once. The arms hang nearly still (owner, 2026-10-30: they moved too
-- much). A 7.2 s loop; the body sits low and ground contact lifts it onto the feet.
local stand: { Key } = {
	{
		t = 0.0,
		Root = { -3, 0, 4 },
		RootPos = { 0, -0.1, 0 },
		Waist = { 1, 0, -5 },
		Neck = { -1, 20, 2 },
		LeftHip = { 0, 0, -11 },
		RightHip = { 0, 0, 3 },
		LeftShoulder = { -2.1, 0, -11.4 },
		RightShoulder = { 2.8, 0, 8.6 },
	},
	{
		t = 0.6,
		Root = { -3, 0, 0 },
		RootPos = { 0, -0.1, 0 },
		Waist = { 2, 0, 0 },
		Neck = { -2, 8, 0 },
		LeftHip = { 0, 0, -7 },
		RightHip = { 0, 0, 7 },
		LeftShoulder = { 1.4, 0, -10 },
		RightShoulder = { -1.4, 0, 10 },
	},
	{
		t = 1.2,
		Root = { -3, 0, -4 },
		RootPos = { 0, -0.1, 0 },
		Waist = { 1, 0, 5 },
		Neck = { -1, -20, -2 },
		LeftHip = { 0, 0, -3 },
		RightHip = { 0, 0, 11 },
		LeftShoulder = { 2.8, 0, -8.6 },
		RightShoulder = { -2.1, 0, 11.4 },
	},
	{
		t = 1.8,
		Root = { -3, 0, 0 },
		RootPos = { 0, -0.1, 0 },
		Waist = { 3, 0, 0 },
		Neck = { -4, -6, 0 },
		LeftHip = { 0, 0, -7 },
		RightHip = { 0, 0, 7 },
		LeftShoulder = { -0.7, 0, -10 },
		RightShoulder = { 0.7, 0, 10 },
	},
	{
		t = 2.4,
		Root = { -3, 0, 4 },
		RootPos = { 0, -0.1, 0 },
		Waist = { 1, 4, -5 },
		Neck = { -1, 25, 2 },
		LeftHip = { 0, 0, -11 },
		RightHip = { 0, 0, 3 },
		LeftShoulder = { -3.5, 0, -12.1 },
		RightShoulder = { 3.5, 0, 9.3 },
	},
	{
		t = 3.0,
		Root = { -3, 0, 4 },
		RootPos = { 0, -0.1, 0 },
		Waist = { 2, 8, -4 },
		Neck = { -3, 32, 4 },
		LeftHip = { 0, 0, -11 },
		RightHip = { 0, 0, 3 },
		LeftShoulder = { -2.8, 0, -11.8 },
		RightShoulder = { 3.1, 0, 9.7 },
	},
	{
		t = 3.6,
		Root = { -3, 0, 0 },
		RootPos = { 0, -0.1, 0 },
		Waist = { 2, 0, 0 },
		Neck = { -2, 0, 0 },
		LeftHip = { 0, 0, -7 },
		RightHip = { 0, 0, 7 },
		LeftShoulder = { 4.2, 0, -13.5 },
		RightShoulder = { 4.2, 0, 13.5 },
	},
	{
		t = 4.2,
		Root = { -3, 0, 0 },
		RootPos = { 0, -0.1, 0 },
		Waist = { 5, 0, 0 },
		Neck = { -5, 0, 0 },
		LeftHip = { 0, 0, -7 },
		RightHip = { 0, 0, 7 },
		LeftShoulder = { -3.1, 0, -8.9 },
		RightShoulder = { -3.1, 0, 8.9 },
	},
	{
		t = 4.8,
		Root = { -3, 0, -4 },
		RootPos = { 0, -0.1, 0 },
		Waist = { 1, -4, 5 },
		Neck = { -1, -22, -2 },
		LeftHip = { 0, 0, -3 },
		RightHip = { 0, 0, 11 },
		LeftShoulder = { 2.8, 0, -8.6 },
		RightShoulder = { -2.1, 0, 11.4 },
	},
	{
		t = 5.4,
		Root = { -3, 0, 0 },
		RootPos = { 0, -0.1, 0 },
		Waist = { 2, 0, 0 },
		Neck = { -3, -5, 0 },
		LeftHip = { 0, 0, -7 },
		RightHip = { 0, 0, 7 },
		LeftShoulder = { 0.7, 0, -10 },
		RightShoulder = { -0.7, 0, 10 },
	},
	{
		t = 6.0,
		Root = { -3, 0, 4 },
		RootPos = { 0, -0.1, 0 },
		Waist = { 1, 0, -5 },
		Neck = { -1, 15, 2 },
		LeftHip = { 0, 0, -11 },
		RightHip = { 0, 0, 3 },
		LeftShoulder = { -2.1, 0, -11.4 },
		RightShoulder = { 2.8, 0, 8.6 },
	},
	{
		t = 6.6,
		Root = { -3, 0, 0 },
		RootPos = { 0, -0.1, 0 },
		Waist = { 2, 0, 0 },
		Neck = { -2, 16, 1 },
		LeftHip = { 0, 0, -7 },
		RightHip = { 0, 0, 7 },
		LeftShoulder = { 0, 0, -10.3 },
		RightShoulder = { 0, 0, 10.3 },
	},
}

-- R6 air for walking off an edge (owner: stepping off stairs snapped straight to the
-- mocap jump's arm-up pose; real jumps keep the mocap running jump). A balanced pose
-- with the arms out, a calm fall and the reach for the ground; the presentation fades
-- the flail (fallLong) in only on long falls. Its takeoff and leap keys frame the
-- curve but do not play (falls start from the apex).
local air: { Key } = {
	{
		t = 0,
		Root = { -8, 0, 0 },
		Waist = { -4, 0, 0 },
		LeftHip = { -10, 0, -3 },
		RightHip = { -14, 0, 3 },
		LeftShoulder = { 60, 0, -15 },
		RightShoulder = { 40, 0, 15 },
	},
	{
		t = 0.15,
		Root = { -4, 0, 0 },
		Waist = { 2, 0, 0 },
		Neck = { 4, 0, 0 },
		LeftHip = { 35, 0, -4 },
		RightHip = { -15, 0, 4 },
		LeftShoulder = { -20, 0, -35 },
		RightShoulder = { 85, 0, 25 },
	},
	{
		t = 0.35,
		Root = { -2, 0, 0 },
		Waist = { 2, 0, 0 },
		Neck = { 2, 0, 0 },
		LeftHip = { 28, 0, -6 },
		RightHip = { -18, 0, 6 },
		LeftShoulder = { 25, 0, -55 },
		RightShoulder = { 30, 0, 55 },
	},
	{
		t = 0.55,
		Neck = { -8, 0, 0 },
		LeftHip = { 15, 0, -7 },
		RightHip = { 4, 0, 7 },
		LeftShoulder = { 20, 0, -65 },
		RightShoulder = { 20, 0, 65 },
	},
	{
		t = 0.75,
		Root = { -4, 0, 0 },
		Waist = { -6, 0, 0 },
		Neck = { -10, 0, 0 },
		LeftHip = { 22, 0, -8 },
		RightHip = { 18, 0, 8 },
		LeftShoulder = { 45, 0, -40 },
		RightShoulder = { 45, 0, 40 },
	},
}
local fallLong: { Key } = { -- arms up and legs cycling
	{
		t = 0,
		Root = { 6, 0, 0 },
		Waist = { 8, 0, 0 },
		Neck = { 10, 0, 0 },
		LeftHip = { 20, 0, -18 },
		RightHip = { -10, 0, 14 },
		LeftShoulder = { 150, 0, -40 },
		RightShoulder = { 120, 0, 50 },
	},
	{
		t = 0.5,
		Root = { 6, 0, 0 },
		Waist = { 8, 0, 0 },
		Neck = { 10, 0, 0 },
		LeftHip = { -10, 0, -14 },
		RightHip = { 20, 0, 18 },
		LeftShoulder = { 120, 0, -50 },
		RightShoulder = { 150, 0, 40 },
	},
}

local fall: { Key } = {
	{
		t = 0,
		Root = { -8, 0, 0 },
		Waist = { -6, 0, 0 },
		Neck = { 8, 0, 0 },
		LeftHip = { 35, 0, -8 },
		LeftKnee = { -50, 0, 0 },
		LeftAnkle = { -10, 0, 0 },
		RightHip = { 5, 0, 8 },
		RightKnee = { -25, 0, 0 },
		RightAnkle = { -15, 0, 0 },
		LeftShoulder = { 95, 0, -55 },
		LeftElbow = { 25, 0, 0 },
		RightShoulder = { 110, 0, 50 },
		RightElbow = { 30, 0, 0 },
	},
	{
		t = 0.5,
		Root = { -8, 0, 0 },
		Waist = { -6, 0, 0 },
		Neck = { 8, 0, 0 },
		LeftHip = { 10, 0, -8 },
		LeftKnee = { -30, 0, 0 },
		LeftAnkle = { -15, 0, 0 },
		RightHip = { 35, 0, 8 },
		RightKnee = { -55, 0, 0 },
		RightAnkle = { -10, 0, 0 },
		LeftShoulder = { 115, 0, -50 },
		LeftElbow = { 30, 0, 0 },
		RightShoulder = { 95, 0, 55 },
		RightElbow = { 25, 0, 0 },
	},
}

local function legs(
	t: number,
	hipL: number,
	hipR: number,
	kneeL: number,
	kneeR: number,
	ankle: number
): Key
	return {
		t = t,
		LeftHip = { hipL, 0, -3 },
		RightHip = { hipR, 0, 3 },
		LeftKnee = { kneeL, 0, 0 },
		RightKnee = { kneeR, 0, 0 },
		LeftAnkle = { ankle, 0, 0 },
		RightAnkle = { ankle, 0, 0 },
	}
end

-- Adds symmetric arm, torso and root channels to a key.
local function upper(key: Key, fields: any): Key
	for field, value in fields do
		key[field] = value
	end
	if fields.Shoulder then
		local s = fields.Shoulder
		key.LeftShoulder = { s[1], 0, -s[2] }
		key.RightShoulder = { s[1], 0, s[2] }
		key.Shoulder = nil
	end
	if fields.Elbow then
		key.LeftElbow = { fields.Elbow, 0, 0 }
		key.RightElbow = { fields.Elbow, 0, 0 }
		key.Elbow = nil
	end
	return key
end

local jump: { Key } = {
	upper(legs(0, 50, 50, -70, -70, 25), {
		Root = { -12, 0, 0 },
		RootPos = { 0, -0.2, 0 },
		Waist = { -15, 0, 0 },
		Shoulder = { -30, 8 },
		Elbow = 20,
	}),
	upper(legs(0.1, -4, -6, -6, -4, -30), { -- takeoff: full extension, arms drive up
		Root = { -4, 0, 0 },
		Waist = { 2, 0, 0 },
		Neck = { -3, 0, 0 },
		Shoulder = { 150, 10 },
		Elbow = 15,
	}),
	upper(legs(0.28, 70, 40, -95, -60, -15), {
		Root = { -4, 0, 0 },
		RootPos = { 0, 0.05, 0 },
		Waist = { -6, 0, 0 },
		Shoulder = { 110, 25 },
		Elbow = 40,
	}),
	upper(legs(0.45, 60, 45, -80, -70, -10), { -- apex: arms out for balance
		Root = { -5, 0, 0 },
		RootPos = { 0, 0.05, 0 },
		Waist = { -8, 0, 0 },
		Shoulder = { 80, 55 },
		Elbow = 35,
	}),
	upper(legs(0.62, 35, 25, -45, -35, 0), {
		Root = { -5, 0, 0 },
		Waist = { -8, 0, 0 },
		Shoulder = { 65, 45 },
		Elbow = 30,
	}),
	upper(legs(0.78, 22, 18, -18, -15, 12), { -- reach for the ground
		Root = { -6, 0, 0 },
		Waist = { -10, 0, 0 },
		Shoulder = { 50, 30 },
		Elbow = 30,
	}),
	upper(legs(0.9, 55, 55, -80, -80, 25), {
		Root = { -10, 0, 0 },
		RootPos = { 0, -0.25, 0 },
		Waist = { -20, 0, 0 },
		Shoulder = { 45, 25 },
		Elbow = 35,
	}),
}

local land: { Key } = {
	upper(
		legs(0, 22, 18, -18, -15, 10),
		{ Waist = { -8, 0, 0 }, Shoulder = { 50, 30 }, Elbow = 30 }
	),
	upper(legs(0.1, 62, 55, -95, -88, 28), { -- absorb
		Root = { -10, 0, 0 },
		RootPos = { 0, -0.3, 0 },
		Waist = { -22, 0, 0 },
		Neck = { 18, 0, 0 },
		Shoulder = { 35, 25 },
		Elbow = 40,
	}),
	upper(legs(0.45, 12, 10, -16, -14, 5), {
		RootPos = { 0, -0.04, 0 },
		Waist = { -6, 0, 0 },
		Shoulder = { 10, 10 },
		Elbow = 20,
	}),
}

-- Flips (owner, 2026-10-30). R6 block poses that snap from a set into the shape, spin
-- fastest while compact, open wide and slow into the landing. They turn about the
-- torso's middle (pivot), not the hips.
--   Back: layout with a full twist, arms locked overhead ("a really cool twirl").
--   Diagonals (front-side and back-side): tilted corkscrew, legs split, one arm up.
--   Front: the owner's pick, a front full step-out (winged layout, arms snapping in to
--   twist a full turn in step with the somersault, stepping out to land).
--   Side: the owner's pick, a horizontal twist (the flat counterpart of the back and
--   diagonal twists, acrobatic rather than a torpedo), after tricking's butterfly
--   twist: the body dips and goes flat, a straight leg kicks up, the legs straddle and
--   the arms open like wings, then the body twists a full turn while sweeping round,
--   the arms windmilling (one reaching overhead along the body, the other swept back,
--   then swapping; owner: the crossed arms looked restricted), and opens to land.
-- Only takeoff..land plays in the air, rate-matched to the airtime.
local function flipPose(waist: number, neck: number, hip: { number }, shoulder: { number }): Key
	-- Symmetric: hip and shoulder are the right side's; the left mirrors sideways.
	return {
		Waist = { waist, 0, 0 },
		Neck = { neck, 0, 0 },
		RightHip = hip,
		LeftHip = { hip[1], -hip[2], -hip[3] },
		RightShoulder = shoulder,
		LeftShoulder = { shoulder[1], -shoulder[2], -shoulder[3] },
	}
end
-- Asymmetric pose; tilt { x, z } leans the whole body (Root) before the spin.
local function flipShape(
	waist: number,
	neck: number,
	rightHip: { number },
	leftHip: { number },
	rightShoulder: { number },
	leftShoulder: { number },
	tilt: { number }?
): Key
	return {
		Waist = { waist, 0, 0 },
		Neck = { neck, 0, 0 },
		RightHip = rightHip,
		LeftHip = leftHip,
		RightShoulder = rightShoulder,
		LeftShoulder = leftShoulder,
		tilt = tilt,
	}
end
local FLIP_POSES: { [string]: Key } = {
	setFront = flipPose(-5, -5, { -6, 0, 3 }, { 165, 0, 12 }), -- stretched, arms driving up
	setBack = flipPose(10, 18, { -4, 0, 3 }, { 172, 0, 8 }),
	whip = flipPose(-22, -25, { 60, 0, 4 }, { 110, 0, 12 }), -- arms throwing down, knees coming up
	arch = flipPose(14, 28, { -14, 0, 3 }, { 178, 0, 6 }),
	rocket = flipPose(0, -6, { 0, 0, 1 }, { 174, 0, -5 }), -- straight, arms locked overhead
	tight = flipPose(-40, -35, { 155, 0, 5 }, { 60, 0, 12 }), -- legs to the chest, arms round them
	open = flipPose(6, 10, { -8, 0, 10 }, { 150, 0, 50 }), -- kick-out: arms flung up and out
	hang = flipPose(0, 0, { 6, 0, 8 }, { 110, 0, 75 }), -- opened out wide
	landPrep = flipPose(-10, -6, { 28, 0, 6 }, { 75, 0, 45 }),
	land = flipPose(-18, -8, { 48, 0, 5 }, { 45, 0, 35 }),
	cork = flipShape(4, 6, { -22, 0, 10 }, { 18, 0, -10 }, { 80, 0, -42 }, { 174, 0, 5 }),
	-- Front: the front full step-out (owner's pick, 2026-10-30), after the front full
	-- twist technique: a layout with winged arms (heels up), the arms close across the
	-- chest to twist and open and lift to stop, the legs splitting to step out.
	lwSet = flipPose(-4, 0, { -8, 0, 3 }, { 40, 0, 60 }),
	lwWings = flipPose(-8, 10, { -18, 0, 3 }, { 10, 0, 88 }),
	lwStep = flipShape(-4, 8, { 40, 0, 3 }, { -35, 0, -3 }, { 40, 0, 80 }, { 40, 0, -80 }),
	lwReach = flipShape(-6, 0, { 50, 0, 3 }, { -40, 0, -3 }, { 140, 0, 35 }, { 140, 0, -35 }),
	ffWrap = flipShape(-6, 5, { -12, 0, 2 }, { -12, 0, -2 }, { 70, 0, -45 }, { 70, 0, 45 }),
	ffOpen = flipShape(-4, 10, { 20, 0, 4 }, { -25, 0, -4 }, { 150, 0, 60 }, { 150, 0, -60 }),
	-- Side flips are authored to the right (turning clockwise from above): the left leg
	-- kicks up first.
	bWind = flipShape( -- dipping, arms swung across to the left against the turn
		-20,
		15,
		{ 10, 0, 4 },
		{ -40, 0, -15 },
		{ 70, 0, -55 },
		{ 35, 0, -85 },
		{ -35, 0 }
	),
	bWings = flipShape(
		-5,
		30,
		{ 15, 0, 25 },
		{ -75, 0, -30 },
		{ 0, 0, 88 },
		{ 0, 0, -88 },
		{ -80, 0 }
	),
	-- Windmill through the twist: right arm overhead and left swept back, both wide,
	-- then left overhead and right swept back.
	bLeadRight = flipShape(
		0,
		10,
		{ -15, 0, 8 },
		{ -5, 0, -10 },
		{ 175, 0, 12 },
		{ -35, 0, -25 },
		{ -85, 0 }
	),
	bSwap = flipShape(
		0,
		10,
		{ -10, 0, 12 },
		{ -10, 0, -12 },
		{ 90, 0, 85 },
		{ 120, 0, -70 },
		{ -85, 0 }
	),
	bLeadLeft = flipShape(
		0,
		10,
		{ -5, 0, 10 },
		{ -15, 0, -8 },
		{ -35, 0, 25 },
		{ 175, 0, -12 },
		{ -85, 0 }
	),
	bOpen = flipShape(
		-5,
		20,
		{ 20, 0, 30 },
		{ -30, 0, -35 },
		{ 30, 0, 80 },
		{ 30, 0, -80 },
		{ -60, 0 }
	),
	bReach = flipShape(
		-10,
		5,
		{ -50, 0, 15 },
		{ 20, 0, -6 },
		{ 60, 0, 70 },
		{ 60, 0, -70 },
		{ -25, 0 }
	),
}
-- { t, pose, spin, twist, sink }: spin (degrees) about the flip axis, twist about the
-- body's length, sink lowers the root (hip units). pivot: hip units above the hips.
-- vertical: spin about the vertical (turning toward the side) instead of across it.
local FLIP_STYLES: { [string]: { pivot: number, vertical: boolean?, keys: { { any } } } } = {
	Back = { -- the owner's favourite; the diagonals share its timing
		pivot = 0.4,
		keys = {
			{ 0, "setBack", 0, 0 },
			{ 0.08, "arch", 35, 0 },
			{ 0.14, "rocket", 95, 20 },
			{ 0.21, "rocket", 175, 130 },
			{ 0.28, "rocket", 250, 250 },
			{ 0.35, "rocket", 315, 340 },
			{ 0.43, "hang", 350, 360 },
			{ 0.52, "landPrep", 360, 360 },
			{ 0.6, "land", 360, 360, -0.1 },
			{ 0.8, "land", 360, 360, -0.1 },
		},
	},
	-- The back-side corkscrew tipping forward (owner: diagonals all the same flip).
	FrontSide = {
		pivot = 0.4,
		keys = {
			{ 0, "setFront", 0, 0 },
			{ 0.07, "cork", 30, 0 },
			{ 0.14, "cork", 95, -20 },
			{ 0.21, "cork", 175, -130 },
			{ 0.28, "cork", 250, -250 },
			{ 0.35, "cork", 315, -340 },
			{ 0.43, "hang", 350, -360 },
			{ 0.52, "landPrep", 360, -360 },
			{ 0.6, "land", 360, -360, -0.1 },
			{ 0.8, "land", 360, -360, -0.1 },
		},
	},
	BackSide = {
		pivot = 0.4,
		keys = {
			{ 0, "setBack", 0, 0 },
			{ 0.08, "arch", 35, 0 },
			{ 0.14, "cork", 95, -20 },
			{ 0.21, "cork", 175, -130 },
			{ 0.28, "cork", 250, -250 },
			{ 0.35, "cork", 315, -340 },
			{ 0.43, "hang", 350, -360 },
			{ 0.52, "landPrep", 360, -360 },
			{ 0.6, "land", 360, -360, -0.1 },
			{ 0.8, "land", 360, -360, -0.1 },
		},
	},
	-- Front full step-out (owner's pick). The twist tracks the somersault exactly, so the
	-- face is only ever away from the camera or side-on, never looking back (owner); a
	-- fraction faster than the candidate (rotation done by 0.46, was 0.48).
	FrontFullStepOut = {
		pivot = 0.4,
		keys = {
			{ 0, "lwSet", 0, 0 },
			{ 0.067, "lwWings", 40, 40 },
			{ 0.134, "lwWings", 110, 110 },
			{ 0.192, "ffWrap", 175, 175 },
			{ 0.259, "ffWrap", 245, 245 },
			{ 0.326, "ffOpen", 310, 310 },
			{ 0.394, "lwStep", 345, 345 },
			{ 0.46, "lwReach", 360, 360 },
			{ 0.6, "land", 360, 360, -0.1 },
			{ 0.8, "land", 360, 360, -0.1 },
		},
	},
	-- Twist peaks near 1650 degrees/s at rate 1.
	BTwist = {
		pivot = 0.45,
		vertical = true,
		keys = {
			{ 0, "bWind", 0, 0 },
			{ 0.07, "bWings", 40, 0 },
			{ 0.13, "bLeadRight", 100, -50 },
			{ 0.2, "bSwap", 175, -170 },
			{ 0.27, "bLeadLeft", 250, -290 },
			{ 0.33, "bOpen", 310, -350 },
			{ 0.4, "bReach", 345, -360 },
			{ 0.47, "hang", 360, -360 },
			{ 0.54, "landPrep", 360, -360 },
			{ 0.6, "land", 360, -360, -0.1 },
			{ 0.8, "land", 360, -360, -0.1 },
		},
	},
}
-- Degrees from facing (+ right) and style; left-hand flips mirror the right-hand ones.
local FLIP_DIRECTIONS: { [string]: { any } } = {
	FlipFront = { 0, "FrontFullStepOut" },
	FlipFrontRight = { 45, "FrontSide" },
	FlipRight = { 90, "BTwist" },
	FlipBackRight = { 135, "BackSide" },
	FlipBack = { 180, "Back" },
	FlipBackLeft = { -135, "BackSide" },
	FlipLeft = { -90, "BTwist" },
	FlipFrontLeft = { -45, "FrontSide" },
}
local function flipToward(angle: number, style: string): ({ Key }, { number }, number)
	local spec = FLIP_STYLES[style]
	local keys = {}
	for _, entry in spec.keys do
		local key: Key = table.clone(FLIP_POSES[entry[2]])
		local tilt = key.tilt or { 0, 0 }
		key.tilt = nil
		key.t, key.spin = entry[1], entry[3]
		key.Root = { tilt[1], entry[4], tilt[2] }
		key.RootPos = { 0, entry[5] or 0, 0 }
		table.insert(keys, if angle < 0 then mirrorKey(key) else key)
	end
	if spec.vertical then
		-- Turning toward the side: clockwise from above for a flip to the right.
		return keys, { 0, if angle < 0 then 1 else -1, 0 }, spec.pivot
	end
	-- Up crossed with the direction (sin a, 0, -cos a): the head leads that way.
	local a = math.rad(angle)
	return keys, { -math.cos(a), 0, -math.sin(a) }, spec.pivot
end

-- Slide (owner: CoD/Rivals-style, snappy, cool). Kicks the lead leg out while
-- dropping (0.06 s), lands low with a little overshoot (0.12 s) and settles: pelvis
-- back 50 degrees and the torso a little further, turned toward the trailing left hand
-- that brushes the floor behind, right leg out along the ground, left knee up (an R6
-- leg cannot fold), right arm reaching ahead, head looking ahead. It drifts while held
-- and starts to sit up by the end (Acrobatics.Slide.Duration), so the hand-off to the
-- run reads as a pop-up. Contacts fitted on the R6 block render (lead leg on the floor,
-- hand 0.1 above it). Body contact keeps the lowest part on the floor.
local function slideKey(t: number, values: { [string]: { number } }): Key
	local key: Key = table.clone(values)
	key.t = t
	return key
end
local slideHold = {
	Root = { 50, 8, 4 },
	RootPos = { 0, -0.5, 0 },
	Waist = { 6, 12, 2 },
	Neck = { -48, -20, 0 },
	RightHip = { 23, 0, 6 },
	LeftHip = { 80, 0, -12 },
	LeftShoulder = { -120, 0, -45 },
	RightShoulder = { 40, 0, 12 },
}
local slideRise = {
	Root = { 38, 6, 2 },
	RootPos = { 0, -0.4, 0 },
	Waist = { 2, 8, 0 },
	Neck = { -36, -15, 0 },
	RightHip = { 32, 0, 6 },
	LeftHip = { 58, 0, -10 },
	LeftShoulder = { -80, 0, -30 },
	RightShoulder = { 50, 0, 15 },
}
local slide: { Key } = {
	slideKey(0, {
		Root = { -6, 0, 0 },
		RootPos = { 0, -0.12, 0 },
		RightHip = { 25, 0, 4 },
		LeftHip = { -10, 0, -6 },
		LeftShoulder = { -20, 0, -10 },
		RightShoulder = { 30, 0, 10 },
	}),
	slideKey(0.06, {
		Root = { 24, 4, 2 },
		RootPos = { 0, -0.35, 0 },
		Waist = { 0, 6, 0 },
		Neck = { -25, -10, 0 },
		RightHip = { 55, 0, 6 },
		LeftHip = { 50, 0, -10 },
		LeftShoulder = { -75, 0, -35 },
		RightShoulder = { 75, 0, 25 },
	}),
	slideKey(0.12, {
		Root = { 54, 9, 5 },
		RootPos = { 0, -0.55, 0 },
		Waist = { 6, 13, 2 },
		Neck = { -56, -22, 0 },
		RightHip = { 22, 0, 6 },
		LeftHip = { 84, 0, -12 },
		LeftShoulder = { -126, 0, -48 },
		RightShoulder = { 46, 0, 14 },
	}),
	slideKey(0.24, slideHold),
	slideKey(0.48, {
		Root = { 50, 8, 4 },
		RootPos = { 0, -0.48, 0 },
		Waist = { 6, 12, 2 },
		Neck = { -46, -18, 0 },
		RightHip = { 24, 0, 6 },
		LeftHip = { 78, 0, -12 },
		LeftShoulder = { -116, 0, -44 },
		RightShoulder = { 34, 0, 10 },
	}),
	slideKey(0.74, slideRise),
	slideKey(1.2, slideRise),
}

-- Mantles (owner, 2026-10-30: the old ones were horrible on R6 and over in 0.2-0.3 s;
-- make them smooth, visible, frictionless, not slow). Original R6 clips after parkour
-- technique (climb-up: grip the top, pull the chest up and lean over, transfer the
-- weight onto the hands, a leg onto the top, stand; step and kong vaults), checked
-- frame by frame on the R6 renderer against the client's root path: from 0.8 studs off
-- the face, rising by the ledge height, to standing 1.5 studs past the edge. They face
-- the ledge; advance/rise are the root's progress over and up (0..1); each ends in a
-- running pose. Hands meet the top at the plant for typical heights.
local mantleHigh: { Key } =
	{ -- climb-up: catch, pull, lean over onto the hands, step up, stand into the run
		{
			t = 0,
			Root = { 0, 0, 0 },
			Waist = { -4, 0, 0 },
			Neck = { 20, 0, 0 },
			LeftHip = { 20, 0, -4 },
			RightHip = { -8, 0, 4 },
			LeftShoulder = { 172, 0, -12 },
			RightShoulder = { 172, 0, 12 },
			advance = 0,
			rise = 0,
		},
		{
			t = 0.12,
			Root = { -14, 0, 0 },
			Waist = { -8, 0, 0 },
			Neck = { 22, 0, 0 },
			LeftHip = { 55, 0, -4 },
			RightHip = { -5, 0, 4 },
			LeftShoulder = { 104, 0, -16 },
			RightShoulder = { 104, 0, 16 },
			advance = 0.04,
			rise = 0.3,
		},
		{
			t = 0.24,
			Root = { -30, 0, 0 },
			Waist = { -12, 0, 0 },
			Neck = { 26, 0, 0 },
			LeftHip = { 95, 0, -6 },
			RightHip = { -20, 0, 6 },
			LeftShoulder = { 36, 0, -16 },
			RightShoulder = { 36, 0, 16 },
			advance = 0.22,
			rise = 0.72,
		},
		{
			t = 0.36,
			Root = { -26, 0, 0 },
			Waist = { -10, 0, 0 },
			Neck = { 20, 0, 0 },
			LeftHip = { 40, 0, -4 },
			RightHip = { -35, 0, 6 },
			LeftShoulder = { 0, 0, -18 },
			RightShoulder = { 0, 0, 18 },
			advance = 0.55,
			rise = 0.96,
		},
		{
			t = 0.46,
			Root = { -18, 0, 0 },
			Waist = { -8, 0, 0 },
			Neck = { 12, 0, 0 },
			LeftHip = { -10, 0, -3 },
			RightHip = { 40, 0, 3 },
			LeftShoulder = { -30, 0, -10 },
			RightShoulder = { 55, 0, 12 },
			advance = 0.82,
			rise = 1,
		},
		{
			t = 0.55,
			Root = { -14, 0, 0 },
			Waist = { -8, 0, 0 },
			Neck = { 10, 0, 0 },
			LeftHip = { -25, 0, -2 },
			RightHip = { 30, 0, 2 },
			LeftShoulder = { 60, 0, -8 },
			RightShoulder = { -35, 0, 10 },
			advance = 1,
			rise = 1,
		},
	}
local mantleLow: { Key } =
	{ -- step-up: right hand plants, left foot onto the top, right leg swings through
		{
			t = 0,
			Root = { -12, 0, 0 },
			Waist = { -6, 0, 0 },
			Neck = { 10, 0, 0 },
			LeftHip = { 45, 0, -4 },
			RightHip = { -15, 0, 4 },
			LeftShoulder = { -20, 0, -12 },
			RightShoulder = { 75, 0, 10 },
			advance = 0,
			rise = 0,
		},
		{
			t = 0.12,
			Root = { -24, 0, 0 },
			Waist = { -10, 0, 0 },
			Neck = { 18, 0, 0 },
			LeftHip = { 80, 0, -4 },
			RightHip = { -20, 0, 6 },
			LeftShoulder = { 40, 0, -18 },
			RightShoulder = { 12, 0, 10 },
			advance = 0.22,
			rise = 0.55,
		},
		{
			t = 0.24,
			Root = { -22, 0, 0 },
			Waist = { -8, 0, 0 },
			Neck = { 14, 0, 0 },
			LeftHip = { 15, 0, -3 },
			RightHip = { 50, 0, 6 },
			LeftShoulder = { 60, 0, -14 },
			RightShoulder = { -5, 0, 12 },
			advance = 0.55,
			rise = 0.95,
		},
		{
			t = 0.33,
			Root = { -16, 0, 0 },
			Waist = { -8, 0, 0 },
			Neck = { 10, 0, 0 },
			LeftHip = { -20, 0, -2 },
			RightHip = { 35, 0, 3 },
			LeftShoulder = { -25, 0, -10 },
			RightShoulder = { 60, 0, 12 },
			advance = 0.82,
			rise = 1,
		},
		{
			t = 0.4,
			Root = { -14, 0, 0 },
			Waist = { -8, 0, 0 },
			Neck = { 10, 0, 0 },
			LeftHip = { -30, 0, -2 },
			RightHip = { 28, 0, 2 },
			LeftShoulder = { -35, 0, -10 },
			RightShoulder = { 65, 0, 10 },
			advance = 1,
			rise = 1,
		},
	}
local mantleVault: { Key } =
	{ -- pop-up (the jump nearly reaches the top): slap the edge, tuck up, land on top
		{
			t = 0,
			Root = { -6, 0, 0 },
			Waist = { -4, 0, 0 },
			Neck = { 16, 0, 0 },
			LeftHip = { 25, 0, -6 },
			RightHip = { 10, 0, 6 },
			LeftShoulder = { 100, 0, -22 },
			RightShoulder = { 100, 0, 22 },
			advance = 0,
			rise = 0,
		},
		{
			t = 0.1,
			Root = { -38, 0, 0 },
			Waist = { -12, 0, 0 },
			Neck = { 30, 0, 0 },
			LeftHip = { 70, 0, -8 },
			RightHip = { 55, 0, 8 },
			LeftShoulder = { 30, 0, -18 },
			RightShoulder = { 30, 0, 18 },
			advance = 0.12,
			rise = 0.55,
		},
		{
			t = 0.2,
			Root = { -40, 0, 0 },
			Waist = { -10, 0, 0 },
			Neck = { 30, 0, 0 },
			LeftHip = { 100, 0, -10 },
			RightHip = { 92, 0, 10 },
			LeftShoulder = { 5, 0, -18 },
			RightShoulder = { 5, 0, 18 },
			advance = 0.38,
			rise = 0.95,
		},
		{
			t = 0.3,
			Root = { -22, 0, 0 },
			Waist = { -8, 0, 0 },
			Neck = { 16, 0, 0 },
			LeftHip = { 45, 0, -6 },
			RightHip = { 25, 0, 6 },
			LeftShoulder = { -20, 0, -30 },
			RightShoulder = { -20, 0, 30 },
			advance = 0.7,
			rise = 1,
		},
		{
			t = 0.38,
			Root = { -16, 0, 0 },
			Waist = { -8, 0, 0 },
			Neck = { 10, 0, 0 },
			LeftHip = { -15, 0, -2 },
			RightHip = { 30, 0, 2 },
			LeftShoulder = { 40, 0, -12 },
			RightShoulder = { -20, 0, 12 },
			advance = 0.9,
			rise = 1,
		},
		{
			t = 0.45,
			Root = { -14, 0, 0 },
			Waist = { -8, 0, 0 },
			Neck = { 10, 0, 0 },
			LeftHip = { -25, 0, -2 },
			RightHip = { 30, 0, 2 },
			LeftShoulder = { 60, 0, -8 },
			RightShoulder = { -35, 0, 10 },
			advance = 1,
			rise = 1,
		},
	}
-- Kong vault over a thin obstacle (Vault): rise is the arc over it (times the lift).
local kongVault: { Key } = { -- dive, plant, tuck through, push off, fly in a split, land running
	{
		t = 0,
		Root = { -10, 0, 0 },
		Waist = { -4, 0, 0 },
		Neck = { 10, 0, 0 },
		LeftHip = { -40, 0, -4 },
		RightHip = { 70, 0, 6 },
		LeftShoulder = { -35, 0, -16 },
		RightShoulder = { -35, 0, 16 },
		advance = 0,
		rise = 0,
	},
	{
		t = 0.05,
		Root = { -35, 0, 0 },
		Waist = { -8, 0, 0 },
		Neck = { 30, 0, 0 },
		LeftHip = { -45, 0, -6 },
		RightHip = { 60, 0, 6 },
		LeftShoulder = { 80, 0, -12 },
		RightShoulder = { 80, 0, 12 },
		advance = 0.086,
		rise = 0.15,
	},
	{
		t = 0.1,
		Root = { -65, 0, 0 },
		Waist = { -6, 0, 0 },
		Neck = { 50, 0, 0 },
		LeftHip = { -30, 0, -6 },
		RightHip = { -12, 0, 6 },
		LeftShoulder = { 165, 0, -10 },
		RightShoulder = { 165, 0, 10 },
		advance = 0.172,
		rise = 0.42,
	},
	{
		t = 0.15,
		Root = { -92, 0, 0 },
		Waist = { -10, 0, 0 },
		Neck = { 60, 0, 0 },
		LeftHip = { -18, 0, -8 },
		RightHip = { -30, 0, 8 },
		LeftShoulder = { 90, 0, -16 },
		RightShoulder = { 90, 0, 16 },
		advance = 0.259,
		rise = 0.68,
	},
	{
		t = 0.21,
		Root = { -62, 0, 0 },
		Waist = { -16, 0, 0 },
		Neck = { 45, 0, 0 },
		LeftHip = { 138, 0, -6 },
		RightHip = { 130, 0, 6 },
		LeftShoulder = { 38, 0, -20 },
		RightShoulder = { 38, 0, 20 },
		advance = 0.362,
		rise = 0.84,
	},
	{
		t = 0.27,
		Root = { -36, 0, 0 },
		Waist = { -4, 0, 0 },
		Neck = { 28, 0, 0 },
		LeftHip = { 110, 0, -6 },
		RightHip = { 85, 0, 6 },
		LeftShoulder = { -40, 0, -28 },
		RightShoulder = { -40, 0, 28 },
		advance = 0.466,
		rise = 0.82,
	},
	{
		t = 0.34,
		Root = { -16, 0, 0 },
		Waist = { 2, 4, 0 },
		Neck = { 14, -4, 0 },
		LeftHip = { 82, 0, -4 },
		RightHip = { 40, 0, 4 },
		LeftShoulder = { -45, 0, -38 },
		RightShoulder = { 72, 0, 22 },
		advance = 0.586,
		rise = 0.62,
	},
	{
		t = 0.42,
		Root = { -16, 0, 0 },
		Waist = { -2, 2, 0 },
		Neck = { 12, -2, 0 },
		LeftHip = { 45, 0, -3 },
		RightHip = { -2, 0, 3 },
		LeftShoulder = { -25, 0, -26 },
		RightShoulder = { 52, 0, 14 },
		advance = 0.724,
		rise = 0.3,
	},
	{
		t = 0.5,
		Root = { -22, 0, 0 },
		Waist = { -10, 0, 0 },
		Neck = { 16, 0, 0 },
		LeftHip = { 18, 0, -2 },
		RightHip = { -38, 0, 2 },
		LeftShoulder = { 25, 0, -12 },
		RightShoulder = { -30, 0, 12 },
		advance = 0.862,
		rise = 0.06,
	},
	{
		t = 0.58,
		Root = { -14, 0, 0 },
		Waist = { -8, 0, 0 },
		Neck = { 10, 0, 0 },
		LeftHip = { -25, 0, -2 },
		RightHip = { 30, 0, 2 },
		LeftShoulder = { 60, 0, -8 },
		RightShoulder = { -35, 0, 10 },
		advance = 1,
		rise = 0,
	},
}

-- Wall kick, facing away from the wall: the right foot pushes off behind, the left
-- knee and both arms drive up, then settle into the jump's apex pose.
local wallHop: { Key } = {
	{
		t = 0,
		Root = { -18, 0, 0 },
		Waist = { -10, 0, 0 },
		Neck = { 8, 0, 0 },
		LeftHip = { 95, 0, -4 },
		LeftKnee = { -110, 0, 0 },
		LeftAnkle = { 10, 0, 0 },
		RightHip = { -40, 0, 4 },
		RightKnee = { -20, 0, 0 },
		RightAnkle = { -35, 0, 0 },
		LeftShoulder = { -25, 0, -15 },
		RightShoulder = { -25, 0, 15 },
		LeftElbow = { 40, 0, 0 },
		RightElbow = { 40, 0, 0 },
	},
	{ -- push: trailing leg extends, arms drive up
		t = 0.08,
		Root = { -12, 0, 0 },
		Waist = { -6, 0, 0 },
		LeftHip = { 100, 0, -4 },
		LeftKnee = { -95, 0, 0 },
		RightHip = { -25, 0, 4 },
		RightKnee = { -8, 0, 0 },
		RightAnkle = { -40, 0, 0 },
		LeftShoulder = { 150, 0, -18 },
		RightShoulder = { 150, 0, 18 },
		LeftElbow = { 15, 0, 0 },
		RightElbow = { 15, 0, 0 },
	},
	upper(legs(0.22, 85, 40, -100, -75, -15), {
		Root = { -6, 0, 0 },
		Waist = { -6, 0, 0 },
		Shoulder = { 115, 40 },
		Elbow = 30,
	}),
	upper(legs(0.4, 60, 45, -80, -70, -10), { -- the jump clip's apex pose
		Root = { -5, 0, 0 },
		RootPos = { 0, 0.05, 0 },
		Waist = { -8, 0, 0 },
		Shoulder = { 80, 55 },
		Elbow = 35,
	}),
}

function OriginalClips.build(): { [string]: any }
	local specs: { [string]: any } = {
		Air = { keys = air, duration = 0.75, events = { takeoff = 0, apex = 0.35, land = 0.75 } },
		FallLong = { keys = fallLong, duration = 1, loop = true },
		Fall = { keys = fall, duration = 1, loop = true },
		Jump = { keys = jump, duration = 0.9, events = { takeoff = 0.1, apex = 0.45, land = 0.78 } },
		Land = { keys = land, duration = 0.45, events = { contact = 0 }, contact = "feet" },
		MantleLow = { keys = mantleLow, duration = 0.4, climb = true },
		MantleVault = { keys = mantleVault, duration = 0.45, climb = true },
		MantleHigh = { keys = mantleHigh, duration = 0.55, climb = true },
		Vault = { keys = kongVault, duration = 0.58, climb = true },
		WallHop = { keys = wallHop, duration = 0.4 },
		Slide = { keys = slide, duration = 1.2, contact = "body", fps = FINE_FPS },
	}
	local moves: { [string]: FlowRun } = {
		Run = RUN,
		Sprint = SPRINT,
		RunBack = BACK_RUN,
		StrafeRight = strafeRun(-60),
		StrafeLeft = strafeRun(60),
	}
	for name, p in moves do
		specs[name] = {
			keys = flowRun(p),
			duration = math.round(p.duration * FINE_FPS) / FINE_FPS,
			fps = FINE_FPS,
			loop = true,
			speed = p.speed,
			contact = "feet",
			spinAxis = if p.turn then { 0, 1, 0 } else nil,
		}
	end
	specs.Stand = { keys = stand, duration = 7.2, loop = true, contact = "feet" }
	local flight = { takeoff = 0, apex = 0.27, land = 0.6 }
	for name, direction in FLIP_DIRECTIONS do
		local keys, axis, pivot = flipToward(direction[1], direction[2])
		specs[name] = {
			keys = keys,
			duration = 0.8,
			events = flight,
			spinAxis = axis,
			pivot = pivot,
			fps = FINE_FPS,
		}
	end
	local library: { [string]: any } = {}
	for name, spec in specs do
		library[name] = build(name, spec)
	end
	return library
end

return table.freeze(OriginalClips)
