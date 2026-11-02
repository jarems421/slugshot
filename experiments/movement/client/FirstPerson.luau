--!strict
-- First person by scrolling (owner, 2026-10-31: Rivals-style, not a setting). Scrolling
-- in past the closest third-person distance snaps into first person; scrolling out
-- snaps back. The zoom limits pin the camera in each mode, so the in-between distances
-- (inside the character) are never used.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage:WaitForChild("MovementExperiment"):WaitForChild("Config"))
local Keybinds = require(script.Parent.Keybinds)

local FirstPerson = {}
local FIRST = 0.5 -- Roblox's first-person zoom distance
local THIRD_MIN, THIRD_MAX = Config.Camera.MinZoom, Config.Camera.MaxZoom

local player = Players.LocalPlayer
local wanted = false
local started = false
local landing = 0

-- Current landing dip (studs), written by the camera and read by the hands.
function FirstPerson.setLanding(value: number)
	landing = value
end

function FirstPerson.landing(): number
	return landing
end

local function zoom(): number
	local camera = workspace.CurrentCamera
	return if camera then (camera.CFrame.Position - camera.Focus.Position).Magnitude else math.huge
end

local function enter()
	wanted = true
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMinZoomDistance = FIRST
	player.CameraMaxZoomDistance = FIRST
end

-- A wheel bound to an action must not also zoom, so third person holds its distance.
local function thirdPersonLimits()
	local closest, furthest = THIRD_MIN, THIRD_MAX
	if Keybinds.wheelTaken() then
		closest = math.clamp(zoom(), THIRD_MIN, THIRD_MAX)
		furthest = closest
	end
	player.CameraMaxZoomDistance = furthest
	player.CameraMinZoomDistance = closest
end

local function exit()
	wanted = false
	player.CameraMode = Enum.CameraMode.Classic
	thirdPersonLimits()
end

-- Share the same mode switch between scroll input and programmatic callers.
function FirstPerson.setActive(enabled: boolean)
	if enabled then
		enter()
	else
		exit()
	end
end

-- Mode is a deliberate input choice. A temporary zoom/collision excursion during
-- a wall kick must not destroy the first-person visual rig for a few frames.
function FirstPerson.active(): boolean
	return wanted
end

function FirstPerson.start()
	if started then
		return
	end
	started = true
	UserInputService.InputChanged:Connect(function(input, processed)
		if
			processed
			or input.UserInputType ~= Enum.UserInputType.MouseWheel
			or Keybinds.wheelTaken()
		then
			return
		end
		if not wanted and input.Position.Z > 0 and zoom() <= THIRD_MIN + 1 then
			FirstPerson.setActive(true)
		elseif wanted and input.Position.Z < 0 then
			FirstPerson.setActive(false)
		end
	end)
	Keybinds.on("firstPerson", function(pressed)
		if pressed then
			FirstPerson.setActive(not wanted)
		end
	end)
	Keybinds.onChanged(function()
		if not wanted then
			thirdPersonLimits()
		end
	end)
	-- A new character starts in third person (the movement client sets its limits).
	player.CharacterAdded:Connect(function()
		wanted = false
		player.CameraMode = Enum.CameraMode.Classic
	end)
end

return FirstPerson
