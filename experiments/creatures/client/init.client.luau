--!strict
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local Visual = require(script.Visual)

local folder = Instance.new("Folder")
folder.Name = "SlugPreviewOnly"
folder.Parent = workspace
local glow = Instance.new("Highlight")
glow.FillTransparency = 0.8
glow.OutlineTransparency = 1
glow.Parent = folder
local options: Visual.Options = {
	parent = folder,
	onEffect = function(_effect, sample, _pose)
		glow.Enabled = sample.energy > 0.05
		glow.FillColor = Color3.new(1, 0.65, 0.2)
		glow.Adornee = folder:FindFirstChildWhichIsA("Model")
	end,
}
local visual = Visual.new("placeholder", options)
local camera = workspace.CurrentCamera
if camera then
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(Vector3.new(12, 9, 17), Vector3.new(0, 3, 0))
end

local gui = Instance.new("ScreenGui")
gui.Name = "SlugPreviewHUD"
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
local label = Instance.new("TextLabel")
label.Size = UDim2.new(1, 0, 0, 90)
label.BackgroundTransparency = 0.3
label.BackgroundColor3 = Color3.fromRGB(20, 23, 30)
label.TextColor3 = Color3.new(1, 1, 1)
label.TextSize = 18
label.Parent = gui

local elapsed, duration = 0, 0.8
local mode = "idle"
local inputConnection = UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.One or input.KeyCode == Enum.KeyCode.Two then
		visual:destroy()
		visual = Visual.new("placeholder", options)
		elapsed, duration, mode =
			0, if input.KeyCode == Enum.KeyCode.One then 0.06 else 0.8, "flight"
	elseif input.KeyCode == Enum.KeyCode.I then
		elapsed, mode = duration, "impact"
	elseif input.KeyCode == Enum.KeyCode.A and mode ~= "idle" then
		visual:playAttack()
	elseif input.KeyCode == Enum.KeyCode.R then
		visual:destroy()
		visual = Visual.new("placeholder", options)
		glow.Enabled = false
		elapsed, mode = 0, "idle"
	end
end)

local connection = RunService.PreSimulation:Connect(function(dt)
	elapsed += dt
	local stage = "idle (native Motor6D proxy; no imported FBX)"
	if mode == "idle" then
		visual:idle(CFrame.new(0, 2, 0), elapsed)
	else
		stage = visual:update(CFrame.new(0, 2, 0), elapsed, duration, mode == "impact").stage
	end
	label.Text = "CREATURE PIPELINE — TECHNICAL PLACEHOLDERS\n1 close shot (0.06 s) · 2 long shot (0.8 s) · I impact · A attack visual · R reset\n"
		.. stage
end)
script.Destroying:Connect(function()
	connection:Disconnect()
	inputConnection:Disconnect()
	visual:destroy()
	folder:Destroy()
	gui:Destroy()
end)
