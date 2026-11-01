--!strict
-- First-person visual proportions layered over the actual character animation.
-- Copy each arm's complete pose, with a wider shoulder anchor and slimmer, longer
-- geometry. Running retains bounded source flare/chest motion and each arm's pitch.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Combat = require(ReplicatedStorage:WaitForChild("Combat"))

local player = Players.LocalPlayer
local movement = player:WaitForChild("PlayerScripts"):WaitForChild("MovementSandbox")
local FirstPerson = (require :: any)(movement:WaitForChild("FirstPerson"))
local BlasterAnimator = (require :: any)(movement:WaitForChild("BlasterAnimator"))
local FirstPersonFlip = (require :: any)(movement:WaitForChild("FirstPersonFlip"))
local AcrobaticCamera = (require :: any)(movement:WaitForChild("AcrobaticCamera"))
local Viewmodel = {}
local LIMBS = { "Left Leg", "Right Leg" }
local ARM_SCALE = Vector3.new(0.64, 1.0738 * 1.12 * 0.9, 0.64) -- owner: 10% shorter, first-person copies only
local SHOULDER_OUT = 0.19 -- per side, in torso space
local REST_SHOULDER_OUT = -0.08
local SHOULDER_CROP = 0.5915 * 1.12 * 0.9 -- same 10% reduction preserves crop/hand proportions
local POSE_RATE = 22 -- short render-space follow-through; camera/mouse look stays immediate
local RUN_POSE_RATE = 90 -- restore the earlier short run follow, including at full pace
local GUN_GRIP_RELEASE = 0.1 -- first-person gun sits nearer the fingertips, exposing more handle
local IDLE_HAND_FRAME = Vector3.new(0, 0.05, 0.25)
local RUN_HAND_FRAME = Vector3.new(0, 0.12, 0.25)
local IDLE_HAND_PITCH = math.rad(18)
local IDLE_SHOULDER_DEPTH = -0.05 -- small forward nudge from the relaxed +0.18 position
local RUN_SHOULDER_DEPTH = -0.62 -- slight forward running roll; accepted idle stays separate
local RUN_CHEST_WEIGHT = 0.25
local RUN_POSTURE_DEPTH = 0.25 -- let the eyes move over the shoulders, rather than carrying them ahead
local RUN_POSTURE_LIFT = 0.15
local RUN_FLARE_WEIGHT = 0.45
type Arm = {
	source: BasePart,
	copy: BasePart,
	side: number,
	frame: CFrame?,
	fade: number,
}
type GunPart = { source: BasePart, copy: BasePart, bones: { { source: Bone, copy: Bone } } }
type Rig = { model: Model, character: Model, tool: Tool?, arms: { Arm }, gun: { GunPart } }
local rig: Rig? = nil
local straightWeight = 0
local postureWeight = 0
local visualHandle: CFrame? = nil
local cachedTool: Tool? = nil
local muzzleOffset = Vector3.zero
local visibleParts: { [BasePart]: boolean } = {}

local function equipped(): Tool?
	local character = player.Character
	if character then
		for _, item in character:GetChildren() do
			if Combat.isBlaster(item) then
				return item :: Tool
			end
		end
	end
	return nil
end

-- Actual muzzle in the real handle's frame, including rotated mesh extents.
function Viewmodel.muzzle(): Vector3?
	if not FirstPerson.active() then
		return nil
	end
	local tool = equipped()
	local handle = tool and tool:FindFirstChild("Handle")
	if not tool or not handle or not handle:IsA("BasePart") then
		cachedTool = nil
		return nil
	end
	if tool ~= cachedTool then
		local front, canisterY = math.huge, 0
		for _, part in tool:GetDescendants() do
			if part:IsA("BasePart") and part ~= handle then
				local offset = handle.CFrame:ToObjectSpace(part.CFrame)
				if part.Transparency < 1 and not part:FindFirstAncestor("Floppy") then
					local half = part.Size / 2
					local reach = math.abs(offset.XVector.Z) * half.X
						+ math.abs(offset.YVector.Z) * half.Y
						+ math.abs(offset.ZVector.Z) * half.Z
					front = math.min(front, offset.Z - reach)
				end
				if string.find(part.Name, "Canister") then
					canisterY = offset.Y
				end
			end
		end
		muzzleOffset = Vector3.new(0, canisterY, if front < math.huge then front else -2)
		cachedTool = tool
	end
	return (if rig and rig.tool == tool and visualHandle then visualHandle else handle.CFrame)
		* muzzleOffset
end

local function prepare(part: BasePart)
	part.Anchored = true
	part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
	part.CastShadow = false
	part.LocalTransparencyModifier = 0
end

local function drop()
	if rig then
		rig.model:Destroy()
	end
	rig, visualHandle = nil, nil
	straightWeight = 0
	postureWeight = 0
end

local function build(character: Model, tool: Tool?, camera: Camera): Rig
	local model = Instance.new("Model")
	model.Name = "FirstPersonBodyVisual"
	local current: Rig = { model = model, character = character, tool = tool, arms = {}, gun = {} }
	for _, name in { "Left Arm", "Right Arm" } do
		local source = character:FindFirstChild(name)
		if source and source:IsA("BasePart") then
			local copy = Instance.new("Part")
			copy.Name, copy.Size, copy.Color = name, source.Size * ARM_SCALE, source.Color
			copy.Material = source.Material
			copy.TopSurface, copy.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
			prepare(copy)
			copy.Parent = model
			local entry: Arm = {
				source = source,
				copy = copy,
				side = if name == "Left Arm" then -1 else 1,
				frame = nil,
				fade = 0,
			}
			table.insert(current.arms, entry)
		end
	end
	if tool then
		for _, source in tool:GetDescendants() do
			if source:IsA("BasePart") then
				local copy = source:Clone()
				local originals, descendants = source:GetDescendants(), copy:GetDescendants()
				local bones: { { source: Bone, copy: Bone } } = {}
				for i, item in descendants do
					local original = originals[i]
					if item:IsA("Bone") and original and original:IsA("Bone") then
						table.insert(bones, { source = original, copy = item })
					elseif
						item:IsA("BaseScript")
						or item:IsA("ModuleScript")
						or item:IsA("JointInstance")
						or item:IsA("Constraint")
						or item:IsA("Light")
						or item:IsA("BasePart")
					then
						item:Destroy()
					end
				end
				prepare(copy)
				copy.Parent = model
				table.insert(current.gun, { source = source, copy = copy, bones = bones })
			end
		end
	end
	model.Parent = camera
	return current
end

local nearEye: (BasePart, Vector3) -> number
local function place(current: Rig, torso: BasePart, camera: Camera, dt: number)
	local character = current.character
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local velocity = if root and root:IsA("BasePart")
		then root.AssemblyLinearVelocity
		else Vector3.zero
	local groundedCarry = humanoid ~= nil
		and humanoid.FloorMaterial ~= Enum.Material.Air
		and character:GetAttribute("FirstPersonAction") == nil
		and character:GetAttribute("BlasterFlourish") == nil
		and character:GetAttribute("BlasterPoint") == nil
	local running = groundedCarry and Vector3.new(velocity.X, 0, velocity.Z).Magnitude > 2
	straightWeight += ((if running then 1 else 0) - straightWeight) * (1 - math.exp(-12 * dt))
	postureWeight += ((if groundedCarry then 1 else 0) - postureWeight) * (1 - math.exp(-12 * dt))
	-- Torso yaw/roll is animated too. Straightening only relative to that torso
	-- still points the arms inward on screen, so use the view's horizontal facing.
	local forward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	if forward.Magnitude < 1e-3 then
		forward = Vector3.new(torso.CFrame.LookVector.X, 0, torso.CFrame.LookVector.Z)
	end
	local runFacing =
		CFrame.lookAt(Vector3.zero, if forward.Magnitude > 1e-3 then forward else -Vector3.zAxis)
	local torsoFrame = torso.CFrame
	local chest = runFacing:ToObjectSpace(torsoFrame.Rotation)
	local chestLean =
		math.clamp(-math.atan2(chest.UpVector.Z, chest.UpVector.Y) / math.rad(40), 0, 1)
	local chestTwist = math.clamp(
		math.atan2(-chest.LookVector.X, -chest.LookVector.Z) * RUN_CHEST_WEIGHT,
		-math.rad(6),
		math.rad(6)
	)
	local flipping = character:GetAttribute("FirstPersonAction") == "Flip"
	local flipCue = if flipping
		then FirstPersonFlip.sample(
			workspace:GetServerTimeNow(),
			character:GetAttribute("MovementActionTime") or 0,
			character:GetAttribute("FirstPersonFlipDuration") or 0.6,
			character:GetAttribute("FirstPersonFlipSide") or 0
		)
		else nil
	local gunMap = CFrame.identity
	for _, arm in current.arms do
		local source = arm.source
		local sourceFrame = source.CFrame
		local pose = torsoFrame:ToObjectSpace(sourceFrame)
		local top = pose * CFrame.new(0, source.Size.Y / 2, 0)
		local lane = arm.side * (torso.Size.X + source.Size.X) / 2
		local chestDepth = math.clamp(chest.RightVector.Z * lane * RUN_CHEST_WEIGHT, -0.11, 0.11)
		local chestLift = math.clamp(chest.RightVector.Y * lane * 0.35, -0.05, 0.05)
		local idleShoulder = torsoFrame
			* (top.Position + Vector3.new(arm.side * REST_SHOULDER_OUT, 0, 0))
		local runShoulder = torsoFrame.Position
			+ runFacing:VectorToWorldSpace(
				Vector3.new(lane + arm.side * SHOULDER_OUT, top.Y + chestLift, top.Z)
			)
		local shoulder = idleShoulder:Lerp(runShoulder, straightWeight)
		local viewPose = runFacing:ToObjectSpace(sourceFrame.Rotation)
		local pitch = math.atan2(viewPose.UpVector.Z, viewPose.UpVector.Y)
		-- Preserve the authored back-swing flare rather than forcing both arms into
		-- vertical planes. Bound inward sweep so the hands stay in their own lanes.
		local sourceOut = math.asin(math.clamp(-pose.UpVector.X * arm.side, -1, 1))
		local out = math.rad(3)
			+ math.clamp(sourceOut * RUN_FLARE_WEIGHT, -math.rad(2), math.rad(11))
		local runRotation = runFacing
			* CFrame.Angles(pitch, 0, arm.side * out)
			* CFrame.Angles(0, chestTwist, 0)
		local rotation = sourceFrame.Rotation:Lerp(runRotation, straightWeight)
		local fullSize = source.Size * ARM_SCALE
		local crop = math.min(SHOULDER_CROP, fullSize.Y * 0.4)
		local target = camera.CFrame:ToObjectSpace(CFrame.new(shoulder) * rotation)
		-- Ease shoulder depth independently of the source swing, so framing can
		-- move between a relaxed idle and a more visible running reach.
		local handFrame = IDLE_HAND_FRAME:Lerp(RUN_HAND_FRAME, straightWeight) * postureWeight
		local framedPosition = target.Position + handFrame
		framedPosition += Vector3.new(0, RUN_POSTURE_LIFT * chestLean * straightWeight, 0)
		local shoulderDepth = IDLE_SHOULDER_DEPTH
			+ (
					RUN_SHOULDER_DEPTH
					+ chestDepth
					+ RUN_POSTURE_DEPTH * chestLean
					- IDLE_SHOULDER_DEPTH
				)
				* straightWeight
		framedPosition += Vector3.new(0, 0, (shoulderDepth - framedPosition.Z) * postureWeight)
		target = CFrame.new(framedPosition)
			* target.Rotation
			* CFrame.Angles(IDLE_HAND_PITCH * (1 - straightWeight) * postureWeight, 0, 0)
		if flipCue then
			-- Keep the drive/tuck visible instead of sending the hands behind the
			-- steady view with the somersault. Release back to the real clip's pose.
			local tuck, drive = flipCue.tuck, flipCue.drive
			local carry = CFrame.new(
				arm.side * (1.55 - 0.22 * tuck),
				-0.55 + 0.1 * tuck,
				-0.1 + 0.05 * tuck
			) * CFrame.Angles(
				math.rad(55 + 22 * tuck + 5 * drive),
				math.rad(-arm.side * 10 * tuck),
				math.rad(-arm.side * 14 * tuck)
			)
			local carryWeight, pointingWeight = flipCue.weight, 0.3
			if AcrobaticCamera.enabled() then
				local mode = AcrobaticCamera.status()
				if mode < 3 then
					local gesture = FirstPersonFlip.arm(
						workspace:GetServerTimeNow(),
						character:GetAttribute("MovementActionTime") or 0,
						character:GetAttribute("FirstPersonFlipDuration") or 0.6,
						arm.side,
						pose.Rotation,
						camera.CFrame:ToObjectSpace(sourceFrame).Rotation,
						mode
					)
					carry, carryWeight, pointingWeight = gesture.frame, gesture.weight, 0.2
				else
					carryWeight = 0
				end
			end
			-- The free hand keeps the full gesture while the gun hand can still aim.
			local pointing = arm.side == 1 and character:GetAttribute("BlasterPoint") ~= nil
			target = target:Lerp(carry, carryWeight * (if pointing then pointingWeight else 1))
		end
		local rate = if character:GetAttribute("BlasterPoint") ~= nil
			then POSE_RATE * 2
			elseif flipping and AcrobaticCamera.enabled() and AcrobaticCamera.status() < 3 then 72
			else POSE_RATE + (RUN_POSE_RATE - POSE_RATE) * straightWeight
		local alpha = 1 - math.exp(-rate * dt)
		local blended = if arm.frame then arm.frame:Lerp(target, alpha) else target
		arm.frame = blended
		local armFrame = camera.CFrame * blended
		arm.copy.Size = Vector3.new(fullSize.X, fullSize.Y - crop, fullSize.Z)
		arm.copy.Color = source.Color
		arm.copy.CFrame = armFrame * CFrame.new(0, -(crop + arm.copy.Size.Y / 2), 0)
		local fadeAlpha = 1 - math.exp(-16 * dt)
		arm.fade += (nearEye(arm.copy, camera.CFrame.Position) - arm.fade) * fadeAlpha
		arm.copy.LocalTransparencyModifier = arm.fade
		if arm.side == 1 then
			-- Use the full virtual hand endpoint, independent of the shoulder crop.
			-- Preserve aim/flourishes, with a small distal shift for a shallower grip.
			gunMap = armFrame
				* CFrame.new(0, -(fullSize.Y - source.Size.Y / 2 + GUN_GRIP_RELEASE), 0)
				* sourceFrame:Inverse()
		end
	end
	visualHandle = nil
	local gunFade = 1 - BlasterAnimator.handVisibility(character)
	for _, item in current.gun do
		local source = item.source
		item.copy.CFrame = gunMap * source.CFrame
		item.copy.Transparency = source.Transparency
		item.copy.LocalTransparencyModifier = gunFade
		for _, bone in item.bones do
			bone.copy.Transform = bone.source.Transform
		end
		if source.Name == "Handle" then
			visualHandle = item.copy.CFrame
		end
	end
end

-- Fade only when a real limb approaches the eye during an acrobatic pose.
nearEye = function(part: BasePart, eye: Vector3): number
	local at = part.CFrame:PointToObjectSpace(eye)
	local half = part.Size / 2
	local nearest = Vector3.new(
		math.clamp(at.X, -half.X, half.X),
		math.clamp(at.Y, -half.Y, half.Y),
		math.clamp(at.Z, -half.Z, half.Z)
	)
	return math.clamp((0.65 - (at - nearest).Magnitude) / 0.4, 0, 1)
end

function Viewmodel.start()
	RunService:BindToRenderStep(
		"SlugshotFirstPersonBody",
		Enum.RenderPriority.Character.Value + 10,
		function(dt: number)
			local character, camera = player.Character, workspace.CurrentCamera
			if not FirstPerson.active() or not character or not camera then
				for part in visibleParts do
					if part.Parent then
						part.LocalTransparencyModifier = 0
					end
				end
				table.clear(visibleParts)
				drop()
				return
			end
			local tool = equipped()
			local torso = character:FindFirstChild("Torso")
			if not torso or not torso:IsA("BasePart") then
				drop()
				return
			end
			if not rig or rig.character ~= character or rig.tool ~= tool then
				local previous = rig
				local previousWeight = straightWeight
				local previousPosture = postureWeight
				drop()
				local built = build(character, tool, camera)
				rig = built
				if previous and previous.character == character then
					straightWeight = previousWeight
					postureWeight = previousPosture
					for _, arm in built.arms do
						for _, old in previous.arms do
							if old.source == arm.source then
								arm.frame, arm.fade = old.frame, old.fade
							end
						end
					end
				end
			end
			local current = rig :: Rig
			current.model.Parent = camera
			place(current, torso, camera, dt)
			local nextParts: { [BasePart]: boolean } = {}
			for _, arm in current.arms do
				arm.source.LocalTransparencyModifier = 1
				nextParts[arm.source] = true
			end
			for _, name in LIMBS do
				local part = character:FindFirstChild(name)
				if part and part:IsA("BasePart") then
					part.LocalTransparencyModifier = nearEye(part, camera.CFrame.Position)
					nextParts[part] = true
				end
			end
			if tool then
				for _, part in tool:GetDescendants() do
					if part:IsA("BasePart") then
						part.LocalTransparencyModifier = 1
						nextParts[part] = true
					end
				end
			end
			for part in visibleParts do
				if not nextParts[part] and part.Parent then
					part.LocalTransparencyModifier = 0
				end
			end
			visibleParts = nextParts
		end
	)
end

return Viewmodel
