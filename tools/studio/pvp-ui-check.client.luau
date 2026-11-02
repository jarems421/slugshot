--!strict
-- Check place only (tools/build_pvp_ui_check.py): walks the health bar and settings menu and logs a line at each
-- moment worth capturing, for tools/studio/pvp_ui_check.ps1. Never part of a normal build.
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local probe = player:WaitForChild("PlayerScripts"):WaitForChild("MovementExperimentProbe") :: BindableFunction

local function shot(name: string, hold: number)
	print(`UICHECK shot {name}`)
	task.wait(hold)
end

player:WaitForChild("PlayerGui"):WaitForChild("Settings")
task.wait(6)
shot("hud-full", 2)
for hit = 1, 3 do
	probe:Invoke("Hurt")
	task.wait(0.12)
	shot(`hud-hit{hit}`, 2.5)
end
-- A real key press, sent by the capture script.
print("UICHECK key E")
task.wait(1.5)
print(`UICHECK key result {player:GetAttribute("PvpMenu") or "nothing opened"}`)
if player:GetAttribute("PvpMenu") ~= "Inventory" then
	player:SetAttribute("PvpMenu", "Inventory")
	player:SetAttribute("CombatSettingsOpen", true)
	task.wait(1)
end
shot("inventory", 2.5)
player:SetAttribute("PvpMenu", "Settings")
player:SetAttribute("CombatSettingsOpen", true)
task.wait(1.2)
shot("controls", 2.5)
player:SetAttribute("SettingsTestPage", "Gameplay")
task.wait(1.2)
shot("gameplay", 1)
player:SetAttribute("FieldOfView", 105)
task.wait(0.15)
shot("gameplay-swash", 2.5)
player:SetAttribute("FieldOfView", 65)
task.wait(0.03)
shot("gameplay-left", 2.5)
player:SetAttribute("SettingsTestPage", "Crosshair")
task.wait(1.2)
shot("crosshair", 2.5)
print("UICHECK done")
