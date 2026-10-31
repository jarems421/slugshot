--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SlugAssets")
local Types = require(Shared.Types)
local Timeline = require(Shared.Timeline)
local Definitions = require(Shared.Definitions)
local NativeFixture = require(script.Parent.NativeFixture)
local Playback = require(script.Parent.Playback)
local Squash = require(script.Parent.Squash)
local Visual = {}
Visual.__index = Visual

export type Options = {
	parent: Instance,
	resolveModel: ((string, Types.Form) -> Model)?,
	animationIds: { [string]: { [string]: string } }?,
	onEffect: ((string, Types.Sample, CFrame) -> ())?,
	orientation: CFrame?,
	scale: number?,
	onDeform: ((Model, number) -> ())?,
}
type State = {
	species: Types.Species,
	models: { [string]: Model },
	players: { [string]: Playback.Player },
	parent: Instance,
	active: string,
	options: Options,
	dead: boolean,
	progress: number,
	deformers: { [string]: Squash.Deformer },
	manualSlot: string?,
}
export type Handle = typeof(setmetatable({} :: State, Visual))

function Visual.new(speciesId: string, options: Options): Handle
	local species = Definitions.species[speciesId]
	assert(species, "Unknown slug species: " .. speciesId)
	assert(not options.scale or (options.scale > 0 and options.scale <= 10), "Invalid visual scale")
	local self = setmetatable(
		{
			species = species,
			models = {},
			players = {},
			parent = options.parent,
			active = "protoform",
			options = options,
			dead = false,
			progress = 0,
			deformers = {},
			manualSlot = nil,
		} :: State,
		Visual
	)
	local ok, failure = pcall(function()
		for name, form in species.forms do
			local rig = Definitions.rigs[form.rig]
			local model: Model
			if options.resolveModel then
				model = options.resolveModel(name, form):Clone()
			else
				model = NativeFixture.create(species, form, rig)
			end
			self.models[name] = model
			assert(model.PrimaryPart, "Creature template requires PrimaryPart at its export origin")
			model.PrimaryPart.Anchored = true
			model:ScaleTo(options.scale or 1)
			if not options.resolveModel then
				self.deformers[name] = Squash.new(model)
			end
			model.Parent = options.parent -- Animator requires a model in the DataModel.
			self.players[name] = Playback.new(
				model,
				form,
				rig,
				if options.animationIds then options.animationIds[name] else nil,
				species.placeholder
			)
			if name ~= "protoform" then
				model.Parent = nil
			end
		end
		self.players.protoform:play("idle")
	end)
	if not ok then
		self:destroy()
		error(failure)
	end
	return self
end

function Visual.idle(self: Handle, pose: CFrame, elapsed: number)
	assert(not self.dead and self.active == "protoform", "Idle requires a live protoform")
	self.models.protoform:PivotTo(pose * (self.options.orientation or CFrame.identity))
	self.players.protoform:samplePlaceholder(elapsed, 0)
	if self.deformers.protoform then
		Squash.apply(self.deformers.protoform, math.sin(elapsed * math.pi * 2) * 0.025)
	end
end

-- Caller supplies its projectile pose, elapsed time and a current total-flight estimate.
-- An impact only finishes presentation; this object never casts, deals damage or delays gameplay.
function Visual.update(
	self: Handle,
	pose: CFrame,
	elapsed: number,
	estimatedFlightSeconds: number,
	impacted: boolean
): Types.Sample
	assert(not self.dead, "Visual already destroyed")
	local sample = Timeline.sample(
		self.species.transformation,
		elapsed,
		estimatedFlightSeconds,
		impacted,
		self.progress
	)
	self.progress = sample.progress
	local formName = if sample.transformed then "transformed" else "protoform"
	if self.active ~= formName then
		self.models[self.active].Parent = nil
		self.manualSlot = nil
		self.active = formName
		self.models[formName].Parent = self.parent
		self.players[formName]:play("reveal")
	end
	local player = self.players[self.active]
	if not self.manualSlot then
		local slot = if sample.transformed
			then "reveal"
			elseif sample.stage == "energy" then "prepare"
			elseif sample.stage == "launch" then "launch"
			else "spin"
		if self.species.forms[self.active].animations[slot] then
			player:play(slot)
		end
		local progress = if sample.transformed
			then sample.reveal
			elseif sample.stage == "launch" then sample.progress / 0.15
			elseif sample.stage == "energy" then (sample.progress - 0.35)
				/ (self.species.transformation.transitionFraction - 0.35)
			else (elapsed * self.species.transformation.spinTurnsPerSecond) % 1
		player:seek(progress)
	end
	local model = self.models[self.active]
	local orientation = self.options.orientation or CFrame.identity
	local spin = if player.current == "spin" and player.tracks.spin then 0 else sample.spin
	model:PivotTo(pose * orientation * CFrame.Angles(0, 0, spin))
	if self.deformers[self.active] then
		Squash.apply(self.deformers[self.active], sample.squash)
	elseif self.options.onDeform then
		self.options.onDeform(model, sample.squash)
	end
	self.players[self.active]:samplePlaceholder(elapsed, sample.reveal)
	if self.options.onEffect then
		self.options.onEffect(self.species.transformation.effect, sample, pose)
	end
	return sample
end

-- Species attack VISUAL only, triggered explicitly by a future gameplay owner.
function Visual.playSlot(self: Handle, slot: string): boolean
	if self.dead or not self.species.forms[self.active].animations[slot] then
		return false
	end
	self.manualSlot = slot
	return self.players[self.active]:play(slot, true)
end

function Visual.resumeSequence(self: Handle)
	self.manualSlot = nil
end

function Visual.playAttack(self: Handle): boolean
	return self:playSlot("attack")
end

function Visual.destroy(self: Handle)
	if self.dead then
		return
	end
	self.dead = true
	for _, player in self.players do
		player:destroy()
	end
	for _, model in self.models do
		model:Destroy()
	end
end

return Visual
