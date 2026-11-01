--!strict
-- Applies the look pack locally and blends zone moods by where the player stands. Zones are parts in
-- Workspace.LookZones with a "Mood" attribute; each has full weight inside its radius (half its X size)
-- and fades out over FADE studs beyond. Outside every zone the Hub mood applies.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LookPack = require(ReplicatedStorage:WaitForChild("LookPack"))

local FADE = 18
LookPack.applyBase()
local zones = workspace:WaitForChild("LookZones")

RunService.RenderStepped:Connect(function()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local focus = if root then root.Position else workspace.CurrentCamera.CFrame.Position
	local moods, weights = { LookPack.Moods.Hub }, { 0.35 }
	for _, zone in zones:GetChildren() do
		if not zone:IsA("BasePart") then
			continue
		end
		local mood = LookPack.Moods[zone:GetAttribute("Mood") :: string]
		if not mood then
			continue
		end
		local offset = focus - zone.Position
		local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude - zone.Size.X / 2
		local w = math.clamp(1 - distance / FADE, 0, 1)
		if w > 0 then
			table.insert(moods, mood)
			table.insert(weights, w * w)
		end
	end
	LookPack.applyMood(LookPack.blend(moods, weights))
end)
