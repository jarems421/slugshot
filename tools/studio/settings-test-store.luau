--!strict
-- Only mapped by build_settings_check.py -- never accesses Roblox cloud data.
local Http = game:GetService("HttpService")
local Store = require(script.Parent.ProductionSettingsStore)
local Schema = require(game:GetService("ReplicatedStorage").Combat.SettingsSchema)
local values: any = {}
local leave = Instance.new("RemoteEvent")
leave.Name = "SettingsTestLeave"
leave.Parent = game:GetService("ReplicatedStorage")
leave.OnServerEvent:Connect(function(player: Player)
	player:Kick("Settings persistence test complete")
end)
local backing = {}
function backing:UpdateAsync(key: string, transform: (any) -> any): any
	local previous = values[key]
	if previous == nil then
		previous = Schema.normalize(nil)
		previous.attributes.CrosshairStyle = "Ring"
		previous.attributes.CrosshairColor = "13a7d9"
		previous.attributes.FlipCamera = 3
	end
	local nextValue = transform(Http:JSONDecode(Http:JSONEncode(previous)))
	if nextValue then
		values[key] = Http:JSONDecode(Http:JSONEncode(nextValue))
		if nextValue.lease == nil then
			local defaults = Schema.normalize(nil)
			for name, value in defaults.attributes do
				local actual = nextValue.attributes[name]
				if name == "CrosshairColor" then
					actual, value = string.upper(actual), string.upper(value)
				end
				assert(actual == value, "leave lost reset " .. name)
			end
			assert(nextValue.bindings.inventory[1] == "E", "shutdown lost reset keybind")
			print("SETTINGSCHECK PASS production leave flush/release (injected storage)")
		end
	end
	return nextValue
end
local attempts = 0
return {
	new = Store.new,
	connect = function(): (any, string?)
		attempts += 1
		if attempts == 1 then
			task.wait(1)
			return nil, "StudioUnavailable"
		end
		task.wait(2) -- recover after the production retry, retaining early edits
		return Store.new(backing)
	end,
}
