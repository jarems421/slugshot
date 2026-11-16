--!strict
-- A slug's flight trail as its element, left hanging in the air behind it (owner, 2026-11-14): "it's like a 3D trail of
-- something resembling fire ... molten lava / rock for Ramstone ... something like water for Aquabeak", lasting "like a
-- second". A Roblox Trail is a flat ribbon whose square end met each tip as "a flat line", and a smooth tube read as
-- "colored tubes". This is many overlapping comic sprites (tools/slugs/build_trail_art.py, tinted by each layer's
-- colours) laid evenly along the path the tip has taken, each living its own short life: swelling, drifting, turning,
-- changing colour and fading, so the trail has depth and moves like its element from every side. The body of a trail is
-- round masses packed close enough to merge (Rammstone's, "the ideal trail"); shaped sprites read one by one.
--
-- Each frame's particles are emitted from a box stretched along the path from the last tip to this one, so a shot moving
-- hundreds of studs a second leaves no gaps (emitting from a moved attachment put a whole frame's worth on one spot: the
-- emitter reads its position when it draws). Once released, a trail lays nothing new; what is there plays out, then it
-- goes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local FlightTrail = {}

-- How far a form's reveal (its Reveal attribute, from SlugTransformation) has to go before its trails start: while it
-- grows in, its tips sweep out along the blades and wings and would lay trail over them.
FlightTrail.READY = 0.7

-- Whether a flying form should be laying its trails: shown, not parked far below before its reveal, and mostly grown in.
function FlightTrail.ready(form: Model): boolean
	local reveal = form:GetAttribute("Reveal")
	return form:GetPivot().Position.Y > -10000
		and (typeof(reveal) ~= "number" or reveal >= FlightTrail.READY)
end

-- The sprites, private image ids (private-assets/trails/TrailArt.luau); Roblox's own fire and smoke stand in without them.
local art: { [string]: number } = {}
local artModule = ReplicatedStorage:FindFirstChild("TrailArt")
if artModule and artModule:IsA("ModuleScript") then
	art = (require :: any)(artModule)
end
local STAND_IN: { [string]: string } = {
	lava = "rbxasset://textures/particles/fire_main.dds",
	blaze = "rbxasset://textures/particles/fire_main.dds",
	flow = "rbxasset://textures/particles/smoke_main.dds",
	water = "rbxasset://textures/particles/smoke_main.dds",
}

-- Sizes, distances and speeds are in concept units, turned into studs by each step's `studs`.
export type Layer = {
	sprite: string, -- lava, blaze, flow or water
	spacing: number, -- between particles along the path
	most: number?, -- particles per 60th of a second at most, whatever the frame rate; past it the spacing widens
	size: { number }, -- over the particle's life, evenly spaced keys
	lifetime: NumberRange, -- seconds
	colour: ColorSequence,
	transparency: NumberSequence,
	speed: NumberRange,
	acceleration: Vector3, -- world axes: up drifts, down falls
	drag: number?,
	spin: NumberRange?, -- degrees a second
	scatter: number?, -- how far from the path each starts
	glow: number?, -- LightEmission
	upright: boolean?, -- keep the sprite's top up (flames), rather than any way round
	z: number?, -- ZOffset: which layer draws in front
}

export type Style = { layers: { Layer } }

type Laid = {
	layer: Layer,
	emitter: ParticleEmitter,
	box: Part,
	carry: number, -- distance along the path since the last particle
	studs: number, -- the scale the emitter's sizes were set for
}

export type Trail = {
	holder: Folder,
	laid: { Laid },
	last: Vector3?,
	clock: number?, -- when the last step laid
	released: boolean,
}

local function sizes(layer: Layer, studs: number): NumberSequence
	local keys = {}
	local count = #layer.size
	for i, value in layer.size do
		table.insert(
			keys,
			NumberSequenceKeypoint.new(
				(i - 1) / math.max(count - 1, 1),
				value * studs,
				value * studs * 0.35
			)
		)
	end
	return NumberSequence.new(keys)
end

local function setScale(laid: Laid, studs: number)
	local layer = laid.layer
	local emitter = laid.emitter
	emitter.Size = sizes(layer, studs)
	emitter.Speed = NumberRange.new(layer.speed.Min * studs, layer.speed.Max * studs)
	emitter.Acceleration = layer.acceleration * studs
	laid.studs = studs
end

function FlightTrail.new(style: Style): Trail
	local holder = Instance.new("Folder")
	holder.Name = "FlightTrail"
	local laid: { Laid } = {}
	for _, layer in style.layers do
		local box = Instance.new("Part")
		box.Name = layer.sprite
		box.Size = Vector3.one * 0.05
		box.Transparency = 1
		box.Anchored, box.CanCollide, box.CanQuery, box.CanTouch = true, false, false, false
		box.CastShadow = false
		box.Parent = holder
		local emitter = Instance.new("ParticleEmitter")
		local id = art[layer.sprite]
		emitter.Texture = if id then `rbxassetid://{id}` else STAND_IN[layer.sprite]
		emitter.Rate = 0
		emitter.Lifetime = layer.lifetime
		emitter.Color = layer.colour
		emitter.Transparency = layer.transparency
		emitter.Drag = layer.drag or 0
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Rotation = if layer.upright
			then NumberRange.new(-25, 25)
			else NumberRange.new(0, 360)
		emitter.RotSpeed = layer.spin or NumberRange.new(0)
		emitter.LightEmission = layer.glow or 0
		emitter.LightInfluence = 0
		emitter.ZOffset = layer.z or 0
		emitter.Orientation = if layer.upright
			then Enum.ParticleOrientation.FacingCameraWorldUp
			else Enum.ParticleOrientation.FacingCamera
		emitter.LockedToPart = false
		emitter.Shape = Enum.ParticleEmitterShape.Box
		emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		emitter.Parent = box
		local entry: Laid = { layer = layer, emitter = emitter, box = box, carry = 0, studs = 0 }
		setScale(entry, 1)
		table.insert(laid, entry)
	end
	holder.Parent = Workspace.CurrentCamera
	return { holder = holder, laid = laid, last = nil, clock = nil, released = false }
end

-- `tip` is where the trail leaves the slug, `studs` the studs per concept unit now. While `laying` is false (the form
-- parked before its reveal, or still growing in) nothing is laid, and the next laying step starts afresh rather than
-- filling the jump.
function FlightTrail.step(trail: Trail, tip: Vector3, studs: number, laying: boolean)
	if trail.released then
		return
	end
	if not laying then
		trail.last = nil
		trail.clock = nil
		return
	end
	local first = trail.last == nil
	local path = tip - (trail.last or tip)
	trail.last = tip
	local length = path.Magnitude
	-- The cap counts 60ths of a second, so a slow frame (a long stretch of path) gets as many particles as the fast
	-- frames it stands for and the trail stays smooth rather than beaded; at most four, so a hitch lays no flood.
	local now = os.clock()
	local frames = if trail.clock then math.clamp((now - trail.clock) * 60, 1, 4) else 1
	trail.clock = now
	for _, laid in trail.laid do
		local layer = laid.layer
		if math.abs(studs - laid.studs) > laid.studs * 0.03 then
			setScale(laid, studs)
		end
		local spacing = math.max(layer.spacing * studs, length / ((layer.most or 16) * frames))
		laid.carry = if first then spacing else laid.carry + length -- the first step lays one on the tip
		local count = 0
		while laid.carry >= spacing do
			laid.carry -= spacing
			count += 1
		end
		if count > 0 then
			-- The box runs along this frame's stretch of path, as thick as the layer's scatter.
			local width = math.max((layer.scatter or 0) * studs * 2, 0.02)
			local middle = tip - path / 2
			laid.box.CFrame = if length > 1e-3 then CFrame.lookAt(middle, tip) else CFrame.new(tip)
			laid.box.Size = Vector3.new(width, width, math.max(length, 0.02))
			laid.emitter:Emit(count)
		end
	end
end

-- Stop laying the trail; what is already there plays out, then it goes.
function FlightTrail.release(trail: Trail)
	if trail.released then
		return
	end
	trail.released = true
	local longest = 0
	for _, laid in trail.laid do
		longest = math.max(longest, laid.layer.lifetime.Max)
	end
	task.delay(longest + 0.1, function()
		trail.holder:Destroy()
	end)
end

return FlightTrail
