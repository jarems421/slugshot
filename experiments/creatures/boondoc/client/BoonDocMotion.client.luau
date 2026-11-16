--!strict
-- Boon Doc's motion (docs/slugs/catalog/boon-doc.md). Owner, 2026-11-16: "add both into Studio".
--
-- BoonDocLoaded (his base form in the gun's canister): a calm sway, his little angel wings fluttering now and then, the
-- antennae swaying a beat behind, and the halo bobbing over his head, as the concept's does.
-- BoonDocTransformed (the shared transformation's form, flying): the fat toad's small angel wings beat fast, as if only
-- just holding him up; his pudgy arms and dangling legs sway, each joint a beat behind; the halo bobs. A soft trail of
-- glowing healing motes, mint turning gold, drifts up behind him. The trail is Combat's FlightTrails.
--
-- Moves are authored in concept axes and turned into each bone's own space through the rest rotation BoonDocAppearance
-- recorded on it at import (attribute RestRotation). He exports as Aquabeek does (tools/slugs/export_boon_doc_roblox.py),
-- whose bones import already in concept axes. Roblox can make more than one copy of a bone, so every copy is driven.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local STUDS_PER_UNIT = 0.41 -- tools/slugs/export_boon_doc_roblox.py GAME_SCALE, at the model's import scale

local UP = Vector3.yAxis
local ROLL_AXIS = Vector3.zAxis -- along his length, toward his face
local NOD_AXIS = Vector3.xAxis
local BEAT = 14 -- radians a second: small wings working hard
local SIDES = { { tag = "L", sign = 1 }, { tag = "R", sign = -1 } } -- L is his left, +x
local FlightTrail = (require :: any)(
	Players.LocalPlayer.PlayerScripts:WaitForChild("Combat"):WaitForChild("FlightTrail")
)

type Bones = { [string]: { Bone } }

-- Apply a concept-space move (rotation, or a shift for the halo's bob) to every copy of a bone, each in its own space.
local function apply(copies: { Bone }?, move: CFrame)
	if not copies then
		return
	end
	for _, bone in copies do
		local rest = bone:GetAttribute("RestRotation")
		if typeof(rest) == "CFrame" then
			bone.Transform = rest:Inverse() * move * rest
		end
	end
end

-- A bone's frame in the world with this frame's motion already in it. Bone.TransformedWorldCFrame only catches up a frame
-- later, which left Inferno's fire trailing his tail.
local function moved(item: Instance): CFrame
	local parent = item.Parent
	if item:IsA("Bone") then
		return (if parent then moved(parent) else CFrame.identity) * item.CFrame * item.Transform
	elseif item:IsA("BasePart") then
		return item.CFrame
	end
	return CFrame.identity
end

type Flight = { model: Model, bones: Bones, clock: number, trail: any }

local flights: { [Model]: Flight } = {}
type Idle = { model: Model, bones: Bones, phase: number }
local idles: { [Model]: Idle } = {}

local TRAIL = { -- a FlightTrail.Style
	layers = {
		-- Healing motes: small soft glowing puffs, mint turning gold as they drift up and fade.
		{
			sprite = "flow",
			spacing = 0.22,
			most = 6,
			size = { 0.05, 0.11, 0.09, 0.03 },
			lifetime = NumberRange.new(0.5, 0.9),
			colour = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(170, 255, 220)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 236, 196)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 226, 150)),
			}),
			transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(0.7, 0.3),
				NumberSequenceKeypoint.new(1, 1),
			}),
			speed = NumberRange.new(0.3, 0.8),
			acceleration = Vector3.new(0, 1.2, 0),
			drag = 1.5,
			spin = NumberRange.new(-90, 90),
			scatter = 0.18,
			glow = 0.7,
			z = 1,
		},
	} :: { any },
}
local random = Random.new()

local function bonesOf(model: Model): Bones
	local out: Bones = {}
	for _, item in model:GetDescendants() do
		if item:IsA("Bone") then
			local list = out[item.Name] or {}
			table.insert(list, item)
			out[item.Name] = list
		end
	end
	return out
end

local function startFlight(model: Model)
	if not flights[model] then
		flights[model] =
			{ model = model, bones = bonesOf(model), clock = 0, trail = FlightTrail.new(TRAIL) }
	end
end

local function stopFlight(model: Model)
	local flight = flights[model]
	if flight then
		flights[model] = nil
		FlightTrail.release(flight.trail)
	end
end

local function updateFlight(flight: Flight, dt: number)
	local model = flight.model
	local scale = model:GetAttribute("TimeScale")
	local step = dt * (if typeof(scale) == "number" then scale else 1)
	flight.clock += step
	local c = flight.clock
	local bones = flight.bones
	local studs = STUDS_PER_UNIT * model:GetScale()
	apply(bones.Body, CFrame.fromAxisAngle(ROLL_AXIS, math.rad(2.5 * math.sin(c * 3))))
	apply(bones.Halo, CFrame.new(UP * (0.04 * studs * math.sin(c * 4))))
	for _, side in SIDES do
		local tag, s = side.tag, side.sign
		-- About his length, so a turn lifts the wing; mirrored, so both beat together.
		apply(
			bones[`Wing1.{tag}`],
			CFrame.fromAxisAngle(ROLL_AXIS * s, math.rad(22 * math.sin(c * BEAT)))
		)
		apply(
			bones[`Wing2.{tag}`],
			CFrame.fromAxisAngle(ROLL_AXIS * s, math.rad(14 * math.sin(c * BEAT - 0.8)))
		)
		for i, swing in { 6, 8, 10 } do
			apply(
				bones[`Arm{i}.{tag}`],
				CFrame.fromAxisAngle(NOD_AXIS, math.rad(swing * math.sin(c * 5 - i * 0.6 + s)))
			)
			apply(
				bones[`Leg{i}.{tag}`],
				CFrame.fromAxisAngle(NOD_AXIS, math.rad(swing * math.sin(c * 4 - i * 0.7 - s)))
			)
		end
	end

	-- The motes drift up from behind him.
	local body = bones.Body and bones.Body[1]
	if body then
		FlightTrail.step(flight.trail, moved(body).Position, studs, FlightTrail.ready(model))
	end
end

-- The base form's idle in the canister: a calm sway, the antennae a beat behind, the wings fluttering in short bursts
-- every few seconds, and the halo bobbing.
local function updateIdle(state: Idle, dt: number)
	state.phase += dt
	local c = state.phase
	local bones = state.bones
	apply(bones.body, CFrame.fromAxisAngle(ROLL_AXIS, math.rad(2 * math.sin(c * 1.2))))
	apply(
		bones.head,
		CFrame.fromAxisAngle(ROLL_AXIS, math.rad(3 * math.sin(c * 1.2 - 0.8)))
			* CFrame.fromAxisAngle(NOD_AXIS, math.rad(1.5 * math.sin(c * 0.8)))
	)
	local studs = STUDS_PER_UNIT * state.model:GetScale()
	apply(bones.Halo, CFrame.new(UP * (0.03 * studs * math.sin(c * 1.5))))
	-- A short flutter now and then: a burst of beats every five seconds or so.
	local burst = math.max(0, math.sin(c * 1.25)) ^ 8
	for _, side in SIDES do
		local tag, s = side.tag, side.sign
		apply(
			bones[`Wing.{tag}`],
			CFrame.fromAxisAngle(ROLL_AXIS * s, math.rad(14 * burst * math.sin(c * 16)))
		)
		apply(
			bones[`Antenna.{tag}`],
			CFrame.fromAxisAngle(ROLL_AXIS, math.rad(5 * math.sin(c * 1.2 - 1.6 + s * 0.4)))
		)
	end
end

local function watch(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	if instance.Name == "BoonDocTransformed" then
		startFlight(instance)
	elseif instance.Name == "BoonDocLoaded" then
		idles[instance] =
			{ model = instance, bones = bonesOf(instance), phase = random:NextNumber(0, 6) }
	end
end

for _, item in Workspace:GetDescendants() do
	watch(item)
end
Workspace.DescendantAdded:Connect(watch)
Players.LocalPlayer.CharacterAdded:Connect(function(character)
	for _, item in character:GetDescendants() do
		watch(item)
	end
	character.DescendantAdded:Connect(watch)
end)
if Players.LocalPlayer.Character then
	Players.LocalPlayer.Character.DescendantAdded:Connect(watch)
end

RunService.RenderStepped:Connect(function(dt)
	for model, flight in flights do
		if not model:IsDescendantOf(game) then
			stopFlight(model)
		else
			updateFlight(flight, dt)
		end
	end
	for model, state in idles do
		if not model:IsDescendantOf(game) then
			idles[model] = nil
		else
			updateIdle(state, dt)
		end
	end
end)
