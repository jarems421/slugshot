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
local Clips = require(shared.Clips)
local request = shared:WaitForChild("MovementRequest") :: RemoteEvent
local controls = require(player.PlayerScripts:WaitForChild("PlayerModule")):GetControls()
local library, privateClips = Clips.load()
require(script.Presentation).start(library)
local Acro = Config.Acrobatics

local character: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local sprinting, aiming = false, false
local speed, move = 0, Vector3.zero
local sequence, pendingAction = 0, 0
local lastRoll = -math.huge
local airUsed = false
local acro: any = nil
local bufferedRoll, bufferedDirection = 0, nil :: Vector3?
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

local function send(kind: string, value: any?, direction: Vector3?, extra: any?): number
	sequence += 1
	local packet: any = { sequence = sequence, kind = kind, value = value, direction = direction }
	if extra then
		packet.rate, packet.time = extra.rate, extra.time
	end
	request:FireServer(packet)
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
	speed, move, acro, airUsed, bufferedRoll = 0, Vector3.zero, nil, false, 0
	sprinting, aiming, testMove = false, false, nil
	testUntil, testJumpUntil, pendingAction = 0, 0, 0
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	lastRoll = -math.huge
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

local function flat(vector: Vector3): Vector3?
	local result = Vector3.new(vector.X, 0, vector.Z)
	return if result.Magnitude > 0.01 then result.Unit else nil
end

-- Seconds until the character lands, from the floor distance and vertical speed.
local function timeToLand(verticalSpeed: number): number
	if not character or not humanoid or not root then
		return math.huge
	end
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character }
	local stand = humanoid.HipHeight + root.Size.Y / 2
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -(stand + 200), 0), params)
	if not hit then
		return math.huge
	end
	local height = math.max(0, root.Position.Y - hit.Position.Y - stand)
	local gravity = workspace.Gravity
	return (verticalSpeed + math.sqrt(verticalSpeed * verticalSpeed + 2 * gravity * height))
		/ gravity
end

local function announce(
	kind: string,
	variant: string,
	direction: Vector3,
	rate: number,
	now: number
)
	if not character then
		return
	end
	character:SetAttribute("MovementAction", kind)
	character:SetAttribute("MovementVariant", variant)
	character:SetAttribute("MovementDirection", direction)
	character:SetAttribute("MovementRate", rate)
	character:SetAttribute("MovementActionTime", now)
	pendingAction = send(kind, variant, direction, { rate = rate, time = now })
end

-- Grounded: roll toward the input. The clip whose root motion best matches the
-- direction relative to facing is chosen; the presentation turns the remainder.
local function startRoll(direction: Vector3, now: number): boolean
	if not character or not root or now - lastRoll < Acro.Roll.Cooldown then
		return false
	end
	local settings = Acro.Roll
	if settings.FaceInput and not aiming then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)
	end
	local localDirection = root.CFrame:VectorToObjectSpace(direction)
	local variant, best = "RollForward", -math.huge
	for _, name in Config.Validation.RollVariants do
		local score = library[name].direction:Dot(localDirection)
		if score > best then
			variant, best = name, score
		end
	end
	local clip = library[variant]
	local rate = settings.PlaybackRate
	local length = clip.events.recover or clip.duration
	local travel = math.max(Clips.motion(clip, length):Dot(clip.direction), 0.05)
	lastRoll = now
	acro = {
		kind = "Roll",
		start = now,
		clip = clip,
		rate = rate,
		direction = direction,
		scale = settings.Distance / travel,
		duration = length / rate,
	}
	announce("Roll", variant, direction, rate, now)
	return true
end

-- Airborne: front flip, or backflip when input points behind the facing.
local function startFlip(input: Vector3?, now: number): boolean
	if not character or not root or airUsed then
		return false
	end
	local settings = Acro.Flip
	local facing = flat(root.CFrame.LookVector) or Vector3.new(0, 0, -1)
	local variant = if input and input:Dot(facing) < settings.BackInputDot
		then "FlipBack"
		else "FlipFront"
	local velocity = root.AssemblyLinearVelocity
	if velocity.Y < settings.Lift then
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, settings.Lift, velocity.Z)
	end
	local events = library[variant].events
	local airDuration = (events.land or 0.6) - (events.takeoff or 0)
	local rate = math.clamp(
		airDuration / timeToLand(math.max(velocity.Y, settings.Lift)),
		settings.MinRate,
		settings.MaxRate
	)
	airUsed = true
	acro = { kind = "Flip", start = now, duration = airDuration / rate }
	announce("Flip", variant, facing, rate, now)
	return true
end

local function acrobatics(requested: Vector3?): boolean
	if not character or not humanoid or not root or humanoid.Health <= 0 then
		return false
	end
	local now = workspace:GetServerTimeNow()
	local input = if requested
		then flat(requested)
		elseif move.Magnitude > 0.1 then flat(move)
		else nil
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		return not acro
			and startRoll(input or flat(root.CFrame.LookVector) or Vector3.new(0, 0, -1), now)
	end
	-- Mid-flip, already flipped or too late for a flip to read: roll on touchdown.
	if acro or airUsed or timeToLand(root.AssemblyLinearVelocity.Y) < Acro.LandingRollWindow then
		bufferedRoll, bufferedDirection = os.clock() + Acro.LandingRollWindow + 0.1, input
		return true
	end
	return startFlip(input, now)
end

request.OnClientEvent:Connect(function(id: number, accepted: boolean, detail: string)
	if not accepted then
		lastReject = detail
		if id == pendingAction and character then
			acro = nil
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
bind("ExperimentAcrobatics", function(_, state)
	if state == Enum.UserInputState.Begin then
		acrobatics(nil)
	end
	return Enum.ContextActionResult.Sink
end, "Roll/Flip", Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
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
	local now = workspace:GetServerTimeNow()
	local onGround = humanoid.FloorMaterial ~= Enum.Material.Air
	local rolling = acro and acro.kind == "Roll"
	if rolling then
		-- Drive the Humanoid along the roll so its ground controller cooperates
		-- with the root-motion velocity instead of braking against it.
		humanoid.WalkSpeed = acro.speed or 0
		humanoid:Move(acro.direction, false)
	else
		humanoid:Move(move, false)
	end
	if os.clock() < testJumpUntil then
		humanoid.Jump = true
	end
	if rolling and humanoid.Jump then
		-- Jump cancels only the end of a roll.
		if now - acro.start < acro.duration * Acro.Roll.JumpCancel then
			humanoid.Jump = false
		else
			acro = nil
		end
	end
	if
		acro
		and acro.kind == "Flip"
		and (now - acro.start > acro.duration or onGround and now - acro.start > 0.15)
	then
		acro = nil
	end
	if bufferedRoll > 0 and onGround then
		if os.clock() < bufferedRoll and not acro then
			startRoll(
				bufferedDirection
					or flat(move)
					or flat(root.CFrame.LookVector)
					or Vector3.new(0, 0, -1),
				now
			)
		end
		bufferedRoll = 0
	end
	humanoid.AutoRotate = not aiming and not acro
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
		"SLUGSHOT / MOVEMENT LAB v2   •   %s   •   %s\nWASD move · Shift run · Space jump · Q roll (ground) / flip (air; hold back = backflip)\nRMB aim · Click harmless marker · P compare profiles · R reset\nSpeed %.1f   |   %s   |   Markers %d",
		player:GetAttribute("MovementProfile") or "Athletic",
		if privateClips > 0 then `original + {privateClips} private clips` else "original clips",
		Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude,
		if humanoid.FloorMaterial == Enum.Material.Air then "Airborne" else "Grounded",
		markers
	)
end)

RunService.PreSimulation:Connect(function()
	if not acro or acro.kind ~= "Roll" or not root or not character then
		return
	end
	local elapsed = workspace:GetServerTimeNow() - acro.start
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = { character }
	local blocked =
		workspace:Raycast(root.Position, acro.direction * (Acro.Roll.WallClearance + 1), params)
	if elapsed >= acro.duration or blocked then
		local velocity = root.AssemblyLinearVelocity
		speed = math.min(Vector3.new(velocity.X, 0, velocity.Z).Magnitude, profile().SprintSpeed)
		acro = nil
		return
	end
	-- Follow the clip's own root-motion profile, scaled to the configured distance.
	local along = Clips.motionVelocity(acro.clip, elapsed * acro.rate):Dot(acro.clip.direction)
		* acro.scale
		* acro.rate
	local velocity = root.AssemblyLinearVelocity
	acro.speed = math.clamp(along, 0, Acro.Roll.MaxSpeed)
	root.AssemblyLinearVelocity = acro.direction * acro.speed + Vector3.new(0, velocity.Y, 0)
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
			return acrobatics(value.direction)
		elseif command == "Aim" then
			setAim(value)
		elseif command == "Mark" then
			return markAim()
		elseif command == "Profile" then
			send("Profile", value)
		elseif command == "Respawn" then
			send("Respawn")
		elseif command == "Pose" and character then
			-- Hold a clip frame for visual inspection (nil clears).
			character:SetAttribute("DebugClip", value and value.clip)
			character:SetAttribute("DebugTime", value and value.time)
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
			privateClips = privateClips,
			acro = if acro then acro.kind else "",
			variant = character and character:GetAttribute("MovementVariant"),
			rendered = character and character:GetAttribute("RenderedAction"),
			airState = character and character:GetAttribute("RenderedAirState"),
			footOffset = character and character:GetAttribute("RenderedFootOffset"),
			phase = character and character:GetAttribute("RenderedCyclePhase"),
		}
	end
	probe.Parent = player.PlayerScripts
end
