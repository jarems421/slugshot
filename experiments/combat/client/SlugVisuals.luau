--!strict
-- Draws slug shots on this client: the flight (tumbling end over end), the comedic
-- splat, the quick hop back to the shooter and a puff where it vanishes. The return is
-- cosmetic: the cooldown alone decides when the slug is ready, so a slug still hopping
-- when its cooldown ends just puffs away (owner, 2026-10-31).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Combat = require(ReplicatedStorage:WaitForChild("Combat"))

local Visuals = {}

-- Under the camera: client-only, and the camera is excluded from every shot ray.
local folder = Instance.new("Folder")
folder.Name = "SlugShots"
folder.Parent = workspace.CurrentCamera

local GOO = Color3.fromRGB(110, 107, 62) -- Floppy's muddy outline green
local PUFF = Color3.fromRGB(216, 211, 190) -- Floppy's belly stone

export type Launch = {
	id: number,
	shooter: Player,
	slugId: string,
	origin: Vector3,
	velocity: Vector3,
	readyAt: number, -- os.clock() when this shooter's slug is ready again
}
type Flight = {
	launch: Launch,
	slug: Combat.Slug,
	model: Model,
	start: number,
	t: number,
	phase: string,
	phaseStart: number,
	params: RaycastParams,
	normal: Vector3,
	heading: Vector3,
	from: Vector3,
	hop: number,
	hops: number,
	hopFrom: Vector3,
}
local flights: { Flight } = {}

local function standIn(): Model
	local model = Instance.new("Model")
	model.Name = "SlugStandIn"
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * 0.5
	ball.Color = PUFF
	ball.Anchored, ball.CanCollide, ball.CanQuery, ball.CanTouch = true, false, false, false
	ball.Parent = model
	model.PrimaryPart = ball
	return model
end

function Visuals.model(slugId: string): Model
	local assets = ReplicatedStorage:FindFirstChild("CombatAssets")
	local template = assets and assets:FindFirstChild(slugId .. "Flight")
	if template and template:IsA("Model") then
		return template:Clone()
	end
	return standIn()
end

local function fade(part: BasePart, duration: number, goal: { [string]: any })
	goal.Transparency = 1
	local tween = TweenService:Create(
		part,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	)
	tween.Completed:Connect(function()
		part:Destroy()
	end)
	tween:Play()
end

local function bead(size: number, color: Color3, position: Vector3): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.one * size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.CastShadow = false
	part.Position = position
	part.Parent = folder
	return part
end

local function puff(position: Vector3)
	local part = bead(0.3, PUFF, position)
	part.Material = Enum.Material.Neon
	part.Transparency = 0.2
	fade(part, 0.22, { Size = Vector3.one * 1.3 })
end

-- Muddy splat: a flat stain on the surface plus a spray of goo beads.
local function splat(position: Vector3, normal: Vector3)
	local stain = Instance.new("Part")
	stain.Shape = Enum.PartType.Cylinder -- axis along X, laid along the normal
	stain.Size = Vector3.new(0.04, 1.1, 1.1)
	stain.Color = GOO
	stain.Material = Enum.Material.SmoothPlastic
	stain.Anchored, stain.CanCollide, stain.CanQuery, stain.CanTouch = true, false, false, false
	stain.CastShadow = false
	stain.Transparency = 0.15
	local side = if math.abs(normal.Y) < 0.95 then Vector3.yAxis else Vector3.xAxis
	stain.CFrame = CFrame.fromMatrix(position + normal * 0.03, normal, normal:Cross(side).Unit)
	stain.Parent = folder
	fade(stain, 0.9, {})
	local random = Random.new()
	for _ = 1, 7 do
		local spray = (normal + random:NextUnitVector() * 0.8).Unit
		local drop = bead(random:NextNumber(0.1, 0.18), GOO, position + normal * 0.1)
		fade(drop, 0.35, { Position = drop.Position + spray * random:NextNumber(0.6, 1.2) })
	end
end

function Visuals.launch(launch: Launch)
	local slug = Combat.Slugs[launch.slugId]
	if not slug then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { workspace.CurrentCamera }
	if launch.shooter.Character then
		table.insert(exclude, launch.shooter.Character)
	end
	params.FilterDescendantsInstances = exclude
	local model = Visuals.model(launch.slugId)
	model:PivotTo(CFrame.lookAt(launch.origin, launch.origin + launch.velocity))
	model.Parent = folder
	local now = os.clock()
	table.insert(flights, {
		launch = launch,
		slug = slug,
		model = model,
		start = now,
		t = 0,
		phase = "fly",
		phaseStart = now,
		params = params,
		normal = Vector3.yAxis,
		heading = launch.velocity.Unit,
		from = launch.origin,
		hop = 0,
		hops = 1,
		hopFrom = launch.origin,
	})
end

function Visuals.cancel(shooter: Player, id: number)
	for index = #flights, 1, -1 do
		local flight = flights[index]
		if flight.launch.shooter == shooter and flight.launch.id == id then
			flight.model:Destroy()
			table.remove(flights, index)
		end
	end
end

-- Floating damage number with the shot distance, rising and fading.
function Visuals.popup(position: Vector3, damage: number, distance: number)
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = position
	anchor.Parent = workspace.Terrain
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 54)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = anchor
	local amount = Instance.new("TextLabel")
	amount.Size = UDim2.fromScale(1, 0.62)
	amount.BackgroundTransparency = 1
	amount.Font = Enum.Font.GothamBlack
	amount.TextScaled = true
	amount.Text = `-{damage}`
	amount.TextColor3 = Color3.fromRGB(255, 214, 92)
	amount.TextStrokeTransparency = 0.3
	amount.Parent = gui
	local range = Instance.new("TextLabel")
	range.Size = UDim2.fromScale(1, 0.38)
	range.Position = UDim2.fromScale(0, 0.62)
	range.BackgroundTransparency = 1
	range.Font = Enum.Font.GothamBold
	range.TextScaled = true
	range.Text = string.format("%.1f studs", distance)
	range.TextColor3 = Color3.fromRGB(235, 240, 245)
	range.TextStrokeTransparency = 0.4
	range.Parent = gui
	gui.Parent = anchor
	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0) }):Play()
	TweenService:Create(amount, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	TweenService:Create(range, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.95, function()
		anchor:Destroy()
	end)
end

local function feetOf(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position - Vector3.new(0, 2.6, 0)
	end
	return nil
end

-- Upright, facing its way of travel, back to the given surface normal.
local function upright(position: Vector3, normal: Vector3, heading: Vector3): CFrame
	local forward = heading - normal * heading:Dot(normal)
	if forward.Magnitude < 1e-3 then
		forward = normal:Cross(Vector3.xAxis)
	end
	return CFrame.lookAt(position, position + forward.Unit, normal)
end

local function finish(index: number, flight: Flight)
	puff(flight.model:GetPivot().Position)
	flight.model:Destroy()
	table.remove(flights, index)
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for index = #flights, 1, -1 do
		local flight = flights[index]
		local launch, slug = flight.launch, flight.slug
		if flight.phase == "fly" then
			local before = flight.t
			flight.t = math.min(now - flight.start, Combat.MaxFlight)
			local hit =
				Combat.sweep(launch.origin, launch.velocity, slug, before, flight.t, flight.params)
			if hit then
				local _, velocity = Combat.at(launch.origin, launch.velocity, slug, flight.t)
				flight.phase, flight.phaseStart = "splat", now
				flight.normal, flight.heading = hit.Normal, velocity.Unit
				flight.from = hit.Position + hit.Normal * (slug.Size * 0.22)
				splat(hit.Position, hit.Normal)
			elseif flight.t >= Combat.MaxFlight then
				finish(index, flight)
				continue
			else
				local position, velocity = Combat.at(launch.origin, launch.velocity, slug, flight.t)
				local spin = -2 * math.pi * slug.Tumble * flight.t
				flight.model:PivotTo(
					CFrame.lookAt(position, position + velocity) * CFrame.Angles(spin, 0, 0)
				)
			end
		end
		if flight.phase == "splat" then
			local s = math.clamp((now - flight.phaseStart) / Combat.SplatTime, 0, 1)
			-- Flattened on impact, then pulls itself back together.
			local squash = (1 - s) * 0.12
			flight.model:PivotTo(
				upright(flight.from - flight.normal * squash, flight.normal, flight.heading)
			)
			if s >= 1 then
				local feet = feetOf(launch.shooter)
				local distance = if feet then (feet - flight.from).Magnitude else 0
				flight.phase, flight.phaseStart = "hop", now
				flight.hops = math.clamp(math.ceil(distance / 10), 1, 3)
				flight.hop, flight.hopFrom = 0, flight.from
			end
		end
		if flight.phase == "hop" then
			local feet = feetOf(launch.shooter)
			if not feet or now >= launch.readyAt then
				finish(index, flight)
				continue
			end
			local each = Combat.ReturnTime / flight.hops
			local hop = math.min(math.floor((now - flight.phaseStart) / each), flight.hops)
			if hop >= flight.hops then
				finish(index, flight)
				continue
			end
			if hop ~= flight.hop then
				flight.hop, flight.hopFrom = hop, flight.model:GetPivot().Position
			end
			-- Each hop covers an even share of what is left, toward where the shooter is now.
			local target = flight.hopFrom:Lerp(feet, 1 / (flight.hops - hop))
			local u = (now - flight.phaseStart - hop * each) / each
			local span = target - flight.hopFrom
			local height = 0.8 + span.Magnitude * 0.12
			local position = flight.hopFrom + span * u + Vector3.yAxis * (height * 4 * u * (1 - u))
			flight.model:PivotTo(
				upright(
					position,
					Vector3.yAxis,
					if span.Magnitude > 0.05 then span else flight.heading
				)
			)
		end
	end
end)

return Visuals
