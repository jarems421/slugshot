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
local Traversal = require(script.Traversal)
local request = shared:WaitForChild("MovementRequest") :: RemoteEvent
local controls = require(player.PlayerScripts:WaitForChild("PlayerModule")):GetControls()
local library, privateClips = Clips.load()
require(script.Presentation).start(library)
local Acro = Config.Acrobatics
local Trav = Config.Traversal

local character: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local sprinting, aiming, crouching = false, false, false
local speed, move = 0, Vector3.zero
local sequence, pendingAction = 0, 0
local lastRoll = -math.huge
local airUsed = false
local acro: any = nil
local bufferedRoll, bufferedDirection = 0, nil :: Vector3?
local rays: RaycastParams? = nil
local overlap: OverlapParams? = nil
local hops, lastHop, lastGrounded = 0, -math.huge, 0
local lastMantle, lastMantleCheck = -math.huge, -math.huge
local jumpHeld, jumpWindow, lastJumpRequest = false, 0, -math.huge
local hopBuffer = 0
local testMove: Vector3? = nil
local testUntil = 0
local testJumpUntil = 0
local markers, lastAimSent = 0, 0
local lastReject = "none"
local rejectLog: { string } = {} -- recent rejections, for the Studio probe
local bindName = "SlugshotMovementExperiment"

local gui = Instance.new("ScreenGui")
gui.Name = "MovementSandboxHUD"
gui.ResetOnSpawn = false
local label = Instance.new("TextLabel")
label.Size = UDim2.fromOffset(780, 146)
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
		packet.rate, packet.time, packet.target = extra.rate, extra.time, extra.target
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
	sprinting, aiming, crouching, testMove = false, false, false, nil
	testUntil, testJumpUntil, pendingAction = 0, 0, 0
	rays, overlap = Traversal.params(newCharacter)
	hops, lastHop, lastMantle, lastGrounded = 0, -math.huge, -math.huge, os.clock()
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

local function setCrouch(value: boolean)
	if crouching == value then
		return
	end
	crouching = value
	if character then
		character:SetAttribute("Crouching", value)
	end
	send("Crouch", value)
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
	now: number,
	target: Vector3?
)
	if not character then
		return
	end
	character:SetAttribute("MovementAction", kind)
	character:SetAttribute("MovementVariant", variant)
	character:SetAttribute("MovementDirection", direction)
	character:SetAttribute("MovementRate", rate)
	character:SetAttribute("MovementActionTime", now)
	pendingAction = send(kind, variant, direction, { rate = rate, time = now, target = target })
end

-- Variant names for a clip and its alternatives (Name, Name.2, ...), present only.
local function variantNames(name: string): { string }
	local names = {}
	for index in Clips.variants(library, name) do
		table.insert(names, if index == 1 then name else `{name}.{index}`)
	end
	return names
end

local variantCounter = 0
local function pickVariant(name: string): string
	local names = variantNames(name)
	variantCounter += 1
	return names[variantCounter % math.max(#names, 1) + 1] or name
end

-- Grounded: roll toward the input. The clip whose root motion best matches the
-- direction relative to facing is chosen; the presentation turns the remainder.
-- A roll buffered before touchdown uses the landing roll when there is one.
local function startRoll(direction: Vector3, now: number, landing: boolean?): boolean
	if not character or not root or now - lastRoll < Acro.Roll.Cooldown then
		return false
	end
	local settings = Acro.Roll
	if settings.FaceInput and not aiming then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)
	end
	setCrouch(false)
	local localDirection = root.CFrame:VectorToObjectSpace(direction)
	local base, best = "RollForward", -math.huge
	for _, name in Config.Validation.RollVariants do
		local candidate = library[name]
		local score = if candidate and name ~= "RollLand"
			then candidate.direction:Dot(localDirection)
			else -math.huge
		if score > best then
			base, best = name, score
		end
	end
	local variant = if landing
			and base == "RollForward"
			and library.RollLand
		then "RollLand"
		else pickVariant(base)
	local clip = library[variant]
	local length = clip.events.recover or clip.duration
	local rate = math.clamp(length / settings.Duration, settings.MinRate, settings.MaxRate)
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
	local velocity = root.AssemblyLinearVelocity
	if velocity.Y < settings.Lift then
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, settings.Lift, velocity.Z)
	end
	local landIn = timeToLand(math.max(velocity.Y, settings.Lift))
	local variant = if landIn > settings.DropTime and library.FlipDrop
		then pickVariant("FlipDrop")
		else pickVariant(
			if input and input:Dot(facing) < settings.BackInputDot then "FlipBack" else "FlipFront"
		)
	local events = library[variant].events
	local airDuration = (events.land or 0.6) - (events.takeoff or 0)
	local rate = math.clamp(airDuration / landIn, settings.MinRate, settings.MaxRate)
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
	if humanoid.FloorMaterial ~= Enum.Material.Air and not acro then
		return startRoll(input or flat(root.CFrame.LookVector) or Vector3.new(0, 0, -1), now)
	end
	-- Mid-action, already flipped or too late for a flip to read: roll on touchdown
	-- (after a mantle, once it completes). A wall hop can flow into a flip.
	local busy = acro and acro.kind ~= "WallHop"
	if busy or airUsed or timeToLand(root.AssemblyLinearVelocity.Y) < Acro.LandingRollWindow then
		local remaining = if acro and acro.kind == "Mantle"
			then acro.duration - (now - acro.start)
			else 0
		bufferedRoll = os.clock() + math.max(remaining, 0) + Acro.LandingRollWindow + 0.1
		bufferedDirection = input
		return true
	end
	return startFlip(input, now)
end

-- FloorMaterial keeps reporting the floor for a few frames after takeoff.
local function grounded(): boolean
	return humanoid ~= nil
		and root ~= nil
		and humanoid.FloorMaterial ~= Enum.Material.Air
		and root.AssemblyLinearVelocity.Y < 8
end

local function smoothstep(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Jump into a ledge: close to the wall, then climb along the clip's advance/rise
-- curves while the root is placed kinematically (Physics state, zero velocity).
local function startMantle(now: number): boolean
	if acro or not character or not humanoid or not root or not rays or not overlap then
		return false
	end
	local settings = Trav.Mantle
	if os.clock() - lastMantle < settings.Cooldown or humanoid.Sit then
		return false
	end
	local state = humanoid:GetState()
	if
		state == Enum.HumanoidStateType.Swimming
		or state == Enum.HumanoidStateType.Climbing
		or state == Enum.HumanoidStateType.Dead
	then
		return false
	end
	local velocity = root.AssemblyLinearVelocity
	local approach = math.max(Vector3.new(velocity.X, 0, velocity.Z).Magnitude, speed)
	-- A thin, low obstacle taken at speed is vaulted instead of climbed onto; the
	-- check looks a little further ahead so an early jump press still vaults.
	local vault = Trav.Vault
	local ledge: Traversal.Ledge? = nil
	local target, lift, vaulting = CFrame.identity, 0, false
	if library.Vault and approach >= vault.MinSpeed then
		local ahead = table.clone(settings)
		ahead.Reach = settings.Reach + approach * vault.LookAhead
		ahead.MaxHeight = vault.MaxHeight
		local far = Traversal.findLedge(humanoid, root, ahead, rays, overlap)
		local landing, topY = nil, 0
		if far then
			landing, topY = Traversal.findVault(humanoid, root, far, vault, rays, overlap)
		end
		if far and landing then
			local feetY = root.Position.Y - Traversal.standOffset(humanoid, root)
			ledge, target, vaulting = far, landing, true
			lift = math.max(topY + vault.Clearance - feetY, 0)
		end
	end
	if not ledge then
		ledge = Traversal.findLedge(humanoid, root, settings, rays, overlap)
		if not ledge then
			return false
		end
		target = ledge.target
	end
	assert(ledge, "ledge resolved above")
	local variant = if vaulting
		then pickVariant("Vault")
		elseif ledge.height < settings.ParkourHeight and library.MantleVault then pickVariant(
			"MantleVault"
		)
		elseif ledge.height < settings.LowHeight then "MantleLow"
		else "MantleHigh"
	if variant == "MantleHigh" then
		variant = pickVariant(
			if ledge.height >= settings.HangHeight and library.MantleHang
				then "MantleHang"
				else "MantleHigh"
		)
	elseif variant == "MantleLow" then
		variant = pickVariant("MantleLow")
	end
	local clip = library[variant]
	local timing = settings.Duration
	local duration = math.max(
		math.clamp(timing.Base + ledge.height * timing.PerStud, timing.Min, timing.Max),
		clip.duration / settings.MaxRate
	)
	local from = root.CFrame
	local hang = ledge.wall + ledge.normal * settings.HangGap
	local gap = Vector3.new(hang.X - from.X, 0, hang.Z - from.Z)
	if gap:Dot(ledge.normal) > 0 then
		gap = Vector3.zero -- already closer than the hang distance
	end
	setCrouch(false)
	acro = {
		kind = "Mantle",
		start = now,
		clip = clip,
		rate = clip.duration / duration,
		duration = duration,
		from = from,
		to = target,
		gap = if vaulting then Vector3.zero else gap,
		over = Vector3.new(target.X - from.X, 0, target.Z - from.Z)
			- (if vaulting then Vector3.zero else gap),
		vault = vaulting,
		lift = lift,
		exit = math.clamp(approach * settings.ExitSpeed, settings.ExitMin, profile().SprintSpeed),
	}
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	root.AssemblyLinearVelocity = Vector3.zero
	announce("Mantle", variant, target.LookVector, acro.rate, now, target.Position)
	return true
end

local function finishMantle(completed: boolean)
	local mantle = acro
	acro = nil
	lastMantle = os.clock()
	if not mantle or not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	if completed then
		root.CFrame = mantle.to
		root.AssemblyLinearVelocity = mantle.to.LookVector * mantle.exit + Vector3.new(0, -1.5, 0)
		speed = mantle.exit
		humanoid:ChangeState(Enum.HumanoidStateType.Running)
	else
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
end

-- Kick away from a wall at `contact`: turn to face the launch and play the wall
-- jump clip for the side the wall is on (it ends facing the launch direction).
local function kickOff(now: number, launch: Vector3, up: number, away: Vector3, contact: Vector3)
	assert(root and humanoid, "kick needs a character")
	local direction = flat(launch) or away
	hops += 1
	lastHop = os.clock()
	if Trav.WallHop.RefreshFlip then
		airUsed = false
	end
	if not aiming then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)
	end
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	root.AssemblyLinearVelocity = launch + Vector3.new(0, up, 0)
	acro = {
		kind = "WallHop",
		start = now,
		duration = Trav.WallHop.LockTime,
		direction = direction,
		speed = launch.Magnitude,
	}
	-- The wall is behind-left when it lies to the left of the new facing.
	local wallLeft = (-away):Dot(direction:Cross(Vector3.yAxis)) < 0
	local clip = if wallLeft then "WallJumpLeft" else "WallJumpRight"
	announce(
		"WallHop",
		if library[clip] then pickVariant(clip) else "WallHop",
		direction,
		1,
		now,
		contact
	)
end

-- The wall last kicked off or run, which is not run again straight away.
local lastWallPart: Instance? = nil
local lastWallTime = -math.huge

-- Airborne jump beside a wall: kick away from it, keeping some along-wall speed.
local function tryWallHop(now: number): boolean
	if not character or not humanoid or not root or not rays then
		return false
	end
	local settings = Trav.WallHop
	local clock = os.clock()
	if
		(acro and acro.kind ~= "WallHop")
		or hops >= settings.MaxHops
		or grounded()
		or clock - lastGrounded < settings.GroundDelay
		or clock - lastHop < settings.Cooldown
	then
		return false
	end
	local hit = Traversal.findWall(humanoid, root, settings, rays)
	if not hit then
		return false
	end
	local away = flat(hit.Normal) or -(flat(root.CFrame.LookVector) or Vector3.new(0, 0, -1))
	local velocity = root.AssemblyLinearVelocity
	local along = Vector3.new(velocity.X, 0, velocity.Z)
	along -= away * along:Dot(away)
	if along.Magnitude > settings.MaxTangent then
		along = along.Unit * settings.MaxTangent
	end
	lastWallPart, lastWallTime = hit.Instance, clock
	kickOff(
		now,
		away * settings.AwaySpeed + along * settings.TangentCarry,
		settings.UpSpeed,
		away,
		hit.Position
	)
	return true
end

-- Airborne, running along a wall (not into it) with input along it: attach and
-- run along the wall. No button; the jump onto the wall is enough.
local function tryWallRun(now: number): boolean
	if acro or not character or not humanoid or not root or not rays then
		return false
	end
	local run = Trav.WallRun
	local clock = os.clock()
	if grounded() or clock - lastGrounded < Trav.WallHop.GroundDelay or humanoid.Health <= 0 then
		return false
	end
	local velocity = root.AssemblyLinearVelocity
	local travel = Vector3.new(velocity.X, 0, velocity.Z)
	if travel.Magnitude < run.MinAlong then
		return false
	end
	local stand = Traversal.standOffset(humanoid, root)
	if workspace:Raycast(root.Position, Vector3.new(0, -(stand + run.MinHeight), 0), rays) then
		return false -- too close to the ground
	end
	local hit = Traversal.findWall(humanoid, root, run, rays)
	if not hit or (hit.Instance == lastWallPart and clock - lastWallTime < run.Reattach) then
		return false
	end
	local away = flat(hit.Normal)
	local into = if away then -travel.Unit:Dot(away) else 0
	if not away or into > run.MaxInto or into < -0.35 then
		return false -- too head-on, or already moving away from it
	end
	local along = travel - away * travel:Dot(away)
	if along.Magnitude < run.MinAlong or move:Dot(along.Unit) < run.MinInput then
		return false
	end
	local direction = along.Unit
	-- Wall on the left when its normal points to the runner's right.
	local side = if away:Dot(direction:Cross(Vector3.yAxis)) > 0 then "Left" else "Right"
	setCrouch(false)
	acro = {
		kind = "WallRun",
		start = now,
		direction = direction,
		away = away,
		side = side,
		part = hit.Instance,
		contact = hit.Position,
		speed = math.max(along.Magnitude, run.Speed),
		-- Keep part of the jump's rise so the run starts climbing, then sinks slowly.
		rise = math.clamp(velocity.Y * run.Rise.Carry, run.Rise.Min, run.Rise.Max),
	}
	if not aiming then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)
	end
	announce("WallRun", "WallRun" .. side, direction, 1, now, hit.Position)
	return true
end

-- Leave the wall: Jump kicks off it; otherwise drop away from it.
local function endWallRun(now: number, jump: boolean)
	local wall = acro
	if not wall or wall.kind ~= "WallRun" or not root then
		return
	end
	acro = nil
	lastWallPart, lastWallTime = wall.part, os.clock()
	local run = Trav.WallRun
	if jump then
		kickOff(
			now,
			wall.away * run.JumpAway + wall.direction * wall.speed * run.JumpCarry,
			run.JumpUp,
			wall.away,
			wall.contact
		)
		return
	end
	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = wall.direction * wall.speed
		+ wall.away * run.Release
		+ Vector3.new(0, velocity.Y, 0)
	speed = math.min(wall.speed, profile().SprintSpeed)
end

-- Jump presses: kick off a wall being run; else a ledge ahead takes priority,
-- then a wall to kick off.
local function onJumpPress()
	jumpWindow = os.clock() + Trav.Mantle.JumpWindow
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	setCrouch(false)
	local now = workspace:GetServerTimeNow()
	if acro and acro.kind == "WallRun" then
		endWallRun(now, true)
		return
	end
	if not startMantle(now) and not tryWallHop(now) and not grounded() then
		hopBuffer = os.clock() + Trav.WallHop.Buffer -- retried each frame
	end
end

request.OnClientEvent:Connect(function(id: number, accepted: boolean, detail: string)
	if not accepted then
		lastReject = detail
		table.insert(rejectLog, detail)
		if #rejectLog > 10 then
			table.remove(rejectLog, 1)
		end
		if id == pendingAction and character then
			if acro and acro.kind == "Mantle" then
				finishMantle(false)
			end
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
		setCrouch(false)
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
bind("ExperimentCrouch", function(_, state)
	if state == Enum.UserInputState.Begin then
		setCrouch(not crouching)
	end
	return Enum.ContextActionResult.Sink
end, "Crouch", Enum.KeyCode.C, Enum.KeyCode.ButtonR3)
ContextActionService:BindAction("ExperimentHurt", function(_, state)
	if state == Enum.UserInputState.Begin then
		send("Hurt")
	end
end, false, Enum.KeyCode.H)
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
-- Space/ButtonA presses are jump presses. JumpRequest does not fire for them in
-- every case (it did not while airborne in Studio), so it only covers touch; it
-- repeats while held, so a gap marks a new press. Held jump keeps checking ledges.
local lastJumpPress = -math.huge
local function jumpPressed()
	local clock = os.clock()
	if clock - lastJumpPress > 0.12 then
		lastJumpPress = clock
		onJumpPress()
	end
end
UserInputService.JumpRequest:Connect(function()
	local clock = os.clock()
	if clock - lastJumpRequest > 0.12 and not jumpHeld then
		jumpPressed()
	end
	lastJumpRequest = clock
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if
		not processed
		and (input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA)
	then
		jumpHeld = true
		jumpPressed()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
		jumpHeld = false
	end
end)
UserInputService.WindowFocusReleased:Connect(function()
	jumpHeld = false
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
	local target = if crouching
		then Config.Crouch.Speed
		elseif sprinting then settings.SprintSpeed
		else settings.RunSpeed
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
	local kind = if acro then acro.kind else nil
	local rolling = kind == "Roll"
	if kind == "WallRun" and rays then
		-- Follow the wall surface; let go when it ends, input stops pointing along
		-- it (or points away), the ground arrives or time runs out.
		local run = Trav.WallRun
		local hit = workspace:Raycast(root.Position, -acro.away * (run.Reach + 0.6), rays)
		local away = hit and math.abs(hit.Normal.Y) < 0.35 and flat(hit.Normal)
		if away then
			local along = acro.direction - away * acro.direction:Dot(away)
			acro.away, acro.contact = away, hit.Position
			acro.direction = flat(along) or acro.direction
		end
		if
			not away
			or onGround
			or now - acro.start > run.MaxTime
			or move:Dot(acro.direction) < run.MinInput * 0.5
			or move:Dot(acro.away) > 0.5
		then
			endWallRun(now, false)
			kind = nil
		elseif not aiming then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + acro.direction)
		end
	elseif kind == "WallHop" and (now - acro.start > acro.duration or onGround) then
		local velocity = root.AssemblyLinearVelocity
		speed = math.min(Vector3.new(velocity.X, 0, velocity.Z).Magnitude, settings.SprintSpeed)
		acro, kind = nil, nil
	end
	if not acro and not onGround then
		if tryWallRun(now) then
			kind = "WallRun"
		end
	end
	if rolling or kind == "WallHop" or kind == "WallRun" then
		-- Drive the Humanoid along the roll/kick so its controller cooperates with
		-- the action's velocity instead of braking or air-steering against it.
		humanoid.WalkSpeed = acro.speed or 0
		humanoid:Move(acro.direction, false)
	elseif kind == "Mantle" then
		humanoid.WalkSpeed = 0
		humanoid:Move(Vector3.zero, false)
	else
		humanoid:Move(move, false)
	end
	if
		not acro
		and (jumpHeld or os.clock() < jumpWindow)
		and os.clock() - lastMantleCheck >= Trav.Mantle.CheckInterval
	then
		lastMantleCheck = os.clock()
		startMantle(now)
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
	if bufferedRoll > 0 and onGround and not (acro and acro.kind == "Mantle") then
		if os.clock() < bufferedRoll and not acro then
			startRoll(
				bufferedDirection
					or flat(move)
					or flat(root.CFrame.LookVector)
					or Vector3.new(0, 0, -1),
				now,
				true
			)
		end
		bufferedRoll = 0
	end
	humanoid.AutoRotate = not aiming and not acro
	if aiming and not (acro and acro.kind == "Mantle") then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + forward)
		if os.clock() - lastAimSent > 0.2 then
			lastAimSent = os.clock()
			send("Aim", true, camera.CFrame.LookVector)
		end
	end
	if humanoid.FloorMaterial ~= Enum.Material.Air then
		airUsed = false
	end
	if grounded() then
		hops, hopBuffer = 0, 0
		lastGrounded = os.clock()
	elseif os.clock() < hopBuffer and tryWallHop(now) then
		hopBuffer = 0
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
		"SLUGSHOT / MOVEMENT LAB v4.1   •   %s   •   %s\nWASD move · Shift sprint · C crouch · Space jump · Q roll (ground) / flip (air; hold back = backflip)\nSpace into a ledge: mantle (low wall at speed: vault) · jump onto a wall running along it: wall run (Space: kick off) · by a wall in the air: wall jump\nRMB aim · Click marker · H test hit reaction · P profiles · R reset\nSpeed %.1f   |   %s   |   Markers %d",
		player:GetAttribute("MovementProfile") or "Athletic",
		if privateClips > 0 then `original + {privateClips} private clips` else "original clips",
		Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude,
		if humanoid.FloorMaterial == Enum.Material.Air then "Airborne" else "Grounded",
		markers
	)
end)

RunService.PreSimulation:Connect(function()
	if acro and acro.kind == "WallRun" and root then
		-- Along the wall, held lightly against it: a small rise that light wall
		-- gravity turns into a slow sink.
		local run = Trav.WallRun
		local elapsed = workspace:GetServerTimeNow() - acro.start
		local gap = (root.Position - acro.contact):Dot(acro.away)
		local pull = run.Stick + math.clamp((gap - run.Hug) * 10, 0, 14)
		root.AssemblyLinearVelocity = acro.direction * acro.speed
			- acro.away * pull
			+ Vector3.new(0, acro.rise - run.Gravity * elapsed, 0)
		return
	end
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

-- Mantle path, after physics so the placed root is what renders.
RunService.Heartbeat:Connect(function()
	if not acro or acro.kind ~= "Mantle" or not root or not humanoid then
		return
	end
	if humanoid.Health <= 0 or not root.Parent then
		finishMantle(false)
		return
	end
	local t = (workspace:GetServerTimeNow() - acro.start) * acro.rate
	if t >= acro.clip.duration then
		finishMantle(true)
		return
	end
	local progress = Clips.climb(acro.clip, t)
	local close = smoothstep(t / (acro.clip.duration * 0.3))
	local from, to = acro.from.Position, acro.to.Position
	-- Climbs rise with the clip; vaults travel over, lifted by the clip's arc.
	local rise = if acro.vault
		then (to.Y - from.Y) * progress.X + acro.lift * progress.Y
		else (to.Y - from.Y) * progress.Y
	local position = from + acro.gap * close + acro.over * progress.X + Vector3.new(0, rise, 0)
	local startFacing = flat(acro.from.LookVector) or acro.to.LookVector
	local facing = flat(startFacing:Lerp(acro.to.LookVector, close)) or acro.to.LookVector
	root.CFrame = CFrame.lookAt(position, position + facing)
	root.AssemblyLinearVelocity = Vector3.zero
end)

if RunService:IsStudio() then
	local probe = Instance.new("BindableFunction")
	probe.Name = "MovementExperimentProbe"
	probe.OnInvoke = function(command: string, value: any)
		if command == "Move" then
			testMove, testUntil = value.direction, os.clock() + (value.duration or 1)
		elseif command == "Sprint" then
			sprinting = value
		elseif command == "Crouch" then
			setCrouch(value)
		elseif command == "Hurt" then
			send("Hurt")
		elseif command == "Jump" and humanoid then
			testJumpUntil = os.clock() + 0.12
		elseif command == "JumpPress" and humanoid then
			-- A real jump press: native jump plus the traversal checks.
			testJumpUntil = os.clock() + 0.12
			onJumpPress()
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
			rejects = rejectLog,
			profile = player:GetAttribute("MovementProfile"),
			state = humanoid:GetState().Name,
			privateClips = privateClips,
			acro = if acro then acro.kind else "",
			hops = hops,
			variant = character and character:GetAttribute("MovementVariant"),
			rendered = character and character:GetAttribute("RenderedAction"),
			renderedMove = character and character:GetAttribute("RenderedMove"),
			renderedClip = character and character:GetAttribute("RenderedClip"),
			crouching = crouching,
			airState = character and character:GetAttribute("RenderedAirState"),
			footOffset = character and character:GetAttribute("RenderedFootOffset"),
			phase = character and character:GetAttribute("RenderedCyclePhase"),
		}
	end
	probe.Parent = player.PlayerScripts
end
