--!strict
-- Far-side check build only: a look at the cavern wall and the cave (docs/art/lobby-hub.md), and a real walk into the barrier.
-- Output lines start with GUNCHECK, so tools/lobby/gun_check.ps1 captures each shot.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local STOPS: { { name: string, from: Vector3, at: Vector3 } } = {
	-- Owner, 2026-11-05 (round 5): the cave mouth's corners, the cliff, the mist, the volcano, the mountain, crystals.
	{ name = "gapLeft", from = Vector3.new(-105, 14, 238), at = Vector3.new(-150, -20, 298) },
	{ name = "gapRight", from = Vector3.new(105, 14, 238), at = Vector3.new(150, -20, 298) },
	{ name = "gapLeftLip", from = Vector3.new(-60, 8, 282), at = Vector3.new(-160, -10, 300) },
	{ name = "gapRightLip", from = Vector3.new(60, 8, 282), at = Vector3.new(160, -10, 300) },
	{ name = "cliffLeft", from = Vector3.new(-30, 12, 250), at = Vector3.new(-70, -5, 292) },
	{ name = "cliffRight", from = Vector3.new(30, 12, 250), at = Vector3.new(70, -5, 292) },
	{ name = "mistDown", from = Vector3.new(0, 10, 284), at = Vector3.new(0, -150, 420) },
	{ name = "caveWide", from = Vector3.new(0, 12, 284), at = Vector3.new(0, 20, 480) },
	{ name = "volcano", from = Vector3.new(0, 20, -60), at = Vector3.new(0, 150, -235) },
	{ name = "mountainBridge", from = Vector3.new(110, 9, 0), at = Vector3.new(300, 80, 0) },
	{ name = "mountainHigh", from = Vector3.new(60, 60, -60), at = Vector3.new(300, 120, 0) },
	{ name = "alcove", from = Vector3.new(0, 40, 0), at = Vector3.new(390, 170, 0) },
	{ name = "eye", from = Vector3.new(0, 20, 30), at = Vector3.new(0, 225, 31) },
	{ name = "roofEdge", from = Vector3.new(60, 30, 60), at = Vector3.new(150, 225, 150) },
	{ name = "stones", from = Vector3.new(-108, 10, 6), at = Vector3.new(-150, -10, 0) },
	{ name = "gunCrystals", from = Vector3.new(-200, 10, 96), at = Vector3.new(-205, -45, 30) },
	{ name = "gunCrystalsFar", from = Vector3.new(-140, 10, 40), at = Vector3.new(-250, -30, -20) },
	{ name = "path", from = Vector3.new(0, 9, 106), at = Vector3.new(0, 2, 290) },
	{ name = "lanterns", from = Vector3.new(22, 9, 140), at = Vector3.new(-4, 8, 200) },
	{ name = "wallVines", from = Vector3.new(-110, 40, 140), at = Vector3.new(-166, 60, 222) },
	{ name = "floorSide", from = Vector3.new(-60, 30, 150), at = Vector3.new(40, 0, 230) },
}

task.spawn(function()
	local player = Players.LocalPlayer
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	while not workspace:GetAttribute("HubSolid") do
		task.wait(0.5)
	end
	print("GUNCHECK solid ready")
	-- Where the floor has no collision: from high up, straight down, round the whole ring (owner: fell through by the mountain).
	local Lighting = game:GetService("Lighting")
	local sun = Lighting:GetSunDirection()
	print(
		string.format(
			"GUNCHECK ground sun %.3f %.3f %.3f brightness %.2f",
			sun.X,
			sun.Y,
			sun.Z,
			Lighting.Brightness
		)
	)
	local solid = RaycastParams.new()
	solid.RespectCanCollide = true
	for angle = 0, 359, 1 do
		local rad = math.rad(angle)
		local out = Vector3.new(math.sin(rad), 0, -math.cos(rad))
		local holes = {}
		for radius = 106, 286, 6 do
			-- About as wide as a character, so a seam too thin to fall through doesn't count.
			local hit = workspace:Spherecast(
				out * radius + Vector3.new(0, 14, 0),
				1.2,
				Vector3.new(0, -60, 0),
				solid
			)
			if not hit then
				table.insert(holes, tostring(radius))
			end
		end
		if #holes > 0 then
			print(`GUNCHECK ground hole a={angle} r={table.concat(holes, ",")}`)
		end
	end
	print("GUNCHECK ground holes done")
	task.wait(10)
	if workspace:GetAttribute("FarCheckFloorOnly") then
		print("GUNCHECK PASS floor only")
		return
	end
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	print("GUNCHECK tour starts")
	-- FarCheckViews (set by the teleport script) limits the tour to the views it names, comma separated, and skips the walks.
	local only = workspace:GetAttribute("FarCheckViews") :: string?
	for _, stop in if workspace:GetAttribute("FarCheckBarrierOnly") then {} else STOPS do
		if only and not table.find(string.split(only, ","), stop.name) then
			continue
		end
		camera.CFrame = CFrame.lookAt(stop.from, stop.at)
		task.wait(2.5)
		print(`GUNCHECK shot {stop.name}`)
		task.wait(1)
	end
	camera.CameraType = Enum.CameraType.Custom
	if only then
		print("GUNCHECK PASS tour ends")
		return
	end
	-- Walk into the mouth at three places: how close to the cliff's lip does the barrier let you get (owner: it held you
	-- back). Positive is short of the lip, negative past it, standing on the broken rim.
	local barriers, noParkour = 0, 0
	for _, part in workspace:GetDescendants() do
		if
			part:IsA("BasePart")
			and part.Name == "Barrier"
			and part.Parent
			and part.Parent.Name == "FarBarrier"
		then
			barriers += 1
			if part:GetAttribute("NoParkour") then
				noParkour += 1
			end
		end
	end
	print(`GUNCHECK ground far barrier panels {barriers}, NoParkour on {noParkour}`)
	local teleport =
		game:GetService("ReplicatedStorage"):WaitForChild("FarCheckTeleport") :: RemoteEvent
	local character = player.Character :: Model
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	-- The game's movement controller cancels MoveTo, so a steady push toward the cave stands in for holding W.
	for _, x in { 0, -55, 60, -100 } do
		teleport:FireServer(CFrame.lookAt(Vector3.new(x, 12, 262), Vector3.new(x, 12, 400)))
		task.wait(1.5)
		local push = RunService.Heartbeat:Connect(function()
			local v = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(0, v.Y, 16)
		end)
		task.wait(4)
		push:Disconnect()
		local at = root.Position
		local u = at.X / 5
		local s = math.clamp((math.abs(u) - 24) / 6, 0, 1)
		local lip = (
			66
			+ (57.6 + 0.8 * math.sin(u * 0.45) + 0.5 * math.sin(u * 1.3 + 2) - 66)
				* (1 - s * s * (3 - 2 * s))
		) * 5
		local reached = Vector3.new(at.X, 0, at.Z).Magnitude
		print(
			`GUNCHECK ground edge walk x={x} reached {math.round(reached * 10) / 10} lip {math.round(
				lip * 10
			) / 10} short {math.round((lip - reached) * 10) / 10} y {math.round(at.Y)}`
		)
	end
	-- The same into the shop's hole (owner: it doesn't work, you can fall through at some angles). The game's movement undoes
	-- a move that passes through a wall, so the character hops round the rim in short steps, from the far bridge's landing
	-- over the pit to the gun side's and on round the hole, and is pushed into it at walking and at sliding speed.
	local gunSide = require(
		game:GetService("ReplicatedStorage"):WaitForChild("LobbyScale"):WaitForChild("gun_side")
	) :: any
	local centre = Vector3.new(gunSide.hole.centre[1], 0, gunSide.hole.centre[2])
	local radii = gunSide.hole.radii
	local function edge(t: number): number
		local f = (t % (2 * math.pi)) / (2 * math.pi) * #radii
		local i = math.floor(f)
		local a, b = radii[i % #radii + 1], radii[(i + 1) % #radii + 1]
		return a + (b - a) * (f - i)
	end
	local function rim(t: number, out: number): Vector3
		return centre
			+ Vector3.new(math.cos(t), 0, math.sin(t)) * (edge(t) + out)
			+ Vector3.new(0, 8, 0)
	end
	local function hop(to: Vector3)
		teleport:FireServer(CFrame.new(to))
		task.wait(0.4)
	end
	-- Every move a straight line through open air: up, across above the knoll's mushrooms outside the barrier, then down.
	local HIGH = 60
	local function arrive(target: number)
		local at = root.Position
		hop(Vector3.new(at.X, HIGH, at.Z))
		local start = Vector3.new(-112, HIGH, 0)
		if (Vector3.new(at.X, 0, at.Z) - centre).Magnitude > 150 then
			hop(Vector3.new(0, HIGH, 112))
			hop(start)
		end
		local here = math.rad(16)
		hop(rim(here, 12) + Vector3.new(0, HIGH - 8, 0))
		while here < target do
			here = math.min(here + math.rad(8), target)
			hop(rim(here, 12) + Vector3.new(0, HIGH - 8, 0))
		end
		hop(rim(target, 12))
		task.wait(0.6)
	end
	local respawn =
		game:GetService("ReplicatedStorage"):WaitForChild("FarCheckRespawn") :: RemoteEvent
	local fell = 0
	for _, degrees in { 30, 60, 95, 130, 165, 200, 235, 270, 305 } do
		local target = math.rad(degrees)
		for _, speed in { 16, 70 } do
			arrive(target)
			local inward = (centre - rim(target, 0)) * Vector3.new(1, 0, 1)
			inward = inward.Unit * speed
			local push = RunService.Heartbeat:Connect(function()
				local v = root.AssemblyLinearVelocity
				root.AssemblyLinearVelocity = Vector3.new(inward.X, v.Y, inward.Z)
			end)
			task.wait(if speed > 20 then 1.2 else 3)
			push:Disconnect()
			task.wait(0.5)
			local reached = (Vector3.new(root.Position.X, 0, root.Position.Z) - centre).Magnitude
			local down = root.Position.Y < -15
			print(
				`GUNCHECK ground gun push {degrees} speed {speed} reached {math.round(reached * 10) / 10} edge {math.round(
					edge(target) * 10
				) / 10} y {math.round(root.Position.Y)}{if down then " FELL" else ""}`
			)
			if down then
				fell += 1
				respawn:FireServer()
				character = player.CharacterAdded:Wait()
				root = character:WaitForChild("HumanoidRootPart") :: BasePart
				task.wait(3)
			end
		end
	end
	print(`GUNCHECK ground gun pushes fell {fell}`)
	print("GUNCHECK PASS tour ends")
end)
