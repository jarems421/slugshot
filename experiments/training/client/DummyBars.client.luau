--!strict
-- What a dummy shows: nothing until it's hit, then a thin health bar and the damage, well above its head so the sights
-- stay clear. Both go again when it heals.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local INK = Color3.fromRGB(14, 14, 18)
local GOO = Color3.fromRGB(190, 236, 96)

type Bar = { humanoid: Humanoid, gui: BillboardGui, fill: Frame }
local bars: { [Model]: Bar } = {}

local function attach(model: Instance)
	if not model:IsA("Model") or bars[model] then
		return
	end
	local humanoid = model:WaitForChild("Humanoid", 10)
	local head = model:WaitForChild("Head", 10)
	if not humanoid or not humanoid:IsA("Humanoid") or not head or not head:IsA("BasePart") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "DummyBar"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(70, 34)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 140
	gui.Enabled = false
	local back = Instance.new("Frame")
	back.AnchorPoint = Vector2.new(0.5, 1)
	back.Position = UDim2.fromScale(0.5, 1)
	back.Size = UDim2.new(1, 0, 0, 7)
	back.BackgroundColor3, back.BorderSizePixel = INK, 0
	back.Parent = gui
	local fill = Instance.new("Frame")
	fill.Position = UDim2.fromOffset(1, 1)
	fill.Size = UDim2.new(1, -2, 1, -2)
	fill.BackgroundColor3, fill.BorderSizePixel = GOO, 0
	fill.Parent = back
	gui.Parent = model
	bars[model] = { humanoid = humanoid, gui = gui, fill = fill }
	model:GetAttributeChangedSignal("LastHit"):Connect(function()
		local damage = model:GetAttribute("LastDamage")
		if typeof(damage) ~= "number" then
			return
		end
		local number = Instance.new("TextLabel")
		number.BackgroundTransparency = 1
		number.Position = UDim2.fromOffset(0, 8)
		number.Size = UDim2.new(1, 0, 0, 16)
		number.Font = Enum.Font.GothamBold
		number.TextSize = 15
		number.TextColor3 = Color3.new(1, 1, 1)
		number.TextStrokeColor3, number.TextStrokeTransparency = INK, 0
		number.Text = tostring(math.round(damage))
		number.Parent = gui
		gui.Enabled = true
		local tween = TweenService:Create(
			number,
			TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = UDim2.fromOffset(0, -4), TextTransparency = 1, TextStrokeTransparency = 1 }
		)
		tween.Completed:Connect(function()
			number:Destroy()
		end)
		tween:Play()
	end)
end

for _, model in CollectionService:GetTagged("RangeDummy") do
	task.spawn(attach, model)
end
CollectionService:GetInstanceAddedSignal("RangeDummy"):Connect(attach)

RunService.RenderStepped:Connect(function()
	for model, bar in bars do
		if not model.Parent then
			bars[model] = nil
			continue
		end
		local share = math.clamp(bar.humanoid.Health / bar.humanoid.MaxHealth, 0, 1)
		bar.fill.Size = UDim2.new(share, -2, 1, -2)
		bar.gui.Enabled = share < 1
	end
end)
