--!strict
-- One cosmetic driver per client, observing all players. Supports the native
-- Weld/Motor6D RightGrip; it never removes that joint or changes input/physics.
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
	hand: BasePart,
	relative: CFrame,
	pivot: CFrame,
}
type State = {
	character: Model,
	tool: Tool?,
	phase: string?,
	start: number,
	grip: Layer?,
	shoulder: Layer?,
	ghost: Ghost?,
	lastHandle: CFrame?,
	lastRelative: CFrame?,
	lastHand: BasePart?,
	lastPivot: CFrame?,
	parts: { BasePart },
	connections: { RBXScriptConnection },
}

local function blaster(item: Instance): boolean
	return item:IsA("Tool") and item:GetAttribute("BlasterMotionDriver") == true
end

local function restore(layer: Layer?)
	if layer and layer.joint.Parent and layer.joint.C0 == layer.output then
		layer.joint.C0 = layer.base
	end
end

local function apply(layer: Layer, offset: CFrame, parentAxes: boolean)
	local current = layer.joint.C0
	if current ~= layer.output then
		layer.base = current -- Animator/presentation remains the owner of the base pose.
	end
	layer.output = if parentAxes
		then CFrame.new(layer.base.Position) * offset * layer.base.Rotation
		else layer.base * offset
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
	return { joint = joint, base = joint.C0, output = joint.C0 }
end

local function clear(state: State)
	restore(state.grip)
	restore(state.shoulder)
	for _, part in state.parts do
		if part.Parent then
			part.LocalTransparencyModifier = 0
		end
	end
	if state.ghost then
		state.ghost.model:Destroy()
	end
	state.grip, state.shoulder, state.ghost, state.phase = nil, nil, nil, nil
	state.parts = {}
end

local function equip(state: State, tool: Tool)
	clear(state) -- rapid re-equip cancels the previous visual immediately
	state.tool, state.start, state.phase = tool, os.clock(), "draw"
	for _, item in tool:GetDescendants() do
		if item:IsA("BasePart") and item.Name ~= "Handle" then
			table.insert(state.parts, item)
			item.LocalTransparencyModifier = 1
		end
	end
	state.lastHandle, state.lastRelative = nil, nil
	state.lastHand, state.lastPivot = nil, nil
end

local function holster(state: State, tool: Tool)
	if state.tool ~= tool or not state.lastHandle then
		clear(state)
		state.tool = nil
		return
	end
	-- Roblox can destroy RightGrip before ChildRemoved fires. Cache its hand and
	-- palm pivot while equipped, rather than relying on the removed joint.
	local hand = state.lastHand
	local handle = tool:FindFirstChild("Handle")
	if not hand or not handle or not handle:IsA("BasePart") then
		clear(state)
		state.tool = nil
		return
	end
	local lastHandle = state.lastHandle
	local relative = state.lastRelative or hand.CFrame:ToObjectSpace(lastHandle)
	local pivot = state.lastPivot or CFrame.identity
	-- Clone the complete model so skinned bones and PBR maps survive. Strip only
	-- executable/physical joints and lights; meshes keep their rest/skin data.
	local copied = tool:Clone()
	local copiedHandle = copied:FindFirstChild("Handle") :: BasePart
	local copiedFrame = copiedHandle.CFrame
	local model = Instance.new("Model")
	model.Name = "BlasterHolsterVisual"
	for _, child in copied:GetChildren() do
		child.Parent = model
	end
	copied:Destroy()
	local parts: { { part: BasePart, offset: CFrame } } = {}
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
			item.Anchored, item.CanCollide, item.CanQuery, item.CanTouch = true, false, false, false
			item.LocalTransparencyModifier = 0
			table.insert(parts, { part = item, offset = copiedFrame:ToObjectSpace(item.CFrame) })
		end
	end
	clear(state)
	state.tool, state.phase, state.start = nil, "holster", os.clock()
	state.ghost = { model = model, parts = parts, hand = hand, relative = relative, pivot = pivot }
	model.Parent = workspace
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
		local state: State =
			{ character = character, phase = nil, start = 0, parts = {}, connections = {} }
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
	-- Render after native animation and the movement presentation. Additive C0
	-- layers avoid fighting Animator's Transform writes and preserve grip contact.
	RunService:BindToRenderStep(
		"SlugshotBlasterDrawHolster",
		Enum.RenderPriority.Character.Value + 1,
		function()
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
				local elapsed = os.clock() - state.start
				local drawing = state.phase == "draw"
				local track = if drawing then Motion.Draw else Motion.Holster
				local wrist, arm, visibility = Motion.sample(track, elapsed)
				if state.phase then
					if not state.shoulder then
						local shoulder = findJoint(character, "Right Shoulder")
							or findJoint(character, "RightShoulder")
						if shoulder then
							state.shoulder = makeLayer(shoulder)
						end
					end
					if state.shoulder then
						apply(state.shoulder, arm, true)
					end
				end
				if state.tool then
					local handle = state.tool:FindFirstChild("Handle")
					local joint = if state.grip and state.grip.joint.Parent
						then state.grip.joint
						else findJoint(character, "RightGrip")
					if joint and (not state.grip or state.grip.joint ~= joint) then
						state.grip = makeLayer(joint)
					end
					if drawing and state.grip then
						apply(state.grip, wrist, false)
						for _, part in state.parts do
							if part.Parent then
								part.LocalTransparencyModifier = 1 - visibility
							end
						end
					end
					if handle and handle:IsA("BasePart") then
						state.lastHandle = handle.CFrame
						if joint and joint.Part0 then
							state.lastHand, state.lastPivot = joint.Part0, joint.C1
							state.lastRelative = joint.Part0.CFrame:ToObjectSpace(handle.CFrame)
						end
					end
				end
				local ghost = state.ghost
				if ghost then
					if not ghost.hand.Parent then
						clear(state)
						continue
					end
					local frame = ghost.hand.CFrame
						* ghost.relative
						* ghost.pivot
						* wrist
						* ghost.pivot:Inverse()
					for _, entry in ghost.parts do
						entry.part.CFrame = frame * entry.offset
						entry.part.LocalTransparencyModifier = 1 - visibility
					end
				end
				if state.phase and elapsed >= track[#track][1] then
					if drawing then
						for _, part in state.parts do
							if part.Parent then
								part.LocalTransparencyModifier = 0
							end
						end
						restore(state.grip)
						restore(state.shoulder)
						state.phase, state.shoulder = nil, nil
					else
						clear(state)
					end
				end
			end
		end
	)
end

return Animator
