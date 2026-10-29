--!strict
-- Synthetic clip data only; no third-party animation is used in tests.
local shared = game:GetService("ReplicatedStorage"):WaitForChild("MovementExperiment")
local Clips = require(shared.Clips)

local half = math.sin(math.pi / 4)
local raw = {
	fps = 10,
	frames = 3,
	loop = false,
	speed = 0,
	direction = { 0, -1 },
	events = { recover = 0.2 },
	floor = { 0, 0.5, 0 },
	-- Root: translation then quaternion; Waist: identity -> 90 degrees about Y.
	joints = {
		Root = { 0, 0, 0, 0, 0, 0, 1, 0, -0.5, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1 },
		Waist = { 0, 0, 0, 1, 0, half, 0, half, 0, 1, 0, 0 },
	},
	motion = { 0, 0, 0, -1, 0, -2 },
}
local clip = Clips.decode("Synthetic", raw)
assert(math.abs(clip.duration - 0.2) < 1e-6, "Non-looping duration spans first to last frame")
local pose = Clips.sample(clip, 0.05)
local _, yaw = pose.Waist:ToOrientation()
assert(math.abs(yaw - math.pi / 4) < 1e-3, "Sampling interpolates rotations between frames")
assert(math.abs(pose.Root.Y + 0.25) < 1e-4, "Root translation interpolates")
assert(math.abs(Clips.floor(clip, 0.15) - 0.25) < 1e-4, "Floor clearance interpolates")
assert(
	(Clips.motion(clip, 0.2) - Vector3.new(0, 0, -2)).Magnitude < 1e-4,
	"Motion clamps at the end"
)
assert(
	math.abs(Clips.motionVelocity(clip, 0.1).Z + 10) < 1e-3,
	"Root-motion velocity is per second"
)

raw.loop = true
local loop = Clips.decode("Loop", raw)
assert(math.abs(loop.duration - 0.3) < 1e-6, "Loops wrap from the last frame to the first")
local wrapped = Clips.sample(loop, 0.35)
local _, wrappedYaw = wrapped.Waist:ToOrientation()
assert(math.abs(wrappedYaw - math.pi / 4) < 1e-3, "Loop sampling wraps past the end")

local blended = Clips.blend(
	{ { Waist = CFrame.identity }, { Waist = CFrame.Angles(0, math.pi / 2, 0) } },
	{ 3, 1 }
)
local _, blendYaw = blended.Waist:ToOrientation()
assert(math.abs(blendYaw - math.pi / 8) < 1e-3, "Blend weights need not be normalized")
local original = Clips.load()
for _, name in
	{ "Idle", "Run", "Sprint", "RunBack", "StrafeLeft", "StrafeRight", "Jump", "Fall", "Land" }
do
	assert(original[name], "Original clip missing: " .. name)
end
for _, name in { "RollForward", "RollBack", "RollLeft", "RollRight" } do
	local roll = original[name]
	local travel = Clips.motion(roll, roll.events.recover):Dot(roll.direction)
	assert(roll.contact == "body" and travel > 1, name .. " must travel along its direction")
end
for _, name in { "FlipFront", "FlipBack" } do
	local events = original[name].events
	assert(events.takeoff < events.apex and events.apex < events.land, name .. " air events")
end
for _, name in { "MantleLow", "MantleHigh" } do
	local mantle = original[name]
	assert(mantle and mantle.climb, name .. " needs a climb curve")
	local first, last = Clips.climb(mantle, 0), Clips.climb(mantle, mantle.duration)
	assert(
		first.Magnitude < 1e-3 and (last - Vector2.one).Magnitude < 1e-3,
		name .. " climbs 0 to 1"
	)
	local previous = first
	for frame = 1, mantle.frames do
		local value = Clips.climb(mantle, (frame - 1) / mantle.fps)
		assert(value.Y >= previous.Y - 0.02, name .. " rise must not drop back")
		previous = value
	end
end
assert(original.WallHop and not original.WallHop.climb, "Wall hop clip present")
local synthetic = Clips.climb(clip, clip.duration / 2)
assert(math.abs(synthetic.X - 0.5) < 1e-3, "Clips without a climb curve ease evenly")
local _, turn = original.FlipFront.joints.Root[original.FlipFront.frames // 2]:ToAxisAngle()
assert(turn > math.pi / 2, "Front flip rotates the body through the air")
for name, entry in original do
	for joint, frames in entry.joints do
		for _, frame in frames do
			local x, y, z = frame:ToEulerAnglesXYZ()
			assert(x == x and y == y and z == z, name .. "." .. joint .. " has a non-finite pose")
		end
	end
end
print(
	"[Movement tests] PASS: clip decode, sampling, loop wrap, root motion, climb curves and weighted blend"
)
