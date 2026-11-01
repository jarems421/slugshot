--!strict
-- Inked white charge: quiet intake, then restrained held energy. Aim never moves.
local Players = game:GetService("Players")
local FirstPerson = require(script.Parent.FirstPerson)
local CrosshairStyles = require(script.Parent.CrosshairStyles)
local player = Players.LocalPlayer
local Reticle = {}
local STYLE = {
	Ink = Color3.fromRGB(14, 14, 18),
	Charge = Color3.new(1, 1, 1),
	Diameter = 48,
	Radius = 19,
	Thickness = 1.8,
	ThirdPersonScale = 1.15,
	FirstPersonScale = 1.22,
	IntakeDelay = 0.14, -- tap fire gets no moving intake or charge-scale kick
	ReadyFrequency = 6,
	Vibration = Vector2.new(0.16, 0.12), -- subpixel ring motion, never the aim mark
	SheenSpeed = 110,
}
local CUT = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.499, 0),
	NumberSequenceKeypoint.new(0.501, 1),
	NumberSequenceKeypoint.new(1, 1),
})
local SOLID = NumberSequence.new(0)
type Half = { clip: Frame, frames: { Frame }, strokes: { UIStroke }, masks: { UIGradient } }
type Halo = { frame: Frame, stroke: UIStroke, weight: number }
type FullLayer = { frame: Frame, stroke: UIStroke }
type Ring = {
	root: Frame,
	modeScale: UIScale,
	scale: UIScale,
	markScale: UIScale,
	mark: Frame,
	style: string,
	color: Color3,
	right: Half,
	left: Half,
	tip: Frame,
	start: Frame,
	halos: { Halo },
	motes: { Frame },
	full: { FullLayer },
	sheen: Frame,
	sheenStroke: UIStroke,
	sheenMask: UIGradient,
}
local ring: Ring? = nil
local progress: number? = nil
local chargeAge, fullTime = 0, 0
local wasFull = false

local function round(frame: Frame)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
end

local function outline(frame: Frame, thickness: number, transparency: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = STYLE.Ink
	stroke.Thickness = thickness
	stroke.Transparency = transparency
	stroke.Parent = frame
	return stroke
end

local function circle(parent: Instance, name: string, thickness: number): (Frame, UIStroke)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size =
		UDim2.fromScale(STYLE.Radius * 2 / STYLE.Diameter, STYLE.Radius * 2 / STYLE.Diameter)
	frame.BackgroundTransparency = 1
	frame.Parent = parent
	round(frame)
	return frame, outline(frame, thickness, 0)
end

local function half(parent: Frame, right: boolean): Half
	local clip = Instance.new("Frame")
	clip.Name = if right then "RightArc" else "LeftArc"
	local padding = 8 / STYLE.Diameter
	clip.Position = UDim2.fromScale(if right then 0.5 else -padding, -padding)
	clip.Size = UDim2.fromScale(0.5 + padding, 1 + padding * 2)
	clip.BackgroundTransparency = 1
	clip.ClipsDescendants = true
	clip.Parent = parent
	local frames, strokes, masks = {}, {}, {}
	for i, name in { "EnergyHalo", "CurveInk", "CurveFeather", "Curve", "OuterInk", "InnerInk" } do
		local frame, stroke = circle(clip, name, STYLE.Thickness)
		frame.Position = UDim2.fromScale(if right then 0 else 1, 0.5)
		frame.Size = UDim2.fromScale(
			STYLE.Radius * 2 / (STYLE.Diameter / 2 + 8),
			STYLE.Radius * 2 / (STYLE.Diameter + 16)
		)
		stroke.Color = if i == 2 or i >= 5 then STYLE.Ink else STYLE.Charge
		stroke.Transparency = if i == 1
			then 0.98
			elseif i == 2 then 0.5
			elseif i == 3 then 0.88
			else 0.26
		if i >= 5 then
			stroke.Transparency = 0.16
		end
		local mask = Instance.new("UIGradient")
		mask.Transparency = CUT
		mask.Parent = stroke
		table.insert(frames, frame)
		table.insert(strokes, stroke)
		table.insert(masks, mask)
	end
	return { clip = clip, frames = frames, strokes = strokes, masks = masks }
end

local function cap(parent: Frame, name: string): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = STYLE.Charge
	frame.BorderSizePixel = 0
	frame.Parent = parent
	round(frame)
	return frame
end

function Reticle.create(parent: Instance): Frame
	local root = Instance.new("Frame")
	root.Name = "Reticle"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(STYLE.Diameter, STYLE.Diameter)
	root.BackgroundTransparency = 1
	root.Parent = parent
	local modeScale = Instance.new("UIScale")
	modeScale.Name = "ModeScale"
	modeScale.Scale = if FirstPerson.active()
		then STYLE.FirstPersonScale
		else STYLE.ThirdPersonScale
	modeScale.Parent = root
	local mark = Instance.new("Frame")
	mark.Name = "Crosshair"
	mark.AnchorPoint = Vector2.new(0.5, 0.5)
	mark.Position = UDim2.fromScale(0.5, 0.5)
	mark.Size = UDim2.fromOffset(18, 18)
	mark.BackgroundTransparency = 1
	mark.Parent = root
	local markScale = Instance.new("UIScale")
	markScale.Name = "MarkScale"
	markScale.Parent = mark
	local selectedStyle = CrosshairStyles.find(player:GetAttribute("CrosshairStyle"))
	local selectedColor = CrosshairStyles.color(player:GetAttribute("CrosshairColor"))
	CrosshairStyles.draw(mark, selectedStyle.id, selectedColor)
	local charge = Instance.new("Frame")
	charge.Name = "ChargeRing"
	charge.AnchorPoint = Vector2.new(0.5, 0.5)
	charge.Position = UDim2.fromScale(0.5, 0.5)
	charge.Size = UDim2.fromScale(1, 1)
	charge.BackgroundTransparency = 1
	charge.Visible = false
	charge.Parent = root
	local scale = Instance.new("UIScale")
	scale.Name = "TensionScale"
	scale.Parent = charge
	local _, track = circle(charge, "Track", 1)
	track.Transparency = 0.9
	local halos: { Halo } = {}
	for i, width in { 14, 10, 6 } do
		local frame, stroke = circle(charge, `IntakeHalo{i}`, width)
		stroke.Color = STYLE.Charge
		stroke.Transparency = 1
		frame.Visible = false
		table.insert(halos, { frame = frame, stroke = stroke, weight = i * 0.22 })
	end
	local right, left = half(charge, true), half(charge, false)
	-- A continuous held circle avoids a moving clipping seam during fine vibration.
	local full: { FullLayer } = {}
	for i, name in
		{ "HeldHalo", "HeldInk", "HeldFeather", "HeldCore", "HeldOuterInk", "HeldInnerInk" }
	do
		local frame, stroke = circle(charge, name, STYLE.Thickness)
		stroke.Color = if i == 2 or i >= 5 then STYLE.Ink else STYLE.Charge
		stroke.Transparency = if i == 1
			then 0.98
			elseif i == 2 then 0.5
			elseif i == 3 then 0.88
			else 0.26
		if i >= 5 then
			stroke.Transparency = 0.16
		end
		frame.Visible = false
		table.insert(full, { frame = frame, stroke = stroke })
	end
	local sheen, sheenStroke = circle(charge, "HeldSheen", 1.1)
	sheen.Visible = false
	sheenStroke.Color = STYLE.Charge
	sheenStroke.Transparency = 1
	local sheenMask = Instance.new("UIGradient")
	sheenMask.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.8, 1),
		NumberSequenceKeypoint.new(0.94, 0.6),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	sheenMask.Parent = sheenStroke
	local startCap, tip = cap(charge, "StartCap"), cap(charge, "ChargeTip")
	startCap.Position = UDim2.fromScale(0.5, 0.5 - STYLE.Radius / STYLE.Diameter)
	local motes: { Frame } = {}
	for i = 1, 2 do
		table.insert(motes, cap(charge, `IntakeMote{i}`))
	end
	ring = {
		root = charge,
		modeScale = modeScale,
		scale = scale,
		markScale = markScale,
		mark = mark,
		style = selectedStyle.id,
		color = selectedColor,
		right = right,
		left = left,
		tip = tip,
		start = startCap,
		halos = halos,
		motes = motes,
		full = full,
		sheen = sheen,
		sheenStroke = sheenStroke,
		sheenMask = sheenMask,
	}
	return root
end

function Reticle.setCharge(value: number?)
	progress = if value then math.clamp(value, 0, 1) else nil
end

function Reticle.step(dt: number)
	local current = ring
	if not current then
		return
	end
	local selectedStyle = CrosshairStyles.find(player:GetAttribute("CrosshairStyle"))
	local selectedColor = CrosshairStyles.color(player:GetAttribute("CrosshairColor"))
	if current.style ~= selectedStyle.id or current.color ~= selectedColor then
		CrosshairStyles.draw(current.mark, selectedStyle.id, selectedColor)
		current.style, current.color = selectedStyle.id, selectedColor
	end
	current.modeScale.Scale = if FirstPerson.active()
		then STYLE.FirstPersonScale
		else STYLE.ThirdPersonScale
	current.markScale.Scale = CrosshairStyles.size(player:GetAttribute("CrosshairSize"))
	local value = progress
	current.root.Visible = value ~= nil
	if value == nil then
		chargeAge, fullTime, wasFull = 0, 0, false
		current.scale.Scale = 1
		current.root.Position = UDim2.fromScale(0.5, 0.5)
		for _, halo in current.halos do
			halo.frame.Visible = false
		end
		for _, mote in current.motes do
			mote.Visible = false
		end
		for _, layer in current.full do
			layer.frame.Visible = false
		end
		current.sheen.Visible = false
		return
	end
	chargeAge += dt
	fullTime = if value < 1 then 0 elseif wasFull then fullTime + dt else 0
	wasFull = value >= 1
	-- Constant geometry avoids whole-ring pixel stepping. The held energy is a
	-- subpixel tremor plus a fine shimmer in the feathered stroke, outside the aim mark.
	local envelope = if wasFull then math.clamp(fullTime / 0.15, 0, 1) else 0
	local phase = fullTime * 2 * math.pi * STYLE.ReadyFrequency
	local hum = envelope * (0.7 * math.sin(phase) + 0.3 * math.sin(phase * 1.42))
	current.scale.Scale = 1
	current.root.Position = UDim2.fromScale(
		0.5 + STYLE.Vibration.X * envelope * math.sin(phase) / STYLE.Diameter,
		0.5 + STYLE.Vibration.Y * envelope * math.sin(phase * 1.42 + 0.7) / STYLE.Diameter
	)
	local thickness = STYLE.Thickness + 0.45 * value ^ 1.3 + 0.035 * hum
	local coreTransparency = 0.26 - 0.025 * hum
	current.right.clip.Visible = value > 0 and not wasFull
	current.left.clip.Visible = value > 0.5 and not wasFull
	for _, arc in { current.right, current.left } do
		local right = arc == current.right
		for _, mask in arc.masks do
			mask.Rotation =
				math.clamp(value * 360, if right then 0 else 180, if right then 180 else 360)
			mask.Transparency = if value >= (if right then 0.5 else 1) then SOLID else CUT
		end
		arc.strokes[1].Thickness = thickness + 5
		arc.strokes[1].Transparency = 0.98 - 0.008 * hum
		arc.strokes[2].Thickness = thickness + 1.7
		arc.strokes[3].Thickness = thickness + 1.6 + 0.08 * hum
		arc.strokes[3].Transparency = 0.88 - 0.012 * hum
		arc.strokes[4].Thickness = thickness
		arc.strokes[4].Transparency = coreTransparency
		for i = 5, 6 do
			local radius = STYLE.Radius + (if i == 5 then 1 else -1) * (thickness / 2 + 0.25)
			arc.frames[i].Size = UDim2.fromScale(
				radius * 2 / (STYLE.Diameter / 2 + 8),
				radius * 2 / (STYLE.Diameter + 16)
			)
			arc.strokes[i].Thickness = 0.65
		end
	end
	for i, layer in current.full do
		layer.frame.Visible = wasFull
		layer.stroke.Thickness = current.right.strokes[i].Thickness
		layer.stroke.Transparency = current.right.strokes[i].Transparency
		if i >= 5 then
			local radius = STYLE.Radius + (if i == 5 then 1 else -1) * (thickness / 2 + 0.25)
			layer.frame.Size =
				UDim2.fromScale(radius * 2 / STYLE.Diameter, radius * 2 / STYLE.Diameter)
		end
	end
	-- Traveling light supplies a spinning feel without rotating the aiming geometry.
	current.sheen.Visible = wasFull
	current.sheenMask.Rotation = (chargeAge * STYLE.SheenSpeed) % 360
	current.sheenStroke.Transparency = 1 - 0.42 * envelope
	local angle = value * 2 * math.pi
	current.tip.Position = UDim2.fromScale(
		0.5 + math.sin(angle) * STYLE.Radius / STYLE.Diameter,
		0.5 - math.cos(angle) * STYLE.Radius / STYLE.Diameter
	)
	current.tip.Size = UDim2.fromScale(thickness / STYLE.Diameter, thickness / STYLE.Diameter)
	current.start.Size = current.tip.Size
	current.tip.BackgroundTransparency, current.start.BackgroundTransparency =
		coreTransparency, coreTransparency
	current.tip.Visible, current.start.Visible = value > 0 and value < 1, value > 0 and value < 1
	-- One softly feathered intake wave, rather than a separate hard-edged outer ring.
	local intakeAge = math.max(chargeAge - STYLE.IntakeDelay, 0)
	local gate = math.clamp(intakeAge / 0.16, 0, 1)
	local cycle = (intakeAge / 0.65) % 1
	local radius = if wasFull then STYLE.Radius else STYLE.Radius + 5.5 * (1 - cycle)
	local alpha = if wasFull
		then 0.08 + 0.012 * hum
		else 0.12 * gate * math.sin(math.pi * cycle) ^ 2
	for _, halo in current.halos do
		halo.frame.Size = UDim2.fromScale(radius * 2 / STYLE.Diameter, radius * 2 / STYLE.Diameter)
		halo.stroke.Transparency = 1 - alpha * halo.weight
		halo.frame.Visible = wasFull or gate > 0
	end
	for i, mote in current.motes do
		local travel = (intakeAge / 0.7 + i / 2) % 1
		local direction = i * math.pi - 0.6 + 0.25 * (1 - travel)
		local distance = STYLE.Radius + 10 - 10 * travel
		mote.Position = UDim2.fromScale(
			0.5 + math.cos(direction) * distance / STYLE.Diameter,
			0.5 + math.sin(direction) * distance / STYLE.Diameter
		)
		local size = 1.7 + 0.5 * travel
		mote.Size = UDim2.fromScale(size / STYLE.Diameter, size / STYLE.Diameter)
		mote.BackgroundTransparency = 1 - gate * 0.48 * math.sin(math.pi * travel) ^ 2
		mote.Visible = not wasFull and gate > 0
	end
end

return Reticle
