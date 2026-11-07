--!strict
-- Floppy's idle on the client (Bone.Transform does not replicate). Same motion
-- and 12 s loop as the Blender Idle: breathing rise, travelling wobble, head
-- loll, antenna drift and the two eyes' rings spinning in opposite directions.
-- Plays on every Floppy in the workspace: the one on the pedestal and the one
-- loaded in the equipped blaster. Each Floppy's own frame comes from its bones
-- (eye to eye is sideways, root to head is up), so a Floppy lying in the gun
-- moves the same way relative to himself. A loaded Floppy instead lives on springs
-- (same tuning as SlugIcon): idle and the inspect's look only set targets, so they flow
-- into one another.
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
local inspectModels: { [Model]: (number, boolean) -> () } = {}
local fitModels: { [Model]: () -> () } = {}

type Spring = { x: number, v: number, target: number, freq: number, damp: number }
local TIME_STEP = 1 / 120 -- fixed, so the motion is the same at any frame rate
local function spring(freq: number, damp: number): Spring
	return { x = 0, v = 0, target = 0, freq = freq, damp = damp }
end
local function stepSpring(s: Spring, dt: number)
	local w = TAU * s.freq
	s.v += (w * w * (s.target - s.x) - 2 * s.damp * w * s.v) * dt
	s.x += s.v * dt
end
-- How far the springs bend the rig, in source units and radians. As SlugIcon's.
-- The wiggle bends up the spine, each joint trailing the one below, so the base stays put
-- and the body flows above it.
local BEND_LOWER, BEND_UPPER, BEND_HEAD = math.rad(2), math.rad(11), math.rad(7)
local TRAIL_ANGLE = 0.1
local SQUASH_UPPER, SQUASH_HEAD, SQUASH_FLANK = 0.38, 0.03, 0.28
local STRETCH_FLANK_SHARE = 0.6
local SWAY_UPPER = 0.07
-- Looking up bends mostly from the waist. Tilting the head alone shears the cheek, which is part
-- head-weighted, against the fully head-bound lids and smears his dark under-eyes into streaks
-- (owner, 2026-11-03 in the lobby; 2026-11-07 in the gun and the HUD). Was head 22, upper 6.
local PITCH_HEAD, PITCH_UPPER = math.rad(6), math.rad(14)
local FLOP_ANGLE = 0.12

local function setup(model: Model)
	if floppies[model] or (model.Name ~= "Floppy" and model.Name ~= "FloppyFlight") then
		return
	end
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
		-- The Model can arrive before its skinned parts and their bones.
		-- Register only a complete skeleton, then retry the same loaded copy.
		task.delay(0.1, function()
			if model.Parent and not floppies[model] then
				setup(model)
			end
		end)
		return
	end
	local tool = model:FindFirstAncestorOfClass("Tool")
	local handle = tool and tool:FindFirstChild("Handle")
	if tool then
		local attached = false
		for _, item in model:GetDescendants() do
			if item:IsA("Weld") and item.Part0 == handle then
				attached = true
				break
			end
		end
		-- Model, Handle and weld references can replicate in separate batches.
		-- Do not permanently register an idle-only model before its grip arrives.
		if not handle or not handle:IsA("BasePart") or not attached then
			task.delay(0.1, function()
				if model.Parent and not floppies[model] then
					setup(model)
				end
			end)
			return
		end
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
		local centre = model:GetAttribute("ChamberCentre")
		local pivot = if typeof(centre) == "Vector3"
			then centre
			else handle.CFrame:PointToObjectSpace(
				(root.WorldPosition + head.WorldPosition) / 2
			)
		local height = model:GetAttribute("ChamberRoom")
		local room = if typeof(height) == "number" then height else 0
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

		local squash, sway, lag = spring(5, 0.26), spring(3.4, 0.42), spring(2.6, 0.34)
		local pitch, flop, stand = spring(1.8, 0.8), spring(2.4, 0.5), spring(2.2, 0.8)
		local tip = spring(2.2, 0.4)
		local springs = { squash, sway, lag, tip, pitch, flop, stand }
		local body = model:FindFirstChild("FloppyBody", true)
		if body and body:IsA("MeshPart") then
			task.spawn(function()
				local mesh =
					game:GetService("AssetService")
						:CreateEditableMeshAsync(Content.fromUri(body.MeshId), { FixedSize = true }) :: EditableMesh
				local bases, points, meshBones = {}, {}, {}
				for _, entry in joints do
					bases[entry.joint.Part1] = entry.base
				end
				local function frame(bone: Bone, moved: boolean, frames: any): CFrame
					if frames[bone] then
						return frames[bone]
					end
					local parent = bone.Parent
					local base = if parent and parent:IsA("Bone")
						then frame(parent, moved, frames)
						else bases[parent :: BasePart]
					local transform = if moved then bone.Transform else CFrame.identity
					local result = base * bone.CFrame * transform
					frames[bone] = result
					return result
				end
				for _, id in mesh:GetBones() do
					meshBones[id] = model:FindFirstChild(mesh:GetBoneName(id), true) :: Bone
				end
				local rests = {}
				local lowHeight, highHeight = math.huge, -math.huge
				for _, id in mesh:GetVertices() do
					local point = bases[body]
						* ((mesh:GetPosition(id) - mesh:GetCenter()) * (body.Size / body.MeshSize))
					local links = {}
					local weights = mesh:GetVertexBoneWeights(id)
					for k, boneId in mesh:GetVertexBones(id) do
						local bone = meshBones[boneId]
						table.insert(links, {
							bone = bone,
							point = frame(bone, false, rests):PointToObjectSpace(point),
							weight = weights[k],
						})
					end
					local y = point:Dot(uy)
					lowHeight, highHeight = math.min(lowHeight, y), math.max(highHeight, y)
					table.insert(points, { links = links, height = y, rest = point })
				end
				mesh:Destroy()
				local half = model:GetAttribute("ChamberHalfSize") :: Vector3
				local restMin, restMax = Vector3.one * math.huge, Vector3.one * -math.huge
				local restFoot, footCount = Vector3.zero, 0
				local sole = {}
				for _, point in points do
					point.foot = point.height < lowHeight + (highHeight - lowHeight) * 0.13
					restMin, restMax = restMin:Min(point.rest), restMax:Max(point.rest)
					if point.foot then
						table.insert(sole, point)
						restFoot += point.rest
						footCount += 1
					end
				end
				restFoot /= math.max(footCount, 1)
				local restCentre = (restMin + restMax) / 2
				fitModels[model] = function()
					if body.Transparency >= 1 then
						return
					end
					local original = model:GetAttribute("InspectPose") :: CFrame
					local t = inspectTime()
					local hop = if t then Inspect.hop(t) else 0
					-- Only evaluate the sole. Whole-body searches both cost a
					-- frame and repeatedly choke the upper-body spring output.
					local frames = {}
					local foot = Vector3.zero
					for _, point in sole do
						local p = Vector3.zero
						for _, link in point.links do
							p += (frame(link.bone, true, frames) * link.point) * link.weight
						end
						p = original * p
						foot += p
					end
					foot /= math.max(footCount, 1)
					local basis = if t and Inspect.looking(t) > 0.999 then upright else original
					local anchor = pivot + basis:VectorToWorldSpace(restFoot - restCentre)
					-- The authored root is the original flat ground plane. Seat
					-- it on the cap, hiding the below-ground underside as in the
					-- accepted standing design.
					local flat = (original * frame(root, true, frames).Position).Z
					local shift = Vector3.new(
						anchor.X - foot.X,
						anchor.Y - foot.Y,
						pivot.Z + half.Z * 0.86 - flat - half.Z * 0.14 * hop
					)
					local pose = CFrame.new(shift) * original
					model:SetAttribute("InspectPose", pose)
					model:SetAttribute("InspectFootCentre", foot + shift)
					model:SetAttribute("InspectUpperGain", 1)
					model:SetAttribute("InspectFitRatio", nil)
					model:SetAttribute("InspectSoleSamples", #sole)
					model:SetAttribute("InspectGroundGap", half.Z * 0.14 * hop)
					for _, entry in joints do
						if entry.joint.Parent then
							entry.joint.C0 = pose * entry.base
							if entry.joint.Part1 then
								entry.joint.Part1:SetAttribute("InspectLocalFrame", entry.joint.C0)
							end
						end
					end
				end
			end)
		end
		local leftover, clock = 0, 0
		local flying, landed = false, false

		inspectModels[model] = function(dt: number, restore: boolean)
			if restore then
				for _, entry in joints do
					if entry.joint.Parent then
						entry.joint.C0 = entry.base
						if entry.joint.Part1 then
							entry.joint.Part1:SetAttribute("InspectLocalFrame", nil)
						end
					end
				end
				return
			end
			clock += dt
			local t = inspectTime()
			local looking = if t then Inspect.looking(t) else 0
			-- Slow, loose and never quite repeating, in the chamber or looking at the holder.
			local swell, beat, pump, hop, crouch, snug = 0, 0, 0, 0, 0, 0
			if t then
				swell, beat, pump = Inspect.wiggle(t)
				hop, crouch = Inspect.hop(t)
				snug = Inspect.snug(t)
			end
			local idle = 1 - math.max(swell, looking)
			squash.target = 0.1 * math.sin(TAU * clock / 3.6) * idle + 0.12 * swell * pump + crouch
			sway.target = 0.16 * math.sin(TAU * clock / 7.3) * idle + swell * beat + snug
			pitch.target = 0.14 * math.sin(TAU * clock / 11) * idle
				+ 0.7 * looking * (1 - swell)
				+ 0.15 * swell
			stand.target = looking
			-- Turns to the holder, snaps home during the hop, drifts home if interrupted.
			stand.freq = if not t then 1.4 elseif looking > 0 then 2.2 else 3
			stand.damp = if not t then 1 elseif looking > 0 then 0.8 else 0.9
			if t and hop > 0 and not flying then
				flying = true
				squash.v -= 10
			end
			if t and Inspect.landed(t) and not landed then
				landed = true
				squash.v += 12
			end
			if not t then
				flying, landed = false, false
			end
			local steps = math.min(dt, 0.1) + leftover
			while steps >= TIME_STEP do
				steps -= TIME_STEP
				local before = squash.v
				lag.target = sway.x
				tip.target = lag.x
				for _, item in springs do
					stepSpring(item, TIME_STEP)
				end
				flop.v += (squash.v - before) * 0.08
			end
			leftover = steps
			local upness = math.clamp(stand.x, 0, 1)
			model:SetAttribute("InspectStandWeight", upness)
			local float = CFrame.new(uy * 0.012 * math.sin(TAU * clock / 4.3))
				* CFrame.fromAxisAngle(uy, math.rad(10) * math.sin(TAU * clock / 6.7))
				* CFrame.fromAxisAngle(sx, math.rad(3) * math.sin(TAU * clock / 5.3 + 1))
			-- Upright he stands on top of the chamber's end cap, not sunk into it.
			local pose = CFrame.new(uy * room * (0.4 * hop - 0.4 * upness) + pivot)
				* upright:Lerp(CFrame.identity, 1 - upness)
				-- Upright he is stuck to the bottom: only the rig moves.
				* float:Lerp(CFrame.identity, upness)
				* CFrame.new(-pivot)
			model:SetAttribute("InspectPose", pose)
			for _, entry in joints do
				if entry.joint.Parent then
					entry.joint.C0 = pose * entry.base
				end
			end
		end

		local lower = bones.body_lower
		if lower then
			-- This bone's origin is at the base, so turning it leaves the base where it is.
			local lz = toLocal(lower, front)
			motion[lower] = function(_: number): CFrame
				return CFrame.fromAxisAngle(
					lz,
					-BEND_LOWER * sway.x * (1 - math.clamp(stand.x, 0, 1))
				)
			end
		end
		if upper then
			local idleUpper = motion[upper]
			local ux, uu, uz = toLocal(upper, sideways), toLocal(upper, up), toLocal(upper, front)
			motion[upper] = function(c: number): CFrame
				return idleUpper(c)
					* CFrame.new((ux * SWAY_UPPER * lag.x - uu * SQUASH_UPPER * squash.x) * SCALE)
					* CFrame.fromAxisAngle(uz, -BEND_UPPER * lag.x)
					* CFrame.fromAxisAngle(ux, -PITCH_UPPER * pitch.x)
			end
		end
		local idleHead = motion[head]
		local hx, hu, hz = toLocal(head, sideways), toLocal(head, up), toLocal(head, front)
		motion[head] = function(c: number): CFrame
			return idleHead(c)
				* CFrame.new(hu * -SQUASH_HEAD * squash.x * SCALE)
				* CFrame.fromAxisAngle(hz, -BEND_HEAD * tip.x)
				* CFrame.fromAxisAngle(hx, -PITCH_HEAD * pitch.x)
		end
		for _, side in { -1, 1 } do
			local antenna = bones["antenna_" .. (side < 0 and "L" or "R")]
			if antenna then
				local idleAntenna = motion[antenna]
				local axis = toLocal(antenna, front)
				motion[antenna] = function(c: number): CFrame
					-- They spread with a jolt and trail behind the head's bend.
					return idleAntenna(c)
						* CFrame.fromAxisAngle(
							axis,
							-side * flop.x * FLOP_ANGLE + (lag.x - tip.x) * TRAIL_ANGLE
						)
				end
			end
		end
		-- Flanks flatten out with a squash: Roblox has no bone scale.
		local flanks: { [string]: Vector3 } = {
			jelly_L = -sideways,
			jelly_R = sideways,
			jelly_F = front,
			jelly_B = -front,
		}
		for name, direction in flanks do
			local flankBone = bones[name]
			if flankBone then
				local outward = toLocal(flankBone, direction)
				motion[flankBone] = function(_: number): CFrame
					local flank = if squash.x > 0 then squash.x else squash.x * STRETCH_FLANK_SHARE
					return CFrame.new(
						outward * flank * SQUASH_FLANK * SCALE * (1 - math.clamp(stand.x, 0, 1))
					)
				end
			end
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
	function(dt: number)
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
					restoreInspect(0, true)
				end
				floppies[model] = nil
				inspectModels[model] = nil
				fitModels[model] = nil
				continue
			end
			local inspectModel = inspectModels[model]
			if inspectModel then
				inspectModel(dt, false)
			end
			for bone, fn in motion do
				bone.Transform = fn(t)
			end
		end
	end
)

-- The lids and mouth finish at Character + 3. Fit their final pose too, before
-- the first-person copy is placed; a previous-frame blink can miss the glass.
RunService:BindToRenderStep(
	"SlugshotFloppySole",
	Enum.RenderPriority.Character.Value + 4,
	function()
		for _, fit in fitModels do
			fit()
		end
	end
)
