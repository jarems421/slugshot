--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SlugAssets")
local Types = require(Shared.Types)
local Playback = {}
Playback.__index = Playback

type Joint = Bone | Motor6D
type State = {
	model: Model,
	form: Types.Form,
	joints: { [string]: Joint },
	tracks: { [string]: AnimationTrack },
	animations: { Animation },
	current: string?,
	placeholder: boolean,
	clock: number,
	started: number,
}
export type Player = typeof(setmetatable({} :: State, Playback))

function Playback.new(
	model: Model,
	form: Types.Form,
	rig: Types.Rig,
	ids: { [string]: string }?,
	placeholder: boolean
): Player
	assert(model:GetAttribute("RigId") == form.rig, "Model RigId does not match species form")
	local joints: { [string]: Joint } = {}
	for _, item in model:GetDescendants() do
		if item:IsA("Bone") or item:IsA("Motor6D") then
			assert(not joints[item.Name], "Duplicate creature joint: " .. item.Name)
			joints[item.Name] = item
		elseif item:IsA("BasePart") then
			item.CanCollide, item.CanTouch, item.CanQuery = false, false, false
		end
	end
	for _, bone in rig.bones do
		assert(joints[bone.name], "Missing creature bone: " .. bone.name)
		local joint = joints[bone.name]
		if joint:IsA("Bone") then
			local parentBone = joint:FindFirstAncestorWhichIsA("Bone")
			assert(
				(if parentBone then parentBone.Name else nil) == bone.parent,
				"Incorrect bone hierarchy: " .. bone.name
			)
		elseif bone.parent then
			local parentJoint = joints[bone.parent]
			assert(
				parentJoint and parentJoint:IsA("Motor6D") and joint.Part0 == parentJoint.Part1,
				"Incorrect joint hierarchy: " .. bone.name
			)
		end
	end
	for name, socket in rig.sockets do
		local existing = model:FindFirstChild(name, true)
		if existing then
			assert(existing:IsA("Attachment"), "Socket name is not an Attachment: " .. name)
		else
			local joint = joints[socket.bone]
			local localPosition = Vector3.new(
				socket.position[1] * form.size[1],
				socket.position[3] * form.size[3],
				-socket.position[2] * form.size[2]
			) * model:GetScale()
			local world = model:GetPivot() * CFrame.new(localPosition)
			local attachment = Instance.new("Attachment")
			attachment.Name = name
			if joint:IsA("Bone") then
				attachment.CFrame = joint.WorldCFrame:ToObjectSpace(world)
				attachment.Parent = joint
			else
				local target = joint.Part1
				assert(target, "Socket joint has no Part1: " .. name)
				attachment.CFrame = target.CFrame:ToObjectSpace(world)
				attachment.Parent = target
			end
		end
	end
	for _, animation in form.animations do
		assert(animation.rig == rig.id, "Incompatible animation rig")
	end
	local self = setmetatable(
		{
			model = model,
			form = form,
			joints = joints,
			tracks = {},
			animations = {},
			current = nil,
			placeholder = placeholder,
			clock = 0,
			started = 0,
		} :: State,
		Playback
	)
	local controller = model:FindFirstChildOfClass("AnimationController")
		or Instance.new("AnimationController")
	controller.Parent = model
	local animator = controller:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = controller
	local references: { [string]: string } = ids or {}
	for slot, id in references do
		assert(
			string.match(id, "^rbxassetid://[1-9]%d*$"),
			"Invalid private animation reference: " .. slot
		)
		local definition = form.animations[slot]
		assert(definition, "Missing animation slot: " .. slot)
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		table.insert(self.animations, animation)
		local ok, result = pcall(function(): AnimationTrack
			return animator:LoadAnimation(animation)
		end)
		if ok then
			local track = result :: AnimationTrack
			track.Looped = definition.loop
			self.tracks[slot] = track
		else
			warn("Creature animation load failed: " .. slot .. ": " .. tostring(result))
		end
	end
	return self
end

function Playback.play(self: Player, slot: string, restart: boolean?): boolean
	assert(self.form.animations[slot], "Missing animation slot: " .. slot)
	if self.current == slot and not restart then
		return if self.tracks[slot] then true else self.placeholder
	end
	for _, track in self.tracks do
		track:Stop(0.08)
	end
	self.current = slot
	self.started = self.clock
	local track = self.tracks[slot]
	if track then
		track:AdjustSpeed(1)
		track:Play(0.08)
		return true
	end
	if not self.placeholder then
		warn("No private Roblox animation binding for slot: " .. slot)
	end
	return self.placeholder
end

function Playback.seek(self: Player, progress: number)
	local track = if self.current then self.tracks[self.current] else nil
	if track then
		track:AdjustSpeed(0)
		track.TimePosition = math.clamp(progress, 0, 1) * track.Length
	end
end

function Playback.samplePlaceholder(self: Player, time: number, reveal: number)
	self.clock = time
	if not self.placeholder or (self.current and self.tracks[self.current]) then
		return
	end
	for name, joint in self.joints do
		local transform = CFrame.identity
		if self.current == "idle" and name == "head" then
			transform = CFrame.Angles(0, math.sin(time * math.pi * 2) * 0.12, 0)
		elseif self.current == "reveal" and string.find(name, "wing", 1, true) then
			transform =
				CFrame.Angles(0, 0, (if name == "wing_left" then -1 else 1) * 0.8 * (1 - reveal))
		elseif self.current == "attack" and name == "crest" then
			transform = CFrame.Angles(
				-math.sin(math.clamp(time - self.started, 0, 1) * math.pi) * 0.6,
				0,
				0
			)
		end
		-- Both engine classes expose Transform; cast avoids an LSP union-property limitation.
		local target = joint :: Motor6D
		target.Transform = transform
	end
end

function Playback.destroy(self: Player)
	for _, track in self.tracks do
		track:Stop(0)
		track:Destroy()
	end
	for _, animation in self.animations do
		animation:Destroy()
	end
	table.clear(self.tracks)
	table.clear(self.animations)
end

return Playback
