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
-- Roblox's own PlayerModule only exists at run time, so it is required untyped.
local playerModule = player.PlayerScripts:WaitForChild("PlayerModule") :: ModuleScript
local controls = (require :: any)(playerModule):GetControls()
local library, privateClips = Clips.load()
require(script.Presentation).start(library)
local Acro = Config.Acrobatics
local Trav = Config.Traversal

local character: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil
local sprinting, aiming = false, false
local speed, move = 0, Vector3.zero
local sequence, pendingAction = 0, 0
local airUsed = false
local acro: any = nil
local rays: RaycastParams? = nil
local overlap: OverlapParams? = nil
local hops, lastHop, lastGrounded = 0, -math.huge, 0
local lastMantle, lastMantleCheck = -math.huge, -math.huge
local jumpHeld, jumpWindow, lastJumpRequest = false, 0, -math.huge
local hopBuffer = 0
local flipBuffer, groundPress = 0, -math.huge -- a double jump pressed too early, and the last jump press
local slideBuffer, slideHeld = 0, false -- a slide pressed before it could start, and Shift down
local bouncing = false -- a ground jump in the air (Profiles.JumpGravity applies)
-- Ctrl shift lock (owner, 2026-10-30; Roblox's own is off so Shift can slide): mouse
-- locked to the centre, body facing the camera, camera over the right shoulder.
local shiftLocked, lockBlend, cameraBase = false, 0, Vector3.zero
local sprintShake = 0 -- 0..1, how much of the sprint camera shake is applied
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
	local newHumanoid = newCharacter:WaitForChild("Humanoid") :: Humanoid
	character = newCharacter
	humanoid = newHumanoid
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
	local animator = newHumanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in animator:GetPlayingAnimationTracks() do
			track:Stop(0)
		end
	end
	speed, move, acro, airUsed, slideBuffer = 0, Vector3.zero, nil, false, 0
	bouncing = false
	sprinting, aiming, testMove = false, false, nil
	testUntil, testJumpUntil, pendingAction = 0, 0, 0
	rays, overlap = Traversal.params(newCharacter)
	hops, lastHop, lastMantle, lastGrounded = 0, -math.huge, -math.huge, os.clock()
	-- Every touchdown restores the flip, including a landing that jumps again on the
	-- same frame, which the per-frame grounded check can miss.
	newHumanoid.StateChanged:Connect(function(_, state)
		if state == Enum.HumanoidStateType.Landed then
			airUsed, hops = false, 0
		end
		-- Jumping also fires for a double jump (airUsed) or a kick (hops/acro); the
		-- extra pull checks those every step as well.
		if state == Enum.HumanoidStateType.Jumping then
			bouncing = not airUsed and hops == 0 and not acro
		elseif state ~= Enum.HumanoidStateType.Freefall then
			bouncing = false
		end
	end)
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	newHumanoid.UseJumpPower = true
	newHumanoid.JumpPower = profile().JumpPower
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraSubject = newHumanoid
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
	if not character or not humanoid or not root or not rays then
		return math.huge
	end
	local stand = Clips.standHeight(humanoid, root)
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -(stand + 200), 0), rays)
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

-- The double jump: a fresh upward launch that flips toward the held direction, read
-- as on screen. The body turns to the camera's facing and flips one of eight ways (W
-- front, W+D front-right, D right, S+D back-right, S back...), carrying the current
-- speed toward the input.
local lastFlip = "none" -- shown on the HUD
local FLIP_SECTORS = {
	"FlipFront",
	"FlipFrontRight",
	"FlipRight",
	"FlipBackRight",
	"FlipBack",
	"FlipBackLeft",
	"FlipLeft",
	"FlipFrontLeft",
}
local function startFlip(input: Vector3?, now: number): boolean
	if not character or not root or not humanoid or airUsed then
		return false
	end
	local settings = Acro.Flip
	local camera = workspace.CurrentCamera
	local facing = (if camera then flat(camera.CFrame.LookVector) else nil)
		or flat(root.CFrame.LookVector)
		or Vector3.new(0, 0, -1)
	local base = "FlipFront"
	if input then
		local angle = math.atan2(input:Dot(facing:Cross(Vector3.yAxis)), input:Dot(facing))
		base = FLIP_SECTORS[math.round(angle / (math.pi / 4)) % 8 + 1]
	end
	if not aiming then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + facing)
	end
	local velocity = root.AssemblyLinearVelocity
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	if input then
		horizontal = input * horizontal.Magnitude
	end
	humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	root.AssemblyLinearVelocity = horizontal + Vector3.new(0, settings.DoubleJump, 0)
	local landIn = timeToLand(settings.DoubleJump)
	local variant = pickVariant(base)
	lastFlip = variant
	local events = library[variant].events
	local airDuration = (events.land or 0.6) - (events.takeoff or 0)
	local rate = math.clamp(airDuration / landIn, settings.MinRate, settings.MaxRate)
	airUsed = true
	acro = { kind = "Flip", start = now, duration = airDuration / rate }
	announce("Flip", variant, facing, rate, now)
	return true
end

-- FloorMaterial keeps reporting the floor for a few frames after takeoff.
local function grounded(): boolean
	return humanoid ~= nil
		and root ~= nil
		and humanoid.FloorMaterial ~= Enum.Material.Air
		and root.AssemblyLinearVelocity.Y < 8
end

-- Grounded, or standing on an edge the Humanoid's own floor check misses: something
-- under the body's footprint and not rising.
local function standing(): boolean
	if grounded() then
		return true
	end
	if not humanoid or not root or not rays or root.AssemblyLinearVelocity.Y >= 8 then
		return false
	end
	local radius = Acro.Jump.Footprint
	local drop = Clips.standHeight(humanoid, root) - radius + 0.35
	return workspace:Spherecast(root.Position, radius, Vector3.new(0, -drop, 0), rays) ~= nil
end

-- Shift while running: slide the way the body is moving, boosted, slowing over
-- Acrobatics.Slide.Duration (driven in PreSimulation).
local lastSlide = -math.huge
local function startSlide(now: number): boolean
	if
		acro
		or not character
		or not root
		or not humanoid
		or humanoid.Health <= 0
		or not grounded()
	then
		return false
	end
	local settings = Acro.Slide
	local velocity = root.AssemblyLinearVelocity
	local ground = Vector3.new(velocity.X, 0, velocity.Z)
	if ground.Magnitude < settings.MinSpeed or os.clock() - lastSlide < settings.Cooldown then
		return false
	end
	local direction = ground.Unit
	local boosted =
		math.min(math.max(ground.Magnitude, profile().RunSpeed) + settings.Boost, settings.MaxSpeed)
	lastSlide = os.clock()
	acro = { kind = "Slide", start = now, direction = direction, speed0 = boosted, speed = boosted }
	if not aiming then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + direction)
	end
	announce("Slide", "Slide", direction, 1, now)
	return true
end

-- Leave a slide keeping its momentum (a jump carries it into the air). The local
-- presentation ends the pose from MovementActionEnd; observers see the slide stop.
local function endSlide()
	if not acro or acro.kind ~= "Slide" or not root or not character then
		return
	end
	local velocity = root.AssemblyLinearVelocity
	speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	acro = nil
	character:SetAttribute("MovementActionEnd", workspace:GetServerTimeNow())
end

-- How far below the ledge top the feet are predicted to be when the body reaches
-- the ledge face, for the jump about to start or under way (negative: above it).
-- Ledges too low above the ground to be worth mantling return -math.huge.
local function jumpShortfall(ledge: Traversal.Ledge): number
	assert(humanoid and root, "jump check needs a character")
	local settings = Trav.Mantle
	local offset = Traversal.standOffset(humanoid, root)
	local topY = ledge.target.Y - offset - 0.12
	-- Low ledges (steps, small boxes) are never mantled, whatever the jump does.
	local ground = workspace:Raycast(root.Position, Vector3.new(0, -60, 0), rays)
	if ground and topY - ground.Position.Y < settings.MinGroundHeight then
		return -math.huge
	end
	local velocity = root.AssemblyLinearVelocity
	local onGround = grounded()
	local rise = if onGround then profile().JumpPower else velocity.Y
	local bounce = onGround or (bouncing and not airUsed and hops == 0)
	local gravity = workspace.Gravity * (if bounce then profile().JumpGravity else 1)
	local toward = -ledge.normal
	local approach =
		math.max(Vector3.new(velocity.X, 0, velocity.Z):Dot(toward), settings.ClearApproach)
	local face = ledge.wall - root.Position
	local t = math.max(Vector3.new(face.X, 0, face.Z):Dot(toward) - 1, 0) / approach
	local feetY = root.Position.Y - offset + rise * t - 0.5 * gravity * t * t
	return topY - feetY
end

-- Jump into a ledge the jump would not clear: close to the wall, then climb along
-- the clip's advance/rise curves while the root is placed kinematically (Physics
-- state, zero velocity). `direction` looks for the ledge that way (the wall being
-- run) instead of along the input; a kick or wall run in progress gives way.
local function startMantle(now: number, direction: Vector3?): boolean
	if
		(acro and acro.kind ~= "WallHop" and acro.kind ~= "WallRun" and acro.kind ~= "Flip")
		or not character
		or not humanoid
		or not root
		or not rays
		or not overlap
	then
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
	local vaultTime, vaultFace = 0, 0
	local shortfall = 0
	if approach >= vault.MinSpeed and not direction then
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
			-- Keep the approach speed: the hands plant as the body reaches the wall,
			-- and the landing is as far past it as the speed carries.
			local into = -far.normal
			local speedIn = math.max(approach, vault.MinSpeed)
			local toFace = math.max(
				Vector3.new(far.wall.X - root.Position.X, 0, far.wall.Z - root.Position.Z):Dot(into),
				0.5
			)
			local depth = (landing.Position - far.wall):Dot(into) - vault.LandDistance
			vaultTime =
				math.clamp(toFace / (speedIn * vault.PlantAt), vault.Time.Min, vault.Time.Max)
			local carry = speedIn * vaultTime * (1 - vault.PlantAt) - depth
			if carry > vault.LandDistance + 0.5 then
				local farther = table.clone(vault)
				farther.LandDistance = math.min(carry, vault.MaxLand)
				local landingFar = Traversal.findVault(humanoid, root, far, farther, rays, overlap)
				if landingFar then
					target = landingFar
				end
			end
			local total = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
				:Dot(into)
			vaultFace = math.clamp(toFace / math.max(total, 0.1), 0.05, 0.95)
		end
	end
	if not ledge then
		ledge = Traversal.findLedge(humanoid, root, settings, rays, overlap, direction)
		if not ledge then
			return false
		end
		-- A jump that clears the top is just a jump onto it (from a wall, the top is
		-- always taken).
		shortfall = jumpShortfall(ledge)
		if shortfall <= -settings.ClearMargin and not direction then
			return false
		end
		shortfall = math.max(shortfall, 0)
		target = ledge.target
	end
	assert(ledge, "ledge resolved above")
	-- Kong vault over a thin wall; a pop-up when the jump nearly reaches the top;
	-- otherwise a step-up or climb-up by height.
	local variant = pickVariant(
		if vaulting
			then "Vault"
			elseif shortfall < settings.ParkourReach then "MantleVault"
			elseif ledge.height < settings.LowHeight then "MantleLow"
			else "MantleHigh"
	)
	local clip = library[variant]
	local timing = settings.Duration
	local duration = math.max(
		if vaulting
			then vaultTime
			else math.clamp(
				timing.Base + ledge.height * timing.PerStud,
				timing.Min,
				timing.Max
			),
		clip.duration / settings.MaxRate
	)
	local from = root.CFrame
	local hang = ledge.wall + ledge.normal * settings.HangGap
	local gap = Vector3.new(hang.X - from.X, 0, hang.Z - from.Z)
	if gap:Dot(ledge.normal) > 0 then
		gap = Vector3.zero -- already closer than the hang distance
	end
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
		face = vaultFace, -- vaults: fraction of the way over at the hand plant
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

-- Kick off a wall at `contact`: turn to face the launch and play the wall jump
-- clip for the side the wall is on (it ends facing the launch direction). An
-- up-kick keeps its facing (`face`) and plays the jump clip instead.
local function kickOff(
	now: number,
	launch: Vector3,
	up: number,
	away: Vector3,
	contact: Vector3,
	face: Vector3?
)
	assert(root and humanoid, "kick needs a character")
	local direction = face or flat(launch) or away
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
	local variant = if face
		then "WallKickUp"
		elseif library[clip] then pickVariant(clip)
		else "WallHop"
	announce("WallHop", variant, direction, 1, now, contact)
end

-- Launch for a kick off a wall (owner: full control of the direction, from a run
-- or a wall run). The kick goes where the input points, camera relative, or where
-- the camera faces with no input, turned off the wall so it leaves at MinOut or
-- more; speed already going that way is kept. Input almost straight into the wall
-- leaps up it instead, once per wall per airtime. Returns the launch, the up speed
-- and, for an up-kick, the facing kept.
local upKickWall: Instance? = nil -- the wall already leapt up this airtime
local function kickLaunch(
	away: Vector3,
	along: Vector3,
	kickSpeed: number,
	up: number,
	part: Instance?
): (Vector3, number, Vector3?)
	local settings = Trav.WallHop
	local camera = workspace.CurrentCamera
	local wanted: Vector3 = (
		if move.Magnitude > 0.1
			then flat(move)
			elseif camera then flat(camera.CFrame.LookVector)
			else nil
	) or away
	if -wanted:Dot(away) > settings.UpInto and part ~= nil and part ~= upKickWall then
		upKickWall = part
		local face = if root then flat(root.CFrame.LookVector) else nil
		return away * settings.Up.Away + along * settings.Up.Carry, settings.Up.Speed, face or -away
	end
	local out = math.max(wanted:Dot(away), settings.MinOut)
	local side = flat(wanted - away * wanted:Dot(away))
	local direction = if side then side * math.sqrt(1 - out * out) + away * out else away
	return direction * math.max(kickSpeed, along:Dot(direction)), up, nil
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
		(acro and acro.kind ~= "WallHop" and acro.kind ~= "Flip")
		or hops >= settings.MaxHops
		or standing()
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
	local launch, up, face = kickLaunch(
		away,
		along * settings.TangentCarry,
		settings.AwaySpeed,
		settings.UpSpeed,
		hit.Instance
	)
	kickOff(now, launch, up, away, hit.Position, face)
	return true
end

-- A wall to kick off is in reach, or the body is heading for one it will reach within
-- the hop buffer.
local function wallComing(): boolean
	if not humanoid or not root or not rays or hops >= Trav.WallHop.MaxHops then
		return false
	end
	local settings = Trav.WallHop
	local hit =
		Traversal.findWall(humanoid, root, { Reach = settings.Reach + settings.LookAhead }, rays)
	local away = if hit then flat(hit.Normal) else nil
	if not hit or not away then
		return false
	end
	local velocity = root.AssemblyLinearVelocity
	local toward = math.max(-Vector3.new(velocity.X, 0, velocity.Z):Dot(away), 0)
	return hit.Distance - toward * settings.Buffer <= settings.Reach
end

-- Airborne, running along a wall (not into it) with input along it: attach and
-- run along the wall. No button; the jump onto the wall is enough.
local function tryWallRun(now: number, input: Vector3): boolean
	-- A double-jump flip gives way at once (owner: flipping onto a wall slid down it
	-- until the flip ended before the run caught).
	if (acro and acro.kind ~= "Flip") or not character or not humanoid or not root or not rays then
		return false
	end
	local run = Trav.WallRun
	local clock = os.clock()
	if grounded() or clock - lastGrounded < run.GroundDelay or humanoid.Health <= 0 then
		return false
	end
	local velocity = root.AssemblyLinearVelocity
	local travel = Vector3.new(velocity.X, 0, velocity.Z)
	local stand = Traversal.standOffset(humanoid, root)
	if workspace:Raycast(root.Position, Vector3.new(0, -(stand + run.MinHeight), 0), rays) then
		return false -- too close to the ground
	end
	local hit = Traversal.findWall(humanoid, root, run, rays)
	if not hit or (hit.Instance == lastWallPart and clock - lastWallTime < run.Reattach) then
		return false
	end
	local away = flat(hit.Normal)
	if not away then
		return false
	end
	-- Running along the wall (not head-on, input along it) attaches at run speed.
	local along = travel - away * travel:Dot(away)
	local into = if travel.Magnitude > 0.01 then -travel.Unit:Dot(away) else 0
	local running = along.Magnitude >= run.MinAlong
		and into <= run.MaxInto
		and into >= -0.35
		and input:Dot(along.Unit) >= run.MinInput
	-- Owner (2026-10-30): jumping onto a wall and doing nothing clings to it, dragging
	-- slowly down. Moving or holding into the wall attaches too, unless there is a
	-- ledge in reach to mantle instead.
	local clinging = not running
		and (-travel:Dot(away) > run.Cling.Into or input:Dot(-away) > 0.5)
		and Traversal.findLedge(
				humanoid,
				root,
				Trav.Mantle,
				rays,
				overlap :: OverlapParams,
				-away
			)
			== nil
	if not running and not clinging then
		return false
	end
	local direction = if along.Magnitude > 0.5
		then along.Unit
		else flat(root.CFrame.RightVector - away * root.CFrame.RightVector:Dot(away)) or away:Cross(
			Vector3.yAxis
		)
	-- Wall on the left when its normal points to the runner's right.
	local side = if away:Dot(direction:Cross(Vector3.yAxis)) > 0 then "Left" else "Right"
	acro = {
		kind = "WallRun",
		start = now,
		direction = direction,
		away = away,
		side = side,
		part = hit.Instance,
		contact = hit.Position,
		speed = if running then math.max(along.Magnitude, run.Speed) else 0,
		-- Keep part of the jump's rise; Jump held then climbs, released slides down.
		vy = math.clamp(velocity.Y * run.Rise.Carry, run.Rise.Min, run.Rise.Max),
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
		local launch, up, face = kickLaunch(
			wall.away,
			wall.direction * wall.speed * run.JumpCarry,
			run.JumpAway,
			run.JumpUp,
			wall.part
		)
		kickOff(now, launch, up, wall.away, wall.contact, face)
		return
	end
	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = wall.direction * wall.speed
		+ wall.away * run.Release
		+ Vector3.new(0, velocity.Y, 0)
	speed = math.min(wall.speed, Trav.WallHop.MaxCarry)
end

-- From a wall run: mantle onto the top of the wall when it is in reach.
local function mantleFromWall(now: number): boolean
	local wall = acro
	if not wall or wall.kind ~= "WallRun" or not startMantle(now, -wall.away) then
		return false
	end
	lastWallPart, lastWallTime = wall.part, os.clock()
	return true
end

-- Jump presses: on a wall run, mantle its top or start a climb/kick; else a ledge
-- ahead takes priority, then a wall to kick off.
local function onJumpPress()
	jumpWindow = os.clock() + Trav.Mantle.JumpWindow
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	local now = workspace:GetServerTimeNow()
	if acro and acro.kind == "Slide" then
		endSlide() -- slide cancel: the jump (or mantle) carries the slide's speed
	end
	if acro and acro.kind == "WallRun" then
		-- Owner (2026-10-30): a press holding away from the wall (or back against the run)
		-- jumps off at once; any other press mantles over the top when it is in reach;
		-- otherwise it climbs, and letting go within TapTime is a tap that kicks off
		-- (see InputEnded).
		local wanted = if move.Magnitude > 0.1 then flat(move) else nil
		local off = wanted ~= nil
			and (
				wanted:Dot(acro.away) > Trav.WallRun.KickAway
				or wanted:Dot(acro.direction) < -Trav.WallRun.KickAway
			)
		if off then
			endWallRun(now, true)
		elseif not mantleFromWall(now) then
			acro.pressedAt = os.clock()
		end
		return
	end
	if startMantle(now) or tryWallHop(now) then
		return
	end
	local clock = os.clock()
	-- Coyote time: just walked off an edge (not jumped off it), so still a first jump.
	local coyote = clock - lastGrounded < Acro.Jump.Coyote
		and not airUsed
		and hops == 0
		and root.AssemblyLinearVelocity.Y < 8
	if standing() or coyote then
		if not grounded() then
			-- The Humanoid thinks it is falling, so its own jump would not fire.
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			local velocity = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(velocity.X, profile().JumpPower, velocity.Z)
			lastGrounded = clock
		end
		-- A second press before the body has left the ground is already the double
		-- jump (owner: fast double taps lost it); it waits for the jump to get going.
		if clock - groundPress < Acro.Flip.Buffer then
			flipBuffer = clock + Acro.Flip.Buffer
		end
		groundPress = clock
		return
	end
	-- The second press in the air: a double jump that flips toward the keys held,
	-- held over if it comes in the first moments of the jump.
	local busy = acro and acro.kind ~= "WallHop"
	if not busy and not airUsed and wallComing() then
		-- A wall in reach (kick not ready yet) or about to be: the press waits for the
		-- kick rather than being spent on the flip.
		hopBuffer = clock + Trav.WallHop.Buffer
		return
	end
	if not busy and not airUsed then
		if clock - lastGrounded >= Acro.Flip.DoubleJumpDelay then
			startFlip(if move.Magnitude > 0.1 then flat(move) else nil, now)
		else
			flipBuffer = clock + Acro.Flip.Buffer
		end
		return
	end
	hopBuffer = clock + Trav.WallHop.Buffer -- retried each frame
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
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 250, rays)
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
-- Owner (2026-10-29): Shift slides (again stands up), double-tap W sprints until W is
-- released (gamepad: L3 until the stick is released). There is no ground roll.
bind("ExperimentSlide", function(_, state)
	if state == Enum.UserInputState.Begin then
		slideHeld = true
		if acro and acro.kind == "Slide" then
			endSlide()
		elseif
			not startSlide(workspace:GetServerTimeNow())
			and (acro or not grounded() or os.clock() - lastSlide < Acro.Slide.Cooldown)
		then
			-- Owner (2026-10-30): presses in the air, landing off a wall run or between
			-- slide-jumps were lost. They wait (see the render step); a slow start on
			-- the ground is simply refused.
			slideBuffer = os.clock() + Acro.Slide.Buffer
		end
	elseif state == Enum.UserInputState.End then
		slideHeld = false
	end
	return Enum.ContextActionResult.Sink
end, "Slide", Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonB)
bind("ExperimentShiftLock", function(_, state)
	if state == Enum.UserInputState.Begin then
		shiftLocked = not shiftLocked
		if not shiftLocked then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end
	return Enum.ContextActionResult.Sink
end, "Shift lock", Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl)
-- The camera scripts reset the mouse every frame, so the lock is reapplied after them.
RunService:BindToRenderStep("SlugshotShiftLock", Enum.RenderPriority.Camera.Value + 1, function()
	if shiftLocked then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	end
end)
bind("ExperimentSprint", function(_, state)
	if state == Enum.UserInputState.Begin then
		sprinting = true
	end
	return Enum.ContextActionResult.Sink
end, "Sprint", Enum.KeyCode.ButtonL3)
local lastForwardTap = -math.huge
UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.W and not UserInputService:GetFocusedTextBox() then
		local clock = os.clock()
		if clock - lastForwardTap < Config.Lab.SprintDoubleTap then
			sprinting = true
		end
		lastForwardTap = clock
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.W then
		sprinting = false
	end
end)
if Config.Lab.Aim then
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
end
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
-- Key presses always count (owner: a fast double tap lost the second press); the
-- 0.12 s window only stops a JumpRequest echo of the same press counting twice.
local function jumpPressed(key: boolean?)
	local clock = os.clock()
	if key or clock - lastJumpPress > 0.12 then
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
		jumpPressed(true)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
		jumpHeld = false
		if
			acro
			and acro.kind == "WallRun"
			and acro.pressedAt
			and os.clock() - acro.pressedAt < Trav.WallRun.TapTime
		then
			endWallRun(workspace:GetServerTimeNow(), true)
		end
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
	if sprinting and raw.Magnitude < 0.1 then
		sprinting = false -- a gamepad sprint ends when the stick is released
	end
	local target = if sprinting then settings.SprintSpeed else settings.RunSpeed
	if bouncing and not acro and not airUsed and hops == 0 then
		target *= Acro.Jump.AirSpeedScale
	end
	local goal = if desired.Magnitude > 0.01 then target else 0
	-- Speed above the goal (a slide-jump) bleeds slowly in the air: momentum carries.
	local rate = if humanoid.FloorMaterial == Enum.Material.Air and speed > goal
		then Acro.Slide.AirDecay
		elseif desired.Magnitude > 0.01 then settings.Acceleration
		else settings.Braking
	speed = Math.approach(speed, goal, rate, dt)
	humanoid.WalkSpeed = speed
	humanoid.JumpPower = settings.JumpPower
	local now = workspace:GetServerTimeNow()
	local onGround = humanoid.FloorMaterial ~= Enum.Material.Air
	local kind = if acro then acro.kind else nil
	if kind == "WallRun" and rays then
		-- Locked on: follow the wall surface until it ends or the feet reach the
		-- ground (a Jump tap kicks off; see InputEnded).
		local run = Trav.WallRun
		local hit = workspace:Raycast(root.Position, -acro.away * (run.Reach + 0.6), rays)
		local away = hit and math.abs(hit.Normal.Y) < 0.35 and flat(hit.Normal)
		if away then
			local along = acro.direction - away * acro.direction:Dot(away)
			acro.away, acro.contact = away, hit.Position
			acro.direction = flat(along) or acro.direction
		end
		-- Near the top (nothing beside the head): the climb holds the height and runs
		-- along the top edge. Owner (2026-10-30): it used to mantle over by itself; a
		-- fresh press mantles instead (see onJumpPress).
		acro.atTop = away
			and workspace:Raycast(
					root.Position + Vector3.new(0, run.TopMargin, 0),
					-acro.away * (run.Reach + 0.6),
					rays
				)
				== nil
		-- Steering (owner, 2026-10-30: once running there was no control but Space).
		-- Input along the wall sets the run speed, and pushing into the wall counts as
		-- forward; no input stops into a drag;
		-- input back along the wall brakes, turns round and runs the other way.
		local wanted =
			math.clamp(desired:Dot(acro.direction) + math.max(desired:Dot(-acro.away), 0), -1, 1)
		local steerTarget = run.Speed * wanted
		-- Letting go stops at once (owner: straight into the slide, no slowing down);
		-- a faster attach bleeds down to the run speed while the run is held.
		local steerRate = if math.abs(wanted) < run.MinInput
			then run.Stop
			elseif acro.speed > steerTarget and steerTarget >= acro.speed * 0.9 then run.Bleed
			elseif math.abs(steerTarget) < acro.speed then run.Stop
			else run.Steer
		local signed = Math.approach(acro.speed, steerTarget, steerRate, dt)
		if signed < 0 then
			acro.direction = -acro.direction
			signed = -signed
		end
		acro.speed = signed
		if not away or onGround then
			endWallRun(now, false)
			kind = nil
		elseif not aiming then
			-- Turns round smoothly rather than snapping when the run reverses.
			root.CFrame = root.CFrame:Lerp(
				CFrame.lookAt(root.Position, root.Position + acro.direction),
				Math.alpha(run.TurnRate, dt)
			)
		end
	elseif kind == "WallHop" and (now - acro.start > acro.duration or onGround) then
		local velocity = root.AssemblyLinearVelocity
		-- Keep the kick's momentum; it bleeds in the air (Slide.AirDecay) and brakes on landing.
		speed = math.min(Vector3.new(velocity.X, 0, velocity.Z).Magnitude, Trav.WallHop.MaxCarry)
		acro, kind = nil, nil
	end
	if (not acro or acro.kind == "Flip") and not onGround then
		if tryWallRun(now, desired) then
			kind = "WallRun"
		end
	end
	if kind == "WallHop" or kind == "WallRun" or kind == "Slide" then
		-- Drive the Humanoid along the kick/wall run/slide so its controller cooperates with
		-- the action's velocity instead of braking or air-steering against it.
		humanoid.WalkSpeed = acro.speed or 0
		humanoid:Move(acro.direction, false)
		if kind == "Slide" and not aiming then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + acro.direction)
		end
	elseif kind == "Mantle" then
		humanoid.WalkSpeed = 0
		humanoid:Move(Vector3.zero, false)
	else
		humanoid:Move(move, false)
	end
	if
		(not acro or acro.kind == "WallHop" or acro.kind == "Flip")
		and (jumpHeld or os.clock() < jumpWindow)
		and os.clock() - lastMantleCheck >= Trav.Mantle.CheckInterval
	then
		lastMantleCheck = os.clock()
		startMantle(now)
	end
	if os.clock() < testJumpUntil then
		humanoid.Jump = true
	end
	if
		acro
		and acro.kind == "Flip"
		and (now - acro.start > acro.duration or onGround and now - acro.start > 0.15)
	then
		acro = nil
	end
	-- A waiting slide starts on touchdown or once the action ends; Shift still held
	-- keeps it waiting through a long fall or wall run.
	if slideBuffer > 0 then
		local waiting = slideHeld and (acro ~= nil or not grounded())
		if startSlide(now) or (os.clock() >= slideBuffer and not waiting) then
			slideBuffer = 0
		end
	end
	humanoid.AutoRotate = not aiming and not shiftLocked and not acro
	if aiming and not (acro and acro.kind == "Mantle") then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + forward)
		if os.clock() - lastAimSent > 0.2 then
			lastAimSent = os.clock()
			send("Aim", true, camera.CFrame.LookVector)
		end
	elseif shiftLocked and not acro then
		-- Actions (wall run, slide, kicks, mantles) keep their own facing; afterwards
		-- the body swings quickly back round to the camera.
		root.CFrame = root.CFrame:Lerp(
			CFrame.lookAt(root.Position, root.Position + forward),
			Math.alpha(Config.Camera.ShiftLockTurnRate, dt)
		)
	end
	-- A real landing restores the flip; FloorMaterial alone lags a few frames after
	-- takeoff, which let the client and server disagree about a quick double jump.
	if standing() then
		hops, hopBuffer, upKickWall, airUsed = 0, 0, nil, false
		lastGrounded = os.clock()
	elseif os.clock() < hopBuffer and tryWallHop(now) then
		hopBuffer = 0
	elseif
		os.clock() < flipBuffer
		and not airUsed
		and not (acro and acro.kind ~= "WallHop")
		and os.clock() - lastGrounded >= Acro.Flip.DoubleJumpDelay
	then
		flipBuffer = 0
		startFlip(if move.Magnitude > 0.1 then flat(move) else nil, now)
	end
	local sliding = acro ~= nil and acro.kind == "Slide"
	cameraBase = cameraBase:Lerp(
		if aiming
			then Config.Camera.Shoulder
			elseif sliding then Vector3.new(0, -Acro.Slide.CameraDrop, 0)
			else Vector3.zero,
		Math.alpha(Config.Camera.BlendRate * (if sliding then 2 else 1), dt)
	)
	-- The shoulder offset is kept to the camera's right (CameraOffset is in root space),
	-- so the view does not swing when an action turns the body.
	lockBlend += ((if shiftLocked then 1 else 0) - lockBlend) * Math.alpha(
		Config.Camera.BlendRate,
		dt
	)
	local shoulder = Config.Camera.ShiftLock * lockBlend
	-- Sprint shake (owner: make sprinting obvious, very subtle, no tilting): a small
	-- bounce on each footfall while sprinting on the ground, eased in and out.
	local shake = Config.Camera.SprintShake
	local shaking = sprinting and onGround and not acro and speed > settings.RunSpeed + 1
	sprintShake += ((if shaking then 1 else 0) - sprintShake) * Math.alpha(shake.Rate, dt)
	local bounce = math.abs(math.sin(os.clock() * math.pi * shake.Steps)) * shake.Bounce
	humanoid.CameraOffset = cameraBase
		+ root.CFrame:VectorToObjectSpace(right * shoulder.X)
		+ Vector3.new(0, shoulder.Y + (bounce - shake.Bounce * 0.5) * sprintShake, 0)
	local fov = if aiming
		then Config.Camera.AimFov
		elseif sliding then Config.Camera.SlideFov
		elseif sprinting then Config.Camera.SprintFov
		else Config.Camera.Fov
	camera.FieldOfView += (fov - camera.FieldOfView) * Math.alpha(Config.Camera.BlendRate, dt)
	label.Text = string.format(
		"SLUGSHOT / MOVEMENT LAB v7.37   •   %s   •   %s\nWASD move · Ctrl shift lock · double-tap W sprint · Shift slide (works in the air: slides on landing; jump out of it to keep the speed) · Space jump · Space again in the air: double-jump flip toward the keys held\nSpace into a ledge: mantle (low wall at speed: vault) · jump onto a wall running along it: wall run (hold Space: up, tap: kick off) · by a wall in the air: wall jump\n%sH test hit reaction · P profiles · R reset\nSpeed %.1f   |   %s   |   %sLast flip: %s   |   Last rejected: %s   |   Corrections: %d",
		player:GetAttribute("MovementProfile") or "Athletic",
		if privateClips > 0 then `original + {privateClips} private clips` else "original clips",
		if Config.Lab.Aim then "RMB aim · Click marker · " else "",
		Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude,
		if humanoid.FloorMaterial == Enum.Material.Air then "Airborne" else "Grounded",
		if Config.Lab.Aim then `Markers {markers}   |   ` else "",
		lastFlip,
		lastReject,
		(player:GetAttribute("MotionCorrections") :: number?) or 0
	)
end)

RunService.PreSimulation:Connect(function(dt)
	-- Profiles may add gravity during a first jump; other aerial actions are separate.
	if bouncing and not acro and not airUsed and hops == 0 and root then
		local extra = profile().JumpGravity - 1
		if extra > 0 then
			root.AssemblyLinearVelocity -= Vector3.new(0, extra * workspace.Gravity * dt, 0)
		end
	end
	if acro and acro.kind == "WallRun" and root then
		-- Along the wall at the Hug distance: climbing while Jump is held (less as
		-- the run goes on), otherwise sliding down ever faster.
		local run = Trav.WallRun
		local elapsed = workspace:GetServerTimeNow() - acro.start
		if jumpHeld then
			acro.releasedAt = nil
			-- The climb allowance counts time held, so holding later in a run still climbs.
			acro.heldTime = (acro.heldTime or 0) + dt
		else
			acro.releasedAt = acro.releasedAt or elapsed
		end
		-- Not running along the wall (Space held or not): the wall slide drags straight
		-- down (owner: stopping a run must slide at once; holding Space had kept it
		-- climbing for seconds).
		local sliding = acro.speed < run.Cling.Below
		local target = if sliding
			then -run.Cling.Drag
			elseif acro.releasedAt then -math.min(
				run.Slide + run.SlideGrow * (elapsed - acro.releasedAt),
				run.SlideMax
			)
			else run.Climb - (run.Climb + run.HeldSlide) * math.clamp(
				((acro.heldTime or 0) - run.ClimbTime) / run.ClimbFade,
				0,
				1
			)
		if acro.atTop and target > 0 then
			-- At the top: stop rising and run along the edge.
			target = 0
			acro.vy = math.min(acro.vy, 0)
		end
		-- The wall slide drops straight to its drag speed (owner: directly down).
		acro.vy = Math.approach(
			acro.vy,
			target,
			if sliding then run.Cling.Accel else run.VerticalAccel,
			dt
		)
		-- Slowing into the cling pulls the body in close enough for its hand and feet
		-- to reach the wall.
		local slow = math.clamp(acro.speed / run.Cling.Below, 0, 1)
		local cling = 1 - slow * slow * (3 - 2 * slow)
		local hug = run.Hug + (run.Cling.Hug - run.Hug) * cling
		local gap = (root.Position - acro.contact):Dot(acro.away)
		local pull = math.clamp((gap - hug) * run.Pull.Rate, -run.Pull.Away, run.Pull.Max)
		root.AssemblyLinearVelocity = acro.direction * acro.speed
			- acro.away * pull
			+ Vector3.new(0, acro.vy, 0)
		return
	end
	if acro and acro.kind == "Slide" and root and character and humanoid then
		local settings = Acro.Slide
		local elapsed = workspace:GetServerTimeNow() - acro.start
		local blocked =
			workspace:Raycast(root.Position, acro.direction * (settings.WallClearance + 1), rays)
		local airborne = humanoid.FloorMaterial == Enum.Material.Air and elapsed > 0.1
		if elapsed >= settings.Duration or blocked or airborne then
			endSlide()
			return
		end
		-- Steer a little toward the input; hold speed early, slow late.
		local wanted = flat(move)
		if wanted then
			local angle = math.atan2(acro.direction:Cross(wanted).Y, acro.direction:Dot(wanted))
			local turn = math.clamp(angle, -settings.Steer * dt, settings.Steer * dt)
			acro.direction = CFrame.Angles(0, turn, 0):VectorToWorldSpace(acro.direction)
		end
		local f = elapsed / settings.Duration
		acro.speed = acro.speed0 + (settings.EndSpeed - acro.speed0) * f * f
		local velocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = acro.direction * acro.speed + Vector3.new(0, velocity.Y, 0)
		return
	end
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
	if acro.vault then
		-- Even speed over the wall: the face at the hand plant, the landing at the end,
		-- with no easing in or out (owner: the run's momentum must carry through).
		local f = math.clamp(t / acro.clip.duration, 0, 1)
		local plant = Trav.Vault.PlantAt
		local x = if f <= plant
			then f / plant * acro.face
			else acro.face + (f - plant) / (1 - plant) * (1 - acro.face)
		progress = Vector2.new(x, progress.Y)
	end
	-- The gap to the wall closes easing out, carrying the approach speed in (owner:
	-- frictionless) instead of starting from a standstill.
	local into = math.clamp(t / (acro.clip.duration * 0.3), 0, 1)
	local close = 1 - (1 - into) * (1 - into)
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
		elseif command == "Hurt" then
			send("Hurt")
		elseif command == "Jump" and humanoid then
			testJumpUntil = os.clock() + 0.12
		elseif command == "JumpPress" and humanoid then
			-- A real jump press: native jump plus the traversal checks.
			testJumpUntil = os.clock() + 0.12
			onJumpPress()
		elseif command == "Slide" then
			return startSlide(workspace:GetServerTimeNow())
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
			corrections = player:GetAttribute("MotionCorrections"),
			suspectAir = player:GetAttribute("SuspectAirBoosts"),
			suspectWalls = player:GetAttribute("SuspectWallPasses"),
			profile = player:GetAttribute("MovementProfile"),
			state = humanoid:GetState().Name,
			privateClips = privateClips,
			acro = if acro then acro.kind else "",
			hops = hops,
			variant = character and character:GetAttribute("MovementVariant"),
			rendered = character and character:GetAttribute("RenderedAction"),
			renderedMove = character and character:GetAttribute("RenderedMove"),
			renderedClip = character and character:GetAttribute("RenderedClip"),
			airState = character and character:GetAttribute("RenderedAirState"),
			footOffset = character and character:GetAttribute("RenderedFootOffset"),
			phase = character and character:GetAttribute("RenderedCyclePhase"),
		}
	end
	probe.Parent = player.PlayerScripts
end
