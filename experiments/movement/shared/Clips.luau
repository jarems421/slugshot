--!strict
-- Decodes and samples R15 clips. Original keyframed clips (OriginalClips) are
-- always available; privately retargeted clips (tools/mixamo_to_r15.py, kept
-- outside Git) replace them by name when present.
local Clips = {}

export type Clip = {
	name: string,
	fps: number,
	frames: number,
	duration: number,
	loop: boolean,
	speed: number,
	direction: Vector3,
	events: { [string]: number },
	joints: { [string]: { CFrame } },
	motion: { Vector3 }?,
	floor: { number }?,
	contact: string?, -- "feet" or "body": what the presentation keeps on the floor
	climb: { Vector2 }?, -- traversal progress per frame: X over the ledge, Y up, 0..1
}

export type Library = { [string]: Clip }

-- Raw generated layout: flat quaternion arrays (x, y, z, w) per joint; Root also
-- carries a translation (x, y, z first). Translations/motion are in hip units.
function Clips.decode(name: string, raw: any): Clip
	local frames = raw.frames :: number
	local joints = {}
	for joint, values in raw.joints do
		local stride = if joint == "Root" then 7 else 4
		local list = table.create(frames)
		for frame = 0, frames - 1 do
			local i = frame * stride
			if stride == 7 then
				list[frame + 1] = CFrame.new(
					values[i + 1],
					values[i + 2],
					values[i + 3],
					values[i + 4],
					values[i + 5],
					values[i + 6],
					values[i + 7]
				)
			else
				list[frame + 1] =
					CFrame.new(0, 0, 0, values[i + 1], values[i + 2], values[i + 3], values[i + 4])
			end
		end
		joints[joint] = list
	end
	local motion: { Vector3 }? = nil
	if raw.motion then
		local list = table.create(frames)
		for frame = 0, frames - 1 do
			list[frame + 1] = Vector3.new(raw.motion[frame * 2 + 1], 0, raw.motion[frame * 2 + 2])
		end
		motion = list
	end
	local climb: { Vector2 }? = nil
	if raw.climb then
		local list = table.create(frames)
		for frame = 0, frames - 1 do
			list[frame + 1] = Vector2.new(raw.climb[frame * 2 + 1], raw.climb[frame * 2 + 2])
		end
		climb = list
	end
	local direction = raw.direction or { 0, 0, -1 }
	return {
		name = name,
		fps = raw.fps,
		frames = frames,
		-- Loops wrap from the last frame back to the first.
		duration = (if raw.loop then frames else frames - 1) / raw.fps,
		loop = raw.loop == true,
		speed = raw.speed or 0,
		direction = Vector3.new(direction[1], 0, direction[2]),
		events = raw.events or {},
		joints = joints,
		motion = motion,
		floor = raw.floor,
		contact = raw.contact,
		climb = climb,
	}
end

local function locate(clip: Clip, time: number): (number, number, number)
	local position: number
	if clip.loop then
		position = (time % clip.duration) * clip.fps
	else
		position = math.clamp(time, 0, clip.duration) * clip.fps
	end
	local a = math.floor(position)
	local b = a + 1
	if b >= clip.frames then
		b = if clip.loop then 0 else clip.frames - 1
	end
	a = math.min(a, clip.frames - 1)
	return a + 1, b + 1, position - math.floor(position)
end

function Clips.sample(clip: Clip, time: number, into: { [string]: CFrame }?): { [string]: CFrame }
	local pose = into or {}
	local a, b, f = locate(clip, time)
	for joint, list in clip.joints do
		pose[joint] = list[a]:Lerp(list[b], f)
	end
	return pose
end

function Clips.floor(clip: Clip, time: number): number
	local floor = clip.floor
	if not floor then
		return 0
	end
	local a, b, f = locate(clip, time)
	return floor[a] + (floor[b] - floor[a]) * f
end

-- Root-motion position (hip units, character space) relative to the first frame.
function Clips.motion(clip: Clip, time: number): Vector3
	local motion = clip.motion
	if not motion then
		return Vector3.zero
	end
	local a, b, f = locate(clip, time)
	return motion[a]:Lerp(motion[b], f)
end

function Clips.motionVelocity(clip: Clip, time: number): Vector3
	local step = 1 / clip.fps
	return (Clips.motion(clip, time + step * 0.5) - Clips.motion(clip, time - step * 0.5)) / step
end

-- Traversal progress (X over the ledge, Y up), each clamped to 0..1. Clips
-- without a climb curve ease both together.
function Clips.climb(clip: Clip, time: number): Vector2
	local climb = clip.climb
	if not climb then
		local x = math.clamp(time / clip.duration, 0, 1)
		x = x * x * (3 - 2 * x)
		return Vector2.new(x, x)
	end
	local a, b, f = locate(clip, time)
	local value = climb[a]:Lerp(climb[b], f)
	return Vector2.new(math.clamp(value.X, 0, 1), math.clamp(value.Y, 0, 1))
end

-- Accumulates weighted poses; weights need not be normalized.
function Clips.blend(
	poses: { { [string]: CFrame } },
	weights: { number },
	into: { [string]: CFrame }?
): { [string]: CFrame }
	local result = into or {}
	table.clear(result)
	local total: { [string]: number } = {}
	for index, pose in poses do
		local weight = weights[index]
		if weight > 1e-4 then
			for joint, value in pose do
				local sum = (total[joint] or 0) + weight
				local current = result[joint]
				result[joint] = if current then current:Lerp(value, weight / sum) else value
				total[joint] = sum
			end
		end
	end
	return result
end

function Clips.load(): (Library, number)
	local library: Library = require(script.Parent.OriginalClips).build()
	local overrides = 0
	local source = game:GetService("ReplicatedStorage"):FindFirstChild("MovementPrivateClips")
	if source and source:IsA("ModuleScript") then
		local ok, raw = pcall(require, source)
		if ok and typeof(raw) == "table" then
			for name, data in raw :: any do
				library[name] = Clips.decode(name, data)
				overrides += 1
			end
		else
			warn("[Movement sandbox] private clip module failed to load", raw)
		end
	end
	return library, overrides
end

local function attachmentFrame(joint: Instance, which: string): CFrame
	if joint:IsA("Motor6D") then
		return if which == "0" then joint.C0 else joint.C1
	end
	local attachment = (joint :: any)["Attachment" .. which] :: Attachment?
	return if attachment then attachment.CFrame else CFrame.identity
end
Clips.attachmentFrame = attachmentFrame

-- Height of the Root joint pivot above the floor: one clip "hip unit" in studs.
function Clips.hipUnit(character: Model): number
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local lower = character:FindFirstChild("LowerTorso")
	local joint = lower and (lower:FindFirstChild("Root") :: Instance?)
	if not root or not humanoid then
		return 3
	end
	local pivot = if joint then attachmentFrame(joint, "0").Y else 0
	return math.max(1, humanoid.HipHeight + root.Size.Y / 2 + pivot)
end

return table.freeze(Clips)
