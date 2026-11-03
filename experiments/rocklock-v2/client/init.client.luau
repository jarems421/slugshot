--!strict
-- Rocklock v2 client: cosmetic destruction effects (dust, chips, warning rings) and the
-- temporary Terrain Tester controls. Nothing here decides damage or collision; the server
-- owns every gameplay-relevant change and these effects only follow its events.
local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config =
	require(ReplicatedStorage:WaitForChild("RocklockV2"):WaitForChild("DestructionConfig"))
local remotes = ReplicatedStorage:WaitForChild("RocklockV2Remotes")
local request = remotes:WaitForChild("DestructionRequest") :: RemoteEvent
local fx = remotes:WaitForChild("DestructionFx") :: RemoteEvent
local player = Players.LocalPlayer

local effects = Instance.new("Folder")
effects.Name = "RocklockV2Effects"
effects.Parent = workspace

local DUST = "rbxasset://textures/particles/smoke_main.dds"
local STONE = Color3.fromRGB(170, 150, 124)
local EARTH = Color3.fromRGB(122, 98, 74)

local function sound(position: Vector3, speed: number, volume: number)
	local holder = Instance.new("Part")
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Position = position
	holder.Parent = effects
	local s = Instance.new("Sound")
	s.SoundId = "rbxasset://sounds/collide.wav"
	s.PlaybackSpeed = speed
	s.Volume = volume
	s.RollOffMaxDistance = 220
	s.Parent = holder
	s:Play()
	Debris:AddItem(holder, 3)
end

local function dust(position: Vector3, color: Color3, amount: number, size: number, speed: number)
	local holder = Instance.new("Part")
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
	holder.Transparency = 1
	holder.Size = Vector3.one
	holder.Position = position
	holder.Parent = effects
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = DUST
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size * 0.5),
		NumberSequenceKeypoint.new(1, size * 1.6),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.8, 1.6)
	emitter.Speed = NumberRange.new(speed * 0.5, speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 3
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(amount)
	Debris:AddItem(holder, 2.5)
end

local function chips(position: Vector3, color: Color3, count: number, scale: number)
	for _ = 1, math.clamp(count, 0, 14) do
		local chip = Instance.new("Part")
		chip.Size = Vector3.new(math.random(), math.random(), math.random()) * scale
			+ Vector3.one * 0.25 * scale
		chip.Color = color
		chip.Material = Enum.Material.Slate
		chip.CanCollide, chip.CanQuery, chip.CanTouch = false, false, false
		chip.CFrame = CFrame.new(
			position
				+ Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
					* scale
		) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		chip.AssemblyLinearVelocity = Vector3.new(
			math.random() - 0.5,
			math.random() * 0.8 + 0.4,
			math.random() - 0.5
		) * 40
		chip.AssemblyAngularVelocity = Vector3.new(math.random(), math.random(), math.random()) * 10
		chip.Parent = effects
		TweenService:Create(
			chip,
			TweenInfo.new(
				Config.Rubble.SmallLifetime * 0.5,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In,
				0,
				false,
				Config.Rubble.SmallLifetime * 0.4
			),
			{ Transparency = 1 }
		):Play()
		Debris:AddItem(chip, Config.Rubble.SmallLifetime)
	end
end

-- Readable warning: a pulsing ring on the ground where the formation will land, falling
-- dust from it and a rumble, for exactly the server's warning time.
local function warn(position: Vector3, top: Vector3, radius: number, duration: number)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch = true, false, false, false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 120, 60)
	ring.Transparency = 0.55
	ring.Size = Vector3.new(0.2, radius * 2, radius * 2)
	ring.CFrame = CFrame.new(position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = effects
	TweenService:Create(
		ring,
		TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.85 }
	):Play()
	Debris:AddItem(ring, duration + 0.4)
	local start = os.clock()
	task.spawn(function()
		while os.clock() - start < duration do
			dust(top - Vector3.new(0, 6, 0), STONE, 4, 1.2, 4)
			task.wait(0.15)
		end
	end)
	for i = 0, 2 do
		task.delay(i * duration / 3, sound, top, 0.45, 0.6)
	end
end

fx.OnClientEvent:Connect(function(data: any)
	if typeof(data) ~= "table" then
		return
	end
	local kind = data.kind
	if kind == "Result" then
		return
	end
	local position = data.position
	if typeof(position) ~= "Vector3" then
		return
	end
	if kind == "Hit" then
		local strength = tonumber(data.strength) or 10
		dust(position, STONE, math.clamp(math.floor(strength / 8), 2, 10), 0.8, 8)
		if not data.essential then
			chips(position, STONE, math.floor(strength / 18), 0.5)
		end
		sound(position, 1.6, 0.35)
	elseif kind == "Break" then
		local size = if typeof(data.size) == "Vector3" then data.size.Magnitude else 4
		local color = if typeof(data.color) == "Color3" then data.color else STONE
		dust(position, color, math.clamp(math.floor(size * 3), 8, 30), 1.2 + size * 0.12, 12)
		chips(position, color, math.floor(size * 1.5), 0.6)
		sound(position, 0.9, 0.7)
	elseif kind == "Warn" then
		warn(
			position,
			if typeof(data.top) == "Vector3" then data.top else position,
			tonumber(data.radius) or 9,
			tonumber(data.duration) or 1.3
		)
	elseif kind == "Impact" then
		dust(position, STONE, 40, 3, 26)
		chips(position, STONE, 14, 0.9)
		sound(position, 0.6, 1)
	elseif kind == "Dig" then
		dust(position, EARTH, 16, 1.5, 10)
		chips(position, EARTH, 6, 0.5)
		sound(position, 0.8, 0.5)
	elseif kind == "Raise" then
		dust(position, STONE, 20, 1.6, 10)
		sound(position, 0.7, 0.6)
	end
end)

-- ------------------------------------------------------------------ Terrain Tester controls
local gui = Instance.new("ScreenGui")
gui.Name = "RocklockV2Tester"
gui.ResetOnSpawn = false
local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 1)
label.Position = UDim2.new(0.5, 0, 1, -140)
label.Size = UDim2.fromOffset(640, 96)
label.BackgroundColor3 = Color3.fromRGB(32, 26, 22)
label.BackgroundTransparency = 0.2
label.TextColor3 = Color3.fromRGB(240, 230, 214)
label.Font = Enum.Font.GothamMedium
label.TextSize = 15
label.TextWrapped = true
label.TextYAlignment = Enum.TextYAlignment.Top
label.Visible = false
label.Parent = gui
gui.Parent = player:WaitForChild("PlayerGui")

local tierIndex, archetypeIndex = 2, 1
local lines: { string } = {}
local function tier(): string
	return Config.TierOrder[tierIndex]
end
local function archetype(): string
	return Config.ArchetypeOrder[archetypeIndex]
end
local function render()
	label.Text = `TERRAIN TESTER  ·  {tier()} ({(Config.Tiers :: any)[tier()]})  ·  {archetype()}\n`
		.. "Click attack · Z/X/C weak/medium/heavy · V attack type · F raise slab · T reset round · Y self-test\n"
		.. table.concat(lines, "\n")
end
local function note(text: string)
	table.insert(lines, text)
	while #lines > 3 do
		table.remove(lines, 1)
	end
	render()
end
fx.OnClientEvent:Connect(function(data: any)
	if typeof(data) == "table" and data.kind == "Result" and typeof(data.text) == "string" then
		note(data.text)
	end
end)

local function aim(): Vector3?
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not head then
		return nil
	end
	local mouse = player:GetMouse()
	mouse.TargetFilter = character
	local direction = mouse.Hit.Position - head.Position
	return if direction.Magnitude > 0.1 then direction.Unit else nil
end

type Action = { name: string, key: Enum.KeyCode, run: () -> () }
local ACTIONS: { Action } = {
	{
		name = "RocklockTesterWeak",
		key = Enum.KeyCode.Z,
		run = function()
			tierIndex = 1
			render()
		end,
	},
	{
		name = "RocklockTesterMedium",
		key = Enum.KeyCode.X,
		run = function()
			tierIndex = 2
			render()
		end,
	},
	{
		name = "RocklockTesterHeavy",
		key = Enum.KeyCode.C,
		run = function()
			tierIndex = 3
			render()
		end,
	},
	{
		name = "RocklockTesterType",
		key = Enum.KeyCode.V,
		run = function()
			archetypeIndex = archetypeIndex % #Config.ArchetypeOrder + 1
			render()
		end,
	},
	{
		name = "RocklockTesterRaise",
		key = Enum.KeyCode.F,
		run = function()
			local direction = aim()
			if direction then
				request:FireServer({ kind = "Raise", direction = direction })
			end
		end,
	},
	{
		name = "RocklockTesterReset",
		key = Enum.KeyCode.T,
		run = function()
			request:FireServer({ kind = "Reset" })
		end,
	},
	{
		name = "RocklockTesterSelfTest",
		key = Enum.KeyCode.Y,
		run = function()
			note("self-test running (about 6 s)...")
			request:FireServer({ kind = "SelfTest" })
		end,
	},
}

local bound = false
local function setBound(on: boolean)
	if on == bound then
		return
	end
	bound = on
	label.Visible = on
	for _, action in ACTIONS do
		local name, key, run = action.name, action.key, action.run
		if on then
			ContextActionService:BindAction(name, function(_, state)
				if state == Enum.UserInputState.Begin then
					run()
				end
				return Enum.ContextActionResult.Sink
			end, false, key)
		else
			ContextActionService:UnbindAction(name)
		end
	end
	if on then
		render()
	end
end

local hooked: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local function hook(tool: Instance)
	if tool:IsA("Tool") and tool:GetAttribute("RocklockTester") and not hooked[tool] then
		hooked[tool] = true
		tool.Activated:Connect(function()
			local direction = aim()
			if direction then
				request:FireServer({
					kind = "Attack",
					direction = direction,
					tier = tier(),
					archetype = archetype(),
				})
			end
		end)
	end
end
local function watch(character: Model)
	character.ChildAdded:Connect(hook)
	for _, item in character:GetChildren() do
		hook(item)
	end
end
player.CharacterAdded:Connect(watch)
if player.Character then
	watch(player.Character)
end

RunService.Heartbeat:Connect(function()
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	setBound(tool ~= nil and tool:GetAttribute("RocklockTester") == true)
end)
