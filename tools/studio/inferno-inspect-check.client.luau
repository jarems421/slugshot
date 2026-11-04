--!strict
-- Only included by build_inferno_inspect_check.py, never the ordinary range.
local P = game:GetService("Players").LocalPlayer
local R = game:GetService("RunService")
local scripts = P:WaitForChild("PlayerScripts")
local probe = scripts:WaitForChild("CombatExperimentProbe") :: BindableFunction
local movement = scripts:WaitForChild("MovementSandbox")
local First = (require :: any)(movement:WaitForChild("FirstPerson"))
local Rig = (require :: any)(scripts:WaitForChild("InfernoInspect"):WaitForChild("Rig"))
local Inspect = (require :: any)(movement:WaitForChild("SlugInspect"))
local function say(message: string)
	print("TRANSCHECK " .. message)
end
local function waitFor(test: () -> boolean, label: string)
	local stop = os.clock() + 35
	repeat
		if test() then
			return
		end
		task.wait(0.05)
	until os.clock() > stop
	error(label)
end
local frozen: number? = nil
local character: Model
R:BindToRenderStep("InfernoInspectFreeze", Enum.RenderPriority.First.Value, function()
	if frozen and character then
		character:SetAttribute("SlugInspectAt", workspace:GetServerTimeNow() - frozen)
	end
end)
local ok, problem = pcall(function()
	character = P.Character or P.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local backpack = P:WaitForChild("Backpack")
	waitFor(function()
		return character:FindFirstChildOfClass("Tool") ~= nil
			or backpack:FindFirstChildOfClass("Tool") ~= nil
	end, "gun missing")
	local tool = (
		character:FindFirstChildOfClass("Tool") or backpack:FindFirstChildOfClass("Tool")
	) :: Tool
	humanoid:EquipTool(tool)
	probe:Invoke("Select", 2)
	local model = tool:WaitForChild("InfernoLoaded") :: Model
	waitFor(function()
		return model:GetAttribute("InspectReady") == true
	end, "Inferno preparation failed")
	say("ready")
	assert(
		model:GetAttribute("LoadedSizeIncrease")
			== tool:WaitForChild("Floppy"):GetAttribute("LoadedSizeIncrease"),
		"species size increases differ"
	)
	say(
		"size factors Inferno "
			.. tostring(model:GetAttribute("LoadedSizeIncrease"))
			.. " Floppy "
			.. tostring((tool:WaitForChild("Floppy")):GetAttribute("LoadedSizeIncrease"))
	)
	assert(not tool:FindFirstChild("CanisterTeal_Ink", true), "old black canister hull is present")
	assert(
		math.abs(Inspect.Catch - Inspect.Release - 0.24) < 1e-6,
		"flip flight is not the quicker revision"
	)
	say(
		string.format(
			"current baseline: clear canister, flip 0.24 s, Floppy %.2f s, Inferno %.2f s",
			Inspect.Duration,
			Inspect.InfernoDuration
		)
	)
	First.setActive(true)
	task.wait(1)
	local camera = workspace.CurrentCamera :: Camera
	local lights = tool:FindFirstChild("ChamberLightFrame") :: BasePart
	local shownLights = (camera:FindFirstChild("FirstPersonBodyVisual") :: Model):FindFirstChild(
		"ChamberLightFrame"
	) :: BasePart
	local beamCount = 0
	for _, beam in shownLights:GetChildren() do
		if beam:IsA("Beam") then
			assert(beam.Enabled and beam.Segments >= 24, "curved light missing from first person")
			assert(
				beam.Attachment0
					and beam.Attachment0.Parent == shownLights
					and beam.Attachment1
					and beam.Attachment1.Parent == shownLights,
				"light attachments still point at the source gun"
			)
			beamCount += 1
		end
	end
	assert(beamCount == 20, "incomplete chamber light outline")
	for _, beam in lights:GetChildren() do
		if beam:IsA("Beam") then
			assert(not beam.Enabled, "duplicate source lights visible in first person")
		end
	end
	say("continuous chamber lights: 20 core/soft curves, first-person references correct")
	for _, item in workspace:GetDescendants() do
		if item:IsA("BillboardGui") then
			item.Enabled = false
		end
	end
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local viewFrame = root.CFrame
	local cameraBase = CFrame.new(viewFrame.Position + Vector3.new(0, 1.5, 0)) * viewFrame.Rotation
	local firstMacro = false
	R:BindToRenderStep("InspectCameraReset", Enum.RenderPriority.Camera.Value + 1, function()
		if firstMacro then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = cameraBase
		end
	end)
	R:BindToRenderStep(
		"InspectActualFirstPersonCloseup",
		Enum.RenderPriority.Last.Value - 1,
		function()
			if firstMacro then
				local visual = camera:FindFirstChild("FirstPersonBodyVisual")
				local handle = visual and visual:FindFirstChild("Handle") :: BasePart
				if handle then
					local at = handle.CFrame * (model:GetAttribute("ChamberCentre") :: Vector3)
					camera.CFrame = CFrame.new(at - viewFrame.LookVector * 0.62)
						* viewFrame.Rotation
				end
			end
		end
	)
	-- Independently sample the imported body's complete skin against the physical chamber.
	local sourceHandle = tool:FindFirstChild("Handle") :: BasePart
	local body = model:FindFirstChild("InfernoBody", true) :: MeshPart
	local mesh = game:GetService("AssetService")
		:CreateEditableMeshAsync(body.MeshContent, { FixedSize = true }) :: EditableMesh
	local points = {}
	local boneIds = {}
	for _, id in mesh:GetBones() do
		boneIds[id] = model:FindFirstChild(mesh:GetBoneName(id), true) :: Bone
	end
	for _, id in mesh:GetVertices() do
		local rest = body.CFrame
			* ((mesh:GetPosition(id) - mesh:GetCenter()) * (body.Size / body.MeshSize))
		local links = {}
		local ids = mesh:GetVertexBones(id)
		local weights = mesh:GetVertexBoneWeights(id)
		for k, boneId in ids do
			local bone = boneIds[boneId]
			table.insert(links, {
				bone = bone,
				point = bone.WorldCFrame:PointToObjectSpace(rest),
				weight = weights[k],
			})
		end
		table.insert(points, links)
	end
	mesh:Destroy()
	local function bounds(moment: number)
		local centre = model:GetAttribute("ChamberCentre") :: Vector3
		local size = model:GetAttribute("ChamberSize") :: Vector3

		local back, front, radial = -math.huge, math.huge, 0
		local frames = {}
		for _, bone in boneIds do
			frames[bone] = Rig.frame(bone)
		end
		for _, links in points do
			local world = Vector3.zero
			for _, link in links do
				world += (frames[link.bone] * link.point) * link.weight
			end
			local point = sourceHandle.CFrame:PointToObjectSpace(world) - centre
			back = math.max(back, point.Z)
			front = math.min(front, point.Z)
			radial = math.max(
				radial,
				math.sqrt((point.X / (size.X / 2)) ^ 2 + (point.Y / (size.Y / 2)) ^ 2)
			)
		end
		local gap = size.Z * 0.43 - back
		say(
			string.format(
				"bounds %.2f gap %.6f radial %.4f front %.5f",
				moment,
				gap,
				radial,
				front + size.Z / 2
			)
		)
		if moment < Inspect.InfernoLower then
			assert(
				math.abs(gap - (model:GetAttribute("InspectGroundGap") :: number)) < 0.0005,
				"physical sole gap differs from intended hop"
			)
		end
		assert(radial < 1 and front > -size.Z / 2, "body crossed chamber")
	end
	local previousFlow: { Vector3 }? = nil
	local function checkFlame(fire: MeshPart, visual: Instance)
		local editable = fire.MeshContent.Object :: EditableMesh
		assert(editable, "flame has no live geometry")
		local visibleHandle = visual:FindFirstChild("Handle") :: BasePart
		local frame = visibleHandle.CFrame:ToObjectSpace(fire.CFrame)
		local centre = model:GetAttribute("ChamberCentre") :: Vector3
		local size = model:GetAttribute("ChamberSize") :: Vector3
		local vertices = {}
		local visited = {}
		for _, face in editable:GetFaces() do
			for _, id in editable:GetFaceVertices(face) do
				if not visited[id] then
					visited[id] = true
					local p = editable:GetPosition(id)
					table.insert(vertices, p)
					local at = frame * (p * (fire.Size / fire.MeshSize)) - centre
					assert(at.X == at.X and at.Y == at.Y and at.Z == at.Z, "invalid flame vertex")
					assert(
						Vector2.new(at.X, at.Y).Magnitude <= math.min(size.X, size.Y) * 0.491,
						"flame crossed cylinder wall"
					)
					assert(math.abs(at.Z) <= size.Z * 0.461, "flame crossed end cap")
				end
			end
		end
		if previousFlow then
			local change = 0
			for k, p in vertices do
				change += (p - previousFlow[k]).Magnitude
			end
			assert(change / #vertices > 0.005, "developed flame is static")
		end
		previousFlow = vertices
		local opacity, green, colourCount = 0, 0, 0
		for _, id in editable:GetColors() do
			opacity += editable:GetColorAlpha(id)
			green += editable:GetColor(id).G
			colourCount += 1
		end
		assert(green / colourCount > 0.35, "flame is still predominantly red")
		model:SetAttribute("CheckMeanFireOpacity", opacity / colourCount)
		say(
			string.format(
				"flame vertex opacity %.4f orange green %.4f",
				opacity / colourCount,
				green / colourCount
			)
		)
		say("flame moving/finite/contained " .. tostring(#vertices) .. " vertices")
		say(
			"flame scale "
				.. tostring(model:GetAttribute("InspectFlameScale"))
				.. " mouth radius "
				.. tostring(model:GetAttribute("InspectFlameOriginRadius"))
		)
	end
	local faceCentres = {}
	local detachedFrame: CFrame? = nil
	local opacityBefore: number? = nil
	for _, moment in { 0.9, 1.35, 1.55, 1.9, 2.15, 2.45, 3.1, 3.8, 4.05, 4.18, 4.3, 4.44, 4.64 } do
		frozen = moment
		task.wait(0.3)
		bounds(moment)
		local visual = camera:FindFirstChild("FirstPersonBodyVisual")
		assert(visual, "viewmodel missing")
		local shownBody = visual:FindFirstChild("InfernoBody")
		assert(
			shownBody and shownBody:FindFirstChildOfClass("Motor6D"),
			"Inferno first-person body cannot deform"
		)
		local mouth = model:FindFirstChild("InfernoMouth", true) :: MeshPart
		local ink = model:FindFirstChild("InfernoMouthInk", true) :: MeshPart
		local copy = visual:FindFirstChild("InfernoMouth") :: MeshPart
		local copiedInk = visual:FindFirstChild("InfernoMouthInk") :: MeshPart
		assert(copy and copiedInk, "face copy missing")
		local divider = model:FindFirstChild("InfernoMouthLine", true) :: MeshPart
		if moment < 1 then
			assert(divider.Transparency < 0.2, "smile tooth divider missing")
		end
		if moment > 2.1 and moment < 3.6 then
			assert(divider.Transparency == 1, "tooth divider shows in the O")
		end
		for _, part in { copy, copiedInk } do
			local em = part.MeshContent.Object :: EditableMesh
			local centre = em:GetCenter()
			local before = faceCentres[part.Name]
			if before then
				assert((centre - before).Magnitude < 1e-5, "mouth render bounds drift")
			else
				faceCentres[part.Name] = centre
			end
		end
		assert(copiedInk:GetAttribute("InspectMeshRevision") == 1, "ink mesh copy stale")
		local sa = mouth:FindFirstChildOfClass("SurfaceAppearance") :: SurfaceAppearance
		local ca = copy:FindFirstChildOfClass("SurfaceAppearance") :: SurfaceAppearance
		assert(sa.Color == ca.Color, "cavity tint copy stale")
		assert(model:FindFirstChild("mouth_t4", true), "ApplyMesh dropped skeleton")
		local fire = camera:FindFirstChild("InfernoInspectFlame") :: MeshPart
		assert(fire, "flame missing")
		local mouthAmount = model:GetAttribute("InspectMouthAmount") :: number
		if moment == 1.9 then
			assert(
				(model:GetAttribute("InspectBellyExpansion") :: number) > 0.99,
				"inhale belly is not fully expanded"
			)
			assert(
				(shownBody :: MeshPart).MeshContent.Object == body.MeshContent.Object,
				"first-person belly mesh is stale"
			)
		end
		if moment > 2.1 and moment < 3.6 then
			assert(mouthAmount > 0.99 and fire.Transparency < 0.1, "breath missing")
			checkFlame(fire, visual)
		end
		if moment == 3.8 or moment == 4.05 then
			checkFlame(fire, visual)
			assert(
				model:GetAttribute("InspectFlameDetached") == true,
				"finished breath still follows the lips"
			)
			local h = visual:FindFirstChild("Handle") :: BasePart
			local at = h.CFrame:ToObjectSpace(fire.CFrame)
			if detachedFrame then
				assert(
					(at.Position - detachedFrame.Position).Magnitude < 0.0001,
					"tail drops with recovering mouth"
				)
				assert(
					(model:GetAttribute("CheckMeanFireOpacity") :: number) < opacityBefore :: number,
					"breath does not dissipate"
				)
			end
			detachedFrame = at
			opacityBefore = model:GetAttribute("CheckMeanFireOpacity") :: number
		end
		say(
			string.format(
				"pose %.2f mouth %.3f gap %.5f fire %.3f",
				moment,
				mouthAmount,
				model:GetAttribute("InspectGroundGap") :: number,
				fire.Transparency
			)
		)
		say("shot first-" .. string.format("%.2f", moment))
		task.wait(0.7)
	end
	firstMacro = true
	for _, moment in { 1.35, 1.9, 2.03, 2.65, 3.8, 4.05, 4.18, 4.3, 4.44 } do
		frozen = moment
		task.wait(0.35)
		say("shot fp-close-" .. string.format("%.2f", moment))
		task.wait(0.7)
	end
	firstMacro = false
	camera.CameraType = Enum.CameraType.Custom
	-- Diagnostic chamber close-ups of the same source rig. Hide only gun casing for this view.
	First.setActive(false)
	task.wait(0.3)
	for _, beam in lights:GetChildren() do
		if beam:IsA("Beam") then
			assert(beam.Enabled, "third-person light did not restore")
		end
	end
	local macro = false
	local handle = tool:FindFirstChild("Handle") :: BasePart
	R:BindToRenderStep("InfernoMacroCamera", Enum.RenderPriority.Last.Value, function()
		if macro then
			local centre = Rig.frame(model:FindFirstChild("head", true) :: Bone).Position
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = CFrame.lookAt(
				centre + handle.CFrame:VectorToWorldSpace(Vector3.new(-0.50, 0.02, 0.08)),
				centre,
				handle.CFrame:VectorToWorldSpace(-Vector3.zAxis)
			)
			for _, part in tool:GetDescendants() do
				if part:IsA("BasePart") and not part:IsDescendantOf(model) then
					part.LocalTransparencyModifier = 1
				end
			end
		end
	end)
	macro = true
	for _, moment in { 1.35, 1.9, 2.03, 2.65, 3.95, 4.18, 4.35 } do
		frozen = moment
		task.wait(0.3)
		say("shot macro-" .. string.format("%.2f", moment))
		task.wait(0.7)
	end
	macro = false
	for _, part in tool:GetDescendants() do
		if part:IsA("BasePart") then
			part.LocalTransparencyModifier = 0
		end
	end
	camera.CameraType = Enum.CameraType.Custom
	First.setActive(true)
	frozen = nil
	character:SetAttribute("SlugInspectAt", nil)
	task.wait(0.3)
	-- The approved Floppy performance and the restored first-person skin joint.
	probe:Invoke("Select", 1)
	task.wait(0.3)
	local floppy = tool:FindFirstChild("Floppy") :: Model
	waitFor(function()
		return floppy:GetAttribute("InspectStandWeight") ~= nil
	end, "Floppy idle/eye preparation failed")
	say("Floppy original face materials restored")
	local floppyBody = floppy:FindFirstChild("FloppyBody", true) :: MeshPart
	local fm = game:GetService("AssetService")
		:CreateEditableMeshAsync(Content.fromUri(floppyBody.MeshId), { FixedSize = true }) :: EditableMesh
	local fPoints, fBones = {}, {}
	for _, id in fm:GetBones() do
		fBones[id] = floppy:FindFirstChild(fm:GetBoneName(id), true) :: Bone
	end
	for _, id in fm:GetVertices() do
		local rest = floppyBody.CFrame
			* ((fm:GetPosition(id) - fm:GetCenter()) * (floppyBody.Size / floppyBody.MeshSize))
		local links = {}
		local ids = fm:GetVertexBones(id)
		local weights = fm:GetVertexBoneWeights(id)
		for k, boneId in ids do
			local bone = fBones[boneId]
			table.insert(links, {
				bone = bone,
				point = bone.WorldCFrame:PointToObjectSpace(rest),
				weight = weights[k],
			})
		end
		table.insert(fPoints, links)
	end
	fm:Destroy()
	local function floppyBounds(moment: number)
		local frames = {}
		for _, bone in fBones do
			frames[bone] = Rig.frame(bone)
		end
		local centre = floppy:GetAttribute("ChamberCentre") :: Vector3
		local half = floppy:GetAttribute("ChamberHalfSize") :: Vector3
		local radial, axial = 0, 0
		for _, links in fPoints do
			local world = Vector3.zero
			for _, link in links do
				world += (frames[link.bone] * link.point) * link.weight
			end
			local point = sourceHandle.CFrame:PointToObjectSpace(world) - centre
			radial = math.max(radial, math.sqrt((point.X / half.X) ^ 2 + (point.Y / half.Y) ^ 2))
			axial = math.max(axial, math.abs(point.Z) / half.Z)
		end
		say(string.format("Floppy bounds %.2f radial %.4f axial %.4f", moment, radial, axial))
		say(
			"Floppy stand "
				.. tostring(floppy:GetAttribute("InspectStandWeight"))
				.. " fit "
				.. tostring(floppy:GetAttribute("InspectFitRatio"))
		)
		assert(radial < 1 and axial < 1, "Floppy crossed chamber")
	end
	firstMacro = true
	for _, moment in { 0.1, 1.1, 1.8, 2.25, 2.8, 3.05, 3.3 } do
		frozen = moment
		task.wait(0.5)
		floppyBounds(moment)
		local visual = camera:FindFirstChild("FirstPersonBodyVisual") :: Model
		local shown = visual:FindFirstChild("FloppyBody")
		assert(
			shown and shown:FindFirstChildOfClass("Motor6D"),
			"current Floppy skin joint missing"
		)
		local sourceSurface =
			floppyBody:FindFirstChildOfClass("SurfaceAppearance") :: SurfaceAppearance
		local copiedSurface = shown:FindFirstChildOfClass("SurfaceAppearance") :: SurfaceAppearance
		assert(
			sourceSurface.ColorMapContent == copiedSurface.ColorMapContent,
			"first-person under-eye material is stale"
		)
		say("shot floppy-" .. string.format("%.2f", moment))
		task.wait(0.7)
	end
	firstMacro = false
	frozen = nil
	camera.CameraType = Enum.CameraType.Custom
	character:SetAttribute("SlugInspectAt", nil)
	probe:Invoke("Select", 2)
	task.wait(0.3)
	-- Real input/server timestamp, moving surface, and all three interruption paths.
	probe:Invoke("Inspect")
	task.wait(2.5)
	assert((model:GetAttribute("InspectMouthAmount") :: number) > 0.99, "real inspect not running")
	say("record first")
	task.wait(3.2)
	task.wait(1.5)
	for _, item in model:GetDescendants() do
		if item:IsA("Bone") then
			assert(item.Transform == CFrame.identity, "completed inspect retained bone pose")
		end
	end
	assert(
		model:GetAttribute("InspectBellyExpansion") == 0,
		"completed inspection retained belly expansion"
	)
	for _, kind in { "switch", "fire", "holster" } do
		if tool.Parent ~= character then
			humanoid:EquipTool(tool)
		end
		probe:Invoke("Select", 2)
		task.wait(1.3)
		probe:Invoke("Inspect")
		task.wait(2.5)
		assert(
			(model:GetAttribute("InspectMouthAmount") :: number) > 0.99,
			"interruption fixture did not begin " .. kind
		)
		if kind == "switch" then
			probe:Invoke("Select", 1)
		elseif kind == "fire" then
			probe:Invoke("Press")
			probe:Invoke("Select", 1)
		else
			humanoid:UnequipTools()
		end
		task.wait(0.2)
		local fire = camera:FindFirstChild("InfernoInspectFlame") :: MeshPart
		assert(fire.Transparency == 1, "cancel left flame")
		for _, item in model:GetDescendants() do
			if item:IsA("Bone") then
				assert(item.Transform == CFrame.identity, "cancel retained bone")
			end
			if item:IsA("Weld") then
				assert(item.C0 == item:GetAttribute("InspectRestC0"), "cancel retained weld")
			end
		end
		say("cancel " .. kind .. " ok")
	end
	First.setActive(false)
	humanoid:EquipTool(tool)
	probe:Invoke("Select", 2)
	task.wait(1.5)
	probe:Invoke("Inspect")
	task.wait(2.5)
	assert(
		(camera:FindFirstChild("InfernoInspectFlame") :: MeshPart).Transparency < 0.1,
		"third person flame missing"
	)
	say("shot third-breath")
	task.wait(0.7)
	humanoid.Health = 0
	task.wait(0.3)
	assert(
		(camera:FindFirstChild("InfernoInspectFlame") :: MeshPart).Transparency == 1,
		"death left flame"
	)
	local discarded = camera:FindFirstChild("InfernoInspectFlame") :: MeshPart
	tool:Destroy()
	task.wait(0.2)
	assert(discarded.Parent == nil, "destroyed model leaked flame")
	say(
		"PASS first/third inspect, face copy, full skin fit, moving contained flame, cycle and switch/fire/holster/death/disposal cleanup"
	)
end)
if not ok then
	say("FAIL " .. tostring(problem))
end
