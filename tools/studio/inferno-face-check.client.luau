--!strict
-- Review only: holds a close camera on each form and steps through its expressions, labelling each on screen so
-- captures can be read. Built by inferno.check.project.json, never by the normal display place.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local HOLD = 2.5
local POSES: { any } = {
	{
		form = "Floppy",
		name = "size match",
		mood = 0,
		blink = 0,
		yaw = 0,
		floor = false,
		view = "lineup",
	},
	{
		form = "InfernoDragon",
		name = "tail fire",
		mood = 0,
		blink = 0,
		yaw = 0,
		floor = false,
		view = "tail",
		live = true,
	},
	{
		form = "InfernoDragon",
		name = "dragon belly",
		mood = 0,
		blink = 0,
		yaw = 0,
		floor = false,
		view = "belly",
	},
	{ form = "Inferno", name = "grin", mood = 0, blink = 0, yaw = 0, floor = false },
	{ form = "Inferno", name = "midway", mood = 0.5, blink = 0, yaw = 0, floor = false },
	{ form = "Inferno", name = "angry", mood = 1, blink = 0, yaw = 0, floor = false },
	{ form = "Inferno", name = "angry side", mood = 1, blink = 0, yaw = 0.8, floor = false },
	{ form = "InfernoDragon", name = "dragon grin", mood = 0, blink = 0, yaw = 0.3, floor = false },
	{
		form = "InfernoDragon",
		name = "dragon midway",
		mood = 0.5,
		blink = 0,
		yaw = 0.3,
		floor = false,
	},
	{
		form = "InfernoDragon",
		name = "dragon angry",
		mood = 1,
		blink = 0,
		yaw = 0.3,
		floor = false,
	},
}

local gui = Instance.new("ScreenGui")
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
local label = Instance.new("TextLabel")
label.Size = UDim2.fromOffset(420, 44)
label.Position = UDim2.fromOffset(20, 90)
label.TextSize = 30
label.BackgroundColor3 = Color3.new(0, 0, 0)
label.TextColor3 = Color3.new(1, 1, 1)
label.Parent = gui
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local start = os.clock()
RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	local index = math.floor((os.clock() - start) / HOLD) % #POSES + 1
	local pose = POSES[index]
	label.Text = `{index}. {pose.name}`
	for _, name in { "Inferno", "InfernoDragon" } do
		local model = workspace:FindFirstChild(name)
		if model then
			model:SetAttribute("ReviewMood", pose.mood)
			model:SetAttribute("ReviewHold", pose.live ~= true)
		end
	end
	local floppy = workspace:FindFirstChild("Floppy")
	if floppy then
		floppy:SetAttribute("FaceBlink", pose.blink)
		floppy:SetAttribute("FaceExpression", 1)
	end
	local model = workspace:FindFirstChild(pose.form)
	if model and model:IsA("Model") and camera then
		local head = model:FindFirstChild("head", true)
		local eye = model:FindFirstChild("eye_L", true)
		local x = if pose.form == "Inferno" then 0 elseif pose.form == "Floppy" then -20 else 28
		local target = if pose.floor
			then Vector3.new(x, 1.2, 0)
			elseif eye and eye:IsA("Bone") then Vector3.new(
				x,
				eye.WorldPosition.Y - 0.3,
				eye.WorldPosition.Z
			)
			elseif head and head:IsA("Bone") then head.WorldPosition + Vector3.new(
				0,
				if pose.form == "Inferno" then 3.3 else 0.5,
				0
			)
			else model:GetPivot().Position
		-- The models face -Z.
		local offset = Vector3.new(math.sin(pose.yaw), 0.06, -math.cos(pose.yaw))
			* (if pose.form == "Floppy" then 3.6 else 10.5)
		camera.CameraType = Enum.CameraType.Scriptable
		local view = (pose :: any).view
		local tail = model:FindFirstChild("tail_3", true)
		if view == "lineup" then
			camera.CFrame = CFrame.lookAt(Vector3.new(-10, 6, -24), Vector3.new(-10, 5, 0))
		elseif view == "belly" then
			camera.CFrame = CFrame.lookAt(Vector3.new(28, 0.6, -9), Vector3.new(28, 7, 2))
		elseif view == "tail" and tail and tail:IsA("Bone") then
			-- From the side and a little behind: the tail runs along +Z, the fire streams on past it.
			local tip = tail.WorldPosition + Vector3.new(0, 0, 5)
			camera.CFrame = CFrame.lookAt(tip + Vector3.new(-13, 2, 3), tip)
		else
			camera.CFrame = CFrame.lookAt(target + offset, target)
		end
	end
end)
