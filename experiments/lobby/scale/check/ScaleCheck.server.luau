--!strict
-- Self-test for the check build only (tools/lobby/build_scale.py --check). A true-speed R6 test character walks
-- the lobby's routes and prints measurements to the Studio output, for when no Studio MCP connection exists.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local layout = require(ReplicatedStorage:WaitForChild("LobbyScale"):WaitForChild("layout")) :: any
local WALK_SPEED = layout.walkSpeeds.default
local REACHED = 4

local function report(name: string, passed: boolean, detail: string)
	print(`[LobbyScaleCheck] {if passed then "PASS" else "FAIL"} {name}: {detail}`)
end

local function polar(angle: number, radius: number, y: number): Vector3
	local rad = math.rad(angle)
	return Vector3.new(radius * math.sin(rad), y, -radius * math.cos(rad))
end

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local description = Instance.new("HumanoidDescription")
local walker = Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R6)
description:Destroy()
walker.Name = "ScaleCheckWalker"
local humanoid = walker:FindFirstChildOfClass("Humanoid") :: Humanoid
local root = walker:FindFirstChild("HumanoidRootPart") :: BasePart
humanoid.WalkSpeed = WALK_SPEED
walker.Parent = workspace
root:SetNetworkOwner(nil)

local function place(position: Vector3)
	root.AssemblyLinearVelocity = Vector3.zero
	walker:PivotTo(CFrame.new(position + Vector3.new(0, 4, 0)))
	task.wait(0.8)
end

local function walkTo(target: Vector3, timeout: number): boolean
	local started = os.clock()
	local issued = -math.huge
	while os.clock() - started < timeout do
		if flat(root.Position - target).Magnitude < REACHED then
			return true
		end
		if os.clock() - issued > 5 then
			humanoid:MoveTo(target)
			issued = os.clock()
		end
		task.wait(0.05)
	end
	return false
end

-- Walks a path from its first point and reports the time and any point it could not reach.
local function walkPath(name: string, path: { Vector3 }, expectFromY: number?)
	place(path[1])
	local started = os.clock()
	local lowest, highest = root.Position.Y, root.Position.Y
	for index = 2, #path do
		local target = path[index]
		local distance = flat(target - root.Position).Magnitude
		local reached = walkTo(target, distance / WALK_SPEED * 2 + 4)
		lowest, highest = math.min(lowest, root.Position.Y), math.max(highest, root.Position.Y)
		if not reached then
			report(
				name,
				false,
				`stuck before point {index}/{#path} at {root.Position} heading to {target}`
			)
			return
		end
	end
	local ground = root.Position.Y - 3
	local detail =
		`{string.format("%.1f", os.clock() - started)} s at speed {WALK_SPEED}, end height {string.format(
			"%.1f",
			ground
		)}, root range {string.format("%.1f", lowest)} to {string.format("%.1f", highest)}`
	report(name, expectFromY == nil or ground > expectFromY, detail)
end

local function routeY(angle: number): number
	local points = layout.route.points
	for index = 1, #points - 1 do
		local p, q = points[index], points[index + 1]
		if angle <= q.angle then
			return p.y + (q.y - p.y) * (angle - p.angle) / (q.angle - p.angle)
		end
	end
	return points[#points].y
end

local function routePath(from: number, to: number): { Vector3 }
	local radius = layout.shore.wallRadius - layout.route.width / 2
	local path = {}
	for angle = from, to, 10 do
		table.insert(path, polar(angle, radius, routeY(angle)))
	end
	return path
end

local function climbPath(peak: any, topRadius: number, joinY: number): { Vector3 }
	local center = polar(peak.angle, peak.radius, 0)
	local route = layout.route
	local function radiusAt(y: number): number
		return peak.baseRadius + (topRadius - peak.baseRadius) * y / peak.height
	end
	local path = {}
	table.insert(path, polar(peak.angle, layout.shore.wallRadius - route.width / 2, joinY))
	local length = (peak.height - joinY) / math.tan(math.rad(route.climbSlope))
	local turn = math.deg(length / (radiusAt((joinY + peak.height) / 2) + route.climbWidth / 2))
	local steps = math.ceil(turn / 25)
	for step = 0, steps do
		local t = step / steps
		local y = joinY + (peak.height - joinY) * t
		table.insert(
			path,
			center + polar(peak.angle + turn * t, radiusAt(y) + route.climbWidth / 2, y)
		)
	end
	return path
end

local function lipAndFall()
	place(polar(30, 100, 0))
	local inside = polar(30, 60, 0)
	local walkUntil = os.clock() + 5
	local fellAt: number? = nil
	while os.clock() < walkUntil and not fellAt do
		humanoid:MoveTo(inside)
		if root.Position.Y < -1 then
			fellAt = os.clock()
		end
		task.wait()
	end
	report(
		"lip stops a plain walk",
		not fellAt,
		`stopped {string.format("%.1f", flat(root.Position).Magnitude)} from centre`
	)
	local fastest = 0
	local deadline = os.clock() + 25
	while os.clock() < deadline do
		humanoid:MoveTo(inside)
		if not fellAt then
			humanoid.Jump = true
			if root.Position.Y < -1 then
				fellAt = os.clock()
			end
		else
			fastest = math.max(fastest, -root.AssemblyLinearVelocity.Y)
			if root.Position.Y < layout.fall.respawnY then
				local seconds = os.clock() - fellAt
				report(
					"hop over the lip and fall to respawn height",
					true,
					`{string.format("%.2f", seconds)} s, top speed {string.format("%.0f", fastest)}`
				)
				return
			end
		end
		task.wait()
	end
	report("hop over the lip and fall to respawn height", false, `ended at {root.Position}`)
end

-- Real players: spawn spot and heading, and the time from leaving the shore to arriving back on the rock.
local function watchPlayer(player: Player)
	local fellAt: number? = nil
	while player.Parent do
		local character = player.Character
		local body = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if body then
			if not fellAt and body.Position.Y < -40 then
				fellAt = os.clock()
			elseif fellAt and body.Position.Y > -5 then
				local onRock = flat(body.Position).Magnitude < layout.spawnRock.radius
				report(
					"player fall respawn",
					onRock,
					`{string.format("%.2f", os.clock() - fellAt)} s, back at {body.Position}`
				)
				fellAt = nil
			end
		end
		task.wait(0.05)
	end
end

local function watchSpawns(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		task.wait(0.5)
		local look = character:GetPivot().LookVector
		local flatDistance = flat(character:GetPivot().Position).Magnitude
		report(
			"player spawn",
			flatDistance < layout.spawnRock.radius and look.Z < -0.9,
			`{character:GetPivot().Position}, facing {look}`
		)
	end)
	task.spawn(watchPlayer, player)
end

Players.PlayerAdded:Connect(watchSpawns)
for _, player in Players:GetPlayers() do
	watchSpawns(player)
end

local model = workspace:WaitForChild("LobbyScale")
local count = 0
for _, item in model:GetDescendants() do
	if item:IsA("BasePart") then
		count += 1
	end
end
report("part count", count < 9000, `{count} parts`)

walkPath("spawn to PvP gate", {
	Vector3.new(0, 0, 0),
	polar(0, 22, 0),
	polar(0, 55, -6),
	polar(0, 90, 0),
	polar(0, 150, 4),
})
for _, angle in { 90, 180, -90 } do
	walkPath(`bridge {angle}`, { polar(angle, 15, 0), polar(angle, 55, -6), polar(angle, 95, 0) })
end
lipAndFall()
walkPath("into the gun shop", { polar(-90, 140, 0), polar(-90, 165, 0), polar(-90, 190, 0) })
walkPath("wade across the pond", { polar(90, 100, 0), polar(90, 155, 0), polar(90, 200, 0) })
local ravine = layout.ravine
walkPath(
	"ravine crossing",
	{ polar(ravine.crossing.angle, 195, 0), polar(ravine.crossing.angle, 282, 0) }
)
walkPath("ravine ledge", {
	polar(ravine.to + 3, ravine.innerRadius - 5, 0),
	polar(ravine.to - 3, ravine.innerRadius + 4, 0),
	polar(ravine.ledge.levelAt, ravine.innerRadius + 4, ravine.ledge.y),
	polar(ravine.from + 3, ravine.innerRadius + 4, ravine.ledge.y),
}, ravine.ledge.y - 2)
walkPath("spiral route: Entrance to volcano", routePath(180, 360), routeY(360) - 3)
walkPath(
	"volcano climb to the rim",
	climbPath(layout.volcano, layout.volcano.rimRadius, routeY(360)),
	layout.volcano.height - 3
)
walkPath("spiral route: volcano to mountain", routePath(360, 430), routeY(430) - 3)
walkPath(
	"mountain climb to the overlook",
	climbPath(layout.mountain, layout.mountain.topRadius, routeY(430)),
	layout.mountain.height - 3
)
walker:Destroy()
print("[LobbyScaleCheck] DONE")
