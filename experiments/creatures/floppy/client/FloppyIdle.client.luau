--!strict
-- Floppy's idle on the client (Bone.Transform does not replicate). Same motion
-- and 12 s loop as the Blender Idle: breathing rise, travelling wobble, head
-- loll, antenna drift and the two eyes' rings spinning in opposite directions.
-- Plays on every Floppy in the workspace: the one on the pedestal and the one
-- loaded in the equipped blaster. Each Floppy's own frame comes from its bones
-- (eye to eye is sideways, root to head is up), so a Floppy lying in the gun
-- moves the same way relative to himself.
local Players = game:GetService("Players")
local Inspect: any = nil -- resolved after startup; standalone creature places have no movement folder
local CollectionService = game:GetService("CollectionService")
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
local inspectModels: { [Model]: () -> () } = {}

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
	-- Add inspect to the existing driver, rather than racing a second bone writer.
	local tool = model:FindFirstAncestorOfClass("Tool")
	local handle = tool and tool:FindFirstChild("Handle")
	local function inspectTime(): number?
		local character = tool and tool.Parent
		return if Inspect
				and character
				and character:IsA("Model")
			then Inspect.elapsed(character)
			else nil
	end
	if tool and handle and handle:IsA("BasePart") then
		local faceVector = (eyeL.WorldPosition + eyeR.WorldPosition) / 2 - head.WorldPosition
		local facing = (faceVector - up * faceVector:Dot(up)).Unit
		local sx = handle.CFrame:VectorToObjectSpace(up:Cross(-facing))
		local uy = handle.CFrame:VectorToObjectSpace(up)
		local fz = handle.CFrame:VectorToObjectSpace(facing)
		local sourceBasis = CFrame.fromMatrix(sx, uy, -fz)
		-- The raised barrel already stands Floppy upright. Turn his face toward
		-- the holder while retaining that long axis instead of tipping him flat.
		local upright = CFrame.fromMatrix(fz, uy, sx) * sourceBasis:Inverse()
		local pivot =
			handle.CFrame:PointToObjectSpace((root.WorldPosition + head.WorldPosition) / 2)
		local joints: { { joint: Weld, base: CFrame } } = {}
		for _, item in model:GetDescendants() do
			if item:IsA("Weld") and item.Part0 == handle then
				local base = item:GetAttribute("InspectRestC0")
				if typeof(base) ~= "CFrame" then
					base = item.C0
					item:SetAttribute("InspectRestC0", base)
				end
				table.insert(joints, { joint = item, base = base :: CFrame })
			end
		end
		inspectModels[model] = function()
			local t = inspectTime()
			local pose = CFrame.identity
			if t then
				local stand = Inspect.stand(t)
				local rotation = CFrame.fromAxisAngle(
					uy,
					Inspect.turn(t, "Floppy") + Inspect.wiggle(t)
				) * upright:Lerp(CFrame.identity, 1 - stand)
				local lift = (uy * (0.25 * stand + Inspect.hop(t)) - sx * (2.2 * stand)) * SCALE
				pose = CFrame.new(lift + pivot) * rotation * CFrame.new(-pivot)
			end
			for _, entry in joints do
				if entry.joint.Parent then
					entry.joint.C0 = pose * entry.base
				end
			end
		end
	end
	local idleHead = motion[head]
	local headSide = toLocal(head, sideways)
	motion[head] = function(clock: number): CFrame
		local t = inspectTime()
		local lift = if t then Inspect.stand(t) else 0
		local nod = if t then math.sin((t - 1) * 6) * math.exp(-math.max(t - 1.4, 0) * 3) else 0
		return idleHead(clock)
			* CFrame.fromAxisAngle(headSide, math.rad(8) * lift + nod * 0.08 * lift)
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
	-- An icon's body is performed by SlugIcon; here it keeps only its eye rings.
	if CollectionService:HasTag(model, "SlugIcon") then
		for bone in motion do
			if string.sub(bone.Name, 1, 4) ~= "eye_" then
				motion[bone] = nil
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
-- Inventory and slot icons live in viewports, outside the workspace.
for _, icon in CollectionService:GetTagged("SlugIcon") do
	task.defer(setup, icon :: Model)
end
CollectionService:GetInstanceAddedSignal("SlugIcon"):Connect(function(icon: Instance)
	task.defer(setup, icon :: Model)
end)

local start = os.clock()
RunService:BindToRenderStep(
	"SlugshotFloppyIdle",
	Enum.RenderPriority.Character.Value + 2,
	function()
		if not Inspect then
			local movement = Players.LocalPlayer.PlayerScripts:FindFirstChild("MovementSandbox")
			local module = movement and movement:FindFirstChild("SlugInspect")
			if module then
				Inspect = (require :: any)(module)
			end
		end
		local t = (os.clock() - start) % LOOP
		for model, motion in floppies do
			if
				not model:IsDescendantOf(workspace)
				and not CollectionService:HasTag(model, "SlugIcon")
			then
				local restoreInspect = inspectModels[model]
				if restoreInspect then
					restoreInspect()
				end
				floppies[model] = nil
				inspectModels[model] = nil
				continue
			end
			local inspectModel = inspectModels[model]
			if inspectModel then
				inspectModel()
			end
			for bone, fn in motion do
				bone.Transform = fn(t)
			end
		end
	end
)
