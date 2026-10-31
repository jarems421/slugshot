--!strict
-- One cosmetic driver per client, observing all players. Supports the native
-- Weld/Motor6D RightGrip; it never removes that joint or changes input/physics.
-- The hold presentation owns RightGrip.C0 (style wrist) and captures it as its base,
-- so this driver only ever writes C1 (the tool's Grip side): the two layers compose
-- instead of one baking the other's flourish into the held pose.
-- Holstered, a visual copy hangs at the hip or shrinks away (HolsterMode); a draw
-- grows that copy back into the hand before the real gun shows, so nothing pops.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Motion = require(script.Parent.BlasterMotion)

local Animator = {}
local started = false
type Grip = JointInstance
type Layer = { joint: Grip, base: CFrame, output: CFrame }
type Ghost = {
	model: Model,
	parts: { { part: BasePart, offset: CFrame } },
	anchor: BasePart, -- the right (upper) leg the holster rides on
	mount: CFrame, -- handle frame relative to the anchor when holstered
	attach: BasePart, -- what the copy currently follows (anchor or hand)
	relative: CFrame,
	stowScale: number,
	vanish: boolean,
	frame: CFrame,
	scale: number,
	fade: number,
}
type Pose = { frame: CFrame, scale: number, fade: number }
type State = {
	character: Model,
	tool: Tool?,
	phase: string?,
	style: Motion.Style,
	start: number,
	moving: number,
	from: { number }?,
	unstow: Pose?,
	values: { number }?,
	grip: Grip?,
	shoulder: Layer?,
	free: Layer?,
	ghost: Ghost?,
	lastHand: BasePart?,
	lastC0: CFrame?,
	holsterGrip: CFrame,
	parts: { BasePart },
	connections: { RBXScriptConnection },
}

local function blaster(item: Instance): boolean
	return item:IsA("Tool") and item:GetAttribute("BlasterMotionDriver") == true
end

-- Each shoulder's rest C0, captured the first time it is seen and never re-read:
-- nothing else writes these joints (the hold presentation uses Transform). Re-reading
-- the live C0 as the base let a missed restore during rapid equip spam bake an
-- offset in, leaving the arm stuck back (owner, 2026-10-31).
local rest: { [Grip]: CFrame } = setmetatable({}, { __mode = "k" }) :: any

local function restore(layer: Layer?)
	if layer and layer.joint.Parent then
		layer.joint.C0 = layer.base
	end
end

local function apply(layer: Layer, offset: CFrame)
	layer.output = CFrame.new(layer.base.Position) * offset * layer.base.Rotation
	layer.joint.C0 = layer.output
end

local function findJoint(character: Model, name: string): Grip?
	for _, item in character:GetDescendants() do
		if item.Name == name and (item:IsA("Weld") or item:IsA("Motor6D")) then
			return item
		end
	end
	return nil
end

local function makeLayer(joint: Grip): Layer
	local base = rest[joint]
	if not base then
		base = joint.C0
		rest[joint] = base
	end
	return { joint = joint, base = base, output = base }
end

local function vanishing(character: Model): boolean
	return (character:GetAttribute("HolsterMode") or Motion.DefaultMode) == "Vanish"
end

-- Visual copy of the tool. Clone the complete model so skinned bones and PBR maps
-- survive; strip only executable/physical joints and lights. It lives under the
-- camera (client-only visuals) and its handle is renamed, so nothing can take it
-- for a tool or a pickup.
local function makeGhost(character: Model, tool: Tool): Ghost?
	local anchor = character:FindFirstChild("Right Leg")
		or character:FindFirstChild("RightUpperLeg")
	local handle = tool:FindFirstChild("Handle")
	if not anchor or not anchor:IsA("BasePart") or not handle or not handle:IsA("BasePart") then
		return nil
	end
	local copied = tool:Clone()
	local copiedFrame = (copied:FindFirstChild("Handle") :: BasePart).CFrame
	local model = Instance.new("Model")
	model.Name = "BlasterHolsterVisual"
	for _, child in copied:GetChildren() do
		child.Parent = model
	end
	copied:Destroy()
	local copiedHandle = model:FindFirstChild("Handle")
	if copiedHandle then
		copiedHandle.Name = "VisualHandle"
	end
	local parts: { { part: BasePart, offset: CFrame } } = {}
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, item in model:GetDescendants() do
		if
			item:IsA("BaseScript")
			or item:IsA("ModuleScript")
			or item:IsA("JointInstance")
			or item:IsA("Constraint")
			or item:IsA("Light")
		then
			item:Destroy()
		elseif item:IsA("BasePart") then
			-- Anchored and placed after physics (settle). Welding it to the body made
			-- the real tool impossible to re-equip (owner, 2026-10-31).
			item.Anchored, item.CanCollide, item.CanQuery, item.CanTouch = true, false, false, false
			item.LocalTransparencyModifier = 0
			local offset = copiedFrame:ToObjectSpace(item.CFrame)
			table.insert(parts, { part = item, offset = offset })
			if item.Transparency < 1 then
				-- Extents in handle space, from each part's rotated half-size.
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
		end
	end
	if low.X > high.X then
		low, high = Vector3.zero, Vector3.zero
	end
	local vanish = vanishing(character)
	local mount, scale = Motion.mount(anchor, (low + high) / 2, (high - low) / 2)
	if vanish then
		-- Shrink toward the same hip point, about the gun's centre.
		local centre = (low + high) / 2
		mount = mount * CFrame.new(centre * scale) * CFrame.new(-centre * Motion.VanishScale)
		scale = Motion.VanishScale
	end
	model.Parent = workspace.CurrentCamera
	return {
		model = model,
		parts = parts,
		anchor = anchor,
		attach = anchor,
		relative = anchor.CFrame:ToObjectSpace(copiedFrame),
		mount = mount,
		stowScale = scale,
		vanish = vanish,
		frame = copiedFrame,
		scale = 1,
		fade = 0,
	}
end

-- Put the copy where its attach part is now. Called again after physics, so it
-- tracks the body in the same frame instead of trailing it (owner).
local function settle(ghost: Ghost)
	local frame = ghost.attach.CFrame * ghost.relative
	ghost.frame = frame
	for _, entry in ghost.parts do
		local offset = entry.offset
		entry.part.CFrame = frame * CFrame.new(offset.Position * ghost.scale) * offset.Rotation
	end
end

local function place(ghost: Ghost, attach: BasePart, frame: CFrame, scale: number, fade: number)
	if math.abs(scale - ghost.scale) > 1e-3 then
		ghost.model:ScaleTo(scale) -- sizes, meshes and bones; frames are set below
		ghost.scale = scale
	end
	ghost.attach, ghost.relative, ghost.fade = attach, attach.CFrame:ToObjectSpace(frame), fade
	for _, entry in ghost.parts do
		entry.part.LocalTransparencyModifier = fade
	end
	settle(ghost)
end

local function hipPose(ghost: Ghost): Pose
	return {
		frame = ghost.anchor.CFrame * ghost.mount,
		scale = ghost.stowScale,
		fade = if ghost.vanish then 1 else 0,
	}
end

-- End the current flourish: joints back to their owners' poses. A holstered ghost stays.
local function finish(state: State)
	if state.grip and state.grip.Parent and state.tool then
		state.grip.C1 = state.tool.Grip
	end
	restore(state.shoulder)
	restore(state.free)
	for _, part in state.parts do
		if part.Parent then
			part.LocalTransparencyModifier = 0
		end
	end
	state.grip, state.shoulder, state.free, state.phase = nil, nil, nil, nil
	state.unstow = nil
	state.parts = {}
	state.character:SetAttribute("BlasterFlourish", nil)
end

local function dropGhost(state: State)
	if state.ghost then
		state.ghost.model:Destroy()
	end
	state.ghost = nil
end

local function clear(state: State)
	finish(state)
	dropGhost(state)
end

-- A new phase starts from wherever the last one was (blended).
local function begin(state: State, phase: string, interrupted: string?)
	local now = os.clock()
	state.from = if interrupted then state.values else nil
	state.style = Motion.style(Motion.Default)
	state.phase, state.start = phase, now
	-- Read by the hold presentation to lift the arm out of the run swing (local only).
	state.character:SetAttribute("BlasterFlourish", phase)
end

local function equip(state: State, tool: Tool)
	local interrupted = state.phase
	-- Draw from the holstered (or half-holstered) copy, making one at the hip if
	-- there is none; the real gun stays hidden until the copy reaches the hand.
	local ghost = state.ghost
	state.ghost = nil
	finish(state)
	if not ghost then
		ghost = makeGhost(state.character, tool)
		if ghost then
			local pose = hipPose(ghost)
			place(ghost, ghost.anchor, pose.frame, pose.scale, pose.fade)
		end
	end
	state.ghost = ghost
	state.unstow = if ghost
		then { frame = ghost.frame, scale = ghost.scale, fade = ghost.fade }
		else nil
	state.tool = tool
	begin(state, "draw", interrupted)
	for _, item in tool:GetDescendants() do
		if item:IsA("BasePart") and item.Name ~= "Handle" then
			table.insert(state.parts, item)
			item.LocalTransparencyModifier = 1
		end
	end
	state.lastHand, state.lastC0 = nil, nil
end

local function holster(state: State, tool: Tool)
	-- Roblox can destroy RightGrip before ChildRemoved fires. Cache its hand and
	-- C0 while equipped, rather than relying on the removed joint.
	local hand, c0 = state.lastHand, state.lastC0
	if state.tool ~= tool or not hand or not c0 then
		clear(state)
		state.tool = nil
		return
	end
	local interrupted = state.phase
	-- Mid-draw the copy is still travelling to the hand: keep it and send it back.
	local ghost = state.ghost
	state.ghost = nil
	clear(state)
	ghost = ghost or makeGhost(state.character, tool)
	state.tool = nil
	if not ghost then
		return
	end
	state.ghost = ghost
	state.lastHand, state.lastC0 = hand, c0
	state.unstow = { frame = ghost.frame, scale = ghost.scale, fade = ghost.fade }
	-- The tool's Grip, kept for placing the copy in the (now empty) hand.
	state.holsterGrip = tool.Grip
	begin(state, "holster", interrupted)
end

function Animator.start()
	if started then
		return
	end
	started = true
	local states: { [Model]: State } = {}
	local function watch(character: Model)
		if states[character] then
			return
		end
		local state: State = {
			character = character,
			phase = nil,
			style = Motion.style(nil),
			start = -math.huge,
			moving = 0,
			holsterGrip = CFrame.identity,
			parts = {},
			connections = {},
		}
		states[character] = state
		table.insert(
			state.connections,
			character.ChildAdded:Connect(function(item)
				if blaster(item) then
					equip(state, item :: Tool)
				end
			end)
		)
		table.insert(
			state.connections,
			character.ChildRemoved:Connect(function(item)
				if blaster(item) then
					holster(state, item :: Tool)
				end
			end)
		)
		for _, item in character:GetChildren() do
			if blaster(item) then
				equip(state, item :: Tool)
			end
		end
	end
	local function playerAdded(player: Player)
		player.CharacterAdded:Connect(watch)
		if player.Character then
			watch(player.Character)
		end
	end
	Players.PlayerAdded:Connect(playerAdded)
	for _, player in Players:GetPlayers() do
		playerAdded(player)
	end
	-- Re-place the copies once animation and physics have moved the body this frame.
	RunService.PostSimulation:Connect(function()
		for _, state in states do
			local ghost = state.ghost
			if ghost and ghost.attach.Parent then
				settle(ghost)
			end
		end
	end)
	-- Render after native animation and the movement presentation. The shoulder is an
	-- additive C0 layer over Animator's Transform writes; the gun turns on C1.
	RunService:BindToRenderStep(
		"SlugshotBlasterDrawHolster",
		Enum.RenderPriority.Character.Value + 1,
		function(dt: number)
			for character, state in states do
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				if not character.Parent or not humanoid or humanoid.Health <= 0 then
					clear(state)
					for _, connection in state.connections do
						connection:Disconnect()
					end
					states[character] = nil
					continue
				end
				local ghost = state.ghost
				if ghost and not (ghost.anchor.Parent and ghost.attach.Parent) then
					dropGhost(state)
					ghost = nil
				end
				local tool = state.tool
				local joint = if tool then findJoint(character, "RightGrip") else nil
				if tool and joint and joint.Part0 then
					-- Clean held frame for a later holster: C0 without any flourish.
					state.lastHand, state.lastC0 = joint.Part0, joint.C0
				end
				local root = humanoid.RootPart
				local velocity = if root then root.AssemblyLinearVelocity else Vector3.zero
				local target = math.clamp(
					Vector3.new(velocity.X, 0, velocity.Z).Magnitude / Motion.RunSpeed,
					0,
					1
				)
				state.moving += (target - state.moving) * (1 - math.exp(-12 * dt))
				if not state.phase then
					if ghost then
						if ghost.vanish or vanishing(character) then
							dropGhost(state) -- fully shrunk away, or the setting changed
						else
							local pose = hipPose(ghost)
							place(ghost, ghost.anchor, pose.frame, pose.scale, pose.fade)
						end
					end
					continue
				end
				local drawing = state.phase == "draw"
				local stand, run = Motion.tracks(state.style, drawing)
				local elapsed = (os.clock() - state.start) * Motion.Speed
				local values = Motion.sample(stand, run, elapsed, state.moving)
				if state.from then
					values = Motion.blend(state.from, values, math.min(elapsed / Motion.Blend, 1))
				end
				-- Hip holster: the hand goes to the holster's grip as the draw starts
				-- and as the holster stows (Vanish keeps the arm's own motion).
				if ghost and not ghost.vanish and state.unstow then
					local reach = Motion.reach(state.style, drawing, elapsed)
					for i, angle in Motion.Hip.Reach do
						values[6 + i] += angle * reach
					end
				end
				state.values = values
				local wrist, arm, counter, visibility = Motion.frames(values)
				if not state.shoulder then
					local shoulder = findJoint(character, "Right Shoulder")
						or findJoint(character, "RightShoulder")
					if shoulder then
						state.shoulder = makeLayer(shoulder)
					end
				end
				if not state.free then
					local shoulder = findJoint(character, "Left Shoulder")
						or findJoint(character, "LeftShoulder")
					if shoulder then
						state.free = makeLayer(shoulder)
					end
				end
				if state.shoulder then
					apply(state.shoulder, arm)
				end
				if state.free then
					apply(state.free, counter)
				end
				local from = state.unstow
				if drawing and tool and joint and joint.Part0 then
					state.grip = joint
					joint.C1 = tool.Grip * wrist:Inverse()
					-- The copy grows from the hip into the hand, then hands over.
					local lifting = ghost ~= nil and from ~= nil and elapsed < Motion.Unstow
					if ghost and from then
						if lifting then
							local held = joint.Part0.CFrame * joint.C0 * wrist * tool.Grip:Inverse()
							local u = Motion.smooth(elapsed / Motion.Unstow)
							place(
								ghost,
								joint.Part0,
								from.frame:Lerp(held, u),
								from.scale + (1 - from.scale) * u,
								from.fade * (1 - u)
							)
						else
							dropGhost(state)
						end
					end
					for _, part in state.parts do
						if part.Parent then
							part.LocalTransparencyModifier = if lifting then 1 else 1 - visibility
						end
					end
				elseif not drawing and ghost and from and state.lastHand and state.lastC0 then
					-- Holster: flourish in the empty hand, then to the hip (or away).
					local inHand = state.lastHand.CFrame
						* state.lastC0
						* wrist
						* state.holsterGrip:Inverse()
					local u = Motion.smooth(math.min(elapsed / Motion.Blend, 1))
					local frame = from.frame:Lerp(inHand, u)
					local scale = from.scale + (1 - from.scale) * u
					local fade = from.fade * (1 - u)
					local a, b = Motion.stowAt(state.style)
					local s = Motion.smooth((elapsed - a) / (b - a))
					if s > 0 then
						if character:GetAttribute("BlasterFlourish") ~= "stow" then
							character:SetAttribute("BlasterFlourish", "stow")
						end
						local hip = hipPose(ghost)
						frame = frame:Lerp(hip.frame, s)
						scale += (hip.scale - scale) * s
						fade += (hip.fade - fade) * s
					end
					local attach = if s > 0.5 then ghost.anchor else state.lastHand
					place(ghost, attach, frame, scale, 1 - (1 - fade) * visibility)
				end
				local _, stowed = Motion.stowAt(state.style)
				local length = math.max(Motion.length(stand), Motion.length(run))
				if not drawing then
					length = math.max(length, stowed + Motion.Hip.ReachOut)
				end
				if elapsed >= length then
					finish(state)
					if drawing then
						dropGhost(state) -- the grip never arrived in time: don't leave a copy
					end
					state.tool = tool
				end
			end
		end
	)
end

return Animator
