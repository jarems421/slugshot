--!strict
-- The match HUD (owner, 2026-11-01): a slim health bar under Roblox's top-left buttons and the soft
-- five-slot slug bar at the bottom centre. CombatClient drives the slots each frame.
local GuiService = game:GetService("GuiService")
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

local SLOT, GAP, PAD = 76, 7, 7
local TOPBAR_FALLBACK = 58 -- height of Roblox's own buttons, until it reports it
local FILL = 0.82 -- the slug's share of its slot: fills it without touching the edges
local HEADROOM = 1.7 -- the view is taller than the slot, so a hop leaves the top of the bar
local NUMBER_HOLD = 2 -- seconds the health number shows in "On change" mode
local RETURN_TWEEN = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

type Slot = {
	frame: Frame,
	scale: UIScale,
	edge: UIStroke,
	key: TextLabel,
	shade: Frame?,
	count: TextLabel?,
	flash: Frame?,
	icon: SlugIcon.Icon?,
}

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

	-- Health ---------------------------------------------------------------------------
	local health = Theme.new("Frame", {
		Name = "Health",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(350, 64),
		Parent = gui,
	})
	-- Under Roblox's top-left buttons, which a game cannot move.
	local function placeHealth()
		local height = GuiService.TopbarInset.Height
		health.Position = UDim2.fromOffset(16, (if height > 0 then height else TOPBAR_FALLBACK) + 6)
	end
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(placeHealth)
	placeHealth()
	Theme.fitHud(gui, Theme.new("UIScale", { Parent = health }))
	local goo = GooBar.new(health, Vector2.new(2, 2), 290, 16)
	local number = Theme.label(health, "100", Theme.TitleBold, 22, {
		Name = "Number",
		Position = UDim2.fromOffset(304, 1),
		Size = UDim2.fromOffset(46, 24),
		TextStrokeColor3 = Theme.Ink,
		TextStrokeTransparency = 0.5,
	})
	local sprint = Theme.label(health, "Sprint on", Theme.Body, 13, {
		Name = "Sprint",
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.fromOffset(120, 18),
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

	-- Slug bar -------------------------------------------------------------------------
	local count = Combat.SlotCount
	local bar = Theme.new("Frame", {
		Name = "SlugBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -36),
		Size = UDim2.fromOffset(count * SLOT + (count - 1) * GAP + PAD * 2, SLOT + PAD * 2),
		BackgroundColor3 = Theme.Bar,
		BackgroundTransparency = 0.28,
		BorderSizePixel = 0,
		Parent = gui,
	})
	Theme.corner(bar, 17)
	Theme.edge(bar, 2)
	Theme.fitHud(gui, Theme.new("UIScale", { Parent = bar }))

	local slots: { Slot } = {}
	for index = 1, count do
		local slugId = Combat.Loadout[index]
		local frame = Theme.new("Frame", {
			Name = `Slot{index}`,
			Position = UDim2.fromOffset(PAD + (index - 1) * (SLOT + GAP), PAD),
			Size = UDim2.fromOffset(SLOT, SLOT),
			BackgroundColor3 = if slugId then Theme.Slot else Theme.SlotEmpty,
			BorderSizePixel = 0,
			Parent = bar,
		})
		Theme.corner(frame, 12)
		local scale = Theme.new("UIScale", { Parent = frame })
		local edge = Theme.edge(frame, 2, Theme.Accent)
		edge.Enabled = slugId ~= nil
		local slot: Slot = {
			frame = frame,
			scale = scale,
			edge = edge,
			key = Theme.label(frame, "", Theme.Title, 13, {
				Name = "Key",
				Position = UDim2.fromOffset(3, 3),
				Size = UDim2.fromOffset(19, 19),
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = if slugId then Theme.OnAccent else Theme.Soft,
				BackgroundColor3 = Theme.Accent,
				BackgroundTransparency = if slugId then 0 else 1,
				ZIndex = 6,
			}),
		}
		Theme.corner(slot.key, 5)
		if slugId then
			slot.icon = SlugIcon.mount(frame, slugId, FILL, true, nil, HEADROOM)
			slot.shade = Theme.new("Frame", {
				Name = "Shade",
				Size = UDim2.fromScale(1, 0),
				BackgroundColor3 = Theme.Ink,
				BackgroundTransparency = 0.24,
				BorderSizePixel = 0,
				ZIndex = 3,
				Parent = frame,
			})
			Theme.corner(slot.shade :: any, 12)
			slot.count = Theme.label(frame, "", Theme.TitleBold, 26, {
				Name = "Count",
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
				ZIndex = 4,
			})
			slot.flash = Theme.new("Frame", {
				Name = "Flash",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Theme.Return,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ZIndex = 5,
				Parent = frame,
			})
			Theme.corner(slot.flash :: any, 12)
		end
		slots[index] = slot
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
					if slot.icon then
						SlugIcon.back(slot.icon)
					end
				elseif remaining > 0 and not cooling[index] and slot.icon then
					SlugIcon.leave(slot.icon)
				end
				cooling[index] = remaining > 0
				shade.Size = UDim2.fromScale(1, math.clamp(remaining / Combat.Cooldown, 0, 1))
				label.Text = if remaining > 0 then string.format("%.1f", remaining) else ""
			end
			slot.edge.Transparency = if index == selected and armed then 0 else 0.75
			slot.key.BackgroundTransparency = if index == selected then 0 else 1
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
