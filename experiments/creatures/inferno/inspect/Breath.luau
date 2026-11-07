--!strict
-- A rest-space torso corrective keeps the original native skin, UVs and face
-- attachments. Only the belly expands; the sole and head remain unchanged.
local AssetService = game:GetService("AssetService")
local Breath = {}

function Breath.new(rig: any, mesh: EditableMesh): any
	local part = rig.body :: MeshPart
	local centre, scale = mesh:GetCenter(), part.Size / part.MeshSize
	local root = rig.bones.root[1].bone
	local head = rig.bones.head[1].bone
	local Rig = require(script.Parent.Rig)
	local origin = Rig.localFrame(rig, root, false).Position
	local height = (Rig.localFrame(rig, head, false).Position - origin):Dot(rig.up)
	local points = {}
	for _, id in mesh:GetVertices() do
		local rest = mesh:GetPosition(id)
		local at = rig.bodyRest * ((rest - centre) * scale) - origin
		local u = at:Dot(rig.up) / height
		local envelope = math.sin(math.pi * math.clamp((u - 0.06) / 0.72, 0, 1)) ^ 2
		if envelope > 0.001 then
			-- 1.5 times the 2026-11-04 swell, so the inhale reads (owner, 2026-11-07).
			local offset = (
				rig.side * at:Dot(rig.side) * 0.48 + rig.front * at:Dot(rig.front) * 0.66
			) * envelope
			table.insert(points, {
				id = id,
				rest = rest,
				delta = rig.bodyRest:VectorToObjectSpace(offset) / scale,
			})
		end
	end
	local made = AssetService:CreateMeshPartAsync(Content.fromObject(mesh))
	local size = part.Size
	part:ApplyMesh(made)
	part.Size = size
	made:Destroy()
	part:SetAttribute("InspectFace", true)
	part:SetAttribute("InspectMeshRevision", 1)
	rig.model:SetAttribute("InspectBellyVertices", #points)
	return { mesh = mesh, points = points, model = rig.model, amount = -1 }
end

function Breath.step(state: any, amount: number)
	if math.abs(state.amount - amount) < 0.0001 then
		return
	end
	for _, point in state.points do
		state.mesh:SetPosition(point.id, point.rest + point.delta * amount)
	end
	state.amount = amount
	state.model:SetAttribute("InspectBellyExpansion", amount)
end

return Breath
