--!strict
-- A real slug model in a viewport, for the slot bar and inventory (owner, 2026-11-01: icons do small
-- animated things rather than spin). The rig idles and blinks through FloppyIdle and FloppyFace, which
-- pick up the SlugIcon tag. Here it wiggles and hops now and then, smiling while it does.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Combat = require(ReplicatedStorage:WaitForChild("Combat"))
local Visuals = require(script.Parent.SlugVisuals)

local SlugIcon = {}

export type Icon = {
	frame: ViewportFrame,
	model: Model?,
	base: CFrame,
	foot: Vector3,
	up: Vector3,
	front: Vector3,
	height: number,
	animated: boolean,
	active: boolean,
	started: number,
	cheerAt: number,
}

local LOOP = 12 -- matches the rig's idle loop
local WIGGLE_AT, WIGGLE_TIME = 3.6, 1.4
local HOP_AT, HOP_TIME = 8.6, 0.7
local WIGGLE_ANGLE = math.rad(5)
local HOP_HEIGHT = 0.1 -- share of the slug's height
local CHEER_TIME = 0.55
local SMILE_AFTER = 1.2 -- seconds the smile outlasts a move
local DROWSY, SMILING = 1, 2 -- FloppyFace expressions

local DEFAULT_FLOOR_GAP = 0.04

local icons: { Icon } = {}

local function place(icon: Icon, slugId: string, fill: number, gap: number)
	local model = Visuals.model(slugId)
	local world = Instance.new("WorldModel")
	model.Parent = world
	world.Parent = icon.frame
	local camera = Instance.new("Camera")
	camera.FieldOfView = 24
	camera.Parent = icon.frame
	icon.frame.CurrentCamera = camera
	-- The flight model's pivot is the slug's true centre, with +Y up and its face toward -Z, and its
	-- height is known. GetBoundingBox is unreliable on imported skinned models (blender-lessons.md).
	local height = Combat.Slugs[slugId].Size
	-- The slug stands near the bottom of its frame, as if on a floor: aim above its centre.
	local look = Vector3.yAxis * (0.5 - fill / 2 - gap) * height / fill
	model:PivotTo(CFrame.Angles(0, math.pi, 0))
	local distance = (height / 2) / math.tan(math.rad(camera.FieldOfView / 2)) / fill
	camera.CFrame = CFrame.lookAt(look + Vector3.new(0.22, 0.08, 1).Unit * distance, look)
	icon.model = model
	icon.base = model:GetPivot()
	icon.foot = -Vector3.yAxis * height / 2
	icon.up, icon.front, icon.height = Vector3.yAxis, Vector3.zAxis, height
	model:SetAttribute("FaceExpression", DROWSY)
	CollectionService:AddTag(model, "SlugIcon")
end

-- fill is the share of the frame's height the slug takes up; floorGap is the share left under it.
function SlugIcon.mount(
	parent: GuiObject,
	slugId: string,
	fill: number,
	animated: boolean,
	floorGap: number?
): Icon
	local frame = Instance.new("ViewportFrame")
	frame.Name = "SlugIcon"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundTransparency = 1
	frame.Ambient = Color3.fromRGB(200, 200, 200)
	frame.LightColor = Color3.fromRGB(255, 250, 240)
	frame.LightDirection = Vector3.new(-0.3, -1, -0.7)
	frame.Parent = parent
	local icon: Icon = {
		frame = frame,
		model = nil,
		base = CFrame.identity,
		foot = Vector3.zero,
		up = Vector3.yAxis,
		front = Vector3.zAxis,
		height = 1,
		animated = animated,
		active = true,
		started = os.clock(),
		cheerAt = -math.huge,
	}
	table.insert(icons, icon)
	task.spawn(function()
		if ReplicatedStorage:WaitForChild("CombatAssets", 30) then
			place(icon, slugId, fill, floorGap or DEFAULT_FLOOR_GAP)
		end
	end)
	return icon
end

-- A quick happy hop: the slug is back from its shot.
function SlugIcon.cheer(icon: Icon)
	icon.cheerAt = os.clock()
end

-- Off-screen icons skip their work.
function SlugIcon.setActive(icon: Icon, active: boolean)
	icon.active = active
end

local function hump(share: number): number
	return math.sin(math.pi * math.clamp(share, 0, 1))
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for _, icon in icons do
		local model = icon.model
		if not model or not icon.active or not icon.animated then
			continue
		end
		local t = (now - icon.started) % LOOP
		local wiggle = (t - WIGGLE_AT) / WIGGLE_TIME
		local hop = (t - HOP_AT) / HOP_TIME
		local cheer = (now - icon.cheerAt) / CHEER_TIME
		local lift = hump(hop) ^ 2
		local tilt = 0
		if wiggle > 0 and wiggle < 1 then
			tilt = WIGGLE_ANGLE * math.sin(wiggle * 6 * math.pi) * hump(wiggle)
		end
		if cheer < 1 then
			lift = math.max(lift, hump(cheer))
		end
		local swing = CFrame.new(icon.foot)
			* CFrame.fromAxisAngle(icon.front, tilt)
			* CFrame.new(-icon.foot)
		model:PivotTo(CFrame.new(icon.up * lift * HOP_HEIGHT * icon.height) * swing * icon.base)
		local moved = (wiggle > 0 and wiggle * WIGGLE_TIME < WIGGLE_TIME + SMILE_AFTER)
			or (hop > 0 and hop * HOP_TIME < HOP_TIME + SMILE_AFTER)
			or (now - icon.cheerAt) < CHEER_TIME + SMILE_AFTER
		local expression = if moved then SMILING else DROWSY
		if model:GetAttribute("FaceExpression") ~= expression then
			model:SetAttribute("FaceExpression", expression)
		end
	end
end)

return SlugIcon
