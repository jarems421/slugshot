--!strict
local Players = game:GetService("Players")
local function expect(condition: any, message: string?)
	assert(condition, message or "settings regression failed")
end

local Schema = require(game:GetService("ReplicatedStorage"):WaitForChild("Combat").SettingsSchema)
local player = Players.LocalPlayer
local function untilTrue(predicate: () -> boolean)
	local deadline = os.clock() + 25
	repeat
		if predicate() then
			return
		end
		task.wait(0.1)
	until os.clock() > deadline
	error("timed out waiting for settings sync")
end
local function check()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("Settings", 20)
	expect(gui, "Settings UI did not start")
	local keys = (require :: any)(player.PlayerScripts.MovementSandbox.Keybinds)
	expect(player:GetAttribute("SettingsLoaded") ~= true, "test missed the early-edit window")
	player:SetAttribute("LookSensitivity", 27)
	keys.set("inventory", 1, "F13")
	untilTrue(function()
		return player:GetAttribute("SettingsLoaded") == true
	end)
	expect(
		player:GetAttribute("LookSensitivity") == 27 and keys.get("inventory", 1) == "F13",
		"late load overwrote early edits"
	)
	expect(player:GetAttribute("CrosshairStyle") == "Ring")
	expect(player:GetAttribute("CrosshairColor") == Color3.fromHex("13a7d9"))
	local camera = (require :: any)(player.PlayerScripts.MovementSandbox.AcrobaticCamera)
	local _, requested = camera.status()
	expect(requested == 3, "saved flip camera did not apply")
	untilTrue(function()
		return player:GetAttribute("SettingsSaveStatus") == "Saved"
	end)
	print(
		"SETTINGSCHECK PASS real client hydration/early edits/color/flip/keybind/save acknowledgement"
	)
	player:SetAttribute("AimSensitivity", 81)
	player:SetAttribute("HolsterMode", "Vanish")
	player:SetAttribute("SprintDoubleTap", false)
	keys.set("shiftLock", 1, nil)
	keys.set("nextSlug", 2, "WheelUp")
	untilTrue(function()
		return player:GetAttribute("SettingsSaveStatus") == "Saved"
	end)
	expect(keys.get("shiftLock", 1) == nil and keys.get("nextSlug", 2) == "WheelUp")
	-- Same reset operations used by the menu; check the whole restored snapshot reaches the server.
	keys.reset()
	for name, value in Schema.Defaults do
		player:SetAttribute(name, if name == "CrosshairColor" then Color3.fromHex(value) else value)
	end
	untilTrue(function()
		return player:GetAttribute("SettingsSaveStatus") == "Saved"
	end)
	expect(keys.get("inventory", 1) == "E" and keys.get("shiftLock", 1) == "LeftControl")
	expect(gui:FindFirstChild("SaveStatus", true).Text == "Settings saved")
	print("SETTINGSCHECK PASS real remote changes/cleared slots/reset/UI status")
	print("SETTINGSCHECK done (injected storage; not Roblox cloud persistence)")
	game:GetService("ReplicatedStorage"):WaitForChild("SettingsTestLeave"):FireServer()
end
local ok, message = pcall(function()
	check()
	return "complete"
end)
if not ok then
	warn("SETTINGSCHECK FAIL client " .. tostring(message))
end
