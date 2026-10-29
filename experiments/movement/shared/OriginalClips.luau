--!strict
-- Original keyframed R15 movement clips (public, no third-party data). Poses are
-- authored in degrees per joint (CFrame.Angles X, Y, Z order), relative to the
-- R15 rest pose, and sampled with Catmull-Rom/Hermite curves at 30 fps.
--
-- Joint axes: Hip/Shoulder +X swings the limb forward; Knee -X flexes; Elbow +X
-- flexes; Ankle +X lifts the toes; Root/Waist/Neck -X leans forward, +Y turns left,
-- +Z tilts left. Left limbs abduct with -Z, right limbs with +Z.
-- RootPos is in hip units (Root pivot height). floor is the clip's intended lowest
-- foot (or body, for rolls) clearance in hip units; motion is cumulative root travel
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

-- A symmetric loop from its first half: the second half is the mirrored first.
local function cycle(half: { Key }, duration: number): { Key }
	local keys = table.clone(half)
	for _, key in half do
		local mirrored = mirrorKey(key)
		mirrored.t = key.t + duration / 2
		table.insert(keys, mirrored)
	end
	return keys
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
	local frames = if loop then math.round(duration * FPS) else math.round(duration * FPS) + 1
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
	local joints, motion, floors, climb = {}, {}, {}, {}
	for _, joint in JOINTS do
		joints[joint] = table.create(frames)
	end
	for frame = 1, frames do
		local t = (frame - 1) / FPS
		for _, joint in JOINTS do
			local axes = rotations[joint]
			local value =
				CFrame.Angles(math.rad(axes[1](t)), math.rad(axes[2](t)), math.rad(axes[3](t)))
			if joint == "Root" then
				value = CFrame.new(position[1](t), position[2](t), position[3](t)) * value
			end
			joints[joint][frame] = value
		end
		floors[frame] = floor(t)
		motion[frame] = directionVector * motionCurve(t)
		climb[frame] = Vector2.new(advance(t), rise(t))
	end
	return {
		name = name,
		fps = FPS,
		frames = frames,
		duration = (if loop then frames else frames - 1) / FPS,
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

-- Speeds are in hip units per second at playback rate 1 (one unit is about
-- 2.2 studs on the default R15), chosen so cadence reads naturally at the profile
-- run/sprint speeds rather than to eliminate all stride slip at Roblox scale.
local RUN = 0.62
local runHalf: { Key } = {
	{ -- Left contact: whole-body lean, trailing heel high
		t = 0,
		Root = { -12, -8, 0 },
		RootPos = { 0, -0.02, 0 },
		Waist = { -6, 16, 0 },
		Neck = { 14, -8, 0 },
		LeftHip = { 52, 0, -3 },
		LeftKnee = { -15, 0, 0 },
		LeftAnkle = { 10, 0, 0 },
		RightHip = { -8, 0, 3 },
		RightKnee = { -110, 0, 0 },
		RightAnkle = { -25, 0, 0 },
		LeftShoulder = { -50, 0, -8 },
		LeftElbow = { 75, 0, 0 },
		RightShoulder = { 60, 0, 8 },
		RightElbow = { 100, 0, 0 },
	},
	{ -- Absorb: body lowest, heel tucked under as the swing leg passes
		t = 0.07,
		Root = { -12, -3, 0 },
		RootPos = { 0, -0.08, 0 },
		Waist = { -6, 6, 0 },
		Neck = { 14, -3, 0 },
		LeftHip = { 30, 0, -3 },
		LeftKnee = { -45, 0, 0 },
		LeftAnkle = { 18, 0, 0 },
		RightHip = { 40, 0, 3 },
		RightKnee = { -135, 0, 0 },
		RightAnkle = { -20, 0, 0 },
		LeftShoulder = { -15, 0, -8 },
		LeftElbow = { 85, 0, 0 },
		RightShoulder = { 25, 0, 8 },
		RightElbow = { 90, 0, 0 },
	},
	{ -- Push-off: full extension behind, high knee drive
		t = 0.165,
		Root = { -13, 6, 0 },
		RootPos = { 0, 0, 0 },
		Waist = { -6, -14, 0 },
		Neck = { 14, 6, 0 },
		LeftHip = { -18, 0, -3 },
		LeftKnee = { -15, 0, 0 },
		LeftAnkle = { -30, 0, 0 },
		RightHip = { 80, 0, 3 },
		RightKnee = { -95, 0, 0 },
		RightAnkle = { 5, 0, 0 },
		LeftShoulder = { 40, 0, -8 },
		LeftElbow = { 95, 0, 0 },
		RightShoulder = { -45, 0, 8 },
		RightElbow = { 70, 0, 0 },
	},
	{ -- Flight: trailing heel kicks up, lead leg reaches
		t = 0.24,
		Root = { -12, 8, 0 },
		RootPos = { 0, 0.06, 0 },
		Waist = { -6, -16, 0 },
		Neck = { 14, 8, 0 },
		LeftHip = { -20, 0, -3 },
		LeftKnee = { -85, 0, 0 },
		LeftAnkle = { -30, 0, 0 },
		RightHip = { 68, 0, 3 },
		RightKnee = { -45, 0, 0 },
		RightAnkle = { 8, 0, 0 },
		LeftShoulder = { 55, 0, -8 },
		LeftElbow = { 95, 0, 0 },
		RightShoulder = { -50, 0, 8 },
		RightElbow = { 75, 0, 0 },
		floor = 0.07,
	},
}

local SPRINT = 0.56
local sprintHalf: { Key } = {
	{
		t = 0,
		Root = { -16, -9, 0 },
		RootPos = { 0, -0.03, 0 },
		Waist = { -8, 18, 0 },
		Neck = { 18, -9, 0 },
		LeftHip = { 62, 0, -3 },
		LeftKnee = { -16, 0, 0 },
		LeftAnkle = { 8, 0, 0 },
		RightHip = { -6, 0, 3 },
		RightKnee = { -125, 0, 0 },
		RightAnkle = { -28, 0, 0 },
		LeftShoulder = { -65, 0, -8 },
		LeftElbow = { 80, 0, 0 },
		RightShoulder = { 75, 0, 8 },
		RightElbow = { 105, 0, 0 },
	},
	{
		t = 0.06,
		Root = { -16, -3, 0 },
		RootPos = { 0, -0.1, 0 },
		Waist = { -8, 6, 0 },
		Neck = { 18, -3, 0 },
		LeftHip = { 38, 0, -3 },
		LeftKnee = { -50, 0, 0 },
		LeftAnkle = { 16, 0, 0 },
		RightHip = { 48, 0, 3 },
		RightKnee = { -145, 0, 0 },
		RightAnkle = { -22, 0, 0 },
		LeftShoulder = { -18, 0, -8 },
		LeftElbow = { 90, 0, 0 },
		RightShoulder = { 28, 0, 8 },
		RightElbow = { 95, 0, 0 },
	},
	{
		t = 0.15,
		Root = { -17, 7, 0 },
		RootPos = { 0, 0, 0 },
		Waist = { -8, -16, 0 },
		Neck = { 18, 7, 0 },
		LeftHip = { -14, 0, -3 },
		LeftKnee = { -16, 0, 0 },
		LeftAnkle = { -34, 0, 0 },
		RightHip = { 95, 0, 3 },
		RightKnee = { -105, 0, 0 },
		RightAnkle = { 5, 0, 0 },
		LeftShoulder = { 55, 0, -8 },
		LeftElbow = { 100, 0, 0 },
		RightShoulder = { -60, 0, 8 },
		RightElbow = { 72, 0, 0 },
	},
	{
		t = 0.22,
		Root = { -16, 9, 0 },
		RootPos = { 0, 0.08, 0 },
		Waist = { -8, -18, 0 },
		Neck = { 18, 9, 0 },
		LeftHip = { -16, 0, -3 },
		LeftKnee = { -100, 0, 0 },
		LeftAnkle = { -34, 0, 0 },
		RightHip = { 80, 0, 3 },
		RightKnee = { -50, 0, 0 },
		RightAnkle = { 8, 0, 0 },
		LeftShoulder = { 70, 0, -8 },
		LeftElbow = { 100, 0, 0 },
		RightShoulder = { -65, 0, 8 },
		RightElbow = { 78, 0, 0 },
		floor = 0.1,
	},
}

-- Back-pedal: the run cycle played backwards with an upright torso.
local BACK = 0.6
local function backpedal(): { Key }
	local keys = {}
	for _, key in cycle(runHalf, RUN) do
		local copy = table.clone(key)
		copy.t = (RUN - key.t) % RUN * (BACK / RUN)
		copy.Root = { 2, key.Root[2] * 0.6, 0 }
		copy.Waist = { 4, key.Waist[2] * 0.5, 0 }
		copy.Neck = { -4, key.Neck[2] * 0.5, 0 }
		-- Run hips include +12 degrees to offset its forward lean; the back-pedal is upright.
		copy.LeftHip = { (key.LeftHip[1] - 12) * 0.75, 0, key.LeftHip[3] }
		copy.RightHip = { (key.RightHip[1] - 12) * 0.75, 0, key.RightHip[3] }
		copy.LeftShoulder = { key.LeftShoulder[1] * 0.6, 0, -12 }
		copy.RightShoulder = { key.RightShoulder[1] * 0.6, 0, 12 }
		table.insert(keys, copy)
	end
	return keys
end

local STRAFE = 0.6
local strafeLeft: { Key } = {
	{ -- Left foot lands out to the side
		t = 0,
		Root = { -4, 6, 7 },
		RootPos = { 0, -0.03, 0 },
		Waist = { -6, -4, -3 },
		Neck = { 6, -2, 0 },
		LeftHip = { 8, 0, -24 },
		LeftKnee = { -18, 0, 0 },
		LeftAnkle = { 5, 0, 0 },
		RightHip = { -4, 0, 10 },
		RightKnee = { -35, 0, 0 },
		RightAnkle = { -15, 0, 0 },
		LeftShoulder = { 15, 0, -20 },
		LeftElbow = { 70, 0, 0 },
		RightShoulder = { 25, 0, 15 },
		RightElbow = { 85, 0, 0 },
	},
	{ -- Absorb while the right leg gathers in
		t = 0.15,
		Root = { -4, 6, 5 },
		RootPos = { 0, -0.08, 0 },
		Waist = { -7, -4, -2 },
		Neck = { 6, -2, 0 },
		LeftHip = { 6, 0, -12 },
		LeftKnee = { -42, 0, 0 },
		LeftAnkle = { 15, 0, 0 },
		RightHip = { 28, 0, -6 },
		RightKnee = { -82, 0, 0 },
		RightAnkle = { -10, 0, 0 },
		LeftShoulder = { 25, 0, -16 },
		LeftElbow = { 80, 0, 0 },
		RightShoulder = { 10, 0, 12 },
		RightElbow = { 80, 0, 0 },
	},
	{ -- Right foot lands under the body
		t = 0.3,
		Root = { -4, 6, 6 },
		RootPos = { 0, -0.02, 0 },
		Waist = { -6, -4, -3 },
		Neck = { 6, -2, 0 },
		LeftHip = { -5, 0, -6 },
		LeftKnee = { -30, 0, 0 },
		LeftAnkle = { -20, 0, 0 },
		RightHip = { 12, 0, -14 },
		RightKnee = { -22, 0, 0 },
		RightAnkle = { 5, 0, 0 },
		LeftShoulder = { 10, 0, -20 },
		LeftElbow = { 75, 0, 0 },
		RightShoulder = { 30, 0, 14 },
		RightElbow = { 90, 0, 0 },
	},
	{ -- Push and reach left
		t = 0.45,
		Root = { -4, 6, 8 },
		RootPos = { 0, 0.03, 0 },
		Waist = { -6, -4, -4 },
		Neck = { 6, -2, 0 },
		LeftHip = { 16, 0, -32 },
		LeftKnee = { -58, 0, 0 },
		LeftAnkle = { 0, 0, 0 },
		RightHip = { -2, 0, 2 },
		RightKnee = { -40, 0, 0 },
		RightAnkle = { -22, 0, 0 },
		LeftShoulder = { 20, 0, -24 },
		LeftElbow = { 75, 0, 0 },
		RightShoulder = { 20, 0, 16 },
		RightElbow = { 85, 0, 0 },
		floor = 0.04,
	},
}

local idle: { Key } = {
	{
		t = 0,
		Root = { -2, 0, 0 },
		RootPos = { 0, -0.04, 0 },
		Waist = { -4, 0, 0 },
		Neck = { 5, 0, 0 },
		LeftHip = { 10, 6, -6 },
		LeftKnee = { -14, 0, 0 },
		LeftAnkle = { 4, 0, 0 },
		RightHip = { 6, -6, 6 },
		RightKnee = { -10, 0, 0 },
		RightAnkle = { 4, 0, 0 },
		LeftShoulder = { 8, 0, -10 },
		LeftElbow = { 20, 0, 0 },
		RightShoulder = { 10, 0, 10 },
		RightElbow = { 24, 0, 0 },
	},
	{
		t = 1.2,
		Root = { -2, 1, 0 },
		RootPos = { 0, -0.055, 0 },
		Waist = { -6, 2, 0 },
		Neck = { 6, -1, 0 },
		LeftHip = { 12, 6, -6 },
		LeftKnee = { -17, 0, 0 },
		LeftAnkle = { 5, 0, 0 },
		RightHip = { 8, -6, 6 },
		RightKnee = { -13, 0, 0 },
		RightAnkle = { 5, 0, 0 },
		LeftShoulder = { 9, 0, -13 },
		LeftElbow = { 26, 0, 0 },
		RightShoulder = { 11, 0, 13 },
		RightElbow = { 28, 0, 0 },
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

-- Diagonal (parkour) shoulder roll: dive, the right forearm guides onto the
-- right shoulder, roll across the upper back with the head turned clear, feet
-- return under the hips, rise into a run. Contact is the whole body.
local rollForward: { Key } = {
	upper(legs(0, 45, 20, -60, -40, 0), {
		Root = { -25, 0, 0 },
		Waist = { -20, 0, 0 },
		Shoulder = { 60, 10 },
		Elbow = 20,
		motion = 0,
	}),
	upper(legs(0.1, 95, 60, -110, -80, -10), { -- reach down, guiding arm leads
		Root = { -70, 0, 12 },
		Waist = { -30, 0, 8 },
		Neck = { -35, 25, -15 },
		LeftShoulder = { 120, 0, -20 },
		RightShoulder = { 140, 0, 15 },
		Elbow = 30,
		motion = 0.6,
	}),
	upper(legs(0.24, 125, 115, -140, -135, -20), { -- forearm to shoulder, head clear
		Root = { -130, 0, 30 },
		Waist = { -35, 0, 15 },
		Neck = { -40, 40, -35 },
		LeftShoulder = { 70, 0, -12 },
		RightShoulder = { 50, 0, 20 },
		LeftElbow = { 95, 0, 0 },
		RightElbow = { 110, 0, 0 },
		motion = 1.6,
	}),
	upper(legs(0.36, 130, 125, -145, -145, -15), { -- across the upper back
		Root = { -225, 0, 25 },
		Waist = { -35, 0, 15 },
		Neck = { -40, 40, -35 },
		LeftShoulder = { 70, 0, -12 },
		RightShoulder = { 70, 0, -10 },
		LeftElbow = { 95, 0, 0 },
		RightElbow = { 120, 0, 0 },
		motion = 2.5,
	}),
	upper(legs(0.48, 115, 100, -130, -115, 15), { -- feet come back to the floor
		Root = { -310, 0, 12 },
		Waist = { -22, 0, 6 },
		Neck = { -15, 15, -10 },
		Shoulder = { 45, 12 },
		Elbow = 60,
		motion = 3.3,
	}),
	upper(legs(0.6, 75, 60, -95, -80, 25), {
		Root = { -350, 0, 3 },
		Waist = { -18, 0, 0 },
		Shoulder = { 40, 10 },
		Elbow = 70,
		motion = 3.85,
	}),
	upper(legs(0.85, 30, -10, -25, -60, 0), { -- rise into a running stride
		Root = { -360, 0, 0 },
		Waist = { -10, 0, 0 },
		LeftShoulder = { -20, 0, -8 },
		RightShoulder = { 30, 0, 8 },
		Elbow = 80,
		motion = 4.1,
	}),
}

local rollBack: { Key } = {
	upper(legs(0, 70, 70, -95, -95, 25), {
		Root = { 15, 0, 0 },
		Waist = { -20, 0, 0 },
		Shoulder = { 60, 15 },
		Elbow = 40,
		motion = 0,
	}),
	upper(legs(0.12, 110, 110, -120, -120, 10), { -- sit back, chin tucked
		Root = { 60, 0, 0 },
		Waist = { -30, 0, 0 },
		Neck = { -30, 0, 0 },
		Shoulder = { 120, 15 },
		Elbow = 110,
		motion = 0.4,
	}),
	upper(legs(0.26, 130, 130, -110, -110, -10), { -- on the back, hands by the ears
		Root = { 150, 0, 0 },
		Waist = { -35, 0, 0 },
		Neck = { -30, 0, 0 },
		Shoulder = { 165, 15 },
		Elbow = 120,
		motion = 1.3,
	}),
	upper(legs(0.4, 125, 125, -125, -125, -10), { -- push over the shoulders
		Root = { 240, 0, 0 },
		Waist = { -30, 0, 0 },
		Neck = { -25, 0, 0 },
		Shoulder = { 170, 15 },
		Elbow = 110,
		motion = 2.3,
	}),
	upper(legs(0.54, 105, 105, -130, -130, 15), {
		Root = { 320, 0, 0 },
		Waist = { -20, 0, 0 },
		Shoulder = { 90, 15 },
		Elbow = 60,
		motion = 3,
	}),
	upper(legs(0.66, 75, 75, -95, -95, 25), {
		Root = { 355, 0, 0 },
		Waist = { -15, 0, 0 },
		Shoulder = { 40, 12 },
		Elbow = 50,
		motion = 3.3,
	}),
	upper(legs(0.9, 15, 15, -20, -20, 4), {
		Root = { 360, 0, 0 },
		Waist = { -6, 0, 0 },
		Shoulder = { 15, 10 },
		Elbow = 30,
		motion = 3.4,
	}),
}

-- Sideways shoulder roll to the left (mirrored for right): tuck and tumble about
-- the forward axis, the leading arm guiding onto the shoulder.
local rollLeft: { Key } = {
	upper(legs(0, 60, 40, -80, -60, 10), {
		Root = { -10, 0, 20 },
		Waist = { -15, 0, 10 },
		LeftShoulder = { 40, 0, -40 },
		RightShoulder = { 60, 0, 10 },
		Elbow = 40,
		motion = 0,
	}),
	upper(legs(0.1, 95, 90, -120, -120, -10), {
		Root = { -30, 0, 70 },
		Waist = { -30, 0, 10 },
		Neck = { -30, 0, -25 },
		LeftShoulder = { 90, 0, -20 },
		RightShoulder = { 80, 0, 15 },
		LeftElbow = { 80, 0, 0 },
		RightElbow = { 100, 0, 0 },
		motion = 0.5,
	}),
	upper(legs(0.22, 115, 115, -140, -140, -15), {
		Root = { -35, 0, 150 },
		Waist = { -40, 0, -5 },
		Neck = { -45, 0, -35 },
		Shoulder = { 70, 12 },
		Elbow = 110,
		motion = 1.3,
	}),
	upper(legs(0.34, 115, 115, -140, -140, -15), {
		Root = { -25, 0, 245 },
		Waist = { -38, 0, -5 },
		Neck = { -40, 0, -30 },
		Shoulder = { 70, 12 },
		Elbow = 110,
		motion = 2.1,
	}),
	upper(legs(0.46, 100, 85, -125, -110, 10), {
		Root = { -10, 0, 320 },
		Waist = { -20, 0, -8 },
		LeftShoulder = { 60, 0, -12 },
		RightShoulder = { 50, 0, 40 },
		Elbow = 60,
		motion = 2.7,
	}),
	upper(legs(0.58, 70, 55, -95, -80, 25), {
		Root = { -5, 0, 352 },
		Waist = { -18, 0, 0 },
		Shoulder = { 40, 15 },
		Elbow = 60,
		motion = 3.1,
	}),
	upper(legs(0.8, 15, 8, -18, -18, 4), {
		Root = { 0, 0, 360 },
		Waist = { -6, 0, 0 },
		Shoulder = { 10, 10 },
		Elbow = 25,
		motion = 3.2,
	}),
}

-- Tucked flips. Only takeoff..land plays in the air; the rest frames the motion.
local function flip(direction: number): { Key }
	local back = direction > 0
	return {
		upper(legs(0, 55, 55, -75, -75, 25), {
			Root = { -15, 0, 0 },
			RootPos = { 0, -0.2, 0 },
			Waist = { -18, 0, 0 },
			Shoulder = { -35, 8 },
			Elbow = 15,
		}),
		upper(legs(0.08, -5, -5, -5, -5, -30), { -- takeoff: stretched, arms driving up
			Root = { if back then 5 else -10, 0, 0 },
			Waist = { if back then 10 else -2, 0, 0 },
			Neck = { if back then 15 else -5, 0, 0 },
			Shoulder = { if back then 170 else 160, 8 },
			Elbow = 10,
		}),
		upper(legs(0.18, if back then 70 else 85, if back then 70 else 85, -85, -85, -20), {
			Root = { 70 * direction, 0, 0 },
			RootPos = { 0, 0.08, 0 },
			Waist = { if back then 5 else -25, 0, 0 },
			Neck = { if back then 25 else -25, 0, 0 },
			Shoulder = { if back then 175 else 110, 10 },
			Elbow = if back then 20 else 40,
		}),
		upper(legs(0.3, 130, 130, -150, -150, -25), { -- full tuck, hands on shins
			Root = { 170 * direction, 0, 0 },
			RootPos = { 0, 0.15, 0 },
			Waist = { -30, 0, 0 },
			Neck = { if back then 5 else -35, 0, 0 },
			Shoulder = { 60, 15 },
			Elbow = 110,
		}),
		upper(legs(0.4, 130, 130, -150, -150, -25), {
			Root = { 235 * direction, 0, 0 },
			RootPos = { 0, 0.15, 0 },
			Waist = { -30, 0, 0 },
			Neck = { if back then 5 else -30, 0, 0 },
			Shoulder = { 60, 15 },
			Elbow = 110,
		}),
		upper(legs(0.52, 95, 95, -95, -95, -10), { -- open out
			Root = { 305 * direction, 0, 0 },
			RootPos = { 0, 0.08, 0 },
			Waist = { -18, 0, 0 },
			Neck = { -10, 0, 0 },
			Shoulder = { 100, 45 },
			Elbow = 40,
		}),
		upper(legs(0.62, 40, 40, -40, -40, 5), { -- spot the landing, arms up and out
			Root = { 345 * direction, 0, 0 },
			Waist = { -10, 0, 0 },
			Neck = { 5, 0, 0 },
			Shoulder = { 110, 55 },
			Elbow = 20,
		}),
		upper(legs(0.7, 25, 25, -25, -25, 12), {
			Root = { 360 * direction, 0, 0 },
			Waist = { -8, 0, 0 },
			Shoulder = { 90, 45 },
			Elbow = 25,
		}),
		upper(legs(0.82, 60, 60, -85, -85, 25), {
			Root = { 360 * direction - 8, 0, 0 },
			RootPos = { 0, -0.25, 0 },
			Waist = { -18, 0, 0 },
			Shoulder = { 60, 30 },
			Elbow = 30,
		}),
	}
end

-- Mantles face the ledge. advance/rise are the root's progress over and up onto
-- the ledge (0..1), timed so the hands meet the edge for typical heights.
-- Two-hand climb: reach, pull, press over the edge, knee onto it, step through.
local mantleHigh: { Key } = {
	{
		t = 0,
		Root = { -12, 0, 0 },
		Waist = { -8, 0, 0 },
		Neck = { 12, 0, 0 },
		LeftHip = { 25, 0, -4 },
		LeftKnee = { -45, 0, 0 },
		LeftAnkle = { -15, 0, 0 },
		RightHip = { 8, 0, 4 },
		RightKnee = { -25, 0, 0 },
		RightAnkle = { -20, 0, 0 },
		LeftShoulder = { 150, 0, -15 },
		RightShoulder = { 150, 0, 15 },
		LeftElbow = { 25, 0, 0 },
		RightElbow = { 25, 0, 0 },
		advance = 0,
		rise = 0,
	},
	upper({ -- hands on the edge, pull
		t = 0.1,
		LeftHip = { 55, 0, -6 },
		LeftKnee = { -85, 0, 0 },
		LeftAnkle = { -10, 0, 0 },
		RightHip = { 20, 0, 4 },
		RightKnee = { -50, 0, 0 },
		RightAnkle = { -25, 0, 0 },
	}, {
		Root = { -20, 0, 0 },
		Waist = { -12, 0, 0 },
		Neck = { 18, 0, 0 },
		Shoulder = { 80, 25 },
		Elbow = 95,
		advance = 0,
		rise = 0.15,
	}),
	upper({ -- press: arms straight, chest over the edge, legs hanging under
		t = 0.22,
		LeftHip = { 70, 0, -6 },
		LeftKnee = { -100, 0, 0 },
		LeftAnkle = { 0, 0, 0 },
		RightHip = { 25, 0, 4 },
		RightKnee = { -45, 0, 0 },
		RightAnkle = { -20, 0, 0 },
	}, {
		Root = { -34, 0, 0 },
		Waist = { -16, 0, 0 },
		Neck = { 24, 0, 0 },
		Shoulder = { -8, 22 },
		Elbow = 15,
		advance = 0.12,
		rise = 0.55,
	}),
	upper({ -- knee onto the ledge
		t = 0.32,
		LeftHip = { 120, 0, -8 },
		LeftKnee = { -140, 0, 0 },
		LeftAnkle = { 20, 0, 0 },
		RightHip = { 30, 0, 4 },
		RightKnee = { -95, 0, 0 },
		RightAnkle = { -15, 0, 0 },
	}, {
		Root = { -40, 0, 0 },
		Waist = { -15, 0, 0 },
		Neck = { 22, 0, 0 },
		Shoulder = { -15, 20 },
		Elbow = 20,
		advance = 0.35,
		rise = 0.82,
	}),
	{ -- step up, trailing leg comes through
		t = 0.42,
		Root = { -25, 0, 0 },
		Waist = { -12, 0, 0 },
		Neck = { 10, 0, 0 },
		LeftHip = { 70, 0, -4 },
		LeftKnee = { -85, 0, 0 },
		LeftAnkle = { 15, 0, 0 },
		RightHip = { 75, 0, 4 },
		RightKnee = { -125, 0, 0 },
		RightAnkle = { -5, 0, 0 },
		LeftShoulder = { -25, 0, -12 },
		RightShoulder = { 30, 0, 12 },
		LeftElbow = { 60, 0, 0 },
		RightElbow = { 60, 0, 0 },
		advance = 0.72,
		rise = 1,
	},
	{ -- out into a running stride
		t = 0.52,
		Root = { -12, 0, 0 },
		Waist = { -8, 0, 0 },
		LeftHip = { 15, 0, -3 },
		LeftKnee = { -20, 0, 0 },
		LeftAnkle = { 5, 0, 0 },
		RightHip = { 45, 0, 3 },
		RightKnee = { -70, 0, 0 },
		LeftShoulder = { 35, 0, -8 },
		RightShoulder = { -20, 0, 8 },
		LeftElbow = { 70, 0, 0 },
		RightElbow = { 70, 0, 0 },
		advance = 1,
		rise = 1,
	},
}

-- One-hand step vault for low ledges: the right hand plants, the left foot steps
-- onto the edge and drives up, the right leg swings through into a stride.
local mantleLow: { Key } = {
	{
		t = 0,
		Root = { -18, 0, 0 },
		Waist = { -10, 0, 0 },
		LeftHip = { 70, 0, -4 },
		LeftKnee = { -95, 0, 0 },
		LeftAnkle = { 10, 0, 0 },
		RightHip = { -15, 0, 4 },
		RightKnee = { -25, 0, 0 },
		RightAnkle = { -25, 0, 0 },
		LeftShoulder = { -15, 0, -20 },
		RightShoulder = { 55, 0, 10 },
		LeftElbow = { 45, 0, 0 },
		RightElbow = { 25, 0, 0 },
		advance = 0,
		rise = 0,
	},
	{ -- hand plants, lead foot on the edge
		t = 0.12,
		Root = { -30, 0, 0 },
		Waist = { -14, 0, -6 },
		Neck = { 12, 0, 0 },
		LeftHip = { 95, 0, -4 },
		LeftKnee = { -115, 0, 0 },
		LeftAnkle = { 15, 0, 0 },
		RightHip = { 5, 0, 4 },
		RightKnee = { -55, 0, 0 },
		RightAnkle = { -20, 0, 0 },
		LeftShoulder = { 40, 0, -35 },
		RightShoulder = { 10, 0, 15 },
		LeftElbow = { 30, 0, 0 },
		RightElbow = { 10, 0, 0 },
		advance = 0.15,
		rise = 0.3,
	},
	{ -- drive up, trailing leg swings through
		t = 0.26,
		Root = { -22, 0, 0 },
		Waist = { -10, 0, 0 },
		Neck = { 6, 0, 0 },
		LeftHip = { 45, 0, -3 },
		LeftKnee = { -50, 0, 0 },
		LeftAnkle = { 10, 0, 0 },
		RightHip = { 70, 0, 4 },
		RightKnee = { -115, 0, 0 },
		RightAnkle = { -5, 0, 0 },
		LeftShoulder = { 35, 0, -20 },
		RightShoulder = { -20, 0, 12 },
		LeftElbow = { 40, 0, 0 },
		RightElbow = { 30, 0, 0 },
		advance = 0.6,
		rise = 0.85,
	},
	{
		t = 0.42,
		Root = { -12, 0, 0 },
		Waist = { -8, 0, 0 },
		LeftHip = { 15, 0, -3 },
		LeftKnee = { -20, 0, 0 },
		LeftAnkle = { 5, 0, 0 },
		RightHip = { 45, 0, 3 },
		RightKnee = { -70, 0, 0 },
		LeftShoulder = { 35, 0, -8 },
		RightShoulder = { -20, 0, 8 },
		LeftElbow = { 70, 0, 0 },
		RightElbow = { 70, 0, 0 },
		advance = 1,
		rise = 1,
	},
}

-- Speed vault onto a ledge (parkour mantle): the left hand plants on the edge,
-- the body tips left while both legs swing out together to the right and over
-- the top, then the right foot lands and the run carries on. The root rises a
-- little past the top (rise above 1) so the legs clear it.
local mantleVault: { Key } = {
	{ -- takeoff: reaching for the edge with the left hand
		t = 0,
		Root = { -20, 0, 0 },
		Waist = { -8, 0, 0 },
		Neck = { 8, 0, 0 },
		LeftShoulder = { 60, 0, -10 },
		LeftElbow = { 15, 0, 0 },
		RightShoulder = { -30, 0, 15 },
		RightElbow = { 40, 0, 0 },
		LeftHip = { 40, 0, -4 },
		LeftKnee = { -60, 0, 0 },
		LeftAnkle = { 5, 0, 0 },
		RightHip = { -20, 0, 4 },
		RightKnee = { -40, 0, 0 },
		RightAnkle = { -25, 0, 0 },
		advance = 0,
		rise = 0,
	},
	{ -- hand planted, body lifting and starting to tip, knees tucking
		t = 0.1,
		Root = { -30, 0, 15 },
		Waist = { -10, 0, 5 },
		Neck = { 10, 0, -8 },
		LeftShoulder = { 75, 0, -5 },
		LeftElbow = { 5, 0, 0 },
		RightShoulder = { 20, 0, 40 },
		RightElbow = { 30, 0, 0 },
		LeftHip = { 80, 0, -5 },
		LeftKnee = { -110, 0, 0 },
		LeftAnkle = { 10, 0, 0 },
		RightHip = { 70, 0, 10 },
		RightKnee = { -100, 0, 0 },
		RightAnkle = { 10, 0, 0 },
		advance = 0.25,
		rise = 0.55,
	},
	{ -- over the top: tipped left on the planted arm, legs swung out to the right
		t = 0.22,
		Root = { -22, 0, 55 },
		Waist = { -5, 0, 10 },
		Neck = { 10, 0, -28 },
		LeftShoulder = { 65, 0, -35 },
		LeftElbow = { 0, 0, 0 },
		RightShoulder = { 0, 0, 100 },
		RightElbow = { 20, 0, 0 },
		LeftHip = { 55, 0, 35 },
		LeftKnee = { -20, 0, 0 },
		LeftAnkle = { 15, 0, 0 },
		RightHip = { 55, 0, 60 },
		RightKnee = { -15, 0, 0 },
		RightAnkle = { 15, 0, 0 },
		advance = 0.55,
		rise = 1.15,
	},
	{ -- legs come down onto the top, right foot first, body righting
		t = 0.34,
		Root = { -15, 0, 20 },
		Waist = { -6, 0, 5 },
		Neck = { 6, 0, -8 },
		LeftShoulder = { 30, 0, -35 },
		LeftElbow = { 20, 0, 0 },
		RightShoulder = { 10, 0, 50 },
		RightElbow = { 30, 0, 0 },
		LeftHip = { 60, 0, 0 },
		LeftKnee = { -90, 0, 0 },
		LeftAnkle = { 5, 0, 0 },
		RightHip = { 40, 0, 10 },
		RightKnee = { -40, 0, 0 },
		RightAnkle = { -5, 0, 0 },
		advance = 0.85,
		rise = 1.05,
	},
	{ -- landed, striding on
		t = 0.46,
		Root = { -12, 0, 0 },
		Waist = { -8, 0, 0 },
		LeftShoulder = { 20, 0, -10 },
		LeftElbow = { 60, 0, 0 },
		RightShoulder = { -20, 0, 10 },
		RightElbow = { 60, 0, 0 },
		LeftHip = { 50, 0, -3 },
		LeftKnee = { -80, 0, 0 },
		LeftAnkle = { 5, 0, 0 },
		RightHip = { 10, 0, 3 },
		RightKnee = { -25, 0, 0 },
		advance = 1,
		rise = 1,
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

local function mirrorAll(keys: { Key }): { Key }
	local result = {}
	for _, key in keys do
		table.insert(result, mirrorKey(key))
	end
	return result
end

function OriginalClips.build(): { [string]: any }
	local air = { takeoff = 0.08, apex = 0.4, land = 0.7 }
	local specs = {
		Idle = { keys = idle, duration = 2.4, loop = true, contact = "feet" },
		Run = {
			keys = cycle(runHalf, RUN),
			duration = RUN,
			loop = true,
			speed = 11,
			contact = "feet",
		},
		Sprint = {
			keys = cycle(sprintHalf, SPRINT),
			duration = SPRINT,
			loop = true,
			speed = 13.7,
			contact = "feet",
		},
		RunBack = {
			keys = backpedal(),
			duration = BACK,
			loop = true,
			speed = 7.3,
			contact = "feet",
		},
		StrafeLeft = {
			keys = strafeLeft,
			duration = STRAFE,
			loop = true,
			speed = 8.2,
			contact = "feet",
		},
		StrafeRight = {
			keys = mirrorAll(strafeLeft),
			duration = STRAFE,
			loop = true,
			speed = 8.2,
			contact = "feet",
		},
		Fall = { keys = fall, duration = 1, loop = true },
		Jump = { keys = jump, duration = 0.9, events = { takeoff = 0.1, apex = 0.45, land = 0.78 } },
		Land = { keys = land, duration = 0.45, events = { contact = 0 }, contact = "feet" },
		RollForward = {
			keys = rollForward,
			duration = 0.85,
			direction = { 0, -1 },
			events = { recover = 0.6 },
			contact = "body",
		},
		RollBack = {
			keys = rollBack,
			duration = 0.9,
			direction = { 0, 1 },
			events = { recover = 0.66 },
			contact = "body",
		},
		RollLeft = {
			keys = rollLeft,
			duration = 0.8,
			direction = { -1, 0 },
			events = { recover = 0.58 },
			contact = "body",
		},
		RollRight = {
			keys = mirrorAll(rollLeft),
			duration = 0.8,
			direction = { 1, 0 },
			events = { recover = 0.58 },
			contact = "body",
		},
		FlipFront = { keys = flip(-1), duration = 0.82, events = air },
		FlipBack = { keys = flip(1), duration = 0.82, events = air },
		MantleLow = { keys = mantleLow, duration = 0.42, climb = true },
		MantleVault = { keys = mantleVault, duration = 0.46, climb = true },
		MantleHigh = { keys = mantleHigh, duration = 0.52, climb = true },
		WallHop = { keys = wallHop, duration = 0.4 },
	}
	local library = {}
	for name, spec in specs do
		library[name] = build(name, spec)
	end
	return library
end

return table.freeze(OriginalClips)
