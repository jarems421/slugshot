--!strict
-- Wire/store values are only numbers, booleans, strings and dense tables. No runtime flags.
local movement = game:GetService("ReplicatedStorage"):WaitForChild("MovementExperiment")
local Config = require(movement.Config)
local Groups = require(movement.KeybindDefinitions)
local Schema = {}
Schema.Version = 1
Schema.Defaults = {
	FieldOfView = Config.Camera.Fov,
	LookSensitivity = 50,
	AimSensitivity = 50,
	RecoilAnimation = "Kick",
	HolsterMode = "Hip",
	HealthNumber = "Always",
	SprintMode = "Toggle",
	SprintDoubleTap = true,
	CrosshairStyle = "Classic",
	CrosshairColor = "EBF4F2",
	CrosshairSize = 1,
	FlipCamera = Config.Camera.FirstPerson.FlipCameraDefault,
} :: { [string]: any }
local ranges = {
	FieldOfView = { 60, 110 },
	LookSensitivity = { 1, 100 },
	AimSensitivity = { 1, 100 },
	CrosshairSize = { 0.75, 1.4 },
	FlipCamera = { 1, 3 },
}
local choices = {
	RecoilAnimation = { "Kick", "Flip" },
	HolsterMode = { "Hip", "Vanish" },
	HealthNumber = { "Always", "On change", "Off" },
	SprintMode = { "Toggle", "Always", "Hold" },
	CrosshairStyle = { "Classic", "Dot", "Micro", "Twin", "Triad", "Open", "Ring" },
}
local inputs: { [string]: boolean } = {
	MouseButton1 = true,
	MouseButton2 = true,
	MouseButton3 = true,
	WheelUp = true,
	WheelDown = true,
}
for _, key in Enum.KeyCode:GetEnumItems() do
	if key.Value > 0 and key.Value < 1000 and key.Name ~= "Escape" and key.Name ~= "Backspace" then
		inputs[key.Name] = true
	end
end

function Schema.valid(name: string, value: any): boolean
	local range = (ranges :: any)[name]
	if range then
		return typeof(value) == "number"
			and value == value
			and value >= range[1]
			and value <= range[2]
			and (name ~= "FlipCamera" or value % 1 == 0)
	end
	local options = (choices :: any)[name]
	if options then
		return table.find(options, value) ~= nil
	end
	if name == "CrosshairColor" then
		return typeof(value) == "string" and #value == 6 and value:match("^%x+$") ~= nil
	end
	return name == "SprintDoubleTap" and typeof(value) == "boolean"
end

function Schema.normalize(raw: any): any
	local source = if typeof(raw) == "table" then raw else {}
	-- Unversioned preferences are the legacy layout. Future layouts must never be overwritten.
	local attributes = if typeof(source.attributes) == "table" then source.attributes else source
	local result: any = { version = Schema.Version, attributes = {}, bindings = {} }
	for name, default in Schema.Defaults do
		local value = attributes[name]
		result.attributes[name] = if Schema.valid(name, value) then value else default
	end
	local saved = if typeof(source.bindings) == "table" then source.bindings else {}
	local used: { [string]: boolean } = {}
	for _, group in Groups do
		for _, row in group.rows do
			local pair = if typeof(saved[row.id]) == "table" then saved[row.id] else {}
			local clean: { any } = {}
			for slot = 1, 2 do
				local value = pair[slot]
				if value ~= false and not (typeof(value) == "string" and inputs[value]) then
					value = if slot == 1 then row.main else row.second
				end
				if typeof(value) == "string" and not used[value] then
					clean[slot], used[value] = value, true
				else
					clean[slot] = false
				end
			end
			result.bindings[row.id] = clean
		end
	end
	return result
end

function Schema.future(raw: any): boolean
	return typeof(raw) == "table"
		and typeof(raw.version) == "number"
		and raw.version > Schema.Version
end

return Schema
