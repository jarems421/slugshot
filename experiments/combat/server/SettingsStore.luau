--!strict
-- Injectable DataStore adapter: shared by production and Studio fault/rejoin checks.
local HttpService = game:GetService("HttpService")
local Schema = require(game:GetService("ReplicatedStorage"):WaitForChild("Combat").SettingsSchema)
local Store = {}
Store.__index = Store
local LEASE = 120

function Store.new(dataStore: any): any
	return setmetatable({ dataStore = dataStore }, Store)
end

function Store.connect(): (any, string?)
	if game:GetService("RunService"):IsStudio() and game.GameId == 0 then
		return nil, "StudioUnavailable"
	end
	-- Keep Studio tests separate from live player preferences.
	local name = if game:GetService("RunService"):IsStudio()
		then "SlugshotSettings_Studio"
		else "SlugshotSettings"
	return Store.new(game:GetService("DataStoreService"):GetDataStore(name)), nil
end

function Store.open(self: any, userId: number): (any, string)
	local token = HttpService:GenerateGUID(false)
	local status = "Busy"
	local raw = self.dataStore:UpdateAsync(`user:{userId}`, function(previous: any)
		status = "Busy" -- UpdateAsync may retry after another server wins the lease.
		if Schema.future(previous) then
			status = "NewerVersion"
			return nil
		end
		if
			typeof(previous) == "table"
			and typeof(previous.lease) == "table"
			and typeof(previous.lease.token) == "string"
			and typeof(previous.lease.expires) == "number"
			and previous.lease.expires > os.time()
			and previous.lease.expires <= os.time() + LEASE + 30
		then
			return nil
		end
		local nextValue = Schema.normalize(previous)
		nextValue.lease = { token = token, expires = os.time() + LEASE }
		status = "Loaded"
		return nextValue
	end)
	if
		status ~= "Loaded"
		or typeof(raw) ~= "table"
		or typeof(raw.lease) ~= "table"
		or raw.lease.token ~= token
	then
		return nil, if status == "Loaded" then "Busy" else status
	end
	return { key = `user:{userId}`, token = token, data = Schema.normalize(raw) }, status
end

function Store.save(self: any, session: any, snapshot: any, release: boolean): boolean
	local written = false
	self.dataStore:UpdateAsync(session.key, function(previous: any)
		written = false
		if
			Schema.future(previous)
			or typeof(previous) ~= "table"
			or typeof(previous.lease) ~= "table"
			or previous.lease.token ~= session.token
		then
			return nil
		end
		local nextValue = Schema.normalize(snapshot)
		if not release then
			nextValue.lease = { token = session.token, expires = os.time() + LEASE }
		end
		written = true
		return nextValue
	end)
	return written
end

return Store
