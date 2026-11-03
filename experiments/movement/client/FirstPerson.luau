--!strict
-- V toggles first person. The wheel belongs to slug selection.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("MovementExperiment"):WaitForChild("Config"))
local Keybinds = require(script.Parent.Keybinds)

local FirstPerson = {}
local FIRST = 0.5 -- Roblox's first-person zoom distance
local THIRD_MIN = Config.Camera.MinZoom

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

local function enter()
	wanted = true
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMinZoomDistance = FIRST
	player.CameraMaxZoomDistance = FIRST
end

-- Pin the distance in third person even if the wheel is rebound or cleared.
local function thirdPersonLimits()
	local distance = THIRD_MIN
	player.CameraMaxZoomDistance = math.max(distance, player.CameraMinZoomDistance)
	player.CameraMinZoomDistance = distance
	player.CameraMaxZoomDistance = distance
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
	Keybinds.on("firstPerson", function(pressed)
		local AimCursor = (require :: any)(script.Parent.AimCursor)
		if pressed and not AimCursor.menuOpen() then
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
		task.defer(function()
			FirstPerson.setActive(false)
		end)
	end)
	FirstPerson.setActive(false)
end

return FirstPerson
