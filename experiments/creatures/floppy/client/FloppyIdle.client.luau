--!strict
-- Floppy's idle on the client (Bone.Transform does not replicate). Same motion
-- and 12 s loop as the Blender Idle: breathing rise, travelling wobble, head
-- loll, antenna drift and the two eyes' rings spinning in opposite directions.
-- Plays on every Floppy in the workspace: the one on the pedestal and the one
-- loaded in the equipped blaster. Each Floppy's own frame comes from its bones
-- (eye to eye is sideways, root to head is up), so a Floppy lying in the gun
-- moves the same way relative to himself.
local RunService = game:GetService("RunService")

local TAU = 2 * math.pi
local LOOP = 12
local BREATH, WOBBLE_X, WOBBLE_Z = 3 * TAU / LOOP, 4 * TAU / LOOP, 3 * TAU / LOOP
local LOLL, ANTENNA, EYE = TAU / LOOP, 2 * TAU / LOOP, TAU / LOOP
-- Motion is authored at source size; each Floppy's scale comes from its eye
-- spacing (0.74 at source), so the ground and shrunken loaded forms both
-- move in proportion. The torso stretch moves the antenna tips up by 0.25.
local EYE_SPACING = 0.74
local TIP = Vector3.new(0.90, 1.44 + 0.25, 0.56)

type Motion = { [Bone]: (number) -> CFrame }
local floppies: { [Model]: Motion } = {}

local function setup(model: Model)
	local bones: { [string]: Bone } = {}
	local allBones: { Bone } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Bone") then
			bones[d.Name] = bones[d.Name] or d
			table.insert(allBones, d)
		end
	end
	local root, head, eyeL, eyeR = bones.root, bones.head, bones.eye_L, bones.eye_R
	if not (root and head and eyeL and eyeR) then
		return
	end
	for _, bone in allBones do
		bone.Transform = CFrame.identity
	end
	-- Concept axes: +x sideways (eye_L to eye_R), up, and toward the face.
	local sideways = (eyeR.WorldPosition - eyeL.WorldPosition).Unit
	local rough = (head.WorldPosition - root.WorldPosition).Unit
	local up = (rough - sideways * rough:Dot(sideways)).Unit
	local front = sideways:Cross(up)
	local SCALE = (eyeR.WorldPosition - eyeL.WorldPosition).Magnitude / EYE_SPACING
	local origin = root.WorldPosition
	local function toLocal(bone: Bone, v: Vector3): Vector3
		return bone.WorldCFrame:VectorToObjectSpace(v)
	end

	local motion: Motion = {}
	local upper = bones.body_upper
	if upper then
		local sx, uy, fz = toLocal(upper, sideways), toLocal(upper, up), toLocal(upper, front)
		motion[upper] = function(t: number): CFrame
			local offset = sx * 0.006 * math.sin(t * WOBBLE_X - 1.6)
				+ uy * 0.010 * math.sin(t * BREATH)
				+ fz * 0.005 * math.sin(t * WOBBLE_Z - 0.3)
			return CFrame.new(offset * SCALE)
		end
	end
	do
		local sx, uy, fz = toLocal(head, sideways), toLocal(head, up), toLocal(head, front)
		motion[head] = function(t: number): CFrame
			local offset = sx * 0.008 * math.sin(t * WOBBLE_X - 3.0)
				+ uy * 0.005 * math.sin(t * BREATH)
				+ fz * 0.006 * math.sin(t * WOBBLE_Z - 2.3)
			return CFrame.new(offset * SCALE) * CFrame.fromAxisAngle(fz, 0.04 * math.sin(t * LOLL))
		end
	end
	for _, side in { -1, 1 } do
		local tag = side < 0 and "L" or "R"
		local antenna = bones["antenna_" .. tag]
		if antenna then
			local tip = origin + (sideways * (side * TIP.X) + up * TIP.Y + front * TIP.Z) * SCALE
			local along = (tip - antenna.WorldPosition).Unit
			local drift = (sideways * 0.04 + front * 0.02).Unit
			local axis = toLocal(antenna, along:Cross(drift).Unit)
			motion[antenna] = function(t: number): CFrame
				return CFrame.fromAxisAngle(axis, 0.05 * math.sin(t * ANTENNA + side * 1.3))
			end
		end
		local eye = bones["eye_" .. tag]
		local axis = toLocal(eye, (sideways * (side * 0.4) + up * 0.05 + front).Unit)
		local direction = side < 0 and 1 or -1
		motion[eye] = function(t: number): CFrame
			return CFrame.fromAxisAngle(axis, direction * EYE * t)
		end
	end
	-- Roblox can create one skeleton per skinned mesh. Animate every copy;
	-- a name-keyed dictionary alone silently leaves the other meshes at rest.
	for _, bone in allBones do
		local primary = bones[bone.Name]
		local sourceMotion = motion[primary]
		if bone ~= primary and sourceMotion then
			local axes = bone.WorldCFrame.Rotation:ToObjectSpace(primary.WorldCFrame.Rotation)
			motion[bone] = function(t: number): CFrame
				return axes * sourceMotion(t) * axes:Inverse()
			end
		end
	end
	floppies[model] = motion
	print(`Floppy idle: animating {model:GetFullName()}`)
end

local function consider(instance: Instance)
	if instance:IsA("Model") and instance.Name == "Floppy" and not floppies[instance] then
		-- Let a freshly equipped tool settle into the hand before reading its frame.
		task.defer(setup, instance)
	end
end
for _, d in workspace:GetDescendants() do
	consider(d)
end
workspace.DescendantAdded:Connect(consider)

local start = os.clock()
RunService.RenderStepped:Connect(function()
	local t = (os.clock() - start) % LOOP
	for model, motion in floppies do
		if not model:IsDescendantOf(workspace) then
			floppies[model] = nil
			continue
		end
		for bone, fn in motion do
			bone.Transform = fn(t)
		end
	end
end)
