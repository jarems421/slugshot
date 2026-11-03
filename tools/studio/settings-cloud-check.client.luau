--!strict
-- Real-cloud acceptance only. Use an owner-approved PRIVATE test experience.
-- Studio writes the separate Studio store, never live player preferences.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Schema = require(ReplicatedStorage:WaitForChild("Combat"):WaitForChild("SettingsSchema"))
local keys = require(script.Parent:WaitForChild("MovementSandbox"):WaitForChild("Keybinds"))
local Sync = require(script.Parent:WaitForChild("SettingsSync"))
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
local expected = Schema.normalize(nil)
expected.attributes = {
	FieldOfView = 91,
	LookSensitivity = 37,
	AimSensitivity = 63,
	RecoilAnimation = "Flip",
	HolsterMode = "Vanish",
	HealthNumber = "On change",
	SprintMode = "Hold",
	SprintDoubleTap = false,
	CrosshairStyle = "Ring",
	CrosshairColor = "18A4C7",
	CrosshairSize = 1.25,
	FlipCamera = 3,
}
expected.bindings.inventory = { "F13", "MouseButton3" } :: { any }
expected.bindings.shiftLock = { false, "RightControl" } :: { any }
local matches = true
for name, value in expected.attributes do
	local wanted = if name == "CrosshairColor" then Color3.fromHex(value) else value
	if player:GetAttribute(name) ~= wanted then
		matches = false
	end
end
for name, pair in expected.bindings do
	for slot = 1, 2 do
		if (keys.get(name, slot) or false) ~= pair[slot] then
			matches = false
		end
	end
end
if matches then
	message(
		"PASS: all 12 preferences and both keybind slots loaded from Roblox storage after leaving and rejoining."
	)
else
	for name, value in expected.attributes do
		player:SetAttribute(name, if name == "CrosshairColor" then Color3.fromHex(value) else value)
	end
	keys.apply(expected.bindings)
	deadline = os.clock() + 60
	repeat
		task.wait(0.1)
		assert(os.clock() < deadline, "cloud save timed out")
	until player:GetAttribute("SettingsSaveStatus") == "Saved"
	message(
		"SAVE CONFIRMED: all 12 preferences and both keybind slots. Stop Play normally, then Play again to verify real persistence."
	)
end
