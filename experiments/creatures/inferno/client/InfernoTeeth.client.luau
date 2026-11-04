--!strict
-- A small pair of pointed tooth divisions, shared by both resting smiles.
-- Keep the authored mouth and skin; only reshape its existing thin divider.
local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")
local states: { [MeshPart]: any } = {}
local pending: { [MeshPart]: boolean } = {}
local knots = {
	{ -0.66, 0.40 },
	{ -0.36, 0.43 },
	{ -0.23, 0.25 },
	{ -0.13, 0.43 },
	{ 0.12, 0.43 },
	{ 0.22, 0.26 },
	{ 0.32, 0.43 },
	{ 0.66, 0.40 },
}
local function shape(u: number): number
	for i = 2, #knots do
		local a, b = knots[i - 1], knots[i]
		if u <= b[1] then
			return a[2] + (b[2] - a[2]) * math.clamp((u - a[1]) / (b[1] - a[1]), 0, 1)
		end
	end
	return knots[#knots][2]
end
local function prepare(part: MeshPart)
	if pending[part] or states[part] or part:FindFirstAncestor("FirstPersonBodyVisual") then
		return
	end
	pending[part] = true
	task.spawn(function()
		local ok, problem = xpcall(function(): any
			local id = (part:GetAttribute("TeethSourceMesh") or part.MeshId) :: string
			do
				local model = part:FindFirstAncestorOfClass("Model")
				if not model then
					return
				end
				local top, bottom = {}, {}
				local deadline = os.clock() + 15
				while not model:FindFirstChild("mouth_b8", true) do
					if not part:IsDescendantOf(workspace) or os.clock() > deadline then
						return nil
					end
					task.wait(0.05)
				end
				for i = 0, 8 do
					top[i + 1] = model:FindFirstChild("mouth_t" .. i, true) :: Bone
					bottom[i + 1] = model:FindFirstChild("mouth_b" .. i, true) :: Bone
					if not top[i + 1] or not bottom[i + 1] then
						return
					end
				end
				local mesh = AssetService:CreateEditableMeshAsync(
					Content.fromUri(id),
					{ FixedSize = false }
				) :: EditableMesh
				local centre, half = mesh:GetCenter(), mesh:GetSize()
				local scale = part.Size / part.MeshSize
				local left, right = top[1].WorldPosition, top[9].WorldPosition
				local side = (right - left).Unit
				local span = (right - left).Magnitude
				local head = model:FindFirstChild("head", true) :: Bone
				local forward = ((left + right) / 2 - head.WorldPosition).Unit
				local surface = AssetService:CreateEditableMesh() :: EditableMesh
				local vertices, points, bones = {}, {}, {}
				for _, boneId in mesh:GetBones() do
					bones[boneId] = model:FindFirstChild(mesh:GetBoneName(boneId), true) :: Bone
				end
				for _, vertex in mesh:GetVertices() do
					local p = mesh:GetPosition(vertex)
					local world = part.CFrame * ((p - centre) * scale)
					local u = math.clamp(2 * (world - left):Dot(side) / span - 1, -0.66, 0.66)
					local position = (u + 1) * 4
					local k = math.min(math.floor(position), 7)
					local f = position - k
					local upper = top[k + 1].WorldPosition:Lerp(top[k + 2].WorldPosition, f)
					local lower = bottom[k + 1].WorldPosition:Lerp(bottom[k + 2].WorldPosition, f)
					local height = upper - lower
					local row = (world - lower):Dot(height) / height:Dot(height)
					local old = 0.40 + 0.11 * math.sin(u * 11 + 0.6) + 0.05 * math.sin(u * 23)
					local target = shape(u) + (row - old) * 0.8
					local moved = world + height * (target - row) + forward * span * 0.008
					local pNew = part.CFrame:PointToObjectSpace(moved) / scale + centre
					local v = surface:AddVertex(pNew)
					vertices[vertex] = v
					local links = {}
					local weights = mesh:GetVertexBoneWeights(vertex)
					for kBone, boneId in mesh:GetVertexBones(vertex) do
						local bone = bones[boneId]
						table.insert(links, {
							bone = bone,
							point = bone.WorldCFrame:PointToObjectSpace(moved),
							weight = weights[kBone],
						})
					end
					table.insert(points, { id = v, links = links })
				end
				for _, face in mesh:GetFaces() do
					local v = mesh:GetFaceVertices(face)
					surface:AddTriangle(vertices[v[1]], vertices[v[2]], vertices[v[3]])
				end
				mesh:Destroy()
				-- Symmetric unused bounds preserve the imported skin's render origin.
				for _, x in { -1, 1 } do
					for _, y in { -1, 1 } do
						for _, z in { -1, 1 } do
							surface:AddVertex(centre + half * Vector3.new(x, y, z))
						end
					end
				end
				local made = AssetService:CreateMeshPartAsync(Content.fromObject(surface))
				if not part:IsDescendantOf(game) then
					made:Destroy()
					surface:Destroy()
					return nil
				end
				local currentScale = part.Size / part.MeshSize
				part:ApplyMesh(made)
				part.Size = made.MeshSize * currentScale
				made:Destroy()
				states[part] = { mesh = surface, points = points, centre = centre, scale = scale }
				part:SetAttribute("TeethSourceMesh", id)
				part:SetAttribute("InspectFace", true)
				part:SetAttribute("InspectMeshRevision", 1)
				part:SetAttribute("TeethShapeRevision", 1)
			end
			return nil
		end, debug.traceback)
		pending[part] = nil
		if not ok then
			warn("Inferno tooth divider: " .. tostring(problem))
		end
	end)
end
local function consider(item: Instance)
	if
		item:IsA("MeshPart")
		and item:IsDescendantOf(workspace)
		and string.sub(item.Name, 1, 7) == "Inferno"
		and string.sub(item.Name, -9) == "MouthLine"
	then
		prepare(item)
	end
end
for _, item in game:GetDescendants() do
	consider(item)
end
game.DescendantAdded:Connect(consider)

local function frame(bone: Bone, frames: any): CFrame
	if frames[bone] then
		return frames[bone]
	end
	local parent = bone.Parent
	local base = if parent and parent:IsA("Bone")
		then frame(parent, frames)
		else (parent :: BasePart).CFrame
	local value = base * bone.CFrame * bone.Transform
	frames[bone] = value
	return value
end
RunService:BindToRenderStep("InfernoSmileTeeth", Enum.RenderPriority.Last.Value + 1, function()
	for part, state in states do
		if not part:IsDescendantOf(game) then
			state.mesh:Destroy()
			states[part] = nil
		elseif part:IsDescendantOf(workspace) then
			local frames = {}
			local physical = part.Size / part.MeshSize
			local resize = physical.X / state.scale.X
			for _, point in state.points do
				local world = Vector3.zero
				for _, link in point.links do
					world += (frame(link.bone, frames) * (link.point * resize)) * link.weight
				end
				state.mesh:SetPosition(
					point.id,
					part.CFrame:PointToObjectSpace(world) / physical + state.centre
				)
			end
		end
	end
end)
