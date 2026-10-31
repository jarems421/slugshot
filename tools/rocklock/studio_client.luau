--!strict
-- Opt-in Studio QA fixture. Inject into the isolated place for a two-client test;
-- never map this file into a playable project. Uses the existing movement probe.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local report: any = { points = {}, actions = {}, peers = {} }
local frameTimes: { number } = {}
local peerActions: { [string]: boolean } = {}
local connection = RunService.RenderStepped:Connect(function(dt: number)
	table.insert(frameTimes, dt)
	for _, peer in Players:GetPlayers() do
		if peer ~= player and peer.Character then
			local action = peer.Character:GetAttribute("MovementAction")
			if typeof(action) == "string" then
				peerActions[action] = true
			end
		end
	end
end)

local ok, failure = pcall(function()
	local probe =
		player.PlayerScripts:WaitForChild("MovementExperimentProbe", 25) :: BindableFunction
	assert(probe, "Movement probe missing")
	local deadline = os.clock() + 25
	while #Players:GetPlayers() < 2 and os.clock() < deadline do
		task.wait(0.1)
	end
	assert(#Players:GetPlayers() == 2, "Expected two clients")
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart") :: BasePart
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	local map = workspace:WaitForChild("Rocklock")
	local spawnName = player:GetAttribute("RocklockSpawn")
	report.spawn = spawnName
	report.rig = humanoid.RigType.Name
	local side = if spawnName == "North" then -1 else 1
	local home = side
	local shelf = map:FindFirstChild("WestShelf", true) :: BasePart
	local sx = shelf.Size.X / 14
	local north = map:WaitForChild("Spawns"):WaitForChild("North") :: BasePart
	local south = map.Spawns:WaitForChild("South") :: BasePart
	local sz = (north.Position - south.Position).Magnitude / 74
	local function state(): any
		return probe:Invoke("Read")
	end
	local function move(direction: Vector3, duration: number)
		probe:Invoke("Move", { direction = direction, duration = duration })
	end
	local function go(label: string, x: number, z: number, timeout: number)
		local started, low, peak = os.clock(), root.Position.Y, root.Position.Y
		-- The same route grows with the map; allow time for background Studio clients.
		while os.clock() - started < timeout * 2 do
			local delta = Vector3.new(x - root.Position.X, 0, z - root.Position.Z)
			if delta.Magnitude < 0.6 then
				break
			end
			move(delta.Unit * math.min(1, delta.Magnitude / 5), 0.2)
			low, peak = math.min(low, root.Position.Y), math.max(peak, root.Position.Y)
			task.wait(0.035)
		end
		move(Vector3.zero, 0.4)
		task.wait(0.2)
		local distance = (Vector3.new(x, 0, z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
		table.insert(report.points, {
			label = label,
			reached = distance < 2,
			distance = distance,
			seconds = os.clock() - started,
			minRootY = low,
			maxRootY = peak,
		})
		assert(distance < 2, "Route blocked: " .. label)
	end

	go("Spawn exit", side * 36 * sx, home * 40 * sz, 7)
	go("Walk up flank", side * 36 * sx, home * 15 * sz, 6)
	assert(math.abs(root.Position.Y - 13) < 0.6, "Shelf height")
	go("Flank crossing", side * 36 * sx, -home * 15 * sz, 6)
	go("Flank return", side * 36 * sx, home * 15 * sz, 6)
	go("Run wall approach", side * (43.5 * sx - 2.1), home * 15 * sz, 4)
	move(Vector3.new(0, 0, -home), 2)
	task.wait(0.18)
	probe:Invoke("Jump")
	task.wait(0.22)
	local running = state()
	report.actions.wallRun = running.acro
	report.actions.wallSpeed = math.abs(root.AssemblyLinearVelocity.Z)
	report.actions.wallRunRootY = root.Position.Y
	assert(running.acro == "WallRun", "Wall run did not attach")
	move(Vector3.new(-side, 0, 0), 0.8)
	task.wait(0.08)
	probe:Invoke("JumpPress")
	task.wait(0.1)
	report.actions.kick = state().acro
	report.actions.kickRootY = root.Position.Y
	assert(report.actions.kick == "WallHop", "Wall kick did not launch")
	task.wait(1.2)
	move(Vector3.zero, 0.3)
	task.wait(0.3)
	go("Underpass entrance", 0, home * 18 * sz, 7)
	go("Underpass crossing", 0, -home * 18 * sz, 7)
	go("Exit beside cover", 16 * sx, -home * 18 * sz, 4)
	go("Open spawn strip", 16 * sx, -home * 40 * sz, 6)
	go("Jump setup", -16 * sx, -home * 40 * sz, 6)
	move(Vector3.xAxis, 1.6)
	task.wait(0.25)
	local origin, peak = root.Position, root.Position.Y
	probe:Invoke("Jump")
	local started = os.clock()
	repeat
		task.wait(0.02)
		peak = math.max(peak, root.Position.Y)
	until (os.clock() - started > 0.3 and humanoid.FloorMaterial ~= Enum.Material.Air)
		or os.clock() - started > 1.5
	report.actions.firstJumpRise = peak - origin.Y
	report.actions.firstJumpTravel = (
		Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(origin.X, 0, origin.Z)
	).Magnitude
	move(Vector3.zero, 0.3)
	task.wait(0.4)
	move(Vector3.xAxis, 1.4)
	task.wait(0.2)
	probe:Invoke("Jump")
	task.wait(0.24)
	probe:Invoke("JumpPress")
	task.wait(0.1)
	report.actions.flip = state().acro
	assert(report.actions.flip == "Flip", "Double-jump flip missing")
	task.wait(1)
	move(Vector3.zero, 0.3)
	task.wait(0.3)
	go("Slide setup", -16 * sx, -home * 40 * sz, 7)
	move(Vector3.xAxis, 1.4)
	task.wait(0.25)
	assert(probe:Invoke("Slide"), "Slide did not start")
	task.wait(0.12)
	report.actions.slide = state().acro
	report.actions.slideSpeed = root.AssemblyLinearVelocity.Magnitude
	probe:Invoke("JumpPress")
	task.wait(0.12)
	report.actions.slideJumpRise = root.AssemblyLinearVelocity.Y
	task.wait(1)
	move(Vector3.zero, 0.3)
	report.beforeRespawn = state()
	local old = player.Character
	probe:Invoke("Respawn")
	local respawnDeadline = os.clock() + 12
	while (player.Character == old or not player.Character) and os.clock() < respawnDeadline do
		task.wait(0.1)
	end
	assert(player.Character and player.Character ~= old, "Respawn did not replace character")
	task.wait(0.8)
	report.respawnStable = player:GetAttribute("RocklockSpawn") == spawnName
	report.final = state()
	assert(report.respawnStable, "Spawn slot changed on reset")
	report.peers = peerActions
	assert(
		peerActions.WallRun and peerActions.WallHop and peerActions.Flip and peerActions.Slide,
		"Peer action replication incomplete"
	)
end)
connection:Disconnect()
table.sort(frameTimes)
local sum = 0
for _, dt in frameTimes do
	sum += dt
end
report.frames = {
	count = #frameTimes,
	meanMs = sum / math.max(#frameTimes, 1) * 1000,
	p95Ms = (frameTimes[math.max(1, math.ceil(#frameTimes * 0.95))] or 0) * 1000,
}
report.ok, report.failure = ok, if ok then nil else tostring(failure)
local remote = ReplicatedStorage:WaitForChild("RocklockQA") :: RemoteEvent
remote:FireServer(report)
