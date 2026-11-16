--!strict
-- Rammstone's motion (docs/slugs/catalog/rammstone.md). Owner, 2026-11-13: "build it in Studio. Do the idle animations,
-- the transformation, make sure the transformation is similar to Burpee's thing, maybe have like a red trail with like
-- floating rocks behind it, like just really small pebbles".
--
-- RammstoneLoaded (his base form in the gun's canister): a slow, heavy idle, the body swaying and the head nodding.
-- RammstoneTransformed (the shared transformation's form, flying): a flight idle with the tail swinging; the punch
-- approved in Blender (tools/slugs/build_rammstone_transformed.py PUNCH, TAIL_SWING), timed so its hit frame lands on the
-- predicted impact (the form's ImpactIn attribute, from SlugTransformation), played faster and from the swing alone on
-- close shots; and behind him a trail of molten lava and tumbling pebbles that start hot and cool to rock (owner,
-- 2026-11-14: "a 3D trail of ... molten lava / rock"), one of Combat's FlightTrails.
--
-- Moves are authored in the source model's units and axes and turned into each bone's own space through the rest
-- rotation RammstoneAppearance recorded on it at import (attribute RestRotation).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local STUDS_PER_UNIT = 0.47 -- tools/slugs/export_rammstone_roblox.py GAME_SCALE, at the model's import scale
local FPS = 24
local HIT = (10 - 1) / FPS -- the punch's hit frame, from its first
local SWING = (7 - 1) / FPS -- where the swing starts, after the wind-up
local FASTEST = 1.6 -- how much faster than authored the punch may play before it starts from the swing
local FlightTrail = (require :: any)(
	Players.LocalPlayer.PlayerScripts:WaitForChild("Combat"):WaitForChild("FlightTrail")
)
local TRAIL = { -- a FlightTrail.Style
	layers = {
		-- Molten blobs left hanging behind his tail, sagging, turning and cooling from yellow-hot to dark rock.
		{
			sprite = "lava",
			spacing = 0.14,
			most = 18,
			size = { 0.45, 0.6, 0.5, 0.25 },
			lifetime = NumberRange.new(0.7, 1.1),
			colour = ColorSequence.new({
				-- Into red at once: sprites this bright read yellow (cheese, not lava) for most of their life otherwise.
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 140, 45)),
				ColorSequenceKeypoint.new(0.06, Color3.fromRGB(255, 90, 25)),
				ColorSequenceKeypoint.new(0.3, Color3.fromRGB(205, 40, 15)),
				ColorSequenceKeypoint.new(0.65, Color3.fromRGB(105, 24, 14)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(42, 28, 26)),
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
			scatter = 0.12,
			glow = 0.1,
			z = 1,
		},
		-- Drips falling off it.
		{
			sprite = "lava",
			spacing = 0.5,
			size = { 0.13, 0.1, 0.04 },
			lifetime = NumberRange.new(0.5, 0.9),
			colour = ColorSequence.new(Color3.fromRGB(255, 150, 50), Color3.fromRGB(150, 30, 12)),
			transparency = NumberSequence.new(0),
			speed = NumberRange.new(0.6, 1.6),
			acceleration = Vector3.new(0, -6, 0),
			glow = 0.5,
			z = 2,
		},
	} :: { any },
}

-- Source axes (x right of the viewer, y back, z up) to the imported model's (exported turned to face +y, then y-up).
local function import(v: Vector3): Vector3
	return Vector3.new(-v.X, v.Z, v.Y)
end

local UP = import(Vector3.zAxis)
local FORWARD_ROLL_AXIS = import(Vector3.yAxis)
-- Arms at rest (shoulder, elbow, wrist), source units.
local ARMS = {
	R = {
		Vector3.new(-0.86, 0.45, 1.40),
		Vector3.new(-1.30, 1.08, 1.00),
		Vector3.new(-1.30, 0.36, 0.80),
	},
	L = {
		Vector3.new(0.86, 0.45, 1.40),
		Vector3.new(1.30, 1.08, 1.00),
		Vector3.new(1.30, 0.36, 0.80),
	},
}
type Arm = { Vector3 }?
type Key = {
	frame: number,
	turn: number,
	roll: number,
	shift: Vector3,
	right: Arm,
	left: Arm,
	tail: number,
}
local STRIKE = { Vector3.new(-1.36, -0.28, 1.30), Vector3.new(-1.22, -1.12, 1.10) }
local LEFT_BACK = { Vector3.new(1.32, 1.28, 1.06), Vector3.new(1.38, 0.58, 0.88) }
local PUNCH: { Key } = {
	{ frame = 1, turn = 0, roll = 0, shift = Vector3.zero, right = nil, left = nil, tail = 0 },
	{
		frame = 5,
		turn = -24,
		roll = 6,
		shift = Vector3.new(0.12, 0.10, 0),
		right = { Vector3.new(-1.20, 1.25, 1.45), Vector3.new(-1.42, 0.60, 1.60) },
		left = nil,
		tail = 9,
	},
	{
		frame = 7,
		turn = -26,
		roll = 7,
		shift = Vector3.new(0.13, 0.12, 0),
		right = { Vector3.new(-1.20, 1.28, 1.48), Vector3.new(-1.44, 0.62, 1.64) },
		left = nil,
		tail = 10,
	},
	{
		frame = 8,
		turn = 4,
		roll = 0,
		shift = Vector3.new(0, -0.10, 0),
		right = { Vector3.new(-1.62, 0.25, 1.40), Vector3.new(-1.70, -0.62, 1.30) },
		left = LEFT_BACK,
		tail = 3,
	},
	{
		frame = 10,
		turn = 26,
		roll = -8,
		shift = Vector3.new(-0.10, -0.30, 0),
		right = STRIKE,
		left = LEFT_BACK,
		tail = -12,
	},
	{
		frame = 12,
		turn = 31,
		roll = -9,
		shift = Vector3.new(-0.12, -0.36, 0),
		right = { Vector3.new(-1.22, -0.45, 1.34), Vector3.new(-0.55, -1.22, 1.20) },
		left = LEFT_BACK,
		tail = 6,
	},
	{
		frame = 16,
		turn = 24,
		roll = -6,
		shift = Vector3.new(-0.08, -0.25, 0),
		right = STRIKE,
		left = LEFT_BACK,
		tail = -3,
	},
	{ frame = 28, turn = 0, roll = 0, shift = Vector3.zero, right = nil, left = nil, tail = 0 },
}
local FAST = { [7] = true, [8] = true } -- keys whose following stretch runs at an even pace: the swing

local function between(a: Vector3, b: Vector3): CFrame
	local axis = a:Cross(b)
	if axis.Magnitude < 1e-6 then
		return CFrame.identity
	end
	return CFrame.fromAxisAngle(axis.Unit, math.acos(math.clamp(a.Unit:Dot(b.Unit), -1, 1)))
end

-- A key as rotations (import space, each relative to its parent bone) and the body's shift (source units).
type Pose = { [string]: CFrame }
local function aim(side: string, target: Arm): (CFrame, CFrame)
	if not target then
		return CFrame.identity, CFrame.identity
	end
	local rest = ARMS[side]
	local s, e0, w0 = import(rest[1]), import(rest[2]), import(rest[3])
	local e1, w1 = import(target[1]), import(target[2])
	local upper = between(e0 - s, e1 - s)
	return upper, upper:Inverse() * between(w0 - e0, w1 - e1)
end
local function pose(key: Key): (Pose, Vector3)
	local p: Pose = {}
	p.Body = CFrame.fromAxisAngle(UP, math.rad(key.turn))
		* CFrame.fromAxisAngle(FORWARD_ROLL_AXIS, math.rad(key.roll))
	p.Tail = CFrame.fromAxisAngle(UP, math.rad(key.tail))
	p["UpperArm.R"], p["Forearm.R"] = aim("R", key.right)
	p["UpperArm.L"], p["Forearm.L"] = aim("L", key.left)
	return p, import(key.shift)
end
local POSES: { Pose } = {}
local SHIFTS: { Vector3 } = {}
for i, key in PUNCH do
	POSES[i], SHIFTS[i] = pose(key)
end

local function smooth(x: number): number
	return x * x * (3 - 2 * x)
end

-- The punch's pose t seconds in.
local function punchAt(t: number): (Pose, Vector3)
	local frame = 1 + t * FPS
	local last = PUNCH[#PUNCH]
	if frame >= last.frame then
		return POSES[#PUNCH], SHIFTS[#PUNCH]
	end
	for i = 1, #PUNCH - 1 do
		local a, b = PUNCH[i], PUNCH[i + 1]
		if frame < b.frame then
			local x = (frame - a.frame) / (b.frame - a.frame)
			if not FAST[a.frame] then
				x = smooth(x)
			end
			local out: Pose = {}
			for bone, from in POSES[i] do
				out[bone] = from:Lerp(POSES[i + 1][bone], x)
			end
			return out, SHIFTS[i]:Lerp(SHIFTS[i + 1], x)
		end
	end
	return POSES[1], SHIFTS[1]
end

-- Apply an import-space rotation (and shift, studs) to a bone in its own space.
local function apply(bone: Bone?, rotation: CFrame, shift: Vector3?)
	if not bone then
		return
	end
	local rest = bone:GetAttribute("RestRotation")
	if typeof(rest) ~= "CFrame" then
		return
	end
	local local_ = rest:Inverse() * rotation * rest
	if shift then
		local_ = CFrame.new(rest:VectorToObjectSpace(shift)) * local_
	end
	bone.Transform = local_
end

type Flight = {
	model: Model,
	bones: { [string]: Bone },
	clock: number,
	trail: any,
	pebbles: {
		{
			part: Part,
			age: number,
			life: number,
			size: Vector3,
			drift: Vector3,
			spin: CFrame,
			rock: Color3,
			molten: boolean,
		}
	},
	spawnDebt: number,
	punchStart: number?,
	punchFrom: number,
	punchRate: number,
}

local flights: { [Model]: Flight } = {}
local idles: { [Model]: { bones: { [string]: Bone }, phase: number } } = {}

local MOLTEN = Color3.fromRGB(255, 120, 35)
local PEBBLE_COLOURS = {
	Color3.fromRGB(92, 22, 16),
	Color3.fromRGB(120, 34, 22),
	Color3.fromRGB(58, 50, 50),
	Color3.fromRGB(150, 52, 30),
}
local random = Random.new()

local function bonesOf(model: Model): { [string]: Bone }
	local out: { [string]: Bone } = {}
	for _, item in model:GetDescendants() do
		if item:IsA("Bone") then
			out[item.Name] = item
		end
	end
	return out
end

local function startFlight(model: Model)
	if flights[model] then
		return
	end
	local flight: Flight = {
		model = model,
		bones = bonesOf(model),
		clock = 0,
		trail = FlightTrail.new(TRAIL),
		pebbles = {},
		spawnDebt = 0,
		punchStart = nil,
		punchFrom = 0,
		punchRate = 1,
	}
	-- Time the punch so its hit frame lands on the predicted impact (shot time from launch, when the form is made).
	local impact = model:GetAttribute("ImpactIn")
	if typeof(impact) == "number" and impact > 0 then
		if impact >= HIT then
			flight.punchStart = impact - HIT
		else
			flight.punchStart = 0
			flight.punchFrom = math.max(0, HIT - impact * FASTEST)
			if flight.punchFrom > SWING then
				flight.punchFrom = SWING -- point-blank: the swing alone, fast
			end
			flight.punchRate = (HIT - flight.punchFrom) / impact
		end
	end
	flights[model] = flight
end

local function stopFlight(model: Model)
	local flight = flights[model]
	if not flight then
		return
	end
	flights[model] = nil
	FlightTrail.release(flight.trail)
	-- Pebbles already thrown off keep tumbling and fade on their own.
	for _, pebble in flight.pebbles do
		local part = pebble.part
		task.spawn(function()
			local left = pebble.life - pebble.age
			local t = 0
			while t < left and part.Parent do
				t += RunService.Heartbeat:Wait()
				local f = 1 - math.clamp((pebble.age + t) / pebble.life, 0, 1)
				part.Size = pebble.size * math.max(f, 0.05)
				part.Transparency = 1 - f
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
	local bones = flight.bones
	local studs = STUDS_PER_UNIT * model:GetScale()
	local p: Pose, shift: Vector3
	if flight.punchStart and flight.clock >= flight.punchStart then
		p, shift = punchAt(flight.punchFrom + (flight.clock - flight.punchStart) * flight.punchRate)
	else
		-- Flight idle: a slow roll and the tail swinging behind it.
		local c = flight.clock
		p = {
			Body = CFrame.fromAxisAngle(FORWARD_ROLL_AXIS, math.rad(3 * math.sin(c * 5))),
			Tail = CFrame.fromAxisAngle(UP, math.rad(7 * math.sin(c * 5 - 1.1))),
		}
		shift = Vector3.zero
	end
	apply(bones.Body, p.Body or CFrame.identity, shift * studs)
	for _, name in { "Tail", "UpperArm.R", "Forearm.R", "UpperArm.L", "Forearm.L" } do
		apply(bones[name], p[name] or CFrame.identity)
	end

	-- The trail and pebbles come off the tip of his tail.
	local body, tail = bones.Body, bones.Tail
	if not (body and tail) then
		return
	end
	local pivot = model:GetPivot()
	local visible = pivot.Position.Y > -10000 -- parked far below until the transformation reveals him
	local back = tail.WorldPosition - body.WorldPosition
	local tip = tail.WorldPosition + back * 2.0
	FlightTrail.step(flight.trail, tip, studs, FlightTrail.ready(model))
	if visible then
		flight.spawnDebt += step * 40
		while flight.spawnDebt >= 1 do
			flight.spawnDebt -= 1
			local size = studs * random:NextNumber(0.1, 0.22)
			local part = Instance.new("Part")
			part.Name = "RammstonePebble"
			part.Size = Vector3.new(
				size,
				size * random:NextNumber(0.6, 1),
				size * random:NextNumber(0.7, 1.1)
			)
			local rock = PEBBLE_COLOURS[random:NextInteger(1, #PEBBLE_COLOURS)]
			local molten = random:NextNumber() < 0.6
			part.Material = if molten then Enum.Material.Neon else Enum.Material.Slate
			part.Color = if molten then MOLTEN else rock
			part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
			part.CastShadow = false
			local spread = random:NextUnitVector() * studs * 0.35
			part.CFrame = CFrame.new(tip + spread)
				* CFrame.Angles(
					random:NextNumber(0, 6.3),
					random:NextNumber(0, 6.3),
					random:NextNumber(0, 6.3)
				)
			part.Parent = Workspace.CurrentCamera
			table.insert(flight.pebbles, {
				part = part,
				age = 0,
				life = random:NextNumber(0.45, 0.8),
				size = part.Size,
				drift = random:NextUnitVector() * studs * 0.6 + Vector3.new(0, studs * 0.15, 0),
				spin = CFrame.Angles(
					random:NextNumber(-6, 6),
					random:NextNumber(-6, 6),
					random:NextNumber(-6, 6)
				),
				rock = rock,
				molten = molten,
			})
		end
	end
	for i = #flight.pebbles, 1, -1 do
		local pebble = flight.pebbles[i]
		pebble.age += step
		local f = 1 - math.clamp(pebble.age / pebble.life, 0, 1)
		if f <= 0 then
			pebble.part:Destroy()
			table.remove(flight.pebbles, i)
		else
			local spin = CFrame.new():Lerp(pebble.spin, step)
			pebble.part.CFrame = (pebble.part.CFrame + pebble.drift * step) * spin
			pebble.part.Size = pebble.size * math.max(f, 0.05)
			pebble.part.Transparency = math.clamp(1 - f * 1.4, 0, 1)
			if pebble.molten then
				-- Cooling: glowing at first, dark rock by halfway.
				local cooled = math.clamp((1 - f) / 0.5, 0, 1)
				pebble.part.Color = MOLTEN:Lerp(pebble.rock, cooled)
				if cooled >= 1 then
					pebble.part.Material = Enum.Material.Slate
					pebble.molten = false
				end
			end
		end
	end
end

-- The base form's idle in the canister: slow and heavy, the body swaying and the head nodding a little.
local function updateIdle(state: { bones: { [string]: Bone }, phase: number }, dt: number)
	state.phase += dt
	local c = state.phase
	apply(
		state.bones.body,
		CFrame.fromAxisAngle(FORWARD_ROLL_AXIS, math.rad(2.5 * math.sin(c * 1.6)))
	)
	apply(
		state.bones.head,
		CFrame.fromAxisAngle(import(Vector3.xAxis), math.rad(3 * math.sin(c * 1.6 - 0.8)))
			* CFrame.fromAxisAngle(UP, math.rad(4 * math.sin(c * 0.7)))
	)
end

local function watch(instance: Instance)
	if not instance:IsA("Model") then
		return
	end
	if instance.Name == "RammstoneTransformed" then
		startFlight(instance)
	elseif instance.Name == "RammstoneLoaded" then
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
