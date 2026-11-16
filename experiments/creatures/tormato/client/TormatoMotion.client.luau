--!strict
-- Tormato's motion (docs/slugs/catalog/tormato.md). Owner, 2026-11-16: "add both into Studio".
--
-- TormatoLoaded (his base form in the gun's canister): the concept's idle, the top of him drifting round in a slow circle
-- as if the wind keeps turning him, and the head following a beat behind.
-- TormatoTransformed (the shared transformation's form, flying): the flap travels out along each dragon wing, arm, hand
-- and tip each a beat behind, as the concept's does; the tail swings behind and the body rolls a little. Thin pale wind
-- streams off each wing tip and the tail's grey tip. The trails are Combat's FlightTrails.
--
-- Moves are authored in concept axes and turned into each bone's own space through the rest rotation TormatoAppearance
-- recorded on it at import (attribute RestRotation). He exports as Aquabeek does (tools/slugs/export_tormato_roblox.py),
-- whose bones import already in concept axes. Roblox can make more than one copy of a bone, so every copy is driven.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local STUDS_PER_UNIT = 0.41 -- tools/slugs/export_tormato_roblox.py GAME_SCALE, at the model's import scale

local UP = Vector3.yAxis
local ROLL_AXIS = Vector3.zAxis -- along his length, toward his face
local NOD_AXIS = Vector3.xAxis
-- His left wing at rest, concept units: root, wrist, hand and tip (export_tormato_roblox.py WING), and the tail's middle
-- and tip (TAIL).
local WING = {
	Vector3.new(0.42, 1.52, -0.80),
	Vector3.new(1.22, 1.79, -0.45),
	Vector3.new(1.87, 2.04, -0.67),
	Vector3.new(2.47, 2.30, -1.35),
}
local TAIL_MIDDLE, TAIL_TIP = Vector3.new(0.11, 1.36, -2.30), Vector3.new(-0.01, 1.53, -3.10)
local FLAP = 8 -- radians a second: a shot is in the air for well under a second
-- Degrees, and each bone's lag behind the wing's root: the flap travels out along the wing.
local CHAIN = {
	{ bone = "Wing1", swing = 20, lag = 0 },
	{ bone = "Wing2", swing = 14, lag = 0.7 },
	{ bone = "Wing3", swing = 12, lag = 1.4 },
}
local FlightTrail = (require :: any)(
	Players.LocalPlayer.PlayerScripts:WaitForChild("Combat"):WaitForChild("FlightTrail")
)

type Flap = { bone: string, axis: Vector3, swing: number, lag: number }
type Tip = { bone: string, length: number }
local FLAPS: { Flap } = {}
-- A tip: the end of a bone. Imported bones run along their own y axis, so the tip is the bone's length up that axis,
-- concept units.
local TIPS: { Tip } = { { bone = "Tail2", length = (TAIL_TIP - TAIL_MIDDLE).Magnitude } }
for _, side in { { tag = "L", sign = 1 }, { tag = "R", sign = -1 } } do -- L is his left, +x
	for _, link in CHAIN do
		-- About his length, so a turn lifts the wing; mirrored, so both wings beat together.
		table.insert(FLAPS, {
			bone = `{link.bone}.{side.tag}`,
			axis = ROLL_AXIS * side.sign,
			swing = link.swing,
			lag = link.lag,
		})
	end
	table.insert(TIPS, { bone = `Wing3.{side.tag}`, length = (WING[4] - WING[3]).Magnitude })
end

type Bones = { [string]: { Bone } }

-- Apply a concept-space rotation to every copy of a bone, each in its own space.
local function apply(copies: { Bone }?, rotation: CFrame)
	if not copies then
		return
	end
	for _, bone in copies do
		local rest = bone:GetAttribute("RestRotation")
		if typeof(rest) == "CFrame" then
			bone.Transform = rest:Inverse() * rotation * rest
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

type Streak = { bone: Bone, length: number, trail: any }
type Flight = { model: Model, bones: Bones, clock: number, streaks: { Streak } }

local flights: { [Model]: Flight } = {}
local idles: { [Model]: { bones: Bones, phase: number } } = {}

local TRAIL = { -- a FlightTrail.Style
	layers = {
		-- Wind where his wings passed: thin, pale and quick, pale wind white thinning to storm grey as it drifts and goes,
		-- so it reads as air rather than smoke.
		{
			sprite = "flow",
			spacing = 0.09,
			most = 18,
			size = { 0.12, 0.2, 0.18, 0.08 },
			lifetime = NumberRange.new(0.3, 0.55),
			colour = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(245, 250, 255)),
				ColorSequenceKeypoint.new(0.4, Color3.fromRGB(205, 214, 226)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 146, 156)),
			}),
			transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.35),
				NumberSequenceKeypoint.new(0.6, 0.5),
				NumberSequenceKeypoint.new(1, 1),
			}),
			speed = NumberRange.new(0.2, 0.6),
			acceleration = Vector3.new(0, 0.4, 0),
			drag = 2,
			spin = NumberRange.new(-180, 180),
			scatter = 0.04,
			glow = 0.1,
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
	if flights[model] then
		return
	end
	local bones = bonesOf(model)
	local streaks: { Streak } = {}
	for _, tip in TIPS do
		local copies = bones[tip.bone]
		if copies then
			table.insert(
				streaks,
				{ bone = copies[1], length = tip.length, trail = FlightTrail.new(TRAIL) }
			)
		end
	end
	flights[model] = { model = model, bones = bones, clock = 0, streaks = streaks }
end

local function stopFlight(model: Model)
	local flight = flights[model]
	if not flight then
		return
	end
	flights[model] = nil
	for _, streak in flight.streaks do
		FlightTrail.release(streak.trail)
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
	apply(bones.Body, CFrame.fromAxisAngle(ROLL_AXIS, math.rad(3 * math.sin(c * FLAP * 0.5))))
	apply(
		bones.Head,
		CFrame.fromAxisAngle(ROLL_AXIS, math.rad(-2 * math.sin(c * FLAP * 0.5 - 0.6)))
	)
	apply(bones.Tail1, CFrame.fromAxisAngle(UP, math.rad(10 * math.sin(c * 6 - 1.0))))
	apply(bones.Tail2, CFrame.fromAxisAngle(UP, math.rad(16 * math.sin(c * 6 - 1.9))))
	for _, flap in FLAPS do
		apply(
			bones[flap.bone],
			CFrame.fromAxisAngle(flap.axis, math.rad(flap.swing * math.sin(c * FLAP - flap.lag)))
		)
	end

	-- The wind comes off his wing tips and tail tip.
	local laying = FlightTrail.ready(model)
	for _, streak in flight.streaks do
		local frame = moved(streak.bone)
		FlightTrail.step(
			streak.trail,
			frame.Position + frame.UpVector * (streak.length * studs),
			studs,
			laying
		)
	end
end

-- The base form's idle in the canister: the top of him drifting round in a slow circle, the head a beat behind.
local function updateIdle(state: { bones: Bones, phase: number }, dt: number)
	state.phase += dt
	local c = state.phase * 1.3
	apply(
		state.bones.body,
		CFrame.fromAxisAngle(ROLL_AXIS, math.rad(2.5 * math.sin(c)))
			* CFrame.fromAxisAngle(NOD_AXIS, math.rad(1.5 * math.cos(c)))
	)
	apply(
		state.bones.head,
		CFrame.fromAxisAngle(ROLL_AXIS, math.rad(3 * math.sin(c - 0.8)))
			* CFrame.fromAxisAngle(NOD_AXIS, math.rad(2 * math.cos(c - 0.8)))
			* CFrame.fromAxisAngle(UP, math.rad(4 * math.sin(state.phase * 0.5)))
	)
end

local function watch(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	if instance.Name == "TormatoTransformed" then
		startFlight(instance)
	elseif instance.Name == "TormatoLoaded" then
		idles[instance] = { bones = bonesOf(instance), phase = random:NextNumber(0, 6) }
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
