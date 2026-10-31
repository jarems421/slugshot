--!strict
-- Rocklock blaster effects on every client. G cycles the hold-style candidates (owner
-- picks; the movement presentation reads the HoldVariant attribute). Taking the blaster
-- out fades it in while the presentation spins it about the trigger finger; putting it
-- away spins a local copy back out of the hand and fades it, so it never just vanishes.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage:WaitForChild("MovementExperiment"):WaitForChild("Config"))
local Hold = Config.Animation.Hold
local player = Players.LocalPlayer

local FADE_IN = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local HOLSTER_TIME = 0.24
-- R6 hand frame at the end of the arm, as the tool's RightGrip weld uses it.
local HAND = CFrame.new(0, -1, 0) * CFrame.Angles(-math.pi / 2, 0, 0)

local function isBlaster(item: Instance): boolean
	return item:IsA("Tool") and item:GetAttribute("HoldStyle") == "Pistol"
end

local function visibleParts(tool: Instance): { BasePart }
	local list = {}
	for _, item in tool:GetDescendants() do
		if item:IsA("BasePart") and item.Name ~= "Handle" then
			table.insert(list, item)
		end
	end
	return list
end

local function fadeIn(tool: Tool)
	for _, part in visibleParts(tool) do
		part.LocalTransparencyModifier = 1
		TweenService:Create(part, FADE_IN, { LocalTransparencyModifier = 0 }):Play()
	end
end

-- A local copy follows the hand, turns half a spin back and fades out.
local function holster(character: Model, tool: Tool)
	local arm = character:FindFirstChild("Right Arm")
	if not (arm and arm:IsA("BasePart")) then
		return
	end
	local hand = arm.CFrame * HAND
	local copies: { { part: BasePart, offset: CFrame } } = {}
	local folder = Instance.new("Folder")
	folder.Name = "BlasterHolster"
	for _, part in visibleParts(tool) do
		local copy = part:Clone()
		copy:ClearAllChildren()
		copy.Anchored = true
		copy.CanCollide, copy.CanQuery, copy.CanTouch = false, false, false
		copy.LocalTransparencyModifier = 0
		copy.Parent = folder
		table.insert(copies, { part = copy, offset = hand:Inverse() * part.CFrame })
	end
	folder.Parent = workspace
	local start = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - start) / HOLSTER_TIME, 0, 1)
		if t >= 1 or not arm.Parent then
			connection:Disconnect()
			folder:Destroy()
			return
		end
		local frame = arm.CFrame * HAND * CFrame.Angles(math.pi * t * t, 0, 0)
		for _, copy in copies do
			copy.part.CFrame = frame * copy.offset
			copy.part.Transparency = t
		end
	end)
end

local function watchCharacter(character: Model)
	character.ChildAdded:Connect(function(item)
		if isBlaster(item) then
			fadeIn(item :: Tool)
		end
	end)
	character.ChildRemoved:Connect(function(item)
		if isBlaster(item) then
			holster(character, item :: Tool)
		end
	end)
end

local function watchPlayer(other: Player)
	other.CharacterAdded:Connect(watchCharacter)
	if other.Character then
		watchCharacter(other.Character)
	end
end
Players.PlayerAdded:Connect(watchPlayer)
for _, other in Players:GetPlayers() do
	watchPlayer(other)
end

-- Hold-style candidates for the owner to choose between (local only).
local gui = Instance.new("ScreenGui")
gui.Name = "BlasterStyleHUD"
gui.ResetOnSpawn = false
local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 1)
label.Position = UDim2.new(0.5, 0, 1, -96)
label.Size = UDim2.fromOffset(360, 30)
label.BackgroundColor3 = Color3.fromRGB(20, 28, 40)
label.BackgroundTransparency = 0.25
label.TextColor3 = Color3.fromRGB(229, 239, 248)
label.Font = Enum.Font.GothamMedium
label.TextSize = 16
label.Visible = false
label.Parent = gui
gui.Parent = player:WaitForChild("PlayerGui")

local index = table.find(Hold.Order, Hold.Default) or 1
local function current(): string
	return Hold.Order[index]
end
local function apply()
	local character = player.Character
	if character then
		character:SetAttribute("HoldVariant", current())
	end
end
player.CharacterAdded:Connect(apply)
apply()

RunService.Heartbeat:Connect(function()
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	local holding = tool ~= nil and isBlaster(tool)
	label.Visible = holding
	label.Text = `Blaster hold: {current()}  ·  G to switch ({index}/{#Hold.Order})`
end)

ContextActionService:BindAction("RocklockBlasterStyle", function(_, state)
	if state == Enum.UserInputState.Begin then
		index = index % #Hold.Order + 1
		apply()
	end
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.G)
