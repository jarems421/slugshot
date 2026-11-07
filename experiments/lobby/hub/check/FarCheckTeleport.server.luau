--!strict
-- Far-side check build only: the walk into the barrier teleports from here, because the server undoes client teleports.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local teleport = Instance.new("RemoteEvent")
teleport.Name = "FarCheckTeleport"
teleport.Parent = ReplicatedStorage
teleport.OnServerEvent:Connect(function(player: Player, at: CFrame)
	if player.Character then
		player.Character:PivotTo(at)
	end
end)
-- After a fall into the shop's hole the barrier is in the way back, and the movement undoes a move through it: start again.
local respawn = Instance.new("RemoteEvent")
respawn.Name = "FarCheckRespawn"
respawn.Parent = ReplicatedStorage
respawn.OnServerEvent:Connect(function(player: Player)
	player:LoadCharacter()
end)

-- workspace:SetAttribute("FarCheckFloorOnly", true) -- uncomment to stop after the floor's hole check
-- workspace:SetAttribute("FarCheckBarrierOnly", true) -- uncomment for a barrier-only run
-- workspace:SetAttribute("FarCheckViews", "gapLeft,gapRight") -- uncomment to run only the named views

-- The barrier's line across the mouth, studs from the hub's centre (farEdge in Arena.luau, a stud past the cliff's lip).
local function barrierRadius(x: number): number
	local u = x / 5
	local s = math.clamp((math.abs(u) - 24) / 6, 0, 1)
	local inMouth = 1 - s * s * (3 - 2 * s)
	local lip = 57.6 + 0.8 * math.sin(u * 0.45) + 0.5 * math.sin(u * 1.3 + 2)
	return (66 + (lip - 66) * inMouth + 0.2) * 5
end
-- The shop's barrier the same way (owner, 2026-11-05: you could fall through it at some angles): balls thrown hard from the
-- knoll at the hole's centre all the way round, low and high; any that ends inside its line got through.
task.spawn(function()
	while not workspace:GetAttribute("HubSolid") do
		task.wait(0.5)
	end
	task.wait(6)
	local gunSide =
		require(ReplicatedStorage:WaitForChild("LobbyScale"):WaitForChild("gun_side")) :: any
	local centre = Vector3.new(gunSide.hole.centre[1], 0, gunSide.hole.centre[2])
	local radii = gunSide.hole.radii
	local through = {}
	for step = 0, 47 do
		local t = step / 48 * 2 * math.pi
		local f = t / (2 * math.pi) * #radii
		local i = math.floor(f)
		local edge = radii[i % #radii + 1]
			+ (radii[(i + 1) % #radii + 1] - radii[i % #radii + 1]) * (f - i)
		local out = Vector3.new(math.cos(t), 0, math.sin(t))
		for _, y in { 3, 30 } do
			local ball = Instance.new("Part")
			ball.Shape = Enum.PartType.Ball
			ball.Size = Vector3.new(3, 3, 3)
			ball.Position = centre + out * (edge + 10) + Vector3.new(0, y, 0)
			ball.Parent = workspace
			ball.AssemblyLinearVelocity = -out * 150
			task.wait(0.35)
			local reached = (Vector3.new(ball.Position.X, 0, ball.Position.Z) - centre).Magnitude
			if reached < edge - 4.5 then
				table.insert(through, `{math.round(math.deg(t))}/{y}:{math.round(reached)}`)
			end
			ball:Destroy()
		end
	end
	print(`GUNCHECK ground gun balls through {#through} {table.concat(through, " ")}`)
end)
-- The barrier, by real physics: balls thrown hard at the mouth from the floor, from high up and along its edges.
task.spawn(function()
	while not workspace:GetAttribute("HubSolid") do
		task.wait(0.5)
	end
	task.wait(3)
	local furthest, past = 0, 0
	for _, angle in { 180, 165, 195, 152, 208 } do
		for _, y in { 4, 60, 150, 215 } do
			local rad = math.rad(angle)
			local out = Vector3.new(math.sin(rad), 0, -math.cos(rad))
			local ball = Instance.new("Part")
			ball.Shape = Enum.PartType.Ball
			ball.Size = Vector3.new(4, 4, 4)
			ball.Position = out * 262 + Vector3.new(0, y, 0)
			ball.Parent = workspace
			ball.AssemblyLinearVelocity = out * 200
			task.wait(0.5)
			local reached = Vector3.new(ball.Position.X, 0, ball.Position.Z).Magnitude
			furthest = math.max(furthest, reached)
			-- Its centre stops about its radius short of the barrier; anything beyond the line got through.
			past = math.max(past, reached - barrierRadius(ball.Position.X))
			ball:Destroy()
		end
	end
	print(
		`GUNCHECK ground barrier ball furthest={math.round(furthest)} beyond line {math.round(
			past * 10
		) / 10} {if past < 0.5 then "held" else "GOT PAST"}`
	)
end)
