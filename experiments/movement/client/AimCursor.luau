--!strict
-- One viewport-space point for the visible reticle and the actual firing ray.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local FirstPerson = require(script.Parent.FirstPerson)
local player = Players.LocalPlayer
local AimCursor = {}
local shiftLocked = false

function AimCursor.setShiftLocked(locked: boolean)
	shiftLocked = locked
end

function AimCursor.centered(): boolean
	return FirstPerson.active()
		or shiftLocked
		or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
end

function AimCursor.menuOpen(): boolean
	return player:GetAttribute("CombatSettingsOpen") == true
		or GuiService.MenuIsOpen
		or UserInputService:GetFocusedTextBox() ~= nil
end

function AimCursor.point(camera: Camera): Vector2
	-- GetMouseLocation and ViewportPointToRay use viewport coordinates; the
	-- reticle's separate IgnoreGuiInset HUD must use that same origin.
	return if AimCursor.centered()
		then camera.ViewportSize / 2
		else UserInputService:GetMouseLocation()
end

return AimCursor
