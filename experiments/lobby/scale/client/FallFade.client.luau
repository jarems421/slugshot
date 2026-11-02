--!strict
-- Fades the view out during the deep part of a fall and back in after the respawn. The block-out only
-- proves the route and the drop; mist and the full plunge come with the Maelstrom design.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local layout = require(ReplicatedStorage:WaitForChild("LobbyScale"):WaitForChild("layout")) :: any
local FADE_IN_SECONDS = 0.6

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "LobbyFallFade"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.Parent = player:WaitForChild("PlayerGui")

local veil = Instance.new("Frame")
veil.Size = UDim2.fromScale(1, 1)
veil.BackgroundColor3 = Color3.fromRGB(190, 235, 235)
veil.BorderSizePixel = 0
veil.BackgroundTransparency = 1
veil.Parent = gui

local opacity = 0
RunService.RenderStepped:Connect(function(dt: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local target = 0
	if root then
		local depth = (layout.fall.fadeStartY - root.Position.Y)
			/ (layout.fall.fadeStartY - layout.fall.respawnY)
		target = math.clamp(depth, 0, 1)
	end
	opacity = if target >= opacity then target else math.max(target, opacity - dt / FADE_IN_SECONDS)
	veil.BackgroundTransparency = 1 - opacity
end)
