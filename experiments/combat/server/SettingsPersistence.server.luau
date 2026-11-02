--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Schema = require(ReplicatedStorage:WaitForChild("Combat").SettingsSchema)
local Store = require(script.Parent.SettingsStore)
local adapter: any = nil
local records: { [Player]: any } = {}
local remote = Instance.new("RemoteEvent")
remote.Name = "SettingsSync"
remote.Parent = ReplicatedStorage

local function notify(player: Player, status: string, data: any?)
	if records[player] then
		records[player].status = status
	end
	if player.Parent then
		remote:FireClient(player, status, data)
	end
end

local function save(player: Player, record: any, release: boolean)
	while record.saving do
		task.wait(0.05)
	end
	if record.closed or not record.session then
		return
	end
	record.saving = true
	local revision = record.revision
	local requestId = record.requestId
	local ok, result = pcall(function()
		return adapter:save(record.session, record.data, release)
	end)
	record.saving = false
	if ok and result then
		record.saved = revision
		if release then
			record.closed = true
		else
			notify(
				player,
				if record.saved == record.revision then "Saved" else "Pending",
				{ requestId = requestId }
			)
		end
	else
		notify(player, "SaveFailed")
		warn("[Settings] Save failed; preferences remain pending")
	end
end

local function join(player: Player)
	local record: any =
		{ revision = 0, saved = 0, lastRequest = -math.huge, saving = false, closed = false }
	records[player] = record
	task.spawn(function()
		while player.Parent and not record.session do
			local ok, session, status = pcall(function()
				if not adapter then
					adapter = Store.connect()
				end
				return adapter:open(player.UserId)
			end)
			if ok and session then
				record.session, record.data = session, session.data
				if not player.Parent then
					save(player, record, true)
					return
				end
				notify(player, "Loaded", record.data)
				return
			elseif ok and status == "NewerVersion" then
				notify(player, "NewerVersion")
				return
			end
			notify(player, if ok and status == "Busy" then "Loading" else "LoadFailed")
			task.wait(10)
		end
	end)
end

remote.OnServerEvent:Connect(function(player: Player, operation: any, raw: any)
	local record = records[player]
	if not record or record.closed then
		return
	end
	local now = os.clock()
	if now - record.lastRequest < 0.5 then
		return
	end
	record.lastRequest = now
	if operation == "Load" then
		if record.session then
			notify(player, "Loaded", record.data)
		else
			notify(player, record.status or "Loading")
		end
		return
	end
	if
		operation ~= "Save"
		or not record.session
		or typeof(raw) ~= "table"
		or raw.version ~= Schema.Version
		or typeof(raw.requestId) ~= "number"
		or raw.requestId ~= raw.requestId
		or raw.requestId < 0
		or raw.requestId > 2 ^ 53
	then
		return
	end
	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, raw)
	if not ok or #encoded > 12000 then
		return
	end
	record.data = Schema.normalize(raw)
	record.requestId = raw.requestId
	record.revision += 1
	notify(player, "Pending")
end)

Players.PlayerAdded:Connect(join)
for _, player in Players:GetPlayers() do
	join(player)
end
Players.PlayerRemoving:Connect(function(player)
	local record = records[player]
	if record then
		for _ = 1, 3 do
			save(player, record, true)
			if record.closed or not record.session then
				break
			end
			task.wait(1)
		end
	end
	records[player] = nil
end)

task.spawn(function()
	local tickCount = 0
	while true do
		task.wait(5)
		tickCount += 1
		for player, record in records do
			if
				record.session
				and not record.saving
				and not record.closed
				and (record.revision ~= record.saved or tickCount % 6 == 0)
			then
				task.spawn(save, player, record, false)
			end
		end
	end
end)

game:BindToClose(function()
	local pending = 0
	for player, record in records do
		pending += 1
		task.spawn(function()
			for _ = 1, 3 do
				save(player, record, true)
				if record.closed or not record.session then
					break
				end
				task.wait(1)
			end
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.05)
	end
end)
