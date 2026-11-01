--!strict
-- Check build only: after a moment of the real player camera, steps through fixed views so screenshots
-- show every area of the block-out, then hands the camera back.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local layout = require(ReplicatedStorage:WaitForChild("LobbyScale"):WaitForChild("layout")) :: any
local PLAYER_CAMERA_SECONDS = 10
local VIEW_SECONDS = 6
local RUN_OFF_SPEED = 30
local FALL_SECONDS = 8

local function polar(angle: number, radius: number, y: number): Vector3
	local rad = math.rad(angle)
	return Vector3.new(radius * math.sin(rad), y, -radius * math.cos(rad))
end

local views: { { any } } = {
	{ "Top-down, ceiling hidden", Vector3.new(0, 400, 1), Vector3.zero, true },
	{ "From the spawn rock to PvP", Vector3.new(0, 6, 10), polar(0, 150, 14) },
	{ "Middle of the bridge", polar(0, 50, 0), polar(0, 150, 10) },
	{ "Portal arc from the shore", polar(0, 100, 7), polar(0, 157, 16) },
	{ "Back at the spawn rock from PvP", polar(0, 145, 10), Vector3.new(0, 4, 0) },
	{ "Volcano from the ravine side", polar(-30, 150, 18), polar(0, 235, 80) },
	{ "Lava ravine", polar(-42, 190, 22), polar(-42, 245, -20) },
	{ "Gun shop", polar(-90, 120, 12), polar(-90, 190, 8) },
	{ "Slug pond and mountain", polar(90, 95, 12), polar(70, 240, 60) },
	{ "Entrance", polar(180, 190, 12), polar(180, 280, 20) },
	{ "Inside the caverns", polar(205, 293, 20), polar(235, 293, 45) },
	{ "Spiral route above the gun side", polar(290, 293, 72), polar(330, 293, 86) },
	{ "View from the volcano rim", polar(0, 217, 142), Vector3.zero },
	{ "View from the mountain overlook", polar(70, 225, 142), Vector3.zero },
	{ "Up the Sky Well", Vector3.new(0, 6, 34), Vector3.new(0, 250, 0) },
	{ "Down into the Maelstrom", polar(45, 70, 8), Vector3.new(0, -300, 1) },
}

local gui = Instance.new("ScreenGui")
gui.Name = "ScaleCheckTour"
gui.DisplayOrder = 40
gui.ResetOnSpawn = false
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
local caption = Instance.new("TextLabel")
caption.Size = UDim2.new(1, 0, 0, 34)
caption.BackgroundTransparency = 0.3
caption.BackgroundColor3 = Color3.new(0, 0, 0)
caption.TextColor3 = Color3.new(1, 1, 1)
caption.TextSize = 22
caption.Font = Enum.Font.GothamBold
caption.Text = "Player camera at spawn"
caption.Parent = gui

task.wait(PLAYER_CAMERA_SECONDS)
-- Run the real character off the rock between the bridges, at a legal speed, for the real fall and respawn.
local character = Players.LocalPlayer.Character
local body = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
local runOff = RunService.RenderStepped:Connect(function()
	if body and body.Position.Y > -2 then
		local fall = body.AssemblyLinearVelocity.Y
		body.AssemblyLinearVelocity = polar(45, RUN_OFF_SPEED, fall)
	end
end)
task.wait(FALL_SECONDS)
runOff:Disconnect()
local model = workspace:WaitForChild("LobbyScale")
local ceiling = model:WaitForChild("Cavern"):WaitForChild("Ceiling")
local sky = model:WaitForChild("Cavern"):WaitForChild("SkyWell")
local function hideRoof(hidden: boolean)
	for _, holder in { ceiling, sky } do
		for _, part in holder:GetDescendants() do
			if part:IsA("BasePart") then
				part.LocalTransparencyModifier = if hidden then 1 else 0
			end
		end
	end
end

local frame = CFrame.new()
RunService:BindToRenderStep("ScaleCheckTour", Enum.RenderPriority.Last.Value + 10, function()
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = frame
end)
for index, view in views do
	frame = CFrame.lookAt(view[2], view[3])
	hideRoof(view[4] == true)
	workspace.CurrentCamera.FieldOfView = if view[4] == true then 80 else 70
	caption.Text = `{index}/{#views}  {view[1]}`
	task.wait(VIEW_SECONDS)
end
RunService:UnbindFromRenderStep("ScaleCheckTour")
hideRoof(false)
workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
gui:Destroy()
print(`[LobbyScaleCheck] tour done, layout version {layout.version}`)
