--!strict
-- Frozen-beat visual review. This script is only mapped by --inspect-review.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local P = Players.LocalPlayer
local scripts = P:WaitForChild("PlayerScripts")
local movement = scripts:WaitForChild("MovementSandbox")
local First = (require :: any)(movement:WaitForChild("FirstPerson"))
local Inspect = (require :: any)(movement:WaitForChild("SlugInspect"))
local acknowledged = false
local frozen: number? = nil
Input.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.K then
		acknowledged = true
	end
end)

local function waitFor(test: () -> boolean, label: string)
	local deadline = os.clock() + 25
	repeat
		if test() then
			return
		end
		task.wait()
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
	end, "tool missing")
	local tool = (
		character:FindFirstChildOfClass("Tool") or backpack:FindFirstChildOfClass("Tool")
	) :: Tool
	humanoid:EquipTool(tool)
	task.wait(2)
	local nativeGrip = tool.Grip
	local rightGrip = character:FindFirstChild("RightGrip", true) :: JointInstance
	assert(rightGrip ~= nil, "native grip missing")
	local camera = workspace.CurrentCamera :: Camera
	local frame = root.CFrame
	local source = tool:FindFirstChild("Floppy") :: Model
	local head = source:FindFirstChild("head", true) :: Bone
	local handle = tool:FindFirstChild("Handle") :: BasePart
	local baselineHead = handle.CFrame:ToObjectSpace(head.TransformedWorldCFrame)
	local headTravel = 0
	local hip = source:FindFirstChild("body_lower", true) :: Bone
	local chamberView = false
	RunService:BindToRenderStep(
		"InspectReviewClock",
		Enum.RenderPriority.Character.Value - 1,
		function()
			if frozen then
				character:SetAttribute("SlugInspectAt", workspace:GetServerTimeNow() - frozen)
			end
		end
	)
	-- Hide target annotations locally, retaining the actual game HUD.
	for _, item in workspace:GetDescendants() do
		if item:IsA("BillboardGui") then
			item.Enabled = false
		end
	end
	local cameraFrame = CFrame.new(frame.Position + Vector3.new(0, 1.5, 0)) * frame.Rotation
	RunService:BindToRenderStep(
		"InspectReviewCamera",
		Enum.RenderPriority.Camera.Value + 1,
		function()
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = cameraFrame
			-- Scriptable cameras stop Roblox's transparency controller. Clear its
			-- cached FP torso/head fade for this disposable third-person review.
			if not First.active() then
				for _, item in character:GetDescendants() do
					if item:IsA("BasePart") then
						item.LocalTransparencyModifier = 0
					end
				end
			end
		end
	)
	RunService:BindToRenderStep("InspectReviewChamber", Enum.RenderPriority.Last.Value, function()
		if chamberView then
			-- Close on the glass, looking the way the holder does. The direction stays
			-- fixed because the character turns to match the camera: following the gun's
			-- own axes would chase itself round in circles.
			local visual = camera:FindFirstChild("FirstPersonBodyVisual")
			local shown = visual and visual:FindFirstChild("Handle")
			local at = (if shown and shown:IsA("BasePart") then shown else handle).CFrame:PointToWorldSpace(
				source:GetAttribute("ChamberCentre") :: Vector3
			)
			camera.CFrame = CFrame.new(at - frame.LookVector * 1.1) * frame.Rotation
		end
	end)
	for _, view in { "fp", "third", "chamber" } do
		-- The close-up is the first-person copy: the mesh the holder actually sees.
		First.setActive(view ~= "third")
		cameraFrame = if view == "fp"
			then CFrame.new(frame.Position + Vector3.new(0, 1.5, 0)) * frame.Rotation
			elseif view == "third" then CFrame.lookAt(
				frame:PointToWorldSpace(Vector3.new(1.6, 2.6, 9)),
				frame:PointToWorldSpace(Vector3.new(0.5, 1.6, -2))
			)
			else cameraFrame
		chamberView = view == "chamber"
		for _, t in
			{
				0.3,
				0.46,
				0.62,
				0.83,
				1.2,
				1.6,
				1.8,
				2.0,
				2.4,
				2.84,
				3.05,
				3.3,
				3.5,
				3.6,
			}
		do
			frozen = t
			task.wait(0.8) -- the slug is on springs: let them reach this beat's targets
			waitFor(function()
				return source:GetAttribute("InspectPose") ~= nil
			end, "loaded inspect attachment not ready")
			assert(
				(rightGrip.C1.Position - nativeGrip.Position).Magnitude < 1e-5,
				"grip position changed"
			)
			local _, angle = (nativeGrip.Rotation:Inverse() * rightGrip.C1.Rotation):ToAxisAngle()
			assert(math.abs(angle) < 1e-5, "grip rotation changed")
			headTravel = math.max(
				headTravel,
				(
					handle.CFrame:ToObjectSpace(head.TransformedWorldCFrame).Position
					- baselineHead.Position
				).Magnitude
			)
			if view == "fp" and t >= 1.3 and t <= Inspect.Lower - 0.3 then
				local visual = camera:FindFirstChild("FirstPersonBodyVisual")
				-- Without this joint the copy's skinned mesh silently ignores its bones.
				local shownBody = visual and visual:FindFirstChild("FloppyBody")
				assert(
					shownBody and shownBody:FindFirstChildOfClass("Motor6D"),
					"first-person slug cannot deform"
				)
				local armCopy = visual and visual:FindFirstChild("Right Arm")
				local handleCopy = visual and visual:FindFirstChild("Handle")
				assert(
					armCopy
						and armCopy:IsA("BasePart")
						and handleCopy
						and handleCopy:IsA("BasePart"),
					"visible grip missing"
				)
				assert(
					handleCopy.CFrame.LookVector:Dot(-armCopy.CFrame.UpVector) > 0.97,
					"barrel and arm are not aligned"
				)
			end
			local pose = source:GetAttribute("InspectPose") :: CFrame
			-- He leans about his base, so the base is what must stay on the chamber's axis.
			local base = (source:GetAttribute("ChamberCentre") :: Vector3)
				+ Vector3.zAxis * (source:GetAttribute("LoadedHalfLength") :: number)
			local delta = pose:PointToWorldSpace(base) - base
			assert(Vector2.new(delta.X, delta.Y).Magnitude < 0.01, "slug slides out sideways")
			acknowledged = false
			print(string.format("LOADOUTCHECK shot %s-%04d", view, math.floor(t * 100)))
			waitFor(function()
				return acknowledged
			end, "capture acknowledgement missing")
		end
		frozen = nil
		character:SetAttribute("SlugInspectAt", nil)
		task.wait(0.3)
		acknowledged = false
		print("LOADOUTCHECK record " .. view)
		waitFor(function()
			return acknowledged
		end, "record acknowledgement missing")
		character:SetAttribute("SlugInspectAt", workspace:GetServerTimeNow())
		task.wait(Inspect.Duration + 0.4)
	end
	-- Conservative authored envelope, including a radial articulation margin.
	local half = source:GetAttribute("ChamberHalfSize") :: Vector3
	local radius = source:GetAttribute("LoadedRadius") :: number
	local length = source:GetAttribute("LoadedHalfLength") :: number
	local height = source:GetAttribute("ChamberRoom") :: number
	assert(radius < math.min(half.X, half.Y), "turn envelope exceeds chamber radius")
	assert(height + length <= half.Z, "slug does not fit the chamber")
	chamberView = false
	-- Real time, springs included: no pops, the slug stays inside, and idle is not frozen.
	local weld = source:FindFirstChildWhichIsA("Weld", true) :: Weld
	local centre = source:GetAttribute("ChamberCentre") :: Vector3
	local fastest, furthestAxis, furthestSide = 0, 0, 0
	local lastHead, lastHip = nil :: Vector3?, nil :: Vector3?
	local idleFirst = nil :: Vector3?
	local idleHead = 0
	local idleTurn = 0
	local wiggleLow, wiggleHigh = math.huge, -math.huge
	local baseFirst = nil :: Vector3?
	local baseDrift = 0
	local idleStart = weld.C0
	local tracing = "idle"
	local trace = RunService.RenderStepped:Connect(function(dt: number)
		local headAt = handle.CFrame:PointToObjectSpace(head.TransformedWorldCFrame.Position)
		local hipAt = handle.CFrame:PointToObjectSpace(hip.TransformedWorldCFrame.Position)
		if tracing == "idle" then
			idleFirst = idleFirst or headAt
			idleHead = math.max(idleHead, (headAt - idleFirst :: Vector3).Magnitude)
			local _, angle = (idleStart.Rotation:Inverse() * weld.C0.Rotation):ToAxisAngle()
			idleTurn = math.max(idleTurn, math.deg(math.abs(angle)))
		else
			if lastHead and lastHip then
				local step = math.max(dt, 1 / 240)
				fastest = math.max(
					fastest,
					(headAt - lastHead).Magnitude / step,
					(hipAt - lastHip).Magnitude / step
				)
			end
			for _, point in { headAt, hipAt } do
				local fromCentre = point - centre
				furthestAxis = math.max(furthestAxis, math.abs(fromCentre.Z))
				furthestSide =
					math.max(furthestSide, Vector2.new(fromCentre.X, fromCentre.Y).Magnitude)
			end
			local now = Inspect.elapsed(character)
			if now and now > 1.75 and now < 2.45 then
				-- The body leans about its base: the head travels from side to side.
				wiggleLow = math.min(wiggleLow, headAt.Y)
				wiggleHigh = math.max(wiggleHigh, headAt.Y)
				baseFirst = baseFirst or hipAt
				baseDrift = math.max(baseDrift, (hipAt - baseFirst :: Vector3).Magnitude)
			end
		end
		lastHead, lastHip = headAt, hipAt
	end)
	task.wait(7)
	tracing = "inspect"
	lastHead, lastHip = nil, nil
	character:SetAttribute("SlugInspectAt", workspace:GetServerTimeNow())
	task.wait(Inspect.Duration + 1.5)
	trace:Disconnect()
	print(
		string.format(
			"LOADOUTCHECK info idle head %.4f studs, idle turn %.1f deg; wiggle %.4f studs, base %.4f; fastest %.2f studs/s; reach axis %.3f/%.3f side %.3f/%.3f",
			idleHead,
			idleTurn,
			wiggleHigh - wiggleLow,
			baseDrift,
			fastest,
			furthestAxis,
			half.Z,
			furthestSide,
			math.min(half.X, half.Y)
		)
	)
	assert(idleHead > 0.01 and idleTurn > 4, "idle in the chamber still looks frozen")
	assert(wiggleHigh - wiggleLow > 0.03, "the wiggle is too small to read")
	assert(baseDrift < 0.003, "the base must stay stuck to the chamber floor")
	assert(fastest < 5, "the slug pops")
	assert(
		furthestAxis < half.Z and furthestSide < math.min(half.X, half.Y),
		"slug left the chamber"
	)
	assert(Inspect.flourish(0.46).Position.Magnitude > 0.5, "toss has no visible separation")
	assert(Inspect.flourish(Inspect.Catch).Position.Magnitude < 1e-5, "catch misses hand")
	assert(Inspect.flourish(Inspect.Release).Position.Magnitude < 1e-5, "release leaves hand")
	assert(
		Inspect.reveal(Inspect.Catch) == 0 and Inspect.reveal(1.5) == 1,
		"tilt must follow catch"
	)
	assert(headTravel > 0.01, "imported head did not visibly move")
	assert(Inspect.looking(1.2) == 1 and Inspect.looking(Inspect.Home) == 0, "look timing")
	assert(Inspect.hop(3.05) > 0.5 and Inspect.hop(Inspect.Lower) == 0, "hop timing")
	assert(math.abs(Inspect.snug(3.45)) > 0.05, "no settling wiggle while lowering")
	assert(Inspect.Catch - Inspect.Release < 0.35, "flip is not quick")
	assert(Inspect.Duration < 4, "inspect is not short")
	assert((Inspect.wiggle(1.2)) == 0, "wiggle must follow the smile")
	assert((Inspect.wiggle(Inspect.Lower + 0.1)) == 0, "wiggle must settle before the drop")
	assert(math.abs(Inspect.spinAngle(Inspect.Catch) - 2 * math.pi) < 1e-6, "flip incomplete")
	assert(Inspect.spinAngle(Inspect.Lower) == Inspect.spinAngle(1.5), "lower must not flip")
	assert(Inspect.flourish(Inspect.Lower + 0.2).Position.Magnitude < 1e-5, "lower must not toss")
	-- The upright part must visibly move, yet stay in place for the slug.
	local still = Inspect.gunRotation(Inspect.Lower + 0.2)
	local heldAt = Inspect.viewGun(1.3).Position
	local turned, drifted = 0, 0
	for i = 130, math.floor(Inspect.Lower * 100) do
		local sample = i / 100
		local _, angle = (still:Inverse() * Inspect.gunRotation(sample)):ToAxisAngle()
		turned = math.max(turned, math.deg(math.abs(angle)))
		drifted = math.max(drifted, (Inspect.viewGun(sample).Position - heldAt).Magnitude)
	end
	assert(turned > 3, "held gun looks frozen")
	assert(turned < 12 and drifted < 0.12, "held gun wanders from its place")
	frozen = nil
	character:SetAttribute("SlugInspectAt", nil)
	print(
		string.format(
			"LOADOUTCHECK PASS inspect review; native grip unchanged; head travel %.3f studs; hold turn %.1f deg, drift %.3f studs",
			headTravel,
			turned,
			drifted
		)
	)
end)
if not ok then
	warn("LOADOUTCHECK FAIL " .. tostring(problem))
end
