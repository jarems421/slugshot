--!strict
-- First-person blaster (owner, 2026-10-31: Rivals-style, clean, active). Both arms and a
-- copy of the gun ride the camera in the lower right; the real character, gun and hip
-- copy are hidden. The gun trails the look and settles on springs (inertia). Its
-- movement response is driven by the body, not a timer: the camera follows the
-- animated head (movement client), and the gun lags that motion, so every footfall,
-- weight shift and landing reaches the hands in step with the legs (owner: feel the
-- legs, not a floating camera). It also leans into strafes, lifts on jumps, carries
-- lower while sprinting, winds up while charging and kicks on firing; the draw flips it
-- into the hand. It is scaled with the FOV setting so it stays the same size on screen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Combat = require(ReplicatedStorage:WaitForChild("Combat"))
local Config = require(ReplicatedStorage:WaitForChild("MovementExperiment"):WaitForChild("Config"))

local player = Players.LocalPlayer
local movement = player:WaitForChild("PlayerScripts"):WaitForChild("MovementSandbox")
local FirstPerson = (require :: any)(movement:WaitForChild("FirstPerson"))

local Viewmodel = {}

-- Layout at the reference FOV: the grip in camera space, low right, the muzzle turned
-- slightly in toward the crosshair.
local REST_FOV = Config.Camera.Fov
local POSE = CFrame.new(0.78, -0.82, -1.5) * CFrame.Angles(math.rad(1.5), math.rad(4), 0)
-- Sprint carry: lowered, canted and turned in.
local SPRINT = CFrame.new(0.05, -0.12, 0.1)
	* CFrame.Angles(math.rad(-14), math.rad(16), math.rad(12))
local PIVOT = Vector3.new(0, 0.1, -0.3) -- the draw flip turns about the trigger finger
-- Action carries (movement client's FirstPersonAction): tucked in through a flip,
-- canted against the wall-run tilt, low and canted in a slide.
local ACTIONS: { [string]: CFrame } = {
	Flip = CFrame.new(-0.12, 0.06, 0.32) * CFrame.Angles(math.rad(22), math.rad(14), math.rad(24)),
	WallRunLeft = CFrame.new(0.04, -0.04, 0.04) * CFrame.Angles(0, 0, math.rad(8)),
	WallRunRight = CFrame.new(-0.06, -0.04, 0.04) * CFrame.Angles(0, 0, math.rad(-8)),
	Slide = CFrame.new(0.04, -0.1, 0.06) * CFrame.Angles(math.rad(-6), math.rad(10), math.rad(-18)),
}
-- Running arms (owner: both arms should move as in the run animation): the real arms'
-- rotation relative to the torso, slightly exaggerated, swung from just below the view
-- so each forward swing brings the left hand into the bottom of the screen (Mirror's
-- Edge style). The gun arm takes only part of its swing, so the gun stays usable.
local ARMS = {
	LeftShoulder = Vector3.new(-0.95, -0.8, -0.5),
	Rest = CFrame.Angles(math.rad(28), 0, math.rad(-8)),
	Gain = 1.3,
	GunShoulder = Vector3.new(0.9, -0.55, -0.2),
	GunFollow = 0.3,
	GunMax = 0.3,
}
-- Legs stay visible (also through flips: owner) and fade only where they come close
-- enough to the camera to block the view.
local LEG_NEAR, LEG_FADE = 1.4, 0.6
local SWAY = { Lag = 0.022, Max = 0.09, Spring = 150, Damping = 0.65 }
-- Lag behind the camera's body-driven motion (seconds of its velocity), with a tilt.
local BODY = { Lag = 0.03, Max = 0.06, Spring = 140, Damping = 0.6, Tilt = 1.4 }
local SPRINT_SPEED = 20.5
local LEAN = 0.0035 -- roll per stud/s of strafe
local RECOIL = { Pitch = 0.16, PitchCharged = 0.1, Back = 0.12, Spring = 210, Damping = 0.55 }
local DRAW, RAISE, LOWER = 0.5, 0.2, 0.2

type Spring = { x: Vector3, v: Vector3 }
local function spring(): Spring
	return { x = Vector3.zero, v = Vector3.zero }
end
-- Critically scaled spring toward a target, stable at any frame rate (dt is capped).
local function step(s: Spring, target: Vector3, stiffness: number, damping: number, dt: number)
	local accel = (target - s.x) * stiffness - s.v * (2 * math.sqrt(stiffness) * damping)
	s.v += accel * dt
	s.x += s.v * dt
end

type Entry = { part: BasePart, offset: CFrame, gun: boolean }
type Rig = {
	model: Model,
	entries: { Entry },
	tool: Tool,
	scale: number,
	muzzle: Vector3, -- in gun space at scale 1
	canister: { { copy: BasePart, source: BasePart } },
	toolParts: { BasePart },
	leftArm: BasePart,
	phase: string,
	phaseStart: number,
}

local rig: Rig? = nil
local sway, recoil, inertia = spring(), spring(), spring()
local swayTarget = Vector3.zero
local lastLook: CFrame? = nil
local body = spring()
local lastCamera: Vector3? = nil
local sprintWeight, lean, chargeShown = 0, 0, 0
local carry = CFrame.identity -- eased action carry
local gunBase = 0 -- slow baseline of the real gun arm's pitch

-- A limb's rotation relative to the torso (identity when hanging at rest).
local function limbTurn(character: Model, name: string): CFrame
	local torso = character:FindFirstChild("Torso")
	local limb = character:FindFirstChild(name)
	if torso and limb and torso:IsA("BasePart") and limb:IsA("BasePart") then
		return torso.CFrame.Rotation:ToObjectSpace(limb.CFrame.Rotation)
	end
	return CFrame.identity
end
local function amplify(rotation: CFrame, gain: number): CFrame
	local axis, angle = rotation:ToAxisAngle()
	if angle < 1e-4 then
		return CFrame.identity
	end
	return CFrame.fromAxisAngle(axis, angle * gain)
end
local charge = 0
local grounded, lastVy = true, 0
local wasFirst = false

local function easeOut(t: number): number
	t = math.clamp(t, 0, 1)
	return 1 - (1 - t) ^ 3
end
local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
local function alpha(rate: number, dt: number): number
	return 1 - math.exp(-rate * dt)
end

local function fovScale(): number
	local fov = (player:GetAttribute("FieldOfView") or REST_FOV) :: number
	return math.tan(math.rad(REST_FOV) / 2) / math.tan(math.rad(fov) / 2)
end

-- An arm block from the hand (at the gun) back toward the elbow, off screen.
local function arm(name: string, hand: Vector3, toward: Vector3, color: Color3): (BasePart, CFrame)
	local length, width = 2.3, 0.45
	local direction = toward.Unit
	local side = direction:Cross(Vector3.yAxis)
	if side.Magnitude < 1e-3 then
		side = Vector3.xAxis
	end
	local centre = hand + direction * (length / 2 - 0.22)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.new(width, length, width)
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	return part, CFrame.fromMatrix(centre, side.Unit, direction)
end

local function build(tool: Tool, character: Model): Rig?
	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return nil
	end
	local sources = tool:GetDescendants()
	local copied = tool:Clone()
	local copies = copied:GetDescendants()
	local model = Instance.new("Model")
	model.Name = "FirstPersonBlaster"
	local frame = (copied:FindFirstChild("Handle") :: BasePart).CFrame
	local entries: { Entry } = {}
	local canister: { { copy: BasePart, source: BasePart } } = {}
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	local canisterY = 0
	for index, item in copies do
		local source = sources[index]
		if
			item:IsA("BaseScript")
			or item:IsA("ModuleScript")
			or item:IsA("JointInstance")
			or item:IsA("Constraint")
			or item:IsA("Light")
		then
			item:Destroy()
		elseif item:IsA("BasePart") then
			item.Anchored, item.CanCollide, item.CanQuery, item.CanTouch = true, false, false, false
			item.CastShadow = false
			item.LocalTransparencyModifier = 0
			local offset = frame:ToObjectSpace(item.CFrame)
			table.insert(entries, { part = item, offset = offset, gun = true })
			if item.Name == "Handle" then
				item.Name = "VisualHandle"
			elseif item.Transparency < 1 then
				-- Extents in gun space from each part's rotated half-size (meshes are turned).
				local half, r = item.Size / 2, offset.Rotation
				local reach = Vector3.new(
					math.abs(r.XVector.X) * half.X
						+ math.abs(r.YVector.X) * half.Y
						+ math.abs(r.ZVector.X) * half.Z,
					math.abs(r.XVector.Y) * half.X
						+ math.abs(r.YVector.Y) * half.Y
						+ math.abs(r.ZVector.Y) * half.Z,
					math.abs(r.XVector.Z) * half.X
						+ math.abs(r.YVector.Z) * half.Y
						+ math.abs(r.ZVector.Z) * half.Z
				)
				low = low:Min(offset.Position - reach)
				high = high:Max(offset.Position + reach)
			end
			if string.find(item.Name, "Canister") then
				canisterY = offset.Position.Y
			end
			if
				source
				and source:IsA("BasePart")
				and source.Name == item.Name
				and item:FindFirstAncestor("Floppy")
			then
				table.insert(canister, { copy = item, source = source })
			end
		end
	end
	for _, child in copied:GetChildren() do
		child.Parent = model
	end
	copied:Destroy()
	-- One hand: a light pistol is held one-handed (owner, 2026-10-31).
	local skin = Color3.fromRGB(234, 184, 146)
	local right = character:FindFirstChild("Right Arm")
	local rightArm, rightFrame = arm(
		"RightArm",
		Vector3.new(0, -0.12, 0.08),
		Vector3.new(0.3, -0.58, 0.76),
		if right and right:IsA("BasePart") then right.Color else skin
	)
	rightArm.Anchored, rightArm.CanCollide, rightArm.CanQuery, rightArm.CanTouch =
		true, false, false, false
	rightArm.CastShadow = false
	rightArm.Parent = model
	table.insert(entries, { part = rightArm, offset = rightFrame, gun = false })
	-- The free left arm, placed each frame from the real left arm's swing.
	local left = character:FindFirstChild("Left Arm")
	local leftArm = Instance.new("Part")
	leftArm.Name = "LeftArm"
	leftArm.Size = Vector3.new(0.42, 1.9, 0.42)
	leftArm.Color = if left and left:IsA("BasePart") then left.Color else skin
	leftArm.Material = Enum.Material.SmoothPlastic
	leftArm.TopSurface, leftArm.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	leftArm.Anchored, leftArm.CanCollide, leftArm.CanQuery, leftArm.CanTouch =
		true, false, false, false
	leftArm.CastShadow = false
	leftArm.Parent = model
	local toolParts: { BasePart } = {}
	for _, item in sources do
		if item:IsA("BasePart") then
			table.insert(toolParts, item)
		end
	end
	model.Parent = workspace.CurrentCamera
	local built: Rig = {
		model = model,
		entries = entries,
		tool = tool,
		scale = 1,
		muzzle = Vector3.new(0, canisterY, if low.Z < math.huge then low.Z else -2),
		canister = canister,
		toolParts = toolParts,
		leftArm = leftArm,
		phase = "draw",
		phaseStart = os.clock(),
	}
	return built
end

local function drop()
	if rig then
		for _, part in rig.toolParts do
			if part.Parent then
				part.LocalTransparencyModifier = 0
			end
		end
		rig.model:Destroy()
	end
	rig = nil
end

local function equipped(): Tool?
	local character = player.Character
	if not character then
		return nil
	end
	for _, item in character:GetChildren() do
		if Combat.isBlaster(item) then
			return item :: Tool
		end
	end
	return nil
end

-- The gun's frame this render (grip, scaled for the FOV), and the flip angle.
local gunFrame: CFrame? = nil

function Viewmodel.setCharge(value: number)
	charge = math.clamp(value, 0, 1)
end

function Viewmodel.kick(shotCharge: number)
	recoil.v += Vector3.new(RECOIL.Pitch + RECOIL.PitchCharged * shotCharge, 0, RECOIL.Back) * 18
end

-- Where shots leave from in first person (nil in third person).
function Viewmodel.muzzle(): Vector3?
	local current = rig
	if not current or not gunFrame or not FirstPerson.active() then
		return nil
	end
	return gunFrame * (current.muzzle * current.scale)
end

function Viewmodel.start()
	RunService:BindToRenderStep(
		"SlugshotViewmodel",
		Enum.RenderPriority.Camera.Value + 10,
		function(rawDt: number)
			local dt = math.min(rawDt, 1 / 20)
			local now = os.clock()
			local camera = workspace.CurrentCamera
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local first = FirstPerson.active()
			local tool = equipped()
			-- Build on equip or on entering first person; lower and remove on holster.
			if first and tool and character and (not rig or rig.tool ~= tool) then
				drop()
				rig = build(tool, character)
				if rig and wasFirst then
					rig.phase, rig.phaseStart = "draw", now
				elseif rig then
					rig.phase, rig.phaseStart = "raise", now
				end
			elseif rig and (not tool or rig.tool ~= tool) and rig.phase ~= "lower" then
				rig.phase, rig.phaseStart = "lower", now
			end
			if rig and not first then
				drop()
			end
			wasFirst = first
			local current = rig
			if
				not current
				or not camera
				or not root
				or not root:IsA("BasePart")
				or not humanoid
			then
				gunFrame = nil
				lastLook = if camera then camera.CFrame else nil
				return
			end
			-- FOV scale (rebuilds sizes only when the setting changes).
			local scale = fovScale()
			if math.abs(scale - current.scale) > 1e-3 then
				current.model:ScaleTo(scale)
				current.scale = scale
			end
			-- Look sway: the gun lags behind the look in proportion to its speed, then settles.
			local look = camera.CFrame
			if lastLook then
				local pitch, yaw = lastLook.Rotation:ToObjectSpace(look.Rotation):ToEulerAnglesYXZ()
				local rate = Vector3.new(pitch, yaw, 0) / math.max(dt, 1e-3)
				swayTarget = Vector3.new(
					math.clamp(-rate.X * SWAY.Lag, -SWAY.Max, SWAY.Max),
					math.clamp(-rate.Y * SWAY.Lag, -SWAY.Max, SWAY.Max),
					0
				)
			end
			lastLook = look
			step(sway, swayTarget, SWAY.Spring, SWAY.Damping, dt)
			-- Movement: body-driven lag, strafe lean, sprint carry, jump lift and landing dip.
			local velocity = root.AssemblyLinearVelocity
			local flat = Vector3.new(velocity.X, 0, velocity.Z)
			local speed = flat.Magnitude
			local onGround = humanoid.FloorMaterial ~= Enum.Material.Air
			local sprinting = onGround and speed > SPRINT_SPEED and charge == 0
			sprintWeight += ((if sprinting then 1 else 0) - sprintWeight) * alpha(8, dt)
			-- The camera's motion relative to the body (head follow, landings), in view space.
			local cameraLocal = root.CFrame:PointToObjectSpace(look.Position)
			local bodyTarget = Vector3.zero
			if lastCamera then
				local moving = look:VectorToObjectSpace(
					root.CFrame:VectorToWorldSpace(cameraLocal - lastCamera)
				) / dt
				bodyTarget = Vector3.new(
					math.clamp(-moving.X * BODY.Lag, -BODY.Max, BODY.Max),
					math.clamp(-moving.Y * BODY.Lag, -BODY.Max, BODY.Max),
					0
				)
			end
			lastCamera = cameraLocal
			step(body, bodyTarget, BODY.Spring, BODY.Damping, dt)
			local strafe = look:VectorToObjectSpace(flat).X
			lean += (math.clamp(-strafe * LEAN, -0.07, 0.07) - lean) * alpha(6, dt)
			if onGround and not grounded then
				inertia.v += Vector3.new(0, -math.clamp(-lastVy * 0.05, 0, 2.5), 0)
			end
			grounded, lastVy = onGround, velocity.Y
			step(
				inertia,
				Vector3.new(0, math.clamp(-velocity.Y * 0.0025, -0.06, 0.05), 0),
				120,
				0.7,
				dt
			)
			step(recoil, Vector3.zero, RECOIL.Spring, RECOIL.Damping, dt)
			chargeShown += (charge - chargeShown) * alpha(14, dt)
			-- Charge: draws back and tightens, with a faint tremble when full.
			local tremble = math.sin(now * 47) * 0.0035 * chargeShown ^ 4
			-- Draw/raise from below (the draw flips the gun in the hand), lower on holster.
			local t = now - current.phaseStart
			local entry, flip = 0, 0
			if current.phase == "draw" then
				entry = 1 - easeOut(t / (DRAW * 0.6))
				flip = 2 * math.pi * smooth((t - DRAW * 0.12) / (DRAW * 0.7))
				if t >= DRAW then
					current.phase = "idle"
				end
			elseif current.phase == "raise" then
				entry = 1 - easeOut(t / RAISE)
				if t >= RAISE then
					current.phase = "idle"
				end
			elseif current.phase == "lower" then
				entry = smooth(t / LOWER)
				if t >= LOWER then
					drop()
					gunFrame = nil
					return
				end
			end
			local action = character and character:GetAttribute("FirstPersonAction")
			local target = if typeof(action) == "string" then ACTIONS[action] else nil
			carry = carry:Lerp(target or CFrame.identity, alpha(14, dt))
			-- The gun arm takes part of the real arm's swing, about a shoulder just off view.
			local pitch = limbTurn(character :: Model, "Right Arm"):ToEulerAnglesXYZ()
			gunBase += (pitch - gunBase) * alpha(1.5, dt)
			local swing = math.clamp((pitch - gunBase) * ARMS.GunFollow, -ARMS.GunMax, ARMS.GunMax)
			local swingFrame = CFrame.new(ARMS.GunShoulder)
				* CFrame.Angles(swing, 0, 0)
				* CFrame.new(-ARMS.GunShoulder)
			local pose = swingFrame * POSE:Lerp(POSE * SPRINT, sprintWeight) * carry
			local frame = pose
				* CFrame.new(
					body.x
						+ inertia.x
						+ Vector3.new(
							0,
							-0.03 * chargeShown - 0.75 * entry + tremble,
							0.1 * chargeShown + recoil.x.Z
						)
				)
				* CFrame.Angles(
					sway.x.X + recoil.x.X + 0.04 * chargeShown - 0.8 * entry - body.x.Y * BODY.Tilt,
					sway.x.Y,
					sway.x.Y * 0.6 + lean + body.x.X * BODY.Tilt
				)
			local grip = look * CFrame.new(frame.Position * scale) * frame.Rotation
			gunFrame = grip
			local spin = CFrame.new(PIVOT * scale)
				* CFrame.Angles(flip, 0, 0)
				* CFrame.new(-PIVOT * scale)
			for _, item in current.entries do
				local offset = item.offset
				local placed = CFrame.new(offset.Position * scale) * offset.Rotation
				item.part.CFrame = if item.gun then grip * spin * placed else grip * placed
			end
			-- The left arm swings as the real one does.
			local leftShoulder = look * CFrame.new((ARMS.LeftShoulder + body.x * 0.5) * scale)
			current.leftArm.CFrame = leftShoulder
				* ARMS.Rest
				* amplify(limbTurn(character :: Model, "Left Arm"), ARMS.Gain)
				* CFrame.new(0, -current.leftArm.Size.Y / 2, 0)
			-- The canister shows Floppy exactly when the real gun does.
			for _, pair in current.canister do
				if pair.copy.Transparency ~= pair.source.Transparency then
					pair.copy.Transparency = pair.source.Transparency
				end
			end
		end
	)
	-- After the draw/holster driver and Roblox's own first-person fade: hide the real gun
	-- and the hip copy, and keep the legs visible (body awareness: look down and see them
	-- running in step with the camera), fading only a leg that comes up to the eye.
	local LEGS = {
		"Left Leg",
		"Right Leg",
		"LeftUpperLeg",
		"LeftLowerLeg",
		"LeftFoot",
		"RightUpperLeg",
		"RightLowerLeg",
		"RightFoot",
	}
	local shown = true
	RunService:BindToRenderStep(
		"SlugshotViewmodelHide",
		Enum.RenderPriority.Character.Value + 10,
		function()
			local first = FirstPerson.active()
			local tool = equipped()
			if first then
				if tool then
					for _, part in tool:GetDescendants() do
						if part:IsA("BasePart") then
							part.LocalTransparencyModifier = 1
						end
					end
				end
				local character = player.Character
				if character then
					local view = workspace.CurrentCamera
					local eye = if view then view.CFrame.Position else Vector3.zero
					for _, name in LEGS do
						local leg = character:FindFirstChild(name)
						if leg and leg:IsA("BasePart") then
							-- Distance from the eye to the nearest point of the leg block.
							local at = leg.CFrame:PointToObjectSpace(eye)
							local half = leg.Size / 2
							local nearest = Vector3.new(
								math.clamp(at.X, -half.X, half.X),
								math.clamp(at.Y, -half.Y, half.Y),
								math.clamp(at.Z, -half.Z, half.Z)
							)
							local distance = (at - nearest).Magnitude
							leg.LocalTransparencyModifier =
								math.clamp((LEG_NEAR - distance) / LEG_FADE, 0, 1)
						end
					end
				end
				local camera = workspace.CurrentCamera
				local ghost = camera and camera:FindFirstChild("BlasterHolsterVisual")
				if ghost then
					for _, part in ghost:GetDescendants() do
						if part:IsA("BasePart") then
							part.LocalTransparencyModifier = 1
						end
					end
				end
				shown = false
			elseif not shown then
				shown = true
				if tool then
					for _, part in tool:GetDescendants() do
						if part:IsA("BasePart") then
							part.LocalTransparencyModifier = 0
						end
					end
				end
			end
		end
	)
end

return Viewmodel
