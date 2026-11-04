--!strict
-- Disposable motion review: real first-person copies, including the current Floppy.
local P = game:GetService("Players").LocalPlayer
local R = game:GetService("RunService")
local scripts = P:WaitForChild("PlayerScripts")
local movement = scripts:WaitForChild("MovementSandbox")
local First = (require :: any)(movement:WaitForChild("FirstPerson"))
local Inspect = (require :: any)(movement:WaitForChild("SlugInspect"))
local probe = scripts:WaitForChild("CombatExperimentProbe") :: BindableFunction
local function say(value: string)
	print("TRANSCHECK " .. value)
end
local function waitFor(test: () -> boolean, label: string)
	local deadline = os.clock() + 30
	repeat
		if test() then
			return
		end
		task.wait(0.05)
	until os.clock() > deadline
	error(label)
end
local ok, problem = pcall(function()
	local character = P.Character or P.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local backpack = P:WaitForChild("Backpack")
	waitFor(function()
		return character:FindFirstChildOfClass("Tool") ~= nil
			or backpack:FindFirstChildOfClass("Tool") ~= nil
	end, "gun missing")
	local tool = (
		character:FindFirstChildOfClass("Tool") or backpack:FindFirstChildOfClass("Tool")
	) :: Tool
	humanoid:EquipTool(tool)
	local model = tool:WaitForChild("InfernoLoaded") :: Model
	waitFor(function()
		return model:GetAttribute("InspectReady") == true
	end, "inspect not ready")
	waitFor(function()
		local floppy = tool:FindFirstChild("Floppy")
		return floppy ~= nil and floppy:GetAttribute("InspectStandWeight") ~= nil
	end, "Floppy not ready")
	for _, item in workspace:GetDescendants() do
		if item:IsA("BillboardGui") then
			item.Enabled = false
		end
	end
	First.setActive(true)
	task.wait(1.4)
	local camera = workspace.CurrentCamera :: Camera
	local Rig = (require :: any)(scripts:WaitForChild("InfernoInspect"):WaitForChild("Rig"))
	local handle = tool:FindFirstChild("Handle") :: BasePart
	local traces = {}
	local function coherentFrame(item: Instance): CFrame
		if item:IsA("Bone") then
			return coherentFrame(item.Parent :: Instance) * item.CFrame * item.Transform
		end
		local part = item :: BasePart
		local localFrame = part:GetAttribute("InspectLocalFrame")
		return if typeof(localFrame) == "CFrame" then handle.CFrame * localFrame else part.CFrame
	end
	for _, entry in
		{
			{ model, "InfernoBody", "Inferno" },
			{ tool:WaitForChild("Floppy"), "FloppyBody", "Floppy" },
		}
	do
		local creature = entry[1] :: Model
		local body = creature:FindFirstChild(entry[2], true) :: MeshPart
		local mesh = game:GetService("AssetService")
			:CreateEditableMeshAsync(body.MeshContent, { FixedSize = true }) :: EditableMesh
		local bones, points, footHeights = {}, {}, {}
		local up = ((creature:FindFirstChild("head", true) :: Bone).WorldPosition - (
			creature:FindFirstChild("root", true) :: Bone
		).WorldPosition).Unit
		local lowHeight, highHeight = math.huge, -math.huge
		local lowRest, highRest = math.huge, -math.huge
		local restFrame = CFrame.identity
		for _, joint in creature:GetDescendants() do
			if joint:IsA("Weld") and joint.Part1 == body then
				restFrame = joint:GetAttribute("InspectRestC0") or joint.C0
			end
		end
		for _, id in mesh:GetBones() do
			bones[id] = creature:FindFirstChild(mesh:GetBoneName(id), true) :: Bone
		end
		for _, id in mesh:GetVertices() do
			local canonical = restFrame
				* ((mesh:GetPosition(id) - mesh:GetCenter()) * (body.Size / body.MeshSize))
			lowRest, highRest = math.min(lowRest, canonical.Z), math.max(highRest, canonical.Z)
			local world = body.CFrame
				* ((mesh:GetPosition(id) - mesh:GetCenter()) * (body.Size / body.MeshSize))
			local links = {}
			local weights = mesh:GetVertexBoneWeights(id)
			for k, boneId in mesh:GetVertexBones(id) do
				local bone = bones[boneId]
				table.insert(links, {
					bone = bone,
					point = bone.WorldCFrame:PointToObjectSpace(world),
					vectorFrame = bone.WorldCFrame:ToObjectSpace(body.CFrame),
					weight = weights[k],
				})
			end
			table.insert(points, { links = links, vertex = id, original = mesh:GetPosition(id) })
			local h = world:Dot(up)
			footHeights[#points] = h
			lowHeight, highHeight = math.min(lowHeight, h), math.max(highHeight, h)
		end
		mesh:Destroy()
		traces[entry[3]] = {
			model = creature,
			body = body,
			bones = bones,
			points = points,
			radial = 0,
			axial = 0,
			samples = 0,
			footFlags = {},
			footMin = Vector3.one * math.huge,
			footMax = Vector3.one * -math.huge,
			headMin = Vector3.one * math.huge,
			headMax = Vector3.one * -math.huge,
			footSamples = 0,
			landingSamples = 0,
			landingError = 0,
			height = 0,
			bellyMovement = 0,
			restHeight = highRest - lowRest,
		}
		for i, h in footHeights do
			traces[entry[3]].footFlags[i] = h < lowHeight + (highHeight - lowHeight) * 0.13
		end
	end
	local tracing: any = nil
	local sampleAt = 0
	R:BindToRenderStep("MotionReviewSkinFit", Enum.RenderPriority.Character.Value + 12, function()
		if not tracing or os.clock() < sampleAt then
			return
		end
		sampleAt = os.clock() + 0.08
		local frames = {}
		for _, bone in tracing.bones do
			frames[bone] = coherentFrame(bone)
		end
		local centre = tracing.model:GetAttribute("ChamberCentre") :: Vector3
		local half = if tracing.model == model
			then (model:GetAttribute("ChamberSize") :: Vector3) / 2
			else tracing.model:GetAttribute("ChamberHalfSize") :: Vector3
		local foot, footCount, footBack = Vector3.zero, 0, -math.huge
		local low, high = math.huge, -math.huge
		local sampleRadial = 0
		local editable = tracing.body.MeshContent.Object :: EditableMesh?
		for i, point in tracing.points do
			local links = point.links
			local world = Vector3.zero
			local delta = if editable
				then (editable:GetPosition(point.vertex) - point.original)
					* (tracing.body.Size / tracing.body.MeshSize)
				else Vector3.zero
			tracing.bellyMovement = math.max(tracing.bellyMovement, delta.Magnitude)
			for _, link in links do
				world += (frames[link.bone] * (link.point + link.vectorFrame:VectorToWorldSpace(
					delta
				))) * link.weight
			end
			local p = handle.CFrame:PointToObjectSpace(world) - centre
			local radius = math.sqrt((p.X / half.X) ^ 2 + (p.Y / half.Y) ^ 2)
			if radius > tracing.radial then
				local names = {}
				for _, link in links do
					table.insert(names, link.bone.Name .. ":" .. string.format("%.2f", link.weight))
				end
				tracing.worst = tostring(p) .. " " .. table.concat(names, ",")
			end
			tracing.radial =
				math.max(tracing.radial, math.sqrt((p.X / half.X) ^ 2 + (p.Y / half.Y) ^ 2))
			sampleRadial =
				math.max(sampleRadial, math.sqrt((p.X / half.X) ^ 2 + (p.Y / half.Y) ^ 2))
			tracing.axial = math.max(tracing.axial, math.abs(p.Z) / half.Z)
			low, high = math.min(low, p.Z), math.max(high, p.Z)
			if tracing.footFlags[i] then
				foot += p
				footCount += 1
				footBack = math.max(footBack, p.Z)
			end
		end
		local t = Inspect.elapsed(character)
		if tracing == traces.Floppy and sampleRadial > 0.995 then
			say("Floppy extreme " .. tostring(tracing.worst))
			say(
				string.format(
					"Floppy fit diagnostic time %s measured %.5f fitted %s gain %s",
					tostring(t),
					sampleRadial,
					tostring(tracing.model:GetAttribute("InspectFitRatio")),
					tostring(tracing.model:GetAttribute("InspectUpperGain"))
				)
			)
		end
		if t and t > 1.15 and t < 1.35 then
			tracing.height = math.max(tracing.height, high - low)
		end
		if tracing == traces.Floppy and t and t > 3.22 and t < 3.87 then
			tracing.landingSamples += 1
			local rootZ = handle.CFrame:PointToObjectSpace(
				coherentFrame(tracing.model:FindFirstChild("root", true) :: Bone).Position
			).Z - centre.Z
			tracing.landingError = math.max(tracing.landingError, math.abs(half.Z * 0.86 - rootZ))
		end
		if tracing == traces.Floppy and t and t > 1.15 and t < 2.65 then
			foot /= math.max(1, footCount)
			tracing.footMin, tracing.footMax = tracing.footMin:Min(foot), tracing.footMax:Max(foot)
			local head = handle.CFrame:PointToObjectSpace(
				coherentFrame(tracing.model:FindFirstChild("head", true) :: Bone).Position
			) - centre
			tracing.headMin, tracing.headMax = tracing.headMin:Min(head), tracing.headMax:Max(head)
			tracing.footSamples += 1
		end
		tracing.samples += 1
	end)
	local view = root.CFrame
	local movementProbe = scripts:WaitForChild("MovementExperimentProbe") :: BindableFunction
	local base = CFrame.new(view.Position + Vector3.new(0, 1.5, 0)) * view.Rotation
	local close = false
	local quarter = false
	local frozen: number? = nil
	local toothView: CFrame? = nil
	local running = false
	local catchSeen = false
	local catchRelative: CFrame? = nil
	local catchSpeed = 0
	local catchSlip = 0
	local catchSpeedRelative = 0
	local lastCatchTime = 0
	local runClock: number? = nil
	R:BindToRenderStep("MotionReviewClock", Enum.RenderPriority.First.Value, function()
		if frozen then
			character:SetAttribute("SlugInspectAt", workspace:GetServerTimeNow() - frozen)
		end
	end)
	R:BindToRenderStep("MotionReviewCamera", Enum.RenderPriority.Camera.Value + 1, function()
		camera.CameraType = Enum.CameraType.Scriptable
		base = CFrame.new(root.Position + Vector3.new(0, 1.5, 0)) * view.Rotation
		camera.CFrame = base
	end)
	R:BindToRenderStep("MotionReviewReturnCatch", Enum.RenderPriority.Last.Value + 3, function()
		if not running or not runClock then
			return
		end
		local t = workspace:GetServerTimeNow() - runClock
		if t < Inspect.InfernoLower + Inspect.ReturnCatch - Inspect.Lower + 0.01 then
			return
		end
		local visual = camera:FindFirstChild("FirstPersonBodyVisual")
		local arm = visual and visual:FindFirstChild("Right Arm") :: BasePart
		local gun = visual and visual:FindFirstChild("Handle") :: BasePart
		if arm and gun then
			local at = arm.CFrame:ToObjectSpace(gun.CFrame)
			if catchRelative then
				catchSlip = math.max(catchSlip, (at.Position - catchRelative.Position).Magnitude)
				catchSpeedRelative = math.max(
					catchSpeedRelative,
					(at.Position - catchRelative.Position).Magnitude
						/ math.max(os.clock() - lastCatchTime, 0.001)
				)
			end
			lastCatchTime = os.clock()
			catchRelative = at
			catchSeen = true
			catchSpeed = math.max(
				catchSpeed,
				Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
			)
		end
	end)
	R:BindToRenderStep("MotionReviewCloseup", Enum.RenderPriority.Last.Value, function()
		if toothView then
			camera.CFrame = toothView
			return
		end
		if close then
			local visual = camera:FindFirstChild("FirstPersonBodyVisual")
			local handle = visual and visual:FindFirstChild("Handle") :: BasePart
			if handle then
				local at = handle.CFrame * (model:GetAttribute("ChamberCentre") :: Vector3)
				local offset = -view.LookVector * 0.62
				if quarter then
					offset += view.RightVector * 0.42
				end
				camera.CFrame = CFrame.lookAt(at + offset, at, view.UpVector)
				if quarter and visual then
					-- Diagnostic quarter-view only: remove casing occlusion around the face.
					for _, item in visual:GetChildren() do
						if item:IsA("BasePart") and not string.find(item.Name, "Inferno") then
							item.LocalTransparencyModifier = 1
						end
					end
				end
			end
		end
	end)
	probe:Invoke("Select", 2)
	task.wait(0.4)
	for _, spec in
		{
			{ 1, "floppy-current", true },
			{ 2, "inferno-whole", false },
			{ 2, "inferno-chamber", true },
			{ 2, "inferno-running", false, true },
		}
	do
		probe:Invoke("Select", spec[1])
		task.wait(0.4)
		close = spec[3]
		if spec[1] == 1 then
			local f = tool:FindFirstChild("Floppy") :: Model
			local names = {}
			for _, p in f:GetDescendants() do
				if p:IsA("MeshPart") then
					table.insert(names, p.Name)
				end
			end
			say("Floppy mesh parts " .. table.concat(names, ","))
		end
		running = spec[4] == true
		if running then
			root.CFrame = CFrame.new(-65, 3, 35) * view.Rotation
			root.AssemblyLinearVelocity = Vector3.zero
		end
		tracing = traces[if spec[1] == 2 then "Inferno" else "Floppy"]
		say("record " .. spec[2])
		task.wait(0.45)
		local previousStamp = character:GetAttribute("SlugInspectAt")
		runClock = nil
		probe:Invoke("Inspect")
		waitFor(function()
			return typeof(character:GetAttribute("SlugInspectAt")) == "number"
				and character:GetAttribute("SlugInspectAt") ~= previousStamp
		end, "inspect timestamp did not update")
		runClock = character:GetAttribute("SlugInspectAt") :: number
		if running then
			task.delay(2.6, function()
				movementProbe:Invoke("Sprint", true)
				movementProbe:Invoke("Move", { direction = Vector3.new(0, 0, -1), duration = 2.8 })
			end)
		end
		task.wait(5.7)
		if spec[1] == 1 then
			local f = tool:FindFirstChild("Floppy") :: Model
			say(
				string.format(
					"Floppy final fit gain %s ratio %s stand %s",
					tostring(f:GetAttribute("InspectUpperGain")),
					tostring(f:GetAttribute("InspectFitRatio")),
					tostring(f:GetAttribute("InspectStandWeight"))
				)
			)
		end
		if running then
			movementProbe:Invoke("Sprint", false)
			movementProbe:Invoke("Move", { direction = Vector3.zero, duration = 1 })
			assert(catchSeen and catchSpeed > 10, "return catch was not checked while running")
			assert(catchSpeedRelative < 4, "caught gun jumps relative to running arm")
			say(
				string.format(
					"running return catch registered, speed %.2f, max grip frame step %.5f, relative speed %.3f",
					catchSpeed,
					catchSlip,
					catchSpeedRelative
				)
			)
		end
		running = false
		tracing = nil
	end
	for name, trace in traces do
		say(
			string.format(
				"continuous %s skin samples %d radial %.5f axial %.5f",
				name,
				trace.samples,
				trace.radial,
				trace.axial
			)
		)
	end
	local floppy = traces.Floppy
	say(
		string.format(
			"rest heights Floppy %.5f Inferno %.5f ratio %.4f",
			floppy.restHeight,
			traces.Inferno.restHeight,
			floppy.restHeight / traces.Inferno.restHeight
		)
	)
	assert(floppy.restHeight > 0 and traces.Inferno.restHeight > 0, "loaded height sample missing")
	say(
		string.format(
			"Floppy landing samples %d sole error %.6f; Inferno belly displacement %.6f",
			floppy.landingSamples,
			floppy.landingError,
			traces.Inferno.bellyMovement
		)
	)
	assert(floppy.landingSamples > 3 and floppy.landingError < 0.001, "Floppy floats after landing")
	assert(traces.Inferno.bellyMovement > 0.002, "Inferno belly did not expand")
	local footSpan = Vector2.new(
		floppy.footMax.X - floppy.footMin.X,
		floppy.footMax.Y - floppy.footMin.Y
	).Magnitude
	local headSpan = (floppy.headMax - floppy.headMin).Magnitude
	say(
		string.format(
			"Floppy planted foot samples %d drift %.6f upper motion %.6f",
			floppy.footSamples,
			footSpan,
			headSpan
		)
	)
	assert(
		floppy.footSamples > 5 and footSpan < 0.002 and headSpan > 0.004,
		"Floppy base is not planted with moving upper body"
	)
	probe:Invoke("Select", 2)
	task.wait(0.4)
	close = false
	for _, moment in { 4.0, 4.2, 4.32, 4.44, 4.55, 4.64 } do
		frozen = moment
		task.wait(0.35)
		if moment == 4.44 then
			local visual = camera:FindFirstChild("FirstPersonBodyVisual") :: Model
			local gun = visual:FindFirstChild("Handle") :: BasePart
			local point, visible = camera:WorldToViewportPoint(gun.Position)
			say(
				string.format(
					"low catch grip on screen %s at %.3f %.3f",
					tostring(visible),
					point.X / camera.ViewportSize.X,
					point.Y / camera.ViewportSize.Y
				)
			)
			assert(
				visible and point.Y < camera.ViewportSize.Y * 0.96,
				"low catch grip is hidden below the view"
			)
		end
		say("shot return-" .. string.format("%.2f", moment))
		task.wait(0.7)
	end
	close = true
	quarter = true
	for _, moment in { 1.55, 1.9, 2.15, 3.95, 4.18, 4.3, 4.44 } do
		frozen = moment
		task.wait(0.4)
		say("shot quarter-" .. string.format("%.2f", moment))
		task.wait(0.7)
	end
	-- Review the actual shared base/transformed templates, not a drawn tooth mock-up.
	frozen = nil
	character:SetAttribute("SlugInspectAt", nil)
	close = false
	First.setActive(false)
	local assets = game:GetService("ReplicatedStorage"):WaitForChild("CombatAssets")
	for _, item in assets:GetDescendants() do
		if item:IsA("MeshPart") and string.sub(item.Name, -9) == "MouthLine" then
			assert(
				item:GetAttribute("TeethShapeRevision") == nil,
				"tooth driver modified a preview template"
			)
		end
	end
	for _, item in P:WaitForChild("PlayerGui"):GetDescendants() do
		if item:IsA("MeshPart") and string.sub(item.Name, -9) == "MouthLine" then
			assert(
				item:GetAttribute("TeethShapeRevision") == nil,
				"tooth driver modified a hotbar icon"
			)
		end
	end
	say("preview templates and hotbar icons unchanged by tooth driver")
	for _, spec in { { "InfernoIcon", "base" }, { "InfernoTransformed", "transformed" } } do
		local review = (assets:WaitForChild(spec[1]) :: Model):Clone()
		review.Name = "TeethReview" .. spec[2]
		review:PivotTo(review:GetPivot() + Vector3.new(0, 60, 0) - review:GetPivot().Position)
		review.Parent = camera
		task.wait(0.2)
		local head = review:FindFirstChild("head", true) :: Bone
		local left = review:FindFirstChild("antenna_L", true) :: Bone
		local right = review:FindFirstChild("antenna_R", true) :: Bone
		local top = review:FindFirstChild("mouth_t4", true) :: Bone
		local bottom = review:FindFirstChild("mouth_b4", true) :: Bone
		local mouth = (top.WorldPosition + bottom.WorldPosition) / 2
		local side = (right.WorldPosition - left.WorldPosition).Unit
		local front = (mouth - head.WorldPosition).Unit
		local up = front:Cross(side).Unit
		front = side:Cross(up).Unit
		local unit = (right.WorldPosition - left.WorldPosition).Magnitude
			/ (if spec[2] == "base" then 0.72 else 0.60)
		local divider: BasePart? = nil
		for _, item in review:GetDescendants() do
			if item:IsA("BasePart") and string.sub(item.Name, -9) == "MouthLine" then
				divider = item
			end
		end
		assert(divider and divider.Transparency < 0.2, "resting smile tooth definition absent")
		waitFor(function()
			return divider ~= nil and divider:GetAttribute("TeethShapeRevision") == 1
		end, "sharper smile did not prepare")
		for _, angle in { 0, 0.7 } do
			local target = mouth + up * unit * 0.20
			toothView = CFrame.lookAt(target + (front * 1.8 + side * angle) * unit, target, up)
			task.wait(0.4)
			say("shot teeth-" .. spec[2] .. (if angle == 0 then "-front" else "-quarter"))
			task.wait(0.8)
		end
		local line = divider :: MeshPart
		local editable = line.MeshContent.Object :: EditableMesh
		local before = {}
		for _, face in editable:GetFaces() do
			for _, id in editable:GetFaceVertices(face) do
				before[id] = editable:GetPosition(id)
			end
		end
		local originalScale = review:GetScale()
		review:ScaleTo(originalScale * 1.25)
		task.wait(0.15)
		local errorSum, count = 0, 0
		for id, position in before do
			errorSum += (editable:GetPosition(id) - position).Magnitude
			count += 1
		end
		assert(errorSum / count < 0.001, "tooth geometry drifted after model resizing")
		review:ScaleTo(originalScale)
		say(spec[2] .. " sharp tooth geometry stays registered across ScaleTo")
		review:Destroy()
	end
	for name, trace in traces do
		assert(
			trace.samples > 25 and trace.radial < 1 and trace.axial < 1,
			name .. " continuous canister fit failed"
		)
	end
	say("PASS full motion, quarter-view mouth attachment and both resting tooth divisions")
end)
if not ok then
	say("FAIL " .. tostring(problem))
end
