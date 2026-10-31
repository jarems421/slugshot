--!strict
-- Opt-in fixture for StudioTestService:ExecuteMultiplayerTestAsync(2, "Rocklock").
-- Inject in Edit; remove after the test. No fixture is included in map projects.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudioTestService = game:GetService("StudioTestService")
local remote = ReplicatedStorage:WaitForChild("RocklockQA") :: RemoteEvent
local results: { [string]: any } = {}
local finished = false
local function finish()
	if finished then
		return
	end
	finished = true
	local spawns: { [string]: boolean } = {}
	local pass = true
	local resultCount = 0
	for _, result in results do
		resultCount += 1
		pass = pass and result.ok == true and result.rejected == 0 and result.corrections == 0
		if spawns[result.spawn] then
			pass = false
		end
		spawns[result.spawn] = true
	end
	local map = workspace:WaitForChild("Rocklock")
	local markers = map:WaitForChild("Spawns")
	local north, south =
		markers:WaitForChild("North") :: BasePart, markers:WaitForChild("South") :: BasePart
	local rays = RaycastParams.new()
	rays.RespectCanCollide = true
	local hit = workspace:Raycast(north.Position, south.Position - north.Position, rays)
	StudioTestService:EndTest({
		ok = pass and resultCount == 2 and #Players:GetPlayers() == 2 and hit ~= nil,
		clients = results,
		mapVersion = map:GetAttribute("MapVersion"),
		configHash = map:GetAttribute("ConfigSHA256"),
		spawnSeparation = (north.Position - south.Position).Magnitude,
		spawnSightBlockedBy = hit and hit.Instance.Name,
	})
end
remote.OnServerEvent:Connect(function(player: Player, result: any)
	if typeof(result) ~= "table" then
		return
	end
	result.rejected = player:GetAttribute("RejectedRequests") or 0
	result.accepted = player:GetAttribute("AcceptedRequests") or 0
	result.corrections = player:GetAttribute("MotionCorrections") or 0
	results[tostring(player:GetAttribute("RocklockSpawn"))] = result
	local count = 0
	for _ in results do
		count += 1
	end
	if count == 2 then
		finish()
	end
end)
task.delay(120, finish)
