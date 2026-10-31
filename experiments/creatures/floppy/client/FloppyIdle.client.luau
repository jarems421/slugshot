--!strict
-- Floppy's idle on the client (Bone.Transform does not replicate). Same motion
-- and 12 s loop as the Blender Idle: breathing rise, travelling wobble, head
-- loll, antenna drift and the two eyes' rings spinning in opposite directions.
-- Directions are given in Floppy's world frame (face toward -Z) and converted
-- into each bone's own frame at rest, so they don't depend on bone axes.
local RunService = game:GetService("RunService")

local model = workspace:WaitForChild("Floppy", 60) :: Model
local bones: { [string]: Bone } = {}
for _, d in model:GetDescendants() do
	if d:IsA("Bone") then
		bones[d.Name] = d
	end
end

local TAU = 2 * math.pi
local LOOP = 12
local BREATH, WOBBLE_X, WOBBLE_Z = 3 * TAU / LOOP, 4 * TAU / LOOP, 3 * TAU / LOOP
local LOLL, ANTENNA, EYE = TAU / LOOP, 2 * TAU / LOOP, TAU / LOOP
-- Concept axes in Roblox: concept +x is -X, up is +Y, toward the face is -Z.
local SIDEWAYS, UP, FRONT = Vector3.new(-1, 0, 0), Vector3.yAxis, Vector3.new(0, 0, -1)

local function toLocal(bone: Bone, v: Vector3): Vector3
	return bone.WorldCFrame:VectorToObjectSpace(v)
end

local root = bones.root
local origin = root.WorldPosition
local motion = {}

local function offsetMotion(name: string, fn: (number) -> (number, number, number))
	local bone = bones[name]
	if not bone then
		return
	end
	local sx, up, fr = toLocal(bone, SIDEWAYS), toLocal(bone, UP), toLocal(bone, FRONT)
	motion[bone] = function(t: number): CFrame
		local x, y, z = fn(t)
		return CFrame.new(sx * x + up * y + fr * z)
	end
end

offsetMotion("body_upper", function(t)
	return 0.006 * math.sin(t * WOBBLE_X - 1.6),
		0.010 * math.sin(t * BREATH),
		0.005 * math.sin(t * WOBBLE_Z - 0.3)
end)

local head = bones.head
if head then
	local sx, up, fr = toLocal(head, SIDEWAYS), toLocal(head, UP), toLocal(head, FRONT)
	motion[head] = function(t: number): CFrame
		local offset = sx * 0.008 * math.sin(t * WOBBLE_X - 3.0)
			+ up * 0.005 * math.sin(t * BREATH)
			+ fr * 0.006 * math.sin(t * WOBBLE_Z - 2.3)
		return CFrame.new(offset) * CFrame.fromAxisAngle(fr, 0.04 * math.sin(t * LOLL))
	end
end

for _, side in { -1, 1 } do
	local tag = side < 0 and "L" or "R"
	local antenna = bones["antenna_" .. tag]
	if antenna then
		-- Tip position from the concept: (side*0.90, 1.44, 0.56).
		local tip = origin + SIDEWAYS * (side * 0.90) + UP * 1.44 + FRONT * 0.56
		local along = (tip - antenna.WorldPosition).Unit
		local drift = (SIDEWAYS * 0.04 + FRONT * 0.02).Unit
		local axis = toLocal(antenna, along:Cross(drift).Unit)
		motion[antenna] = function(t: number): CFrame
			return CFrame.fromAxisAngle(axis, 0.05 * math.sin(t * ANTENNA + side * 1.3))
		end
	end
	local eye = bones["eye_" .. tag]
	if eye then
		local axis = toLocal(eye, (SIDEWAYS * (side * 0.4) + UP * 0.05 + FRONT).Unit)
		local direction = side < 0 and 1 or -1
		motion[eye] = function(t: number): CFrame
			return CFrame.fromAxisAngle(axis, direction * EYE * t)
		end
	end
end

local start = os.clock()
RunService.RenderStepped:Connect(function()
	local t = (os.clock() - start) % LOOP
	for bone, fn in motion do
		bone.Transform = fn(t)
	end
end)
print(string.format(
	"Floppy idle: animating %d bones",
	(function()
		local n = 0
		for _ in motion do
			n += 1
		end
		return n
	end)()
))
