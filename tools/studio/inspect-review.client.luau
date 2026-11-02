--!strict
-- Frozen-beat visual review. This script is only mapped by --inspect-review.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local P = Players.LocalPlayer
local scripts = P:WaitForChild("PlayerScripts")
local probe = scripts:WaitForChild("CombatExperimentProbe") :: BindableFunction
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
	local palmPivot = rightGrip.C0.Position
	local camera = workspace.CurrentCamera :: Camera
	local frame = root.CFrame
	local source = tool:FindFirstChild("Floppy") :: Model
	local head = source:FindFirstChild("head", true) :: Bone
	local handle = tool:FindFirstChild("Handle") :: BasePart
	local baselineHead = handle.CFrame:ToObjectSpace(head.TransformedWorldCFrame)
	local headTravel = 0
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
		for _, t in { 0.02, 0.45, 0.9, 1.25, 1.8, 2.4, 3.0, 3.7, 4.5, 5.25, 5.78 } do
			frozen = t
			task.wait(0.4)
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
			if view == "fp" and t >= 0.9 and t <= 4.5 then
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
			acknowledged = false
			print(string.format("LOADOUTCHECK shot %s-%04d", view, math.floor(t * 100)))
			waitFor(function()
				return acknowledged
			end, "capture acknowledgement missing")
		end
	end
	assert(headTravel > 0.1, "imported head did not visibly move")
	assert(Inspect.hop(1.325) > 0.7, "hop apex missing")
	frozen = nil
	character:SetAttribute("SlugInspectAt", nil)
	print(
		string.format(
			"LOADOUTCHECK PASS inspect review; native grip unchanged; head travel %.3f studs",
			headTravel
		)
	)
end)
if not ok then
	warn("LOADOUTCHECK FAIL " .. tostring(problem))
end
