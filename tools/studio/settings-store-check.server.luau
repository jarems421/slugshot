--!strict
-- Test-only; uses the real schema and Store with a JSON-roundtripping fault-injecting backing store.
local Http = game:GetService("HttpService")
local function expect(condition: any, message: string?)
	assert(condition, message or "settings regression failed")
end

local Schema = require(game:GetService("ReplicatedStorage").Combat.SettingsSchema)
local Store =
	require(game:GetService("ServerScriptService").SettingsPersistence.ProductionSettingsStore)
local function clone(value: any): any
	return if value == nil then nil else Http:JSONDecode(Http:JSONEncode(value))
end
local values: any = {}
local failing = false
local backing = {}
function backing:UpdateAsync(key: string, transform: (any) -> any): any
	expect(not failing, "Injected storage failure")
	local value = transform(clone(values[key]))
	if value ~= nil then
		values[key] = clone(value)
	end
	return clone(value)
end
local function check()
	local normal = Schema.normalize(nil)
	if game.GameId == 0 then
		local unavailable, status = Store.connect()
		expect(
			unavailable == nil and status == "StudioUnavailable",
			"unpublished preview attempted a cloud load"
		)
	end
	expect(normal.attributes.LookSensitivity == 50)
	expect(normal.bindings.shiftLock[2] == "RightControl")
	local invalidInputs: { any } =
		{ false, 7, "broken", { attributes = "broken", bindings = false } }
	for _, invalid in invalidInputs do
		expect(Schema.normalize(invalid).attributes.FieldOfView == Schema.Defaults.FieldOfView)
	end
	local bad = Schema.normalize({
		attributes = {
			LookSensitivity = 0 / 0,
			AimSensitivity = math.huge,
			FieldOfView = 999,
			CrosshairColor = "#bad",
			SprintMode = "Cheat",
			SprintDoubleTap = "false",
			FlipCamera = 2.5,
		},
		bindings = { forward = { "NotAKey", "ButtonA" }, left = { "W", "W" } },
	})
	expect(bad.attributes.LookSensitivity == 50 and bad.attributes.AimSensitivity == 50)
	expect(bad.attributes.FlipCamera == 2 and bad.attributes.SprintDoubleTap == true)
	expect(
		bad.bindings.forward[1] == "W"
			and bad.bindings.left[1] == false
			and bad.bindings.left[2] == false
	)
	-- UpdateAsync may invoke a transform more than once on a conflicting lease.
	local competing: any = {
		lease = { token = "other", expires = os.time() + 60 },
		attributes = { LookSensitivity = 14 },
	}
	local contested = Store.new({
		UpdateAsync = function(_self: any, _key: string, transform: (any) -> any): any
			transform(nil) -- first proposal loses a concurrent update
			transform(competing) -- final retry must report Busy, not the earlier Loaded
			return competing
		end,
	})
	local stolen, locked = contested:open(909)
	expect(stolen == nil and locked == "Busy", "conflicting retry admitted a foreign lease")
	local independent = Store.new(backing):open(910)
	expect(
		independent and independent.data.attributes.LookSensitivity == 50,
		"another account inherited someone else's settings"
	)
	expect(Store.new(backing):save(independent, independent.data, true))
	local old =
		Schema.normalize({ LookSensitivity = 29, CrosshairStyle = "Dot", removed = "ignored" })
	expect(old.attributes.LookSensitivity == 29 and old.attributes.CrosshairStyle == "Dot")
	expect(old.attributes.removed == nil)
	print("SETTINGSCHECK PASS missing/old/invalid/duplicate data")
	local store = Store.new(backing)
	local session = store:open(101)
	expect(session)
	local data = Schema.normalize(nil)
	data.attributes = {
		FieldOfView = 91,
		LookSensitivity = 27,
		AimSensitivity = 73,
		RecoilAnimation = "Flip",
		HolsterMode = "Vanish",
		HealthNumber = "On change",
		SprintMode = "Hold",
		SprintDoubleTap = false,
		CrosshairStyle = "Ring",
		CrosshairColor = "13a7d9",
		CrosshairSize = 1.25,
		FlipCamera = 3,
	}
	data.bindings.forward = { "J", "Up" }
	data.bindings.shiftLock = { false, "RightControl" } :: { any }
	data.bindings.nextSlug = { "WheelUp", false } :: { any }
	data.bindings.previousSlug = { false, false } :: { any }
	data.bindings.inventory = { "F13", "MouseButton3" }
	data.bindings.settings = { false, false }
	expect(store:save(session, data, true))
	local rejoined = Store.new(backing):open(101)
	for name, value in data.attributes do
		expect(rejoined.data.attributes[name] == value, name)
	end
	for action, pair in data.bindings do
		expect(
			rejoined.data.bindings[action][1] == pair[1]
				and rejoined.data.bindings[action][2] == pair[2],
			action
		)
	end
	expect(not store:save(session, normal, true), "Stale session must not overwrite a rejoin")
	local blocked, reason = store:open(101)
	expect(blocked == nil and reason == "Busy")
	expect(store:save(rejoined, normal, true))
	local reset = store:open(101)
	expect(reset.data.attributes.LookSensitivity == 50 and reset.data.bindings.settings[1] == "M")
	expect(store:save(reset, reset.data, true))
	print("SETTINGSCHECK PASS all 12 preferences/both key slots/clear/reset/session fence")
	values["user:202"] = { version = 99, attributes = { LookSensitivity = 9 } }
	local before = Http:JSONEncode(values["user:202"])
	local future, status = store:open(202)
	expect(
		future == nil and status == "NewerVersion" and Http:JSONEncode(values["user:202"]) == before
	)
	failing = true
	expect(not pcall(function()
		store:open(303)
	end))
	failing = false
	local retry = store:open(303)
	failing = true
	expect(not pcall(function()
		store:save(retry, data, true)
	end))
	failing = false
	expect(store:save(retry, data, true))
	expect(store:open(303).data.attributes.LookSensitivity == 27)
	values["user:404"] = {
		lease = { token = "dead", expires = os.time() - 1 },
		attributes = { LookSensitivity = 18 },
	}
	expect(store:open(404).data.attributes.LookSensitivity == 18)
	values["user:405"] =
		{ lease = { token = "corrupt", expires = 1e12 }, attributes = { LookSensitivity = 19 } }
	expect(store:open(405).data.attributes.LookSensitivity == 19, "corrupt lease blocked loading")
	print(
		"SETTINGSCHECK PASS future-version protection/failure retry/expired lease/account isolation/conflicting UpdateAsync retry"
	)
	print("SETTINGSCHECK store done (injected storage; not Roblox cloud persistence)")
end
local ok, message = pcall(function()
	check()
	return "complete"
end)
if not ok then
	warn("SETTINGSCHECK FAIL " .. tostring(message))
end
