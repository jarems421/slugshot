--!strict
-- Real-cloud acceptance only. Use an owner-approved PRIVATE test experience.
-- Studio writes the separate Studio store, never live player preferences.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Schema = require(ReplicatedStorage.Combat.SettingsSchema)
local keys = require(script.Parent.MovementSandbox.Keybinds)
local Sync = require(script.Parent.SettingsSync)
local gui = Instance.new("ScreenGui")
gui.Name = "CloudSettingsReview"
gui.Parent = player:WaitForChild("PlayerGui")
local label = Instance.new("TextLabel")
label.Size = UDim2.fromOffset(650, 170)
label.Position = UDim2.fromScale(0.1, 0.1)
label.TextWrapped = true
label.TextSize = 22
label.Parent = gui
local function message(text: string)
	label.Text = text
	print("SETTINGSCLOUD " .. text)
end
for name, value in Schema.Defaults do
	player:SetAttribute(name, if name == "CrosshairColor" then Color3.fromHex(value) else value)
end
Sync.start(keys)
player:GetAttributeChangedSignal("SettingsSaveStatus"):Connect(function()
	message("Storage: " .. tostring(player:GetAttribute("SettingsSaveStatus")))
end)
local deadline = os.clock() + 60
while player:GetAttribute("SettingsLoaded") ~= true do
	if player:GetAttribute("SettingsSaveStatus") == "StudioUnavailable" then
		message(
			"BLOCKED: publish this PRIVATE test place and enable Studio API access before the real cloud test."
		)
		return
	end
	assert(os.clock() < deadline, "cloud load timed out; inspect storage status")
	task.wait(0.1)
end
if
	player:GetAttribute("LookSensitivity") == 37
	and player:GetAttribute("CrosshairColor") == Color3.fromHex("18A4C7")
	and keys.get("inventory", 1) == "F13"
then
	message("PASS: preferences and keybind loaded from Roblox storage after leaving and rejoining.")
else
	player:SetAttribute("LookSensitivity", 37)
	player:SetAttribute("AimSensitivity", 63)
	player:SetAttribute("CrosshairStyle", "Ring")
	player:SetAttribute("CrosshairColor", Color3.fromHex("18A4C7"))
	keys.set("inventory", 1, "F13")
	deadline = os.clock() + 60
	repeat
		task.wait(0.1)
		assert(os.clock() < deadline, "cloud save timed out")
	until player:GetAttribute("SettingsSaveStatus") == "Saved"
	message(
		"SAVE CONFIRMED: stop Play normally, then Play again in this same PRIVATE experience to verify real persistence."
	)
end
