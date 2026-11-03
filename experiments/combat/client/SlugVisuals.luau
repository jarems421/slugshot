--!strict
-- Draws flight and impact, then Floppy's local fall/wriggle/hop/burrow recovery.
-- Recovery is independent of the firing cooldown and never races to the shooter.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Combat = require(ReplicatedStorage:WaitForChild("Combat"))
local Recovery = require(script.Parent.FloppyRecovery)

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
	params: RaycastParams,
	recovery: Recovery.State?,
}
local flights: { Flight } = {}
local CANISTER_GLOW = Color3.fromRGB(215, 240, 160) -- Floppy's bulb glow
-- Stacked faint discs fake a soft radial falloff with no image asset and no hard edge.
local GLOOM_LAYERS = 9
local GLOOM_ALPHA = 0.045
local GLOOM_TIME = 0.75
type Pop = {
	locate: () -> Vector3?,
	part: Part,
	light: PointLight,
	discs: { Frame },
	started: number,
}
local pops: { Pop } = {}

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

-- A spray of goo beads on impact. The owner removed the flat stain circle (2026-11-01)
-- and plans a different impact effect.
local function splat(position: Vector3, normal: Vector3)
	local random = Random.new()
	for _ = 1, 7 do
		local spray = (normal + random:NextUnitVector() * 0.8).Unit
		local drop = bead(random:NextNumber(0.1, 0.18), GOO, position + normal * 0.1)
		fade(drop, 0.35, { Position = drop.Position + spray * random:NextNumber(0.6, 1.2) })
	end
end

-- The slug is back: a soft gloom swells in the canister and fades, following the gun.
function Visuals.canisterPop(locate: () -> Vector3?)
	local position = locate()
	if not position then
		return
	end
	local part = Instance.new("Part")
	part.Size = Vector3.one * 0.05
	part.Transparency = 1
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.CastShadow = false
	part.Position = position
	local light = Instance.new("PointLight")
	light.Color = CANISTER_GLOW
	light.Range = 3
	light.Brightness = 0
	light.Shadows = false
	light.Parent = part
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromScale(1.3, 1.3)
	board.LightInfluence = 0
	board.Parent = part
	local discs: { Frame } = {}
	for index = 1, GLOOM_LAYERS do
		local disc = Instance.new("Frame")
		local scale = index / GLOOM_LAYERS
		disc.AnchorPoint = Vector2.new(0.5, 0.5)
		disc.Position = UDim2.fromScale(0.5, 0.5)
		disc.Size = UDim2.fromScale(scale, scale)
		disc.BackgroundColor3 = CANISTER_GLOW
		disc.BackgroundTransparency = 1
		disc.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = disc
		disc.Parent = board
		table.insert(discs, disc)
	end
	part.Parent = folder
	table.insert(pops, {
		locate = locate,
		part = part,
		light = light,
		discs = discs,
		started = os.clock(),
	})
end

-- The burrow's materials load on first use, which froze the first dig of a session
-- for most of a second. Show each once, nearly invisible, before a shot can land.
local function prewarm()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	for index, material in
		{ Enum.Material.Ground, Enum.Material.Rock, Enum.Material.Slate, Enum.Material.Sand }
	do
		local part = bead(0.04, GOO, camera.CFrame * Vector3.new(index * 0.02, 0, -1))
		part.Material = material
		part.Transparency = 0.97
		local lump = Instance.new("SpecialMesh")
		lump.MeshType = Enum.MeshType.Sphere
		lump.Parent = part
		Debris:AddItem(part, 3)
	end
end
prewarm()

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
	model:SetAttribute("ShotId", launch.id)
	local now = os.clock()
	table.insert(flights, {
		launch = launch,
		slug = slug,
		model = model,
		start = now,
		t = 0,
		params = params,
		recovery = nil,
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

-- A predicted flight must never visibly continue past an authoritative impact
-- during a render stall or a collision that only the server has observed yet.
function Visuals.confirmImpact(
	shooter: Player,
	id: number,
	position: Vector3,
	normal: Vector3,
	victim: Model?
)
	for _, flight in flights do
		if flight.launch.shooter == shooter and flight.launch.id == id then
			if not flight.recovery then
				local now = os.clock()
				local _, velocity = Combat.at(
					flight.launch.origin,
					flight.launch.velocity,
					flight.slug,
					math.min(now - flight.start, Combat.MaxFlight)
				)
				splat(position, normal)
				local recovery = Recovery.new(
					flight.model,
					flight.slug.Size,
					position,
					normal,
					velocity,
					flight.params,
					victim,
					now
				)
				flight.recovery = recovery
				Recovery.step(recovery, now)
			end
			return
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

local function finish(index: number, flight: Flight)
	flight.model:Destroy()
	table.remove(flights, index)
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for index = #pops, 1, -1 do
		local pop = pops[index]
		local age = (now - pop.started) / GLOOM_TIME
		local position = pop.locate()
		if age >= 1 or not position then
			pop.part:Destroy()
			table.remove(pops, index)
		else
			pop.part.Position = position
			-- A gentle swell that lingers on the way out; it never changes shape or size.
			local level = math.sin(math.pi * math.clamp(age / 0.3, 0, 1) / 2) ^ 2
				* (1 - math.clamp((age - 0.3) / 0.7, 0, 1) ^ 2)
			pop.light.Brightness = 0.8 * level
			for _, disc in pop.discs do
				disc.BackgroundTransparency = 1 - GLOOM_ALPHA * level
			end
		end
	end
	for index = #flights, 1, -1 do
		local flight = flights[index]
		local launch, slug = flight.launch, flight.slug
		if not flight.model.Parent then
			table.remove(flights, index)
			continue
		end
		if flight.recovery then
			if Recovery.step(flight.recovery, now) then
				finish(index, flight)
			end
			continue
		end
		local before = flight.t
		flight.t = math.min(now - flight.start, Combat.MaxFlight)
		local hit =
			Combat.sweep(launch.origin, launch.velocity, slug, before, flight.t, flight.params)
		local position, velocity = Combat.at(launch.origin, launch.velocity, slug, flight.t)
		if hit then
			splat(hit.Position, hit.Normal)
			local victim = Combat.victim(hit.Instance)
			local recovery = Recovery.new(
				flight.model,
				slug.Size,
				hit.Position,
				hit.Normal,
				velocity,
				flight.params,
				victim,
				now
			)
			flight.recovery = recovery
			Recovery.step(recovery, now)
		elseif flight.t >= Combat.MaxFlight then
			-- An unlanded shot falls locally; only a void/unsupported surface times out.
			flight.recovery = Recovery.new(
				flight.model,
				slug.Size,
				position,
				Vector3.zero,
				velocity,
				flight.params,
				nil,
				now
			)
		else
			local spin = -2 * math.pi * slug.Tumble * flight.t
			flight.model:PivotTo(
				CFrame.lookAt(position, position + velocity) * CFrame.Angles(spin, 0, 0)
			)
		end
	end
end)

return Visuals
