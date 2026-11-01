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
local Recoil = (require :: any)(movement:WaitForChild("BlasterRecoil"))
local FirstPersonFlip = (require :: any)(movement:WaitForChild("FirstPersonFlip"))
local AcrobaticCamera = (require :: any)(movement:WaitForChild("AcrobaticCamera"))
local Tuning = (require :: any)(movement:WaitForChild("Tuning"))
local Ads = (require :: any)(movement:WaitForChild("Ads"))
local AdsSight = require(script.Parent:WaitForChild("AdsSight"))
local Viewmodel = {}
local LIMBS = { "Left Leg", "Right Leg" }
local CROP_PER_LENGTH = 0.5915 / 1.0738 -- preserves crop/hand proportions at any arm length
local POSE_RATE = 22 -- short render-space follow-through; camera/mouse look stays immediate
local RUN_POSE_RATE = 90 -- restore the earlier short run follow, including at full pace
local RUN_HAND_FRAME = Vector3.new(0, 0.12, 0.25)
-- One-handed ADS: the arm reaches in from the lower right to the centred gun.
local ADS_ARM = Vector3.new(-0.56, 0.42, -0.72).Unit
local ADS_KICK_KEPT = 0.3 -- recoil is calmer through the sight; the camera never moves
local ADS_ARM_WIDTH = 0.8 -- the arm is nearer the eye here, so it slims to keep the view open
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
local steadyWeight = 0
local visualHandle: CFrame? = nil
local cachedTool: Tool? = nil
local muzzleOffset = Vector3.zero
local canisterOffset = Vector3.zero
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

local function armScale(): Vector3
	local T = Tuning.values
	return Vector3.new(T.armWidth, T.armLength, T.armWidth)
end

-- Actual muzzle in the real handle's frame, including rotated mesh extents. The visible
-- gun is the first-person copy when there is one, otherwise the held tool itself.
local function gunPoint(where: () -> Vector3): Vector3?
	local tool = equipped()
	local handle = tool and tool:FindFirstChild("Handle")
	if not tool or not handle or not handle:IsA("BasePart") then
		cachedTool = nil
		return nil
	end
	if tool ~= cachedTool then
		local front, canister = math.huge, Vector3.zero
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
					canister = offset.Position
				end
			end
		end
		muzzleOffset = Vector3.new(0, canister.Y, if front < math.huge then front else -2)
		canisterOffset = canister
		cachedTool = tool
	end
	return (if rig and rig.tool == tool and visualHandle then visualHandle else handle.CFrame)
		* where()
end

function Viewmodel.muzzle(): Vector3?
	return gunPoint(function()
		return muzzleOffset
	end)
end

function Viewmodel.canister(): Vector3?
	return gunPoint(function()
		return canisterOffset
	end)
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
	steadyWeight = 0
end

local function build(character: Model, tool: Tool?, camera: Camera): Rig
	local model = Instance.new("Model")
	model.Name = "FirstPersonBodyVisual"
	local current: Rig = { model = model, character = character, tool = tool, arms = {}, gun = {} }
	for _, name in { "Left Arm", "Right Arm" } do
		local source = character:FindFirstChild(name)
		if source and source:IsA("BasePart") then
			local copy = Instance.new("Part")
			copy.Name, copy.Size, copy.Color = name, source.Size * armScale(), source.Color
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
	local T = Tuning.values
	local character = current.character
	local point = character:GetAttribute("BlasterPoint")
	local steady = typeof(point) == "Vector3"
		and character:GetAttribute("FirstPersonAction") == nil
		and character:GetAttribute("BlasterFlourish") == nil
	steadyWeight += ((if steady then 1 else 0) - steadyWeight) * (1 - math.exp(-14 * dt))
	local handle = current.tool and current.tool:FindFirstChild("Handle")
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
		local idleShoulder = torsoFrame * (top.Position + Vector3.new(arm.side * T.idleOut, 0, 0))
		local runShoulder = torsoFrame.Position
			+ runFacing:VectorToWorldSpace(
				Vector3.new(lane + arm.side * T.runOut, top.Y + chestLift, top.Z)
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
		local fullSize = source.Size * armScale()
		local crop = math.min(T.armLength * CROP_PER_LENGTH, fullSize.Y * 0.4)
		local target = camera.CFrame:ToObjectSpace(CFrame.new(shoulder) * rotation)
		-- Ease shoulder depth independently of the source swing, so framing can
		-- move between a relaxed idle and a more visible running reach.
		local handFrame = Vector3.new(0, T.idleLift, 0.25):Lerp(RUN_HAND_FRAME, straightWeight)
			* postureWeight
		local framedPosition = target.Position + handFrame
		framedPosition += Vector3.new(0, RUN_POSTURE_LIFT * chestLean * straightWeight, 0)
		local shoulderDepth = T.idleDepth
			+ (T.runDepth + chestDepth + RUN_POSTURE_DEPTH * chestLean - T.idleDepth)
				* straightWeight
		framedPosition += Vector3.new(0, 0, (shoulderDepth - framedPosition.Z) * postureWeight)
		-- The camera drops on landing; carry the hands further down so they trail it.
		framedPosition -= Vector3.new(0, FirstPerson.landing() * 0.6, 0)
		target = CFrame.new(framedPosition)
			* target.Rotation
			* CFrame.Angles(math.rad(T.idlePitch) * (1 - straightWeight) * postureWeight, 0, 0)
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
		if arm.side == 1 and steadyWeight > 0.001 and handle and handle:IsA("BasePart") then
			-- Keep shoulder travel and positional bounce, but settle the gun angle
			-- towards the aim while charging/firing. Rotate the arm and gun together
			-- so the hand stays attached; leave a little angular motion for life.
			local gunFromArm = sourceFrame.Rotation:ToObjectSpace(handle.CFrame.Rotation)
			local aimDirection = if typeof(point) == "Vector3"
				then camera.CFrame:VectorToObjectSpace(point).Unit
				else Vector3.new(0, 0, -1)
			local settled = CFrame.lookAt(Vector3.zero, aimDirection) * gunFromArm:Inverse()
			target = CFrame.new(target.Position)
				* target.Rotation:Lerp(settled, 0.88 * steadyWeight)
		end
		local ads = Ads.weight()
		if arm.side == 1 and ads > 0 and handle and handle:IsA("BasePart") then
			local up = -ADS_ARM
			local right = (Vector3.xAxis - up * up.X).Unit
			local reach = CFrame.fromMatrix(Vector3.zero, right, up, right:Cross(up))
			local grip = CFrame.new(0, -(fullSize.Y - source.Size.Y / 2 + T.gripRelease), 0)
				* sourceFrame:ToObjectSpace(handle.CFrame)
			local gunAt = Vector3.new(0, -T.adsGunDown, -T.adsGunForward)
			target = target:Lerp(CFrame.new(gunAt - reach * grip.Position) * reach, ads)
		end
		local rate = if character:GetAttribute("BlasterPoint") ~= nil
			then POSE_RATE * 2
			elseif flipping and AcrobaticCamera.enabled() and AcrobaticCamera.status() < 3 then 72
			else POSE_RATE + (RUN_POSE_RATE - POSE_RATE) * straightWeight
		local alpha = 1 - math.exp(-rate * dt)
		local blended = if arm.frame then arm.frame:Lerp(target, alpha) else target
		arm.frame = blended
		local rendered = blended
		if arm.side == 1 then
			-- Add the firing gesture after pose smoothing so movement cannot blur
			-- away its fast attack. The gun follows this same hand frame.
			local follow = Recoil.follow(
				character:GetAttribute("BlasterRecoilAt"),
				os.clock(),
				character:GetAttribute("BlasterRecoilCharge"),
				character:GetAttribute("BlasterRecoilStyle")
			):Lerp(CFrame.identity, (1 - ADS_KICK_KEPT) * Ads.weight()) * Recoil.armWindup(
				os.clock()
			)
			rendered = CFrame.new(blended.Position + follow.Position)
				* follow.Rotation
				* blended.Rotation
		end
		local armFrame = camera.CFrame * rendered
		local slim = 1 + (ADS_ARM_WIDTH - 1) * Ads.weight()
		arm.copy.Size = Vector3.new(fullSize.X * slim, fullSize.Y - crop, fullSize.Z * slim)
		arm.copy.Color = source.Color
		arm.copy.CFrame = armFrame * CFrame.new(0, -(crop + arm.copy.Size.Y / 2), 0)
		local fadeAlpha = 1 - math.exp(-16 * dt)
		arm.fade += (nearEye(arm.copy, camera.CFrame.Position) - arm.fade) * fadeAlpha
		arm.copy.LocalTransparencyModifier = arm.fade
		if arm.side == 1 then
			-- Use the full virtual hand endpoint, independent of the shoulder crop.
			-- Preserve aim/flourishes, with a small distal shift for a shallower grip.
			gunMap = armFrame
				* CFrame.new(0, -(fullSize.Y - source.Size.Y / 2 + T.gripRelease), 0)
				* sourceFrame:Inverse()
		end
	end
	-- Apply the shot directly to the visible gun about its hand grip. Reading the
	-- hidden tool's joint here depended on the next physics update and weakened
	-- the fast kick. Keeping this after smoothing also preserves the toss/catch.
	if handle and handle:IsA("BasePart") then
		-- Through the sight the gun sits dead centre in view, level with the aim.
		local ads = Ads.weight()
		if ads > 0 then
			local sighted = camera.CFrame * CFrame.new(0, -T.adsGunDown, -T.adsGunForward)
			gunMap = gunMap:Lerp(sighted * handle.CFrame:Inverse(), ads)
		end
		local held = gunMap * handle.CFrame
		-- The idle hands lift forward into view; level the gun so it still hangs relaxed.
		local relaxed = (1 - straightWeight) * postureWeight
		held = held * CFrame.Angles(-math.rad(T.idlePitch + T.idleGunDown) * relaxed, 0, 0)
		gunMap = held * handle.CFrame:Inverse()
		local kick = Recoil.sample(
			character:GetAttribute("BlasterRecoilAt"),
			os.clock(),
			character:GetAttribute("BlasterRecoilCharge"),
			character:GetAttribute("BlasterRecoilStyle")
		):Lerp(CFrame.identity, (1 - ADS_KICK_KEPT) * ads)
		gunMap = held * kick * Recoil.vibration(os.clock()) * held:Inverse() * gunMap
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
				if camera then
					AdsSight.update(camera, equipped(), nil, dt)
				end
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
			AdsSight.update(camera, tool, visualHandle, dt)
		end
	)
end

return Viewmodel
