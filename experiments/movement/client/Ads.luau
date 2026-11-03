--!strict
-- Aiming down sights (owner, 2026-11-01): one shared state read by the camera, the gun and the
-- body. It never affects where shots go; they always use the crosshair's ray.
local Ads = {}
local wanted = false
local progress = 0
local weight = 0
local aiming = false
local RAISE, LOWER = 0.17, 0.15 -- seconds; eased, so it starts and settles softly
local listeners: { (boolean) -> () } = {}

function Ads.set(value: boolean)
	if wanted ~= value then
		wanted = value
		for _, listener in listeners do
			listener(value)
		end
	end
end

function Ads.wanted(): boolean
	return wanted
end

function Ads.weight(): number
	return weight
end

-- Wanted and not interrupted by an acrobatic action.
function Ads.aiming(): boolean
	return aiming
end

function Ads.onChange(listener: (boolean) -> ())
	table.insert(listeners, listener)
end

function Ads.step(dt: number, allowed: boolean)
	aiming = wanted and allowed
	progress = if aiming
		then math.min(progress + dt / RAISE, 1)
		else math.max(progress - dt / LOWER, 0)
	weight = progress * progress * progress * (progress * (progress * 6 - 15) + 10)
end

return Ads
