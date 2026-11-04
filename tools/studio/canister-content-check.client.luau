--!strict
-- Disposable regression for parts arriving after cached canister visibility.
local player = game:GetService("Players").LocalPlayer
local scripts = player:WaitForChild("PlayerScripts")
local probe = scripts:WaitForChild("CombatExperimentProbe") :: BindableFunction
local function say(s: string)
	print("TRANSCHECK " .. s)
end
local ok, problem = pcall(function()
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local backpack = player:WaitForChild("Backpack")
	local tool = backpack:FindFirstChildOfClass("Tool") or character:FindFirstChildOfClass("Tool")
	local deadline = os.clock() + 30
	while not tool do
		assert(os.clock() < deadline, "gun not ready")
		task.wait(0.05)
		tool = backpack:FindFirstChildOfClass("Tool") or character:FindFirstChildOfClass("Tool")
	end
	humanoid:EquipTool(tool)
	local floppy = tool:WaitForChild("Floppy")
	local inferno = tool:WaitForChild("InfernoLoaded")
	task.wait(1.5)
	for _, pair in { { 1, inferno }, { 2, floppy } } do
		probe:Invoke("Select", pair[1])
		task.wait(0.4)
		local late = Instance.new("Part")
		late.Name = "LateCanisterVisibilityProbe"
		late.Anchored, late.CanCollide = true, false
		late.Position = Vector3.new(0, -1000, 0)
		late.Parent = pair[2]
		task.wait(0.2)
		assert(late.Transparency == 1, "late unselected part bypasses cached visibility")
		late:Destroy()
	end
	probe:Invoke("Select", 1)
	task.wait(0.3)
	assert(
		(inferno:FindFirstChild("InfernoBody", true) :: BasePart).Transparency == 1,
		"unselected Inferno shows over Floppy"
	)
	assert(
		(floppy:FindFirstChild("FloppyBody", true) :: BasePart).Transparency < 1,
		"selected Floppy hidden"
	)
	say("PASS late loaded parts stay hidden, both species switch without overlap")
end)
if not ok then
	say("FAIL " .. tostring(problem))
end
