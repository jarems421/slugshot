--!strict
local AssetService = game:GetService("AssetService")
local Flow = require(script.Parent.Flow)
local MouthRest: { [string]: Vector3 } = require(script.Parent.MouthRest)
local Rig = {}

-- Compute the current frame directly: TransformedWorldCFrame is a render behind.
function Rig.frame(bone: Instance): CFrame
	if bone:IsA("Bone") then
		return Rig.frame(bone.Parent :: Instance) * bone.CFrame * bone.Transform
	elseif bone:IsA("BasePart") then
		return bone.CFrame
	end
	return CFrame.identity
end

-- Work in authored handle space, including while a newly equipped assembly is
-- waiting for its first physics solve. World CFrames are not coherent then.
local function handleFrame(rig: any, item: Instance, moved: boolean): CFrame
	if item:IsA("Bone") then
		return handleFrame(rig, item.Parent :: Instance, moved)
			* item.CFrame
			* (if moved then item.Transform else CFrame.identity)
	elseif item:IsA("BasePart") then
		return rig.parts[item] or rig.handle.CFrame:ToObjectSpace(item.CFrame)
	end
	return CFrame.identity
end

function Rig.localFrame(rig: any, item: Instance, moved: boolean): CFrame
	return handleFrame(rig, item, moved)
end

function Rig.new(model: Model, handle: BasePart): any
	local root = model:FindFirstChild("root", true) :: Bone
	local head = model:FindFirstChild("head", true) :: Bone
	local left = model:FindFirstChild("antenna_L", true) :: Bone
	local right = model:FindFirstChild("antenna_R", true) :: Bone
	assert(root and head and left and right, "Inferno inspect: incomplete skeleton")
	local rig: any = {
		model = model,
		handle = handle,
		parts = {},
		bones = {},
		welds = {},
		feet = {},
		centre = model:GetAttribute("ChamberCentre"),
		size = model:GetAttribute("ChamberSize"),
	}
	for _, item in model:GetDescendants() do
		if item:IsA("Weld") and item.Part0 == handle and item.Part1 then
			table.insert(rig.welds, { weld = item, rest = item.C0 })
			rig.parts[item.Part1] = item.C0
			item:SetAttribute("InspectRestC0", item.C0)
		end
	end
	local leftAt, rightAt =
		handleFrame(rig, left, false).Position, handleFrame(rig, right, false).Position
	local rootAt, headAt =
		handleFrame(rig, root, false).Position, handleFrame(rig, head, false).Position
	local side = (rightAt - leftAt).Unit
	local up = (headAt - rootAt).Unit
	local front = side:Cross(up).Unit
	rig.scale = (rightAt - leftAt).Magnitude / 0.72
	for _, item in model:GetDescendants() do
		if item:IsA("Bone") then
			local frame = handleFrame(rig, item, false)
			local list = rig.bones[item.Name] or {}
			rig.bones[item.Name] = list
			table.insert(list, {
				bone = item,
				x = frame:VectorToObjectSpace(side),
				y = frame:VectorToObjectSpace(up),
				z = frame:VectorToObjectSpace(front),
			})
		end
	end
	rig.side, rig.up, rig.front = side, up, front
	local body = model:FindFirstChild("InfernoBody", true) :: MeshPart
	assert(body, "Inferno inspect: body missing")
	rig.body = body
	rig.bodyRest = rig.parts[body]
	local mesh =
		AssetService:CreateEditableMeshAsync(Content.fromUri(body.MeshId), { FixedSize = true })
	assert(mesh, "Inferno inspect: foot sampling unavailable")
	local meshScale = body.Size / body.MeshSize
	local meshCentre = mesh:GetCenter()
	local boneById = {}
	for _, id in mesh:GetBones() do
		boneById[id] = body:FindFirstChild(mesh:GetBoneName(id), true)
			or model:FindFirstChild(mesh:GetBoneName(id), true)
	end
	local lowest = math.huge
	local candidates = {}
	for _, id in mesh:GetVertices() do
		local world = rig.bodyRest * ((mesh:GetPosition(id) - meshCentre) * meshScale)
		local height = (world - rootAt):Dot(up)
		lowest = math.min(lowest, height)
		table.insert(candidates, { id = id, world = world, height = height })
	end
	for _, candidate in candidates do
		if candidate.height < lowest + 0.012 * rig.scale then
			local links = {}
			local ids = mesh:GetVertexBones(candidate.id)
			local weights = mesh:GetVertexBoneWeights(candidate.id)
			for k, id in ids do
				local bone = boneById[id]
				if bone and bone:IsA("Bone") then
					table.insert(links, {
						bone = bone,
						weight = weights[k],
						point = handleFrame(rig, bone, false):PointToObjectSpace(candidate.world),
					})
				end
			end
			if #links > 0 then
				table.insert(rig.feet, links)
			end
		end
	end
	mesh:Destroy()
	assert(#rig.feet > 0, "Inferno inspect: no skinned sole samples")
	return rig
end

local function drive(
	rig: any,
	name: string,
	offset: Vector3,
	pitch: number?,
	yaw: number?,
	roll: number?
)
	for _, item in rig.bones[name] or {} do
		item.bone.Transform = CFrame.new(
			(item.x * offset.X + item.y * offset.Y + item.z * offset.Z) * rig.scale
		) * CFrame.fromAxisAngle(item.x, pitch or 0) * CFrame.fromAxisAngle(item.y, yaw or 0) * CFrame.fromAxisAngle(
			item.z,
			roll or 0
		)
	end
end

function Rig.reset(rig: any)
	for _, list in rig.bones do
		for _, item in list do
			item.bone.Transform = CFrame.identity
		end
	end
	for _, item in rig.welds do
		item.weld.C0 = item.rest
		if item.weld.Part1 then
			item.weld.Part1:SetAttribute("InspectLocalFrame", nil)
		end
	end
end

function Rig.step(rig: any, t: number, weight: number): any
	local a = Flow.sample(t)
	local ease = Flow.ease
	local zero = Vector3.zero
	local lag = math.sin(math.pi * a.turn)
	local cheek = ease((t - Flow.End) / 0.62) * a.looking
	local preparation = ease((t - Flow.Inhale) / 0.32) * (1 - ease((t - Flow.End) / 0.32))
	local unit = 1 / Flow.GameScale
	drive(
		rig,
		"head",
		Vector3.new(0, (-0.14 * a.press + 0.045 * a.inhale - 0.013 * a.effort) * unit, 0),
		0.14 * a.inhale - 0.08 * a.effort + 0.09 * a.lift - 0.035 * cheek + 0.12 * a.breathHop,
		0.10 * a.looking + 0.13 * lag + 0.04 * cheek,
		0.09 * a.smug + 0.014 * math.sin((t - Flow.Start) * 6) * a.exhale + 0.045 * a.inhale
	)
	drive(
		rig,
		"body_upper",
		Vector3.new(0, (-0.12 * a.press + 0.045 * a.inhale - 0.020 * a.effort) * unit, 0),
		0.045 * a.inhale - 0.040 * a.effort - 0.05 * a.lift + 0.16 * a.breathHop,
		-0.07 * lag,
		-0.045 * a.smug
	)
	drive(rig, "body_lower", zero, 0, -0.05 * lag, 0)
	for _, tag in { "L", "R" } do
		local follow = 0.028 * math.sin(t * 3.4 - 0.35)
			+ 0.06 * a.inhale
			- 0.09 * a.exhale
			+ 0.12 * a.press
			- 0.08 * a.lift
		drive(rig, "antenna_" .. tag, zero, 0, 0, (if tag == "L" then 1 else -1) * follow)
		drive(rig, "antenna_tip_" .. tag, zero, 0.08 * math.sin(t * 3.4 - 0.85) + 0.08 * a.press)
	end
	drive(
		rig,
		"lid_L",
		Vector3.new(-0.008 * a.effort, 0.023 * a.inhale - 0.043 * a.effort + 0.004 * cheek, 0)
			* unit,
		0,
		0,
		0.15 * a.effort
	)
	drive(
		rig,
		"lid_R",
		Vector3.new(0.008 * a.effort, 0.020 * a.inhale - 0.045 * a.effort - 0.014 * a.smug, 0)
			* unit,
		0,
		0,
		-0.14 * a.effort
	)
	local opening = t < Flow.End
	local width = ease(a.mouth)
	local height =
		ease((a.mouth - (if opening then 0.08 else 0.02)) / (if opening then 0.92 else 0.98))
	for name, rest in MouthRest do
		local target: Vector3
		local k = tonumber(string.sub(name, -1))
		if k then
			local theta = math.pi
				+ (if string.sub(name, 7, 7) == "t" then -1 else 1) * k / 8 * math.pi
			local circle = Vector3.new(
				0.008 + (0.038 + 0.021 * a.inhale + 0.008 * a.effort) * math.cos(theta),
				0.067 + (0.042 + 0.014 * a.inhale - 0.005 * a.effort) * math.sin(theta),
				0.278 - 0.006 * a.effort + 0.004 * math.sin(k / 8 * math.pi)
			)
			target = Vector3.new(
				rest.X + (circle.X - rest.X) * width,
				rest.Y + (circle.Y - rest.Y) * height,
				rest.Z + (circle.Z - rest.Z) * ease((a.mouth - 0.12) / 0.88)
			)
			target += Vector3.yAxis * ((0.010 * preparation + 0.017 * a.smug) * math.abs(k - 4) / 4 * (1 - a.mouth) * (if k
					> 4
				then 1
				else 0.45))
		else
			target = rest:Lerp(
				Vector3.new(if string.sub(name, -1) == "L" then -0.031 else 0.047, 0.067, 0.277),
				a.mouth
			)
		end
		drive(rig, name, (target - rest) * unit)
	end
	-- Fade only the hidden raise/lower boundaries, leaving the approved acting unchanged.
	local identity = CFrame.identity
	for _, list in rig.bones do
		for _, item in list do
			item.bone.Transform = identity:Lerp(item.bone.Transform, weight)
		end
	end
	local pivot = rig.centre
	local pose = CFrame.new(pivot)
		* CFrame.fromAxisAngle(rig.up, math.pi / 2 * a.looking * weight)
		* CFrame.new(-pivot)
	local footZ = -math.huge
	for _, links in rig.feet do
		local world = zero
		for _, link in links do
			world += (handleFrame(rig, link.bone, true) * link.point) * link.weight
		end
		local point = pose * world
		footZ = math.max(footZ, point.Z)
	end
	local clearance = 0.14 * rig.scale / Flow.GameScale * (a.lift + a.breathHop)
	local seat = (pivot.Z + rig.size.Z * 0.43 - footZ - clearance) * weight
	-- Centre the imported body's bounds on the chamber axis while upright.
	-- The root reference alone leaves an asymmetric head close to the glass.
	local bodyCentre = pose * rig.bodyRest.Position
	pose = CFrame.new((pivot.X - bodyCentre.X) * weight, (pivot.Y - bodyCentre.Y) * weight, seat)
		* pose
	for _, item in rig.welds do
		item.weld.C0 = pose * item.rest
		if item.weld.Part1 then
			item.weld.Part1:SetAttribute("InspectLocalFrame", item.weld.C0)
		end
	end
	rig.pose = pose
	rig.model:SetAttribute("InspectGroundGap", clearance)
	rig.model:SetAttribute("InspectMouthAmount", a.mouth)
	return a
end

function Rig.flameFrame(rig: any): CFrame
	local top = rig.bones.mouth_t4[1].bone
	local bottom = rig.bones.mouth_b4[1].bone
	local mouth = (handleFrame(rig, top, true).Position + handleFrame(rig, bottom, true).Position)
		* 0.5
	local pose = rig.pose or CFrame.identity
	local localMouth = pose * mouth
	local radial = Vector3.new(localMouth.X - rig.centre.X, localMouth.Y - rig.centre.Y, 0).Unit
	local tangent = Vector3.new(-radial.Y, radial.X, 0)
	local camera = workspace.CurrentCamera
	if
		camera
		and rig.handle.CFrame:VectorToWorldSpace(tangent):Dot(camera.CFrame.RightVector) < 0
	then
		tangent = -tangent
	end
	local direction = rig.handle.CFrame:VectorToWorldSpace(tangent)
	local up = rig.handle.CFrame:VectorToWorldSpace(-Vector3.zAxis)
	mouth = rig.handle.CFrame * localMouth
	return CFrame.fromMatrix(mouth, direction, up, direction:Cross(up))
end

return Rig
