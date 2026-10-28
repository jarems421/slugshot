--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("MovementExperiment")
local Config = require(shared.Config)
local Math = require(shared.MotionMath)
local request = shared:WaitForChild("MovementRequest") :: RemoteEvent
local controls = require(player.PlayerScripts:WaitForChild("PlayerModule")):GetControls()
require(script.Presentation).start()

local character: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local sprinting, aiming = false, false
local speed, move = 0, Vector3.zero
local sequence, pendingAction = 0, 0
local lastEvade, lastFlourish = -math.huge, -math.huge
local airUsed = false
local evade: any = nil
local testMove: Vector3? = nil
local testUntil = 0
local testJumpUntil = 0
local markers, lastAimSent = 0, 0
local lastReject = "none"
local bindName = "SlugshotMovementExperiment"

local gui = Instance.new("ScreenGui")
gui.Name = "MovementSandboxHUD"
gui.ResetOnSpawn = false
local label = Instance.new("TextLabel")
label.Size = UDim2.fromOffset(540, 126)
label.Position = UDim2.fromOffset(20, 65)
label.BackgroundColor3 = Color3.fromRGB(20, 28, 40)
label.BackgroundTransparency = 0.12
label.TextColor3 = Color3.fromRGB(229, 239, 248)
label.TextXAlignment = Enum.TextXAlignment.Left
label.TextYAlignment = Enum.TextYAlignment.Top
label.Font = Enum.Font.Gotham
label.TextSize = 16
label.TextWrapped = true
label.Parent = gui
local padding = Instance.new("UIPadding")
padding.PaddingLeft, padding.PaddingTop = UDim.new(0, 12), UDim.new(0, 10)
padding.Parent = label
gui.Parent = player:WaitForChild("PlayerGui")
local crosshair = Instance.new("TextLabel")
crosshair.Size = UDim2.fromOffset(24, 24)
crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
crosshair.Position = UDim2.fromScale(0.5, 0.5)
crosshair.BackgroundTransparency = 1
crosshair.Text, crosshair.TextSize = "+", 24
crosshair.TextColor3 = Color3.new(1, 1, 1)
crosshair.Parent = gui

local function send(kind: string, value: any?, direction: Vector3?): number
	sequence += 1
	request:FireServer({ sequence = sequence, kind = kind, value = value, direction = direction })
	return sequence
end

local function profile(): any
	return Config.Profiles[player:GetAttribute("MovementProfile") or Config.DefaultProfile]
end

local function attach(newCharacter: Model)
	character = newCharacter
	humanoid = newCharacter:WaitForChild("Humanoid") :: Humanoid
	root = newCharacter:WaitForChild("HumanoidRootPart") :: BasePart
	local function disableDefaultAnimation(item: Instance)
		if item.Name == "Animate" and item:IsA("LocalScript") then
			item.Enabled = false
		end
	end
	for _, item in newCharacter:GetChildren() do
		disableDefaultAnimation(item)
	end
	newCharacter.ChildAdded:Connect(disableDefaultAnimation)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			track:Stop(0)
		end
	end
	speed, move, evade, airUsed = 0, Vector3.zero, nil, false
	sprinting, aiming, testMove = false, false, nil
	testUntil, testJumpUntil, pendingAction = 0, 0, 0
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	lastEvade, lastFlourish = -math.huge, -math.huge
	humanoid.UseJumpPower = true
	humanoid.JumpPower = profile().JumpPower
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraSubject = humanoid
		camera.CameraType = Enum.CameraType.Custom
	end
	player.CameraMinZoomDistance = Config.Camera.MinZoom
	player.CameraMaxZoomDistance = Config.Camera.MaxZoom
	print("[Movement sandbox] client attached", newCharacter.Name)
end
player.CharacterAdded:Connect(attach)
if player.Character then
	task.spawn(attach, player.Character)
end

local function setAim(value: boolean)
	aiming = value
	if character then
		character:SetAttribute("Aiming", value)
	end
	local camera = workspace.CurrentCamera
	send("Aim", value, if camera then camera.CFrame.LookVector else Vector3.new(0, 0, -1))
	UserInputService.MouseBehavior = if value
		then Enum.MouseBehavior.LockCenter
		else Enum.MouseBehavior.Default
end

local function action(kind: string, requestedDirection: Vector3?): boolean
	if not character or not humanoid or not root or humanoid.Health <= 0 then
		return false
	end
	local now = workspace:GetServerTimeNow()
	local onGround = humanoid.FloorMaterial ~= Enum.Material.Air
	if kind == "Evade" and (not onGround or now - lastEvade < Config.Evade.Cooldown) then
		return false
	end
	if
		kind == "Flourish"
		and (onGround or airUsed or now - lastFlourish < Config.Flourish.Cooldown)
	then
		return false
	end
	local direction = requestedDirection
		or (if move.Magnitude > 0.1 then move else root.CFrame.LookVector)
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < 0.01 then
		return false
	end
	direction = direction.Unit
	character:SetAttribute("MovementAction", kind)
	character:SetAttribute("MovementActionTime", now)
	character:SetAttribute("MovementDirection", direction)
	if kind == "Evade" then
		lastEvade = now
		evade = { start = now, direction = direction }
	else
		lastFlourish, airUsed = now, true
	end
	pendingAction = send(kind, nil, direction)
	return true
end

request.OnClientEvent:Connect(function(id: number, accepted: boolean, detail: string)
	if not accepted then
		lastReject = detail
		if id == pendingAction and character then
			evade = nil
			character:SetAttribute("MovementActionTime", -1e9)
		end
	end
end)

local function markAim(): Vector3?
	local camera = workspace.CurrentCamera
	if not camera or not character then
		return nil
	end
	local ray = camera:ViewportPointToRay(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 250, params)
	local position = if hit then hit.Position else ray.Origin + ray.Direction * 80
	local marker = Instance.new("Part")
	marker.Name = "HarmlessAimMarker"
	marker.Shape = Enum.PartType.Ball
	marker.Size = Vector3.one * 0.5
	marker.Color = Color3.fromRGB(255, 211, 97)
	marker.Material = Enum.Material.Neon
	marker.Anchored, marker.CanCollide, marker.CanTouch, marker.CanQuery = true, false, false, false
	marker.Position = position
	marker.Parent = workspace
	Debris:AddItem(marker, 1)
	markers += 1
	return position
end

local profiles = { "Baseline", "Athletic", "Precise" }
local function cycleProfile()
	local index = table.find(profiles, player:GetAttribute("MovementProfile")) or 2
	send("Profile", profiles[index % #profiles + 1])
end

local function bind(name: string, callback: any, title: string, ...: EnumItem)
	ContextActionService:BindAction(name, callback, true, ...)
	ContextActionService:SetTitle(name, title)
end
bind("ExperimentSprint", function(_, state)
	if state == Enum.UserInputState.Begin then
		sprinting = true
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		sprinting = false
	end
	return Enum.ContextActionResult.Sink
end, "Run", Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
bind("ExperimentEvade", function(_, state)
	if state == Enum.UserInputState.Begin then
		action("Evade", nil)
	end
	return Enum.ContextActionResult.Sink
end, "Evade", Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
bind("ExperimentFlourish", function(_, state)
	if state == Enum.UserInputState.Begin then
		action("Flourish", nil)
	end
	return Enum.ContextActionResult.Sink
end, "Flourish", Enum.KeyCode.F, Enum.KeyCode.ButtonY)
bind("ExperimentAim", function(_, state)
	if state == Enum.UserInputState.Begin then
		setAim(true)
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		setAim(false)
	end
	return Enum.ContextActionResult.Sink
end, "Aim", Enum.UserInputType.MouseButton2, Enum.KeyCode.ButtonL2)
bind("ExperimentMarker", function(_, state)
	if state == Enum.UserInputState.Begin then
		markAim()
	end
	return Enum.ContextActionResult.Sink
end, "Mark", Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
ContextActionService:BindAction("ExperimentProfile", function(_, state)
	if state == Enum.UserInputState.Begin then
		cycleProfile()
	end
end, false, Enum.KeyCode.P)
ContextActionService:BindAction("ExperimentRespawn", function(_, state)
	if state == Enum.UserInputState.Begin then
		send("Respawn")
	end
end, false, Enum.KeyCode.R)
UserInputService.WindowFocusReleased:Connect(function()
	sprinting = false
	if aiming then
		setAim(false)
	end
end)

RunService:BindToRenderStep(bindName, Enum.RenderPriority.Input.Value + 1, function(dt)
	if not humanoid or not root or not character or humanoid.Health <= 0 then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local raw = controls:GetMoveVector()
	local forward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	forward = if forward.Magnitude > 0.01 then forward.Unit else Vector3.new(0, 0, -1)
	local right = forward:Cross(Vector3.yAxis)
	local desired = right * raw.X - forward * raw.Z
	if testMove and os.clock() < testUntil then
		desired = testMove
	elseif testMove then
		testMove = nil
	end
	desired = if desired.Magnitude > 1 then desired.Unit else desired
	local settings = profile()
	move = move:Lerp(desired, Math.alpha(settings.TurnRate, dt))
	local target = if sprinting then settings.SprintSpeed else settings.RunSpeed
	speed = Math.approach(
		speed,
		if desired.Magnitude > 0.01 then target else 0,
		if desired.Magnitude > 0.01 then settings.Acceleration else settings.Braking,
		dt
	)
	humanoid.WalkSpeed = speed
	humanoid.JumpPower = settings.JumpPower
	humanoid:Move(if evade then Vector3.zero else move, false)
	if os.clock() < testJumpUntil then
		humanoid.Jump = true
	end
	humanoid.AutoRotate = not aiming
	if aiming then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + forward)
		if os.clock() - lastAimSent > 0.2 then
			lastAimSent = os.clock()
			send("Aim", true, camera.CFrame.LookVector)
		end
	end
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		airUsed = false
	end
	humanoid.CameraOffset = humanoid.CameraOffset:Lerp(
		if aiming then Config.Camera.Shoulder else Vector3.zero,
		Math.alpha(Config.Camera.BlendRate, dt)
	)
	local fov = if aiming
		then Config.Camera.AimFov
		elseif sprinting then Config.Camera.SprintFov
		else Config.Camera.Fov
	camera.FieldOfView += (fov - camera.FieldOfView) * Math.alpha(Config.Camera.BlendRate, dt)
	label.Text = string.format(
		"SLUGSHOT / MOVEMENT LAB   •   %s\nWASD move · Shift run · Space jump · Q evade · F aerial flourish\nRMB aim · Click harmless marker · P compare profiles · R reset\nSpeed %.1f   |   %s   |   Markers %d",
		player:GetAttribute("MovementProfile") or "Athletic",
		Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude,
		if humanoid.FloorMaterial == Enum.Material.Air then "Airborne" else "Grounded",
		markers
	)
end)

RunService.PreSimulation:Connect(function()
	if not evade or not root or not character then
		return
	end
	local t = (workspace:GetServerTimeNow() - evade.start) / Config.Evade.Duration
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character }
	if
		t >= 1
		or workspace:Raycast(
			root.Position,
			evade.direction * (Config.Evade.WallClearance + 1),
			params
		)
	then
		evade = nil
		return
	end
	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = evade.direction
			* Math.evadeSpeed(t, Config.Evade.Speed, Config.Evade.EndSpeed)
		+ Vector3.new(0, velocity.Y, 0)
end)

if RunService:IsStudio() then
	local probe = Instance.new("BindableFunction")
	probe.Name = "MovementExperimentProbe"
	probe.OnInvoke = function(command: string, value: any)
		if command == "Move" then
			testMove, testUntil = value.direction, os.clock() + (value.duration or 1)
		elseif command == "Sprint" then
			sprinting = value
		elseif command == "Jump" and humanoid then
			testJumpUntil = os.clock() + 0.12
		elseif command == "Action" then
			return action(value.kind, value.direction)
		elseif command == "Aim" then
			setAim(value)
		elseif command == "Mark" then
			return markAim()
		elseif command == "Profile" then
			send("Profile", value)
		elseif command == "Respawn" then
			send("Respawn")
		end
		if not root or not humanoid then
			return { ready = false }
		end
		return {
			ready = true,
			position = root.Position,
			velocity = root.AssemblyLinearVelocity,
			cameraUp = if workspace.CurrentCamera
				then workspace.CurrentCamera.CFrame.UpVector.Y
				else 0,
			rootUp = root.CFrame.UpVector.Y,
			markers = markers,
			lastReject = lastReject,
			profile = player:GetAttribute("MovementProfile"),
			state = humanoid:GetState().Name,
		}
	end
	probe.Parent = player.PlayerScripts
end
