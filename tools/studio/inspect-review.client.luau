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
	local hipLeft: Vector3? = nil
	local hipSweep = 0
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
	for _, view in { "fp", "third" } do
		First.setActive(view == "fp")
		cameraFrame = if view == "fp"
			then CFrame.new(frame.Position + Vector3.new(0, 1.5, 0)) * frame.Rotation
			else CFrame.lookAt(
				frame:PointToWorldSpace(Vector3.new(-4, 2.1, -5)),
				frame.Position + Vector3.new(0, 1, -0.5)
			)
		for _, t in
			{
				0.02,
				0.28,
				0.42,
				0.50,
				0.65,
				0.86,
				1.2,
				1.8,
				2.74,
				3.035,
				3.3,
				3.85,
				4.25,
				5.2,
				5.9,
				6.15,
				6.3,
				6.65,
			}
		do
			frozen = t
			task.wait(0.4)
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
			if view == "fp" and t == 3.85 then
				hipLeft = handle.CFrame:PointToObjectSpace(hip.TransformedWorldCFrame.Position)
			elseif view == "fp" and t == 4.25 and hipLeft then
				hipSweep = (
					handle.CFrame:PointToObjectSpace(hip.TransformedWorldCFrame.Position) - hipLeft
				).Magnitude
			end
			if view == "fp" and t >= 1.55 and t <= 5.3 then
				local visual = camera:FindFirstChild("FirstPersonBodyVisual")
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
			local delta = pose:PointToWorldSpace(source:GetAttribute("ChamberCentre") :: Vector3)
				- source:GetAttribute("ChamberCentre") :: Vector3
			assert(Vector2.new(delta.X, delta.Y).Magnitude < 1e-4, "slug slides out sideways")
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
	local height = source:GetAttribute("InspectHopHeight") :: number
	assert(radius < math.min(half.X, half.Y), "turn envelope exceeds chamber radius")
	for i = 0, 680 do
		local offset = height * Inspect.hop(i / 100)
		assert(offset + length <= half.Z, "hop envelope exits chamber")
	end
	assert((Inspect.flourish(0.50).Position).Magnitude > 0.5, "toss has no visible separation")
	assert(Inspect.flourish(0.82).Position.Magnitude < 1e-5, "catch misses hand")
	assert(Inspect.reveal(0.82) == 0 and Inspect.reveal(1.5) == 1, "reveal must follow catch")
	assert(headTravel > 0.005, "imported head did not visibly move")
	assert(hipSweep > 0.002, "imported hips did not sweep independently of the chamber pivot")
	assert(Inspect.hop(3.035) > 0.7, "hop apex missing")
	assert(math.abs(Inspect.spinAngle(0.82) - 2 * math.pi) < 1e-6, "raise spin incomplete")
	assert(math.abs(Inspect.spinAngle(6.65)) < 1e-6, "lower spin incomplete")
	assert(
		math.abs(Inspect.spinAngle(1.8) - Inspect.spinAngle(3.7)) < 1e-6,
		"spin disturbed held reaction"
	)
	frozen = nil
	character:SetAttribute("SlugInspectAt", nil)
	print(
		string.format(
			"LOADOUTCHECK PASS inspect review; native grip unchanged; head travel %.3f studs; hip sweep %.3f studs",
			headTravel,
			hipSweep
		)
	)
end)
if not ok then
	warn("LOADOUTCHECK FAIL " .. tostring(problem))
end
