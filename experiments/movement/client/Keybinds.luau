--!strict
-- Every rebindable action (owner, 2026-11-01). Inputs are strings: a KeyCode name, or
-- MouseButton1/2/3, WheelUp, WheelDown. Roblox exposes no mouse side buttons, so players map
-- them to F13-F15 in their mouse's software and those keys are labelled Side 1-3.
-- Keys go through one high-priority action so Roblox's own uses of them (I and O zoom) give way;
-- default movement keys still pass through to Roblox's controls and touch and gamepad keep their
-- own bindings. Bindings last for the session.
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Keybinds = {}

export type Row = { id: string, label: string, main: string?, second: string? }
export type Group = { name: string, rows: { Row } }

Keybinds.Groups = {
	{
		name = "Moving",
		rows = {
			{ id = "forward", label = "Forward", main = "W" },
			{ id = "left", label = "Left", main = "A" },
			{ id = "back", label = "Back", main = "S" },
			{ id = "right", label = "Right", main = "D" },
			{ id = "jump", label = "Jump", main = "Space" },
			{ id = "sprint", label = "Sprint", main = "C" },
			{ id = "slide", label = "Slide", main = "LeftShift" },
			{
				id = "shiftLock",
				label = "Shift lock",
				main = "LeftControl",
				second = "RightControl",
			},
		},
	},
	{
		name = "Shooting",
		rows = {
			{ id = "fire", label = "Fire", main = "MouseButton1" },
			{ id = "aim", label = "Aim", main = "MouseButton2" },
			{ id = "nextSlug", label = "Next slug" },
			{ id = "previousSlug", label = "Previous slug" },
			{ id = "slug1", label = "Slug 1", main = "One" },
			{ id = "slug2", label = "Slug 2", main = "Two" },
			{ id = "slug3", label = "Slug 3", main = "Three" },
			{ id = "slug4", label = "Slug 4", main = "Four" },
		},
	},
	{
		name = "Other",
		rows = {
			{ id = "inventory", label = "Inventory", main = "I" },
			{ id = "settings", label = "Settings", main = "M" },
			{ id = "firstPerson", label = "First person" },
		},
	},
} :: { Group }

local NAMES: { [string]: string } = {
	MouseButton1 = "Left Click",
	MouseButton2 = "Right Click",
	MouseButton3 = "Middle Click",
	WheelUp = "Wheel Up",
	WheelDown = "Wheel Down",
	F13 = "Side 1",
	F14 = "Side 2",
	F15 = "Side 3",
	LeftShift = "Left Shift",
	RightShift = "Right Shift",
	LeftControl = "Left Ctrl",
	RightControl = "Right Ctrl",
	LeftAlt = "Left Alt",
	RightAlt = "Right Alt",
	CapsLock = "Caps Lock",
	One = "1",
	Two = "2",
	Three = "3",
	Four = "4",
	Five = "5",
	Six = "6",
	Seven = "7",
	Eight = "8",
	Nine = "9",
	Zero = "0",
}
local MOUSE: { [Enum.UserInputType]: string } = {
	[Enum.UserInputType.MouseButton1] = "MouseButton1",
	[Enum.UserInputType.MouseButton2] = "MouseButton2",
	[Enum.UserInputType.MouseButton3] = "MouseButton3",
}
-- What Roblox's own controls use, handed back to our handler once a player moves them.
local NATIVE = { "W", "A", "S", "D", "Up", "Down", "Left", "Right", "Space" }
local NATIVE_ACTIONS = { "forward", "left", "back", "right", "jump" }
local ACTION = "SlugshotKeybinds"

local rows: { [string]: Row } = {}
local binds: { [string]: { string? } } = {}
local owner: { [string]: string } = {} -- input to action
local down: { [string]: boolean } = {}
local listeners: { [string]: { (boolean) -> () } } = {}
local changed: { () -> () } = {}
local paused = false
local custom = false

local function isMouse(input: string): boolean
	return string.sub(input, 1, 5) == "Mouse" or string.sub(input, 1, 5) == "Wheel"
end

local function send(input: string, pressed: boolean)
	if (down[input] == true) == pressed then
		return
	end
	down[input] = pressed
	local action = owner[input]
	local list = action and listeners[action]
	if list then
		for _, listener in list do
			task.spawn(listener, pressed)
		end
	end
end

local function releaseAll()
	for input in down do
		send(input, false)
	end
end

local function isNative(name: string): boolean
	return table.find(NATIVE, name) ~= nil
end

local function handle(_: string, state: Enum.UserInputState, input: InputObject)
	local name = input.KeyCode.Name
	if paused then
		return Enum.ContextActionResult.Sink
	end
	if state == Enum.UserInputState.Begin then
		send(name, true)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		send(name, false)
	end
	return if isNative(name) and not custom
		then Enum.ContextActionResult.Pass
		else Enum.ContextActionResult.Sink
end

local function refresh()
	releaseAll()
	owner, custom = {}, false
	for action, pair in binds do
		for slot = 1, 2 do
			local input = pair[slot]
			if input then
				owner[input] = action
			end
		end
	end
	for _, action in NATIVE_ACTIONS do
		local row = rows[action]
		custom = custom or binds[action][1] ~= row.main or binds[action][2] ~= nil
	end
	ContextActionService:UnbindAction(ACTION)
	local keys: { Enum.KeyCode } = {}
	for input in owner do
		if not isMouse(input) then
			table.insert(keys, (Enum.KeyCode :: any)[input])
		end
	end
	if custom then
		for _, name in NATIVE do
			if not owner[name] then
				table.insert(keys, (Enum.KeyCode :: any)[name])
			end
		end
	end
	ContextActionService:BindActionAtPriority(
		ACTION,
		handle,
		false,
		Enum.ContextActionPriority.High.Value,
		table.unpack(keys)
	)
	for _, listener in changed do
		task.spawn(listener)
	end
end

local function defaults()
	for _, group in Keybinds.Groups do
		for _, row in group.rows do
			rows[row.id] = row
			binds[row.id] = { row.main, row.second }
		end
	end
end

-- Calls listener(true) on press and listener(false) on release.
function Keybinds.on(action: string, listener: (boolean) -> ())
	listeners[action] = listeners[action] or {}
	table.insert(listeners[action], listener)
end

function Keybinds.onChanged(listener: () -> ())
	table.insert(changed, listener)
end

function Keybinds.held(action: string): boolean
	local pair = binds[action]
	local first, second = pair[1], pair[2]
	return (first ~= nil and down[first] == true) or (second ~= nil and down[second] == true)
end

function Keybinds.get(action: string, slot: number): string?
	return binds[action][slot]
end

-- A default movement key has moved, so the movement client reads held() instead of Roblox's controls.
function Keybinds.customMovement(): boolean
	return custom
end

-- The scroll wheel belongs to an action rather than the camera.
function Keybinds.wheelTaken(): boolean
	return owner.WheelUp ~= nil or owner.WheelDown ~= nil
end

function Keybinds.label(input: string?): string
	if not input then
		return ""
	end
	return NAMES[input] or input
end

function Keybinds.isMouseLabel(input: string?): boolean
	return input ~= nil
		and (isMouse(input) or NAMES[input] ~= nil and string.sub(NAMES[input], 1, 4) == "Side")
end

-- Binds input to one slot of an action. An input does one thing, so any action already using it
-- loses it; returns that action's label so the player can be told.
function Keybinds.set(action: string, slot: number, input: string?): string?
	local displaced: string? = nil
	if input then
		local holder = owner[input]
		if holder then
			local pair = binds[holder]
			for index = 1, 2 do
				if pair[index] == input and (holder ~= action or index ~= slot) then
					pair[index] = nil
					displaced = rows[holder].label
				end
			end
		end
	end
	binds[action][slot] = input
	refresh()
	return displaced
end

function Keybinds.reset()
	defaults()
	refresh()
end

-- Waits for the next key or mouse button (the wheel counts) and reports its input name.
-- Backspace reports nil, which clears the binding. Returns a function that cancels the wait.
function Keybinds.capture(report: (string?) -> ()): () -> ()
	local connections: { RBXScriptConnection } = {}
	local function stop()
		for _, connection in connections do
			connection:Disconnect()
		end
		paused = false
	end
	paused = true
	releaseAll()
	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input)
			if RunService:IsStudio() then
				-- Evidence for the side button test: shows what Roblox reports for each press.
				print(`[Keybinds] saw {input.UserInputType.Name} {input.KeyCode.Name}`)
			end
			local name = MOUSE[input.UserInputType]
			if input.UserInputType == Enum.UserInputType.Keyboard then
				name = input.KeyCode.Name
			end
			if name == "Backspace" then
				stop()
				report(nil)
			elseif name and name ~= "Escape" then
				stop()
				report(name)
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseWheel then
				stop()
				report(if input.Position.Z > 0 then "WheelUp" else "WheelDown")
			end
		end)
	)
	return stop
end

UserInputService.InputBegan:Connect(function(input, processed)
	local name = MOUSE[input.UserInputType]
	if name and not processed and not paused then
		send(name, true)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	local name = MOUSE[input.UserInputType]
	if name then
		send(name, false)
	end
end)
UserInputService.InputChanged:Connect(function(input, processed)
	if input.UserInputType == Enum.UserInputType.MouseWheel and not processed and not paused then
		local name = if input.Position.Z > 0 then "WheelUp" else "WheelDown"
		send(name, true)
		send(name, false)
	end
end)
UserInputService.WindowFocusReleased:Connect(releaseAll)

defaults()
refresh()

return Keybinds
