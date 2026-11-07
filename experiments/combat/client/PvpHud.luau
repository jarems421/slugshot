--!strict
-- The match HUD (owner, 2026-11-07): five separate canisters at the bottom centre, each like the
-- blaster's own (a ribbed cap, teal glass, a threaded base), with the slug standing inside
-- and the goo health bar, a size up, on top of them. CombatClient drives the slots each frame.
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Combat = require(ReplicatedStorage:WaitForChild("Combat"))
local Theme = require(script.Parent.PvpTheme)
local SlugIcon = require(script.Parent.SlugIcon)
local GooBar = require(script.Parent.GooBar)

local player = Players.LocalPlayer
local movement = player:WaitForChild("PlayerScripts"):WaitForChild("MovementSandbox")
local Keybinds = (require :: any)(movement:WaitForChild("Keybinds"))

local Hud = {}

local CAN_W, CAN_GAP = 70, 12
local CAP_W, CAP_H = 70, 20 -- the same size as the base (owner, 2026-11-07)
local GLASS_W, GLASS_H = 54, 72
local BASE_W, BASE_H = 70, 22
local CAN_H = CAP_H + GLASS_H + BASE_H - 2 -- the glass tucks 1 px under each end
local LIFT = 6 -- the selected canister stands this much higher
local GOO_W, GOO_H = 300, 16
local HEALTH_SCALE = 1.3 -- the goo is drawn for 16 px, so the bar grows as a whole
local HEALTH_H = math.ceil((GOO_H + 6) * HEALTH_SCALE)
local ROW_Y = HEALTH_H + 26
local FILL = 0.6 -- the slug's share of the glass's height (owner, 2026-11-07: smaller)
local GLASS_SELECTED, GLASS_IDLE, GLASS_EMPTY = 0, 0.25, 0.4 -- glass transparency
local NUMBER_HOLD = 2 -- seconds the health number shows in "On change" mode
local RETURN_TWEEN = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local LIFT_TWEEN = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local METAL = Color3.fromRGB(36, 41, 50)
local METAL_LIGHT = Color3.fromRGB(84, 95, 110)
local GLASS = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(96, 156, 164)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(34, 62, 70)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(26, 48, 56)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 122, 132)),
})

type Slot = {
	frame: Frame,
	scale: UIScale,
	glass: Frame,
	key: TextLabel,
	filled: boolean,
	shade: Frame?,
	count: TextLabel?,
	flash: Frame?,
	icon: SlugIcon.Icon?,
}

local function metal(parent: Instance, props: { [string]: any }): Frame
	local part = Theme.new("Frame", props)
	part.BackgroundColor3 = METAL
	part.BorderSizePixel = 0
	part.Parent = parent
	Theme.corner(part, 4)
	Theme.edge(part, 2)
	return part
end

local function line(parent: Instance, y: number, inset: number, colour: Color3, alpha: number)
	Theme.new("Frame", {
		Position = UDim2.fromOffset(inset, y),
		Size = UDim2.new(1, -inset * 2, 0, 1),
		BackgroundColor3 = colour,
		BackgroundTransparency = alpha,
		BorderSizePixel = 0,
		Parent = parent,
	})
end

-- One canister: cap, glass and base, with the slug standing in the glass.
local function canister(row: Frame, index: number, slugId: string?): Slot
	local frame = Theme.new("Frame", {
		Name = `Slot{index}`,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromOffset((index - 1) * (CAN_W + CAN_GAP) + CAN_W / 2, CAN_H),
		Size = UDim2.fromOffset(CAN_W, CAN_H),
		BackgroundTransparency = 1,
		Parent = row,
	})
	local scale = Theme.new("UIScale", { Parent = frame })

	local glass = Theme.new("Frame", {
		Name = "Glass",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, CAP_H - 1),
		Size = UDim2.fromOffset(GLASS_W, GLASS_H),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = if slugId then GLASS_IDLE else GLASS_EMPTY,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = frame,
	})
	Theme.corner(glass, 3)
	Theme.edge(glass, 2)
	Theme.new("UIGradient", { Color = GLASS, Parent = glass })
	-- Reflections down the tube.
	for _, streak in { { 6, 4, 0.6 }, { GLASS_W - 9, 2, 0.78 } } do
		local shine = Theme.new("Frame", {
			Position = UDim2.fromOffset(streak[1], 7),
			Size = UDim2.new(0, streak[2], 1, -14),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = streak[3],
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = glass,
		})
		Theme.corner(shine, 2)
	end

	local cap = metal(frame, {
		Name = "Cap",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(CAP_W, CAP_H),
		ZIndex = 3,
	})
	-- The ribbed crown.
	for notch = 1, 5 do
		Theme.new("Frame", {
			Position = UDim2.fromOffset(notch * CAP_W / 6 - 2, 0),
			Size = UDim2.fromOffset(3, 6),
			BackgroundColor3 = Theme.Ink,
			BorderSizePixel = 0,
			Parent = cap,
		})
	end
	line(cap, CAP_H - 8, 3, METAL_LIGHT, 0.45)
	line(cap, CAP_H - 5, 3, METAL_LIGHT, 0.25)

	local base = metal(frame, {
		Name = "Base",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(BASE_W, BASE_H),
		ZIndex = 3,
	})
	-- The thread.
	line(base, 3, 3, METAL_LIGHT, 0.25)
	line(base, 6, 3, METAL_LIGHT, 0.45)
	local key = Theme.label(base, "", Theme.Title, 12, {
		Name = "Key",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.fromOffset(22, 12),
		TextXAlignment = Enum.TextXAlignment.Center,
		BackgroundColor3 = Theme.Accent,
		BackgroundTransparency = 1,
		TextColor3 = if slugId then Theme.Soft else Theme.Muted,
		ZIndex = 2,
	})
	Theme.corner(key, 4)

	local slot: Slot = {
		frame = frame,
		scale = scale,
		glass = glass,
		key = key,
		filled = slugId ~= nil,
	}
	if slugId then
		-- Standing still for now (owner, 2026-11-07); it leaves the glass while it is fired.
		slot.icon = SlugIcon.mount(glass, slugId, FILL, false)
		slot.shade = Theme.new("Frame", {
			Name = "Shade",
			Size = UDim2.fromScale(1, 0),
			BackgroundColor3 = Theme.Ink,
			BackgroundTransparency = 0.24,
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = glass,
		})
		slot.count = Theme.label(glass, "", Theme.TitleBold, 24, {
			Name = "Count",
			Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeColor3 = Theme.Ink,
			TextStrokeTransparency = 0.4,
			ZIndex = 5,
		})
		slot.flash = Theme.new("Frame", {
			Name = "Flash",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Return,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 6,
			Parent = glass,
		})
	end
	return slot
end

function Hud.create(): ScreenGui
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	player:SetAttribute("PvpHud", true)

	local gui = Instance.new("ScreenGui")
	gui.Name = "CombatHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- The health bar on top and the canisters under it. The inventory opens up out of this
	-- (Inventory) and the ability chips sit either side of the canisters (AbilityClient).
	local count = Combat.SlotCount
	local rowWidth = count * CAN_W + (count - 1) * CAN_GAP
	local bar = Theme.new("Frame", {
		Name = "SlugBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(rowWidth, ROW_Y + CAN_H),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Theme.fitHud(gui, Theme.new("UIScale", { Parent = bar }))

	-- Health ---------------------------------------------------------------------------
	local health = Theme.new("Frame", {
		Name = "Health",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(GOO_W + 6, GOO_H + 6),
		BackgroundTransparency = 1,
		ZIndex = 1, -- drips fall behind the canisters
		Parent = bar,
	})
	Theme.new("UIScale", { Scale = HEALTH_SCALE, Parent = health })
	local goo = GooBar.new(health, Vector2.zero, GOO_W, GOO_H)
	local number = Theme.label(health, "100", Theme.TitleBold, 22, {
		Name = "Number",
		Position = UDim2.new(1, 8, 0, -1),
		Size = UDim2.fromOffset(46, 24),
		TextStrokeColor3 = Theme.Ink,
		TextStrokeTransparency = 0.5,
	})
	local sprint = Theme.label(health, "Sprint on", Theme.Body, 13, {
		Name = "Sprint",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromOffset(-8, 2),
		Size = UDim2.fromOffset(80, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Theme.Accent,
		TextStrokeColor3 = Theme.Ink,
		TextStrokeTransparency = 0.5,
		Visible = false,
	})
	local function refreshSprint()
		sprint.Visible = player:GetAttribute("SprintActive") == true
			and player:GetAttribute("SprintMode") ~= "Always"
	end
	player:GetAttributeChangedSignal("SprintActive"):Connect(refreshSprint)
	player:GetAttributeChangedSignal("SprintMode"):Connect(refreshSprint)

	local shownUntil = 0
	local function refreshNumber()
		local mode = player:GetAttribute("HealthNumber")
		number.Visible = mode == nil
			or mode == "Always"
			or (mode == "On change" and os.clock() < shownUntil)
	end
	player:GetAttributeChangedSignal("HealthNumber"):Connect(refreshNumber)
	local connection: RBXScriptConnection? = nil
	local function watch(humanoid: Humanoid)
		if connection then
			connection:Disconnect()
		end
		local last = humanoid.Health
		local function update()
			local share = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
			number.Text = tostring(math.ceil(humanoid.Health))
			goo.set(share)
			if humanoid.Health ~= last then
				last = humanoid.Health
				shownUntil = os.clock() + NUMBER_HOLD
				refreshNumber()
				task.delay(NUMBER_HOLD + 0.05, refreshNumber)
			end
		end
		connection = humanoid.HealthChanged:Connect(update)
		update()
		refreshNumber()
	end
	local function onCharacter(character: Model)
		watch(character:WaitForChild("Humanoid") :: Humanoid)
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end

	-- Canisters ------------------------------------------------------------------------
	local row = Theme.new("Frame", {
		Name = "Canisters",
		Position = UDim2.fromOffset(0, ROW_Y),
		Size = UDim2.fromOffset(rowWidth, CAN_H),
		BackgroundTransparency = 1,
		ZIndex = 2,
		Parent = bar,
	})
	local slots: { Slot } = {}
	for index = 1, count do
		slots[index] = canister(row, index, Combat.Loadout[index])
	end
	local function refreshKeys()
		for index, slot in slots do
			local input = Keybinds.get(`slug{index}`, 1)
			local text = Keybinds.label(input)
			-- A long name ("Left Shift") does not fit the badge.
			slot.key.Text = if #text <= 2 then text else string.sub(text, 1, 1)
		end
	end
	Keybinds.onChanged(refreshKeys)
	refreshKeys()

	-- Every slot retains its own cooldown while another slug is selected.
	local cooling: { [number]: boolean } = {}
	local lifted = 0
	function Hud.step(
		cooldowns: { [number]: number },
		selected: number,
		armed: boolean,
		now: number
	)
		for index, slot in slots do
			local remaining = math.max((cooldowns[index] or 0) - now, 0)
			local shade, label, flash = slot.shade, slot.count, slot.flash
			if shade and label and flash then
				if remaining <= 0 and cooling[index] then
					slot.scale.Scale = 1.1
					flash.BackgroundTransparency = 0.45
					TweenService:Create(slot.scale, RETURN_TWEEN, { Scale = 1 }):Play()
					TweenService:Create(flash, RETURN_TWEEN, { BackgroundTransparency = 1 }):Play()
				end
				cooling[index] = remaining > 0
				if slot.icon then
					slot.icon.frame.Visible = remaining <= 0
				end
				shade.Size = UDim2.fromScale(1, math.clamp(remaining / Combat.Cooldown, 0, 1))
				label.Text = if remaining > 0 then string.format("%.1f", remaining) else ""
			end
			slot.glass.BackgroundTransparency = if not slot.filled
				then GLASS_EMPTY
				elseif index == selected and armed then GLASS_SELECTED
				else GLASS_IDLE
			slot.key.BackgroundTransparency = if index == selected then 0 else 1
			slot.key.TextColor3 = if index == selected
				then Theme.OnAccent
				elseif slot.filled then Theme.Soft
				else Theme.Muted
		end
		if selected ~= lifted then
			for index, slot in slots do
				local y = CAN_H - (if index == selected then LIFT else 0)
				local goal = UDim2.fromOffset(slot.frame.Position.X.Offset, y)
				TweenService:Create(slot.frame, LIFT_TWEEN, { Position = goal }):Play()
			end
			lifted = selected
		end
	end

	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

function Hud.step(
	_cooldowns: { [number]: number },
	_selected: number,
	_armed: boolean,
	_now: number
)
end

return Hud
