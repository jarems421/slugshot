--!strict
-- Aquabeek's motion (docs/slugs/catalog/aquabeek.md). Owner, 2026-11-14: "finalize this as a design, and then build out
-- Aquabeek and ... get into Roblox", then "let's work on the transformations and transformation trails".
--
-- AquabeekLoaded (her base form in the gun's canister): a slow, graceful idle, the body swaying and the head tilting.
-- AquabeekTransformed (the shared transformation's form, flying): her blades ripple from root to tip, each pair a beat
-- behind the one above, as the concept's blades sway; the tail swings and the body rolls a little. A thin water trail
-- streams off the tip of each of her six blades and droplets spill off them (owner, 2026-11-14: "I want fluid trails";
-- built water geometry on the blades was "just stiff things"; "a 3D trail resembling something like water"). The trails
-- are Combat's FlightTrails.
--
-- Moves are authored in concept axes and turned into each bone's own space through the rest rotation AquabeekAppearance
-- recorded on it at import (attribute RestRotation). Roblox can make more than one copy of a bone, so every copy is driven.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local STUDS_PER_UNIT = 0.43 -- tools/slugs/export_aquabeek_roblox.py GAME_SCALE, at the model's import scale

-- Concept axes (x her left, y up, z toward her face) to the imported model's. Seen in Studio (2026-11-14): her bones'
-- rest rotations are already in concept axes (she imports facing +z), so nothing turns.
local function import(v: Vector3): Vector3
	return v
end

local UP = import(Vector3.yAxis)
local ROLL_AXIS = import(Vector3.zAxis)
local NOD_AXIS = import(Vector3.xAxis)
-- The blades at rest, concept units: root, bend and tip on her left (tools/slugs/export_aquabeek_roblox.py BLADES).
local BLADES: { [string]: { Vector3 } } = {
	Upper = {
		Vector3.new(0.22, 1.94, -0.32),
		Vector3.new(0.60, 2.28, -0.85),
		Vector3.new(0.76, 2.30, -1.75),
	},
	Middle = {
		Vector3.new(0.40, 1.66, -0.38),
		Vector3.new(0.86, 1.80, -0.82),
		Vector3.new(1.04, 1.70, -1.50),
	},
	Lower = {
		Vector3.new(0.30, 1.28, -0.40),
		Vector3.new(0.76, 1.02, -0.86),
		Vector3.new(0.86, 0.86, -1.65),
	},
}
local BLADE_PHASE: { [string]: number } = { Upper = 0, Middle = 0.7, Lower = 1.4 }
local RIPPLE = 9 -- radians a second: a shot is in the air for well under a second
-- Degrees, and each bone's lag behind the blade's root: the wave runs out along the blade.
local CHAIN = {
	{ bone = "Blade%s1", swing = 6, lag = 0 },
	{ bone = "Blade%s2", swing = 8, lag = 0.9 },
}
local FlightTrail = (require :: any)(
	Players.LocalPlayer.PlayerScripts:WaitForChild("Combat"):WaitForChild("FlightTrail")
)

-- Each bone's flap axis (import space): across the blade, in its flat face, so a turn moves the blade sideways out of
-- its plane, as a fin strokes. Mirrored per side, so both sides stroke out together.
type Flap = { bone: string, axis: Vector3, swing: number, lag: number, phase: number }
type Side = { tag: string, sign: number }
-- A blade's tip: the end of its second bone. Imported bones run along their own y axis, so the tip is the bone's length
-- up that axis, concept units.
type Tip = { bone: string, length: number }
local SIDES: { Side } = { { tag = "L", sign = 1 }, { tag = "R", sign = -1 } } -- L is her left, +x
local FLAPS: { Flap } = {}
local TIPS: { Tip } = {}
for name, points in BLADES do
	for _, side in SIDES do
		local tag, s = side.tag, side.sign
		local a = Vector3.new(points[1].X * s, points[1].Y, points[1].Z)
		local b = Vector3.new(points[2].X * s, points[2].Y, points[2].Z)
		local c = Vector3.new(points[3].X * s, points[3].Y, points[3].Z)
		local out = Vector3.new(s, 0, 0)
		local root = import((b - a):Cross(out).Unit)
		local tip = import((c - b):Cross(out).Unit)
		for index, link in CHAIN do
			table.insert(FLAPS, {
				bone = `{string.format(link.bone, name)}.{tag}`,
				axis = if index == 1 then root else tip,
				swing = link.swing,
				lag = link.lag,
				phase = BLADE_PHASE[name],
			})
		end
		table.insert(TIPS, { bone = `Blade{name}2.{tag}`, length = (c - b).Magnitude })
	end
end

type Bones = { [string]: { Bone } }

-- Apply an import-space rotation to every copy of a bone, each in its own space.
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

type Droplet = { part: Part, age: number, life: number, size: Vector3, velocity: Vector3 }
type Streak = { bone: Bone, length: number, trail: any }
type Flight = {
	model: Model,
	bones: Bones,
	clock: number,
	streaks: { Streak },
	droplets: { Droplet },
	spawnDebt: number,
}

local flights: { [Model]: Flight } = {}
local idles: { [Model]: { bones: Bones, phase: number } } = {}

local TRAIL = { -- a FlightTrail.Style
	layers = {
		-- A body of water where her blade passed, round masses packed into one (owner, 2026-11-14: Rammstone's is "the ideal
		-- trail"; splashes read as spraying), sagging and turning, aqua deepening to blue. Six of these, so each is much
		-- thinner and a little shorter than his (owner, 2026-11-14: several at once "can become a bit overwhelming ...
		-- scale them down a bit"), packed closer to stay smooth at that size.
		{
			sprite = "flow",
			spacing = 0.09,
			most = 20,
			size = { 0.2, 0.3, 0.26, 0.12 },
			lifetime = NumberRange.new(0.45, 0.75),
			colour = ColorSequence.new({
				-- Saturated from the start: pale, it read as cloud.
				ColorSequenceKeypoint.new(0, Color3.fromRGB(110, 215, 255)),
				ColorSequenceKeypoint.new(0.15, Color3.fromRGB(40, 170, 240)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(25, 110, 220)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 55, 160)),
			}),
			transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.8, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
			speed = NumberRange.new(0.1, 0.4),
			acceleration = Vector3.new(0, -1.2, 0),
			drag = 1.5,
			spin = NumberRange.new(-60, 60),
			scatter = 0.05,
			glow = 0.15,
			z = 1,
		},
		-- Spray flicked off it.
		{
			sprite = "water",
			spacing = 0.7,
			most = 3,
			size = { 0.06, 0.045, 0.015 },
			lifetime = NumberRange.new(0.4, 0.8),
			colour = ColorSequence.new(Color3.fromRGB(200, 240, 255), Color3.fromRGB(60, 160, 235)),
			transparency = NumberSequence.new(0.1),
			speed = NumberRange.new(0.8, 1.8),
			acceleration = Vector3.new(0, -5, 0),
			glow = 0.3,
			z = 2,
		},
	} :: { any },
}
local DROPLET_COLOURS = {
	Color3.fromRGB(150, 232, 250),
	Color3.fromRGB(90, 196, 240),
	Color3.fromRGB(225, 250, 255),
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
	flights[model] = {
		model = model,
		bones = bones,
		clock = 0,
		streaks = streaks,
		droplets = {},
		spawnDebt = 0,
	}
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
	-- Droplets already thrown off keep falling and fade on their own.
	for _, droplet in flight.droplets do
		local part = droplet.part
		task.spawn(function()
			local left = droplet.life - droplet.age
			local t = 0
			while t < left and part.Parent do
				local dt = RunService.Heartbeat:Wait()
				t += dt
				local f = 1 - math.clamp((droplet.age + t) / droplet.life, 0, 1)
				part.Position += droplet.velocity * dt
				part.Size = droplet.size * math.max(f, 0.05)
				part.Transparency = 1 - f * 0.8
			end
			part:Destroy()
		end)
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
	apply(bones.Body, CFrame.fromAxisAngle(ROLL_AXIS, math.rad(3 * math.sin(c * 4.5))))
	apply(bones.Tail, CFrame.fromAxisAngle(UP, math.rad(12 * math.sin(c * RIPPLE - 1.6))))
	for _, flap in FLAPS do
		local angle = flap.swing * math.sin(c * RIPPLE - flap.phase - flap.lag)
		apply(bones[flap.bone], CFrame.fromAxisAngle(flap.axis, math.rad(angle)))
	end

	-- The trails and droplets come off her blade tips.
	local pivot = model:GetPivot()
	local visible = pivot.Position.Y > -10000 -- parked far below until the transformation reveals her
	local laying = FlightTrail.ready(model)
	local tips: { Vector3 } = {}
	for _, streak in flight.streaks do
		local frame = moved(streak.bone)
		local tip = frame.Position + frame.UpVector * (streak.length * studs)
		table.insert(tips, tip)
		FlightTrail.step(streak.trail, tip, studs, laying)
	end
	if visible and #tips > 0 then
		flight.spawnDebt += step * 30
		while flight.spawnDebt >= 1 do
			flight.spawnDebt -= 1
			local from = tips[random:NextInteger(1, #tips)]
			local size = studs * random:NextNumber(0.05, 0.11)
			local part = Instance.new("Part")
			part.Name = "AquabeekDroplet"
			part.Shape = Enum.PartType.Ball
			part.Size = Vector3.one * size
			part.Material = Enum.Material.Glass
			part.Color = DROPLET_COLOURS[random:NextInteger(1, #DROPLET_COLOURS)]
			part.Transparency = 0.2
			part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
			part.CastShadow = false
			part.Position = from + random:NextUnitVector() * studs * 0.08
			part.Parent = Workspace.CurrentCamera
			table.insert(flight.droplets, {
				part = part,
				age = 0,
				life = random:NextNumber(0.35, 0.6),
				size = part.Size,
				velocity = random:NextUnitVector() * studs * 0.6 - Vector3.new(0, studs * 1.0, 0),
			})
		end
	end
	for i = #flight.droplets, 1, -1 do
		local droplet = flight.droplets[i]
		droplet.age += step
		local f = 1 - math.clamp(droplet.age / droplet.life, 0, 1)
		if f <= 0 then
			droplet.part:Destroy()
			table.remove(flight.droplets, i)
		else
			droplet.velocity -= Vector3.new(0, studs * 4 * step, 0) -- falling away
			droplet.part.Position += droplet.velocity * step
			droplet.part.Size = droplet.size * math.max(f, 0.05)
			droplet.part.Transparency = math.clamp(1 - f * 0.8, 0.2, 1)
		end
	end
end

-- The base form's idle in the canister: slow and graceful, the body swaying and the head tilting and turning a little.
local function updateIdle(state: { bones: Bones, phase: number }, dt: number)
	state.phase += dt
	local c = state.phase
	apply(state.bones.body, CFrame.fromAxisAngle(ROLL_AXIS, math.rad(2.5 * math.sin(c * 1.4))))
	apply(
		state.bones.head,
		CFrame.fromAxisAngle(ROLL_AXIS, math.rad(4 * math.sin(c * 1.4 - 0.9)))
			* CFrame.fromAxisAngle(NOD_AXIS, math.rad(2 * math.sin(c * 0.9)))
			* CFrame.fromAxisAngle(UP, math.rad(5 * math.sin(c * 0.6)))
	)
end

local function watch(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	if instance.Name == "AquabeekTransformed" then
		startFlight(instance)
	elseif instance.Name == "AquabeekLoaded" then
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
