--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local function untilTrue(test: () -> boolean, duration: number, message: string)
	local started = os.clock()
	while not test() do
		assert(os.clock() - started < duration, message)
		task.wait(0.1)
	end
end
local function run()
	untilTrue(function()
		return workspace:GetAttribute("TrainingReady") == true
			and workspace:GetAttribute("TrainingServerCheck") == true
	end, 100, "arena did not become ready")
	local art = workspace:WaitForChild("TrainingArt")
	game:GetService("ContentProvider"):PreloadAsync({ art })
	task.wait(4)
	local mover = art:WaitForChild("MovingTarget") :: Model
	local remote = ReplicatedStorage:WaitForChild("TrainingTargetSpeed") :: RemoteEvent
	local function speed(n: number)
		remote:FireServer(n)
		untilTrue(function()
			return workspace:GetAttribute("TrainingTargetSpeed") == n
		end, 5, "speed change not acknowledged")
	end
	speed(0)
	task.wait(0.3)
	local before = mover:GetPivot().Position
	task.wait(0.6)
	assert((mover:GetPivot().Position - before).Magnitude < 0.001, "zero speed drift")
	speed(4)
	before = mover:GetPivot().Position
	task.wait(0.6)
	assert((mover:GetPivot().Position - before).Magnitude > 0.05, "slow target stayed still")
	speed(16)
	before = mover:GetPivot().Position
	task.wait(0.25)
	local moved = (mover:GetPivot().Position - before).Magnitude
	assert(moved > 0.05 and moved < 5, "fast target motion out of bounds")
	remote:FireServer(99)
	task.wait(0.3)
	assert(workspace:GetAttribute("TrainingTargetSpeed") == 16, "forged speed was accepted")
	speed(0)
	local gui = player.PlayerGui:WaitForChild("TrainingControls")
	assert(
		gui:FindFirstChild("Stationary", true) and gui:FindFirstChild("Faster", true),
		"dummy controls missing"
	)
	print(
		"[TRAININGCHECK] client PASS: replicated 0/4/16 speed, pause, movement, forged speed rejection and controls"
	)
	local camera = workspace.CurrentCamera :: Camera
	local poses: { { string | Vector3 } } = {
		{ "room", Vector3.new(3, 7, 76), Vector3.new(0, 7, -90) },
		{ "west", Vector3.new(3, 7, 70), Vector3.new(-310, 35, 0) },
		{ "ceiling", Vector3.new(3, 7, 70), Vector3.new(0, 200, 0) },
		{ "edge", Vector3.new(80, 6, 0), Vector3.new(109, -7, 0) },
		{ "runes", Vector3.new(-35, 10, 76), Vector3.new(-52, 4, 53) },
		{ "overview", Vector3.new(160, 150, 220), Vector3.new(0, -15, 0) },
	}
	local character = player.Character or player.CharacterAdded:Wait()
	for _, p in character:GetDescendants() do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = 1
		end
	end
	for _, pose in poses do
		local name, eye, aim = pose[1] :: string, pose[2] :: Vector3, pose[3] :: Vector3
		local frame = CFrame.lookAt(eye, aim)
		RunService:BindToRenderStep("TrainingReview", Enum.RenderPriority.Last.Value, function()
			camera.CameraType, camera.CFrame, camera.FieldOfView =
				Enum.CameraType.Scriptable, frame, 70
		end)
		task.wait(1)
		print(`[TRAININGCHECK] view {name}`)
		task.wait(2)
		RunService:UnbindFromRenderStep("TrainingReview")
	end
	print("[TRAININGCHECK] ALL PASS")
end
local ok, problem = pcall(run :: () -> any)
if not ok then
	warn(`[TRAININGCHECK] FAIL client: {problem}`)
end
