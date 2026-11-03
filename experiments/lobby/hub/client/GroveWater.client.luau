--!strict
-- The grove's pond reacting to whoever is in it, on each client and look-only: ripples that spread from each step, splashes that
-- grow with speed, a wake at a run and a big splash on landing (owner). The emitters live on the server's GroveSplash part.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local POND_X = 155 -- the pond's centre, along world X
local UNIT = 5
local WATER_Y = -0.5
local IN_WATER_ABOVE = 7 -- a character's middle stands this far above the water at most, while in it
local STEP = 3.2 -- studs moved between splashes at a walk
local STILL_EVERY = 1.6 -- seconds between ripples when standing
local LANDING_SPEED = 14 -- studs per second downward that counts as jumping in

local function smin(a: number, b: number, k: number): number
	local h = math.clamp(0.5 + 0.5 * (b - a) / k, 0, 1)
	return b + (a - b) * h - k * h * (1 - h)
end

-- The pond's outline, as pondEdge in the concept: negative in the water.
local function pondEdge(x: number, z: number): number
	local a = math.atan2(z, x)
	local radius = 7
		* (
			1
			+ 0.07 * math.sin(a * 3 + 1)
			+ 0.05 * math.sin(a * 5 + 2)
			+ 0.035 * math.sin(a * 9 + 0.7)
		)
	local lobe = math.sqrt((x - 0.4) ^ 2 + ((z - 7.6) / 0.85) ^ 2) - 2.9
	return smin(math.sqrt(x * x + z * z) - radius, lobe, 1.2)
end

local function inPond(at: Vector3): boolean
	if at.Y > WATER_Y + IN_WATER_ABOVE then
		return false
	end
	return pondEdge(-at.Z / UNIT, (at.X - POND_X) / UNIT) < 0.15
end

type Wader = { last: Vector3, moved: number, still: number, wasIn: boolean, fall: number }

task.spawn(function()
	local art = workspace:WaitForChild("HubArt")
	local splash = art:WaitForChild("GroveSplash", 60) :: BasePart?
	if not splash then
		return
	end
	local rings = splash:WaitForChild("Rings") :: ParticleEmitter
	local drops = splash:WaitForChild("Drops") :: ParticleEmitter
	local foam = splash:WaitForChild("Foam") :: ParticleEmitter
	local waders: { [Player]: Wader } = {}
	local count = 0

	local function burst(at: Vector3, ringCount: number, dropCount: number, foamCount: number)
		splash.CFrame = CFrame.new(at.X, WATER_Y + 0.15, at.Z)
		rings:Emit(ringCount)
		drops:Emit(dropCount)
		foam:Emit(foamCount)
		count += 1
		workspace:SetAttribute("GrovePondSplashes", count)
	end

	RunService.Heartbeat:Connect(function(dt)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				waders[player] = nil
				continue
			end
			local at = root.Position
			local state = waders[player]
			if not state then
				waders[player] = { last = at, moved = 0, still = 0, wasIn = false, fall = 0 }
				continue
			end
			local step = at - state.last
			state.last = at
			local flat = Vector2.new(step.X, step.Z).Magnitude
			-- Teleports and respawns aren't running.
			if flat > 40 * math.max(dt, 1 / 30) then
				flat = 0
			end
			local speed = flat / math.max(dt, 1 / 240)
			local isIn = inPond(at)
			if not isIn then
				state.fall = math.max(-step.Y / math.max(dt, 1 / 240), 0)
			elseif not state.wasIn then
				-- Into the water: harder the faster it was coming.
				local hard = math.clamp((state.fall - LANDING_SPEED) / 40, 0, 1)
				burst(
					at,
					2 + math.floor(hard * 3),
					10 + math.floor(hard * 26),
					2 + math.floor(hard * 6)
				)
			end
			state.wasIn = isIn
			if isIn then
				state.moved += flat
				state.still += dt
				if state.moved >= STEP then
					state.moved = 0
					state.still = 0
					local fast = math.clamp(speed / 24, 0, 1)
					burst(at, 1, 3 + math.floor(fast * 9), if fast > 0.55 then 1 else 0)
				elseif state.still >= STILL_EVERY then
					state.still = 0
					rings.Parent = splash
					splash.CFrame = CFrame.new(at.X, WATER_Y + 0.15, at.Z)
					rings:Emit(1)
				end
			end
		end
		for player in waders do
			if player.Parent == nil then
				waders[player] = nil
			end
		end
	end)
end)
