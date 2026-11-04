--!strict
-- Shared presentation: twirl, build a diffuse glow, swap forms inside it, then let the larger form emerge.
-- Species styling is data in TransformationStyles. Position, speed and hit decisions belong to the flight.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Combat = require(ReplicatedStorage:WaitForChild("Combat"))
local Fx = require(script.Parent.PvpFx)
local Styles = require(script.Parent.TransformationStyles)

local Transformation = {}
Transformation.timeScale = 1 -- Studio review; copied to each new form

local TAU = 2 * math.pi
local PARKED = CFrame.new(0, -20000, 0)
local LYING = CFrame.Angles(-math.pi / 2, 0, 0) * CFrame.Angles(0, math.pi, 0)
local CLOSE_SWAP_SHARE = 0.55

export type State = {
	slug: Combat.Slug,
	style: Styles.Style,
	base: Model,
	baseScale: number,
	form: Model,
	formScale: number,
	anchor: Part,
	board: BillboardGui,
	wide: ImageLabel,
	hot: ImageLabel,
	light: PointLight,
	occlusion: RaycastParams,
	pace: number,
	swapped: boolean,
	ended: boolean,
}

local function ease(value: number): number
	return 1 - (1 - math.clamp(value, 0, 1)) ^ 3
end

-- Compress the presentation for close shots without changing their path or hit time.
local function closeShotPace(launch: any, slug: Combat.Slug, params: RaycastParams): number
	local shape = slug.Transformation :: Combat.Transformation
	local swap = shape.Spin + shape.Flash
	local step = 1 / 60
	local clock = 0
	while clock < swap / CLOSE_SWAP_SHARE do
		local from = Combat.flightTime(slug, clock)
		local to = Combat.flightTime(slug, clock + step)
		if Combat.sweep(launch.origin, launch.velocity, slug, from, to, params) then
			return swap / math.max((clock + step) * CLOSE_SWAP_SHARE, step)
		end
		clock += step
	end
	return 1
end

function Transformation.new(
	slugId: string,
	base: Model,
	launch: any,
	params: RaycastParams,
	parent: Instance
): State?
	local slug = Combat.Slugs[slugId]
	local assets = ReplicatedStorage:FindFirstChild("CombatAssets")
	local template = assets and assets:FindFirstChild(slugId .. "Transformed")
	if not (slug and slug.Transformation and template and template:IsA("Model")) then
		return nil
	end
	local style = Styles.of(slugId)
	local form = template:Clone()
	form:ScaleTo(form:GetScale() * style.formScale)
	form:PivotTo(PARKED)
	-- Initialize before parenting so the motion script never sees fully open wings at the reveal.
	form:SetAttribute("TimeScale", Transformation.timeScale)
	form:SetAttribute("TransformFold", 1)
	form.Parent = parent
	local anchor = Instance.new("Part")
	anchor.Name = "TransformationAura"
	anchor.Size = Vector3.one * 0.05
	anchor.Transparency = 1
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.CastShadow = false
	anchor.CFrame = base:GetPivot()
	anchor.Parent = parent
	local light = Instance.new("PointLight")
	light.Color = style.glow
	light.Range = style.aura.lightRange
	light.Brightness = 0
	light.Shadows = false
	light.Parent = anchor
	local board = Instance.new("BillboardGui")
	board.Name = "DiffuseAura"
	board.Size = UDim2.fromScale(1, 1)
	board.LightInfluence = 0
	-- Depth-testing a large billboard cuts its rectangular plane against the floor. Draw the soft image in screen
	-- space instead; setGlow checks the source's line of sight so it cannot glow through a solid wall.
	board.AlwaysOnTop = true
	board.Enabled = false
	board.Parent = anchor
	local function glowLayer(size: number): ImageLabel
		local image = Fx.glow(board, style.glow)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.Size = UDim2.fromScale(size, size)
		return image
	end
	local occlusion = RaycastParams.new()
	occlusion.FilterType = Enum.RaycastFilterType.Exclude
	occlusion.RespectCanCollide = true
	local ignored: { Instance } = { parent }
	if workspace.CurrentCamera then
		table.insert(ignored, workspace.CurrentCamera)
	end
	if Players.LocalPlayer.Character then
		table.insert(ignored, Players.LocalPlayer.Character)
	end
	occlusion.FilterDescendantsInstances = ignored
	return {
		slug = slug,
		style = style,
		base = base,
		baseScale = base:GetScale(),
		form = form,
		formScale = form:GetScale(),
		anchor = anchor,
		board = board,
		wide = glowLayer(1),
		hot = glowLayer(0.5),
		light = light,
		occlusion = occlusion,
		pace = closeShotPace(launch, slug, params),
		swapped = false,
		ended = false,
	}
end

local function setGlow(state: State, level: number, size: number, heat: number)
	local camera = workspace.CurrentCamera
	local visible = false
	if camera and level > 0 then
		local delta = state.anchor.Position - camera.CFrame.Position
		visible = delta.Magnitude < 0.01
			or workspace:Raycast(camera.CFrame.Position, delta, state.occlusion) == nil
	end
	-- A disabled board's labels do not update IsLoaded, even when preloading succeeded. Gate on the shared asset
	-- fetch instead, otherwise waiting for IsLoaded before enabling the board prevents the glow ever appearing.
	state.board.Enabled = visible
		and ContentProvider:GetAssetFetchStatus(state.wide.Image)
			== Enum.AssetFetchStatus.Success
	local color = state.style.glow:Lerp(state.style.core, heat)
	state.wide.ImageColor3 = color
	state.wide.ImageTransparency = 1 - state.style.aura.strength * level
	state.hot.ImageColor3 = state.style.core:Lerp(color, 0.4)
	state.hot.ImageTransparency = 1 - state.style.aura.coreStrength * level
	state.board.Size = UDim2.fromScale(size, size)
	state.light.Brightness = state.style.aura.lightBrightness * level
end

function Transformation.step(state: State, elapsed: number, cframe: CFrame)
	if state.ended then
		return
	end
	local shape = state.slug.Transformation :: Combat.Transformation
	local motion, aura = state.style.motion, state.style.aura
	local clock = elapsed * state.pace
	local into = clock / shape.Spin
	state.anchor.CFrame = cframe
	if into < 1 then
		local angle = TAU * motion.spinTurns * into * into
		state.base:ScaleTo(
			state.baseScale * (1 - (1 - motion.baseShrink) * math.max(into - 0.5, 0) * 2)
		)
		state.base:PivotTo(cframe * CFrame.Angles(0, 0, angle) * LYING)
		setGlow(state, into * into, aura.startSize + (aura.peakSize - aura.startSize) * into, 0)
		return
	end
	if not state.swapped then
		state.swapped = true
		state.base:ScaleTo(state.baseScale)
		state.base:PivotTo(PARKED)
	end
	local since = clock - shape.Spin
	local reveal = ease(since / motion.revealTime)
	local angle = motion.revealRoll * (1 - reveal)
		+ motion.tilt * math.sin(since * motion.tiltRate) * reveal
	state.form:ScaleTo(state.formScale * (motion.revealScale + (1 - motion.revealScale) * reveal))
	state.form:SetAttribute("TransformFold", 1 - ease(since / motion.foldTime))
	state.form:PivotTo(cframe * CFrame.Angles(0, 0, angle))
	-- Same glow, same size at the swap; it warms briefly and diffuses away without a second flash or burst.
	local fade = 1 - ease(since / aura.fadeTime)
	setGlow(state, fade, aura.peakSize * (1 + 0.12 * (1 - fade)), fade * 0.35)
end

-- The caller handles impact/recovery. The shared transformation adds no explosion or impact ring.
function Transformation.finish(state: State, _position: Vector3, _way: Vector3)
	if state.ended then
		return
	end
	state.ended = true
	state.base:ScaleTo(state.baseScale)
	state.form:Destroy()
	state.anchor:Destroy()
end

function Transformation.destroy(state: State)
	Transformation.finish(state, Vector3.zero, Vector3.zero)
end

function Transformation.prewarm()
	task.spawn(function()
		local assets = ReplicatedStorage:WaitForChild("CombatAssets")
		local glow = Fx.glow(script, Color3.new())
		local forms: { Instance } = { glow }
		for slugId in Combat.Slugs do
			local form = assets:FindFirstChild(slugId .. "Transformed")
			if form then
				table.insert(forms, form)
			end
		end
		local ok, problem = pcall(function()
			ContentProvider:PreloadAsync(forms)
		end)
		glow:Destroy()
		if not ok then
			warn(`Transformation preload: {problem}`)
		end
	end)
end

return Transformation
