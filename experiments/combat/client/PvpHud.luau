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
local Fx = require(script.Parent.PvpFx)
local CanisterIdle = require(script.Parent.CanisterIdle)
local GooBar = require(script.Parent.GooBar)

local player = Players.LocalPlayer
local movement = player:WaitForChild("PlayerScripts"):WaitForChild("MovementSandbox")
local Keybinds = (require :: any)(movement:WaitForChild("Keybinds"))

local Hud = {}

-- Owner, 2026-11-15: the canisters "a bit big ... very chunky for no reason", so smaller (were 70 wide, 112 tall), and
-- then "reduce the size of the chunky grey top, and especially the bottom" (cap and base were 20 and 22 tall, then 14
-- and 18).
local CAN_W, CAN_GAP = 60, 10
local CAP_W, CAP_H = 60, 10 -- the same width as the base (owner, 2026-11-07)
local GLASS_W, GLASS_H = 46, 62
local BASE_W, BASE_H = 60, 12
local CAN_H = CAP_H + GLASS_H + BASE_H - 2 -- the glass tucks 1 px under each end
local SHINE_PX = 2 -- the glass's reflections, in screen pixels
local LIFT = 6 -- the selected canister stands this much higher
-- Owner, 2026-11-14: the bar a bit thinner (was 16 tall). Owner, 2026-11-15: shorter now the canisters are smaller, "a
-- bit longer" than their row "but not as long as it is" (was 300): it overhangs the row by about 20 a side.
local GOO_W, GOO_H = 260, 11
local HEALTH_SCALE = 1.43 -- the bar grows as a whole (owner, 2026-11-14: 10% bigger than 1.3)
local HEALTH_H = math.ceil((GOO_H + 6) * HEALTH_SCALE)
-- The same gap between the bar and the inventory button on its left as the health number on its right (owner,
-- 2026-11-15: the button sat "too close"; "make sure the space ... are both the same").
local HEALTH_GAP = 12
local ROW_Y = HEALTH_H + 26
local FILL = 0.6 -- the slug's share of the glass's height (owner, 2026-11-07: smaller)
local GLASS_SELECTED, GLASS_IDLE, GLASS_EMPTY = 0, 0.25, 0.4 -- glass transparency
local NUMBER_HOLD = 2 -- seconds the health number shows in "On change" mode
local RETURN_TWEEN = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local LIFT_TWEEN = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local METAL = Color3.fromRGB(36, 41, 50)
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
	slug: GuiObject?, -- the slug standing in the glass
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
	-- Two thin reflections down the tube, framing the slug (owner, 2026-11-15: "keep the two thin white lines inside";
	-- the lines on the cap and base went). Each is exactly SHINE_PX screen pixels wide whatever the HUD's scale: a
	-- fraction over two drew as two or three pixels depending on where the canister landed (Rammstone's read thicker).
	local shines: { Frame } = {}
	for _, streak in { { 6, 0.6 }, { GLASS_W - 8, 0.78 } } do
		local shine = Theme.new("Frame", {
			Position = UDim2.fromOffset(streak[1], 7),
			Size = UDim2.new(0, 2, 1, -14),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = streak[2],
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = glass,
		})
		table.insert(shines, shine)
	end
	local function sizeShines()
		-- A share of the glass's width, since UDim offsets are whole numbers.
		local width = glass.AbsoluteSize.X
		if width > 0 then
			for _, shine in shines do
				shine.Size = UDim2.new(SHINE_PX / width, 0, 1, -14)
			end
		end
	end
	glass:GetPropertyChangedSignal("AbsoluteSize"):Connect(sizeShines)
	sizeShines()

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
			Size = UDim2.fromOffset(3, 4),
			BackgroundColor3 = Theme.Ink,
			BorderSizePixel = 0,
			Parent = cap,
		})
	end

	local base = metal(frame, {
		Name = "Base",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(BASE_W, BASE_H),
		ZIndex = 3,
	})
	local key = Theme.label(base, "", Theme.Title, 10, {
		Name = "Key",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(22, 10),
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
		-- It leaves the glass while it is fired; it plays its idle as a flipbook (CanisterIdle).
		-- A sharp picture of the game's own icon view where there is one (tools/ui/build_canister_slugs.py; owner,
		-- 2026-11-15: the live view looked "very like low resolution"), the live view for a slug without one.
		local picture = Fx.asset(`canister{slugId}`)
		local small = Fx.asset(`canisterIdle{slugId}Small`)
		local sheets = { Fx.asset(`canisterIdle{slugId}1`), Fx.asset(`canisterIdle{slugId}2`) }
		if picture ~= "" or small ~= "" or (sheets[1] ~= "" and sheets[2] ~= "") then
			local holder = Theme.new("Frame", {
				Name = "Slug",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 1, -- under the reflections, as the live view was
				Parent = glass,
			})
			CanisterIdle.mount(holder, picture, small, sheets)
			slot.slug = holder
		else
			slot.slug = SlugIcon.mount(glass, slugId, FILL, false).frame
		end
		slot.shade = Theme.new("Frame", {
			Name = "Shade",
			Size = UDim2.fromScale(1, 0),
			BackgroundColor3 = Theme.Ink,
			BackgroundTransparency = 0.24,
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = glass,
		})
		slot.count = Theme.label(glass, "", Theme.TitleBold, 21, {
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
		-- Raised a little (owner, 2026-11-15: "a little bit more in your face"; was 24 off the bottom).
		Position = UDim2.new(0.5, 0, 1, -50),
		Size = UDim2.fromOffset(rowWidth, ROW_Y + CAN_H),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Theme.fitHud(gui, Theme.new("UIScale", { Parent = bar }))
	-- Where the health bar sits, for the inventory button (Inventory): its left end, which overhangs the canister row,
	-- and its middle, in the slug bar's own units.
	bar:SetAttribute("HealthLeft", (rowWidth - (GOO_W + 6) * HEALTH_SCALE) / 2)
	bar:SetAttribute("HealthMiddle", (GOO_H + 6) * HEALTH_SCALE / 2)
	bar:SetAttribute("HealthGap", HEALTH_GAP)

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
		-- Level with the bar, HEALTH_GAP clear of it on screen. The digits sit low in their line, so the label is lifted
		-- to centre the digits themselves (owner, 2026-11-15: "still needs to be moved up a bit").
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1 + HEALTH_GAP / HEALTH_SCALE / (GOO_W + 6), 0, 0.5, -2), -- as a share: offsets are whole
		Size = UDim2.fromOffset(46, 24),
		TextStrokeColor3 = Theme.Ink,
		TextStrokeTransparency = 0.5,
	})
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
	local loadout = Combat.loadoutOf(player)
	for index = 1, count do
		slots[index] = canister(row, index, loadout[index])
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
	-- A swap in the inventory rebuilds the canisters whose slug changed (CanisterIdle drops a picture once it loses its
	-- parent, so nothing is left running).
	player:GetAttributeChangedSignal("Loadout"):Connect(function()
		local now = Combat.loadoutOf(player)
		for index = 1, count do
			if now[index] ~= loadout[index] then
				slots[index].frame:Destroy()
				slots[index] = canister(row, index, now[index])
			end
		end
		loadout = now
		refreshKeys()
	end)

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
				if slot.slug then
					slot.slug.Visible = remaining <= 0
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
