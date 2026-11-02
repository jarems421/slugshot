--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Schema = require(ReplicatedStorage:WaitForChild("Combat").SettingsSchema)
local Sync = {}

function Sync.start(keys: any)
	local player = Players.LocalPlayer
	local touched: { [string]: boolean } = {}
	local keysTouched, applying, loaded, queued = false, false, false, false
	local remote: RemoteEvent? = nil
	local revision = 0
	local function snapshot(): any
		local attributes = {}
		for name in Schema.Defaults do
			local value = player:GetAttribute(name)
			attributes[name] = if typeof(value) == "Color3" then value:ToHex() else value
		end
		return Schema.normalize({ attributes = attributes, bindings = keys.snapshot() })
	end
	local function changed()
		revision += 1
		player:SetAttribute("SettingsSaveStatus", if loaded then "Pending" else "Loading")
		if queued or not loaded then
			return
		end
		queued = true
		task.delay(0.75, function()
			queued = false
			if remote then
				local data = snapshot()
				data.requestId = revision
				remote:FireServer("Save", data)
			end
		end)
	end
	for name in Schema.Defaults do
		player:GetAttributeChangedSignal(name):Connect(function()
			if not applying then
				touched[name] = true
				changed()
			end
		end)
	end
	keys.onChanged(function()
		if not applying then
			keysTouched = true
			changed()
		end
	end)
	player:SetAttribute("SettingsSaveStatus", "Loading")
	task.spawn(function()
		local syncRemote = ReplicatedStorage:WaitForChild("SettingsSync") :: RemoteEvent
		remote = syncRemote
		syncRemote.OnClientEvent:Connect(function(status: string, raw: any)
			if status == "Loaded" and not loaded then
				local data = Schema.normalize(raw)
				applying = true
				for name, value in data.attributes do
					if not touched[name] then
						player:SetAttribute(
							name,
							if name == "CrosshairColor" then Color3.fromHex(value) else value
						)
					end
				end
				if not keysTouched then
					keys.apply(data.bindings)
				end
				applying, loaded = false, true
				player:SetAttribute("SettingsLoaded", true)
				if next(touched) or keysTouched then
					changed()
				else
					player:SetAttribute("SettingsSaveStatus", "Saved")
				end
			elseif status == "Saved" then
				-- An acknowledgement for an older edit must not label a newer pending edit saved.
				if typeof(raw) == "table" and raw.requestId == revision then
					player:SetAttribute("SettingsSaveStatus", "Saved")
				end
			elseif status ~= "Loaded" then
				player:SetAttribute("SettingsSaveStatus", status)
			end
		end)
		-- Server loads independently; this handshake covers a reply sent before this listener existed.
		syncRemote:FireServer("Load")
	end)
end

return Sync
