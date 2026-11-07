--!strict
local AssetService = game:GetService("AssetService")
local Flow = require(script.Parent.Flow)
local Rig = require(script.Parent.Rig)
local Surface = {}
local LENGTH, SIDES = 28, 14

-- Every editable mesh the inspect needs, made before any part changes. Past Roblox's memory
-- budget a mesh comes back nil; a half-prepared rig showed broken parts (2026-11-07).
function Surface.reserve(ink: MeshPart, lip: MeshPart, body: MeshPart): { [string]: EditableMesh }?
	local sources: { [string]: MeshPart } = { ink = ink, lip = lip, body = body }
	local made: { [string]: EditableMesh } = {}
	for _, name in { "ink", "lip", "body", "inkSurface", "lipSurface", "fire" } do
		local source = sources[name]
		local ok, mesh = pcall(function(): EditableMesh?
			if source then
				return AssetService:CreateEditableMeshAsync(
					Content.fromUri(source.MeshId),
					{ FixedSize = name == "body" }
				)
			end
			return AssetService:CreateEditableMesh()
		end)
		if not ok or not mesh then
			for _, other in made do
				other:Destroy()
			end
			return nil
		end
		made[name] = mesh
	end
	return made
end

function Surface.fire(mesh: EditableMesh): any
	local vertices, colours = {}, {}
	-- Unreferenced bounds keep the part origin and scale stable as the flame flows.
	for _, x in { -1.5, 1.5 } do
		for _, y in { -1, 1 } do
			for _, z in { -1.5, 1.5 } do
				mesh:AddVertex(Vector3.new(x, y, z))
			end
		end
	end
	for i = 0, LENGTH do
		for j = 0, SIDES do
			local p, c = Flow.vertex(2.6, i / LENGTH, j / SIDES)
			table.insert(vertices, mesh:AddVertex(p))
			table.insert(colours, mesh:AddColor(c, 1))
		end
	end
	for i = 0, LENGTH - 1 do
		for j = 0, SIDES - 1 do
			local a = i * (SIDES + 1) + j + 1
			local b = a + SIDES + 1
			for _, ids in { { a, b, a + 1 }, { a + 1, b, b + 1 } } do
				local face = mesh:AddTriangle(vertices[ids[1]], vertices[ids[2]], vertices[ids[3]])
				mesh:SetFaceColors(face, { colours[ids[1]], colours[ids[2]], colours[ids[3]] })
			end
		end
	end
	local embers = {}
	local faces = {
		{ 1, 3, 5 },
		{ 3, 2, 5 },
		{ 2, 4, 5 },
		{ 4, 1, 5 },
		{ 3, 1, 6 },
		{ 2, 3, 6 },
		{
			4,
			2,
			6,
		},
		{
			1,
			4,
			6,
		},
	}
	for i = 1, Flow.Embers do
		local ids, colourIds = {}, {}
		for corner = 1, 6 do
			local p, c = Flow.ember(2.6, i, corner)
			ids[corner] = mesh:AddVertex(p)
			colourIds[corner] = mesh:AddColor(c, 0)
		end
		for _, v in faces do
			local face = mesh:AddTriangle(ids[v[1]], ids[v[2]], ids[v[3]])
			mesh:SetFaceColors(face, { colourIds[v[1]], colourIds[v[2]], colourIds[v[3]] })
		end
		embers[i] = { vertices = ids, colours = colourIds }
	end
	local part = AssetService:CreateMeshPartAsync(Content.fromObject(mesh))
	part.Name = "InfernoInspectFlame"
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.CastShadow = false
	part.DoubleSided = true
	part.Color = Color3.new(1, 1, 1)
	part.Material = Enum.Material.Neon
	part.Transparency = 1
	return {
		mesh = mesh,
		part = part,
		vertices = vertices,
		colours = colours,
		embers = embers,
		size = part.MeshSize,
	}
end

function Surface.step(
	fire: any,
	t: number,
	frame: CFrame,
	scale: number,
	radius: number?,
	radialSign: number?,
	bounds: any?
)
	local head = Flow.ease((t - Flow.Start) / 0.34)
	local alpha = 1 - Flow.ease((t - Flow.End - 0.34) / 0.34)
	if t < Flow.Start or head <= 0.001 or alpha <= 0 then
		fire.part.Transparency = 1
		return
	end
	local function warp(p: Vector3, ember: boolean): Vector3
		if radius and radialSign then
			local angle = p.X * scale / radius
			local r = radius + p.Z * scale * radialSign
			if ember and bounds then
				r = math.clamp(r, 0.002, bounds.radius * 0.999)
				p = Vector3.new(p.X, math.clamp(p.Y, bounds.minY, bounds.maxY), p.Z)
			end
			return Vector3.new(
				r * math.sin(angle) / scale,
				p.Y,
				(r * math.cos(angle) - radius) * radialSign / scale
			)
		end
		return p
	end
	for i = 0, LENGTH do
		for j = 0, SIDES do
			local k = i * (SIDES + 1) + j + 1
			local p, c, opacity = Flow.vertex(t, i / LENGTH, j / SIDES)
			fire.mesh:SetPosition(fire.vertices[k], warp(p, false))
			fire.mesh:SetColor(fire.colours[k], c)
			fire.mesh:SetColorAlpha(fire.colours[k], opacity)
		end
	end
	for i, ember in fire.embers do
		for corner = 1, 6 do
			local p, c, opacity = Flow.ember(t, i, corner)
			fire.mesh:SetPosition(ember.vertices[corner], warp(p, true))
			fire.mesh:SetColor(ember.colours[corner], c)
			fire.mesh:SetColorAlpha(ember.colours[corner], opacity)
		end
	end
	fire.part.Size = fire.size * scale
	fire.part.CFrame = frame
	fire.part.Transparency = 1 - 0.96 * alpha
end

local function skin(
	rig: any,
	part: MeshPart,
	mesh: EditableMesh,
	points: any,
	surface: EditableMesh
): any
	local centre = mesh:GetCenter()
	local scale = part.Size / part.MeshSize
	local rest = rig.parts[part]
	local bones = {}
	for _, id in mesh:GetBones() do
		bones[id] = rig.model:FindFirstChild(mesh:GetBoneName(id), true)
	end
	for _, point in points do
		local ids = mesh:GetVertexBones(point.id)
		local weights = mesh:GetVertexBoneWeights(point.id)
		point.links = {}
		for k, id in ids do
			local bone = bones[id]
			if bone then
				local inverse = Rig.localFrame(rig, bone, false):Inverse() * rest
				table.insert(point.links, {
					bone = bone,
					weight = weights[k],
					rest = inverse * ((point.rest - centre) * scale),
					thin = inverse * ((point.thin - centre) * scale),
				})
			end
		end
	end
	-- Bake the same skin on the client. Imported mouth bindings produce folded
	-- corners under large lip translations; a rigid editable surface avoids that.
	-- Keep the render origin fixed while the expression narrows and the head
	-- compresses/turns. Bounds must not follow the changing mouth silhouette.
	local half = mesh:GetSize() / 2 + Vector3.one * 0.8
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				surface:AddVertex(centre + half * Vector3.new(x, y, z))
			end
		end
	end
	local vertices, uvs = {}, {}
	for _, point in points do
		local id = surface:AddVertex(point.rest)
		vertices[point.id] = id
		point.id = id
	end
	for _, id in mesh:GetUVs() do
		uvs[id] = surface:AddUV(mesh:GetUV(id) :: Vector2)
	end
	for _, id in mesh:GetFaces() do
		local v = mesh:GetFaceVertices(id)
		local uv = mesh:GetFaceUVs(id)
		local face = surface:AddTriangle(vertices[v[1]], vertices[v[2]], vertices[v[3]])
		surface:SetFaceUVs(face, { uvs[uv[1]], uvs[uv[2]], uvs[uv[3]] })
	end
	mesh:Destroy()
	local made = AssetService:CreateMeshPartAsync(Content.fromObject(surface))
	part:ApplyMesh(made)
	part.Size = made.MeshSize * scale
	made:Destroy()
	part:SetAttribute("InspectMeshRevision", 1)
	part:SetAttribute("InspectFace", true)
	return {
		mesh = surface,
		points = points,
		part = part,
		centre = centre,
		scale = scale,
		rest = rest,
		rig = rig,
	}
end

function Surface.ink(rig: any, part: MeshPart, lip: MeshPart, lipInInk: CFrame, meshes: any): any
	local mesh, mouth = meshes.ink :: EditableMesh, meshes.lip :: EditableMesh
	local positions = {}
	local inkScale = part.Size / part.MeshSize
	local lipScale = lip.Size / lip.MeshSize
	local inkCentre, lipCentre = mesh:GetCenter(), mouth:GetCenter()
	for _, id in mouth:GetVertices() do
		table.insert(
			positions,
			(lipInInk * ((mouth:GetPosition(id) - lipCentre) * lipScale)) / inkScale + inkCentre
		)
	end
	local points = {}
	for _, id in mesh:GetVertices() do
		local p = mesh:GetPosition(id)
		local closest = p
		local distance = math.huge
		for _, q in positions do
			local d = (q - p).Magnitude
			if d < distance then
				distance = d
				closest = q
			end
		end
		table.insert(points, { id = id, rest = p, thin = closest + (p - closest) * 0.28 })
	end
	local lipPoints = {}
	for _, id in mouth:GetVertices() do
		local p = mouth:GetPosition(id)
		table.insert(lipPoints, { id = id, rest = p, thin = p })
	end
	local result = skin(rig, part, mesh, points, meshes.inkSurface)
	result.lip = skin(rig, lip, mouth, lipPoints, meshes.lipSurface)
	return result
end

local function stepSkin(state: any, amount: number)
	local frames = {}
	local inverse = state.rest:Inverse()
	for _, point in state.points do
		local value = Vector3.zero
		for _, link in point.links do
			local frame = frames[link.bone]
			if not frame then
				frame = Rig.localFrame(state.rig, link.bone, true)
				frames[link.bone] = frame
			end
			value += (frame * link.rest:Lerp(link.thin, amount)) * link.weight
		end
		state.mesh:SetPosition(point.id, (inverse * value) / state.scale + state.centre)
	end
end

function Surface.stepInk(ink: any, amount: number)
	stepSkin(ink, amount)
	stepSkin(ink.lip, 0)
	ink.part.Color = Color3.fromRGB(41, 27, 23):Lerp(Color3.fromRGB(116, 57, 30), amount)
end

return Surface
