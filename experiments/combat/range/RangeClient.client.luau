--!strict
-- Target range readouts over each dummy: health, the last hit (damage and shot
-- distance), the session's damage and DPS, and this player's live distance to it.
-- DPS = session damage / (time from first to last hit + one cooldown), so steady
-- firing reads the true rate (5 damage per 1.5 s = 3.3 for Floppy).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Combat = require(ReplicatedStorage:WaitForChild("Combat"))

local player = Players.LocalPlayer
local IDLE = 4

type Readout = {
	model: Model,
	humanoid: Humanoid,
	fill: Frame,
	health: TextLabel,
	last: TextLabel,
	session: TextLabel,
	distance: TextLabel,
}
local readouts: { [Model]: Readout } = {}

local function text(parent: Instance, order: number, size: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.LayoutOrder = order
	label.Size = UDim2.new(1, 0, 0, size + 4)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = size
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.5
	label.Parent = parent
	return label
end

local function attach(model: Instance)
	if not model:IsA("Model") or readouts[model] then
		return
	end
	local humanoid = model:WaitForChild("Humanoid", 10)
	local head = model:WaitForChild("Head", 10)
	if not humanoid or not humanoid:IsA("Humanoid") or not head or not head:IsA("BasePart") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "RangeReadout"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(190, 108)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.1, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 200
	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = Color3.fromRGB(20, 26, 34)
	panel.BackgroundTransparency = 0.3
	panel.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 8)
	round.Parent = panel
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 5)
	pad.Parent = panel
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 1)
	list.Parent = panel
	local bar = Instance.new("Frame")
	bar.LayoutOrder = 1
	bar.Size = UDim2.new(1, 0, 0, 12)
	bar.BackgroundColor3 = Color3.fromRGB(60, 24, 24)
	bar.Parent = panel
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(110, 200, 96)
	fill.Parent = bar
	local health = text(bar, 0, 11, Color3.new(1, 1, 1))
	health.Size = UDim2.fromScale(1, 1)
	health.ZIndex = 2
	readouts[model] = {
		model = model,
		humanoid = humanoid,
		fill = fill,
		health = health,
		last = text(panel, 2, 13, Color3.fromRGB(255, 214, 92)),
		session = text(panel, 3, 13, Color3.fromRGB(229, 239, 248)),
		distance = text(panel, 4, 13, Color3.fromRGB(170, 214, 240)),
	}
	gui.Parent = model
end

CollectionService:GetInstanceAddedSignal("RangeDummy"):Connect(attach)
CollectionService:GetInstanceRemovedSignal("RangeDummy"):Connect(function(model)
	readouts[model :: Model] = nil
end)
for _, model in CollectionService:GetTagged("RangeDummy") do
	task.spawn(attach, model)
end

-- Controls panel.
local hud = Instance.new("ScreenGui")
hud.Name = "RangeHelp"
hud.ResetOnSpawn = false
local help = Instance.new("TextLabel")
help.AnchorPoint = Vector2.new(0.5, 0)
help.Position = UDim2.new(0.5, 0, 0, 8)
help.Size = UDim2.fromOffset(760, 26)
help.BackgroundColor3 = Color3.fromRGB(20, 26, 34)
help.BackgroundTransparency = 0.3
help.Font = Enum.Font.GothamMedium
help.TextSize = 14
help.TextColor3 = Color3.fromRGB(229, 239, 248)
help.Text =
	"TEMPORARY TEST RANGE  ·  LMB tap or hold to charge  ·  Scroll in: first person  ·  Ctrl shift-lock  ·  M settings"
help.Parent = hud
local helpRound = Instance.new("UICorner")
helpRound.CornerRadius = UDim.new(0, 8)
helpRound.Parent = help
hud.Parent = player:WaitForChild("PlayerGui")

RunService.RenderStepped:Connect(function()
	local now = workspace:GetServerTimeNow()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	for model, readout in readouts do
		if not model.Parent then
			readouts[model] = nil
			continue
		end
		local humanoid = readout.humanoid
		local fraction = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
		readout.fill.Size = UDim2.fromScale(fraction, 1)
		readout.health.Text =
			string.format("%d / %d HP", math.ceil(humanoid.Health), humanoid.MaxHealth)
		local lastHit = model:GetAttribute("LastHit") :: number?
		local damage = (model:GetAttribute("SessionDamage") or 0) :: number
		local hits = (model:GetAttribute("Hits") or 0) :: number
		if lastHit then
			local start = (model:GetAttribute("SessionStart") or lastHit) :: number
			local dps = damage / (lastHit - start + Combat.Cooldown)
			local idle = now - lastHit > IDLE
			readout.last.Text = string.format(
				"Last hit %d @ %.1f studs",
				(model:GetAttribute("LastDamage") or 0) :: number,
				(model:GetAttribute("LastDistance") or 0) :: number
			)
			readout.session.Text = string.format(
				"%s%d dmg · %d hits · %.1f DPS",
				if idle then "Last: " else "",
				damage,
				hits,
				dps
			)
		else
			readout.last.Text = "No hits yet"
			readout.session.Text =
				string.format("KOs %d", (model:GetAttribute("KOs") or 0) :: number)
		end
		local primary = model.PrimaryPart
		if root and root:IsA("BasePart") and primary then
			readout.distance.Text =
				string.format("You: %.1f studs away", (primary.Position - root.Position).Magnitude)
		else
			readout.distance.Text = ""
		end
	end
end)
