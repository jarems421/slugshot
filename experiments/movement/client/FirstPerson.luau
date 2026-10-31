--!strict
-- First person by scrolling (owner, 2026-10-31: Rivals-style, not a setting). Scrolling
-- in past the closest third-person distance snaps into first person; scrolling out
-- snaps back. The zoom limits pin the camera in each mode, so the in-between distances
-- (inside the character) are never used.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage:WaitForChild("MovementExperiment"):WaitForChild("Config"))

local FirstPerson = {}
local FIRST = 0.5 -- Roblox's first-person zoom distance
local THIRD_MIN, THIRD_MAX = Config.Camera.MinZoom, Config.Camera.MaxZoom

local player = Players.LocalPlayer
local wanted = false
local started = false

local function zoom(): number
	local camera = workspace.CurrentCamera
	return if camera then (camera.CFrame.Position - camera.Focus.Position).Magnitude else math.huge
end

local function enter()
	wanted = true
	player.CameraMinZoomDistance = FIRST
	player.CameraMaxZoomDistance = FIRST
end

local function exit()
	wanted = false
	player.CameraMaxZoomDistance = THIRD_MAX
	player.CameraMinZoomDistance = THIRD_MIN
end

-- True once the camera has actually arrived in the head, not merely been asked to.
function FirstPerson.active(): boolean
	return wanted and zoom() < 1.5
end

function FirstPerson.start()
	if started then
		return
	end
	started = true
	UserInputService.InputChanged:Connect(function(input, processed)
		if processed or input.UserInputType ~= Enum.UserInputType.MouseWheel then
			return
		end
		if not wanted and input.Position.Z > 0 and zoom() <= THIRD_MIN + 1 then
			enter()
		elseif wanted and input.Position.Z < 0 then
			exit()
		end
	end)
	-- A new character starts in third person (the movement client sets its limits).
	player.CharacterAdded:Connect(function()
		wanted = false
	end)
end

return FirstPerson
