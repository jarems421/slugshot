--!strict
-- The preview's one moving target. Zero stops at its current position; resume
-- continues the phase without snapping. Peak speed is measured in studs/second.
local Motion = {}
export type State = { speed: number, phase: number, radius: number }
function Motion.new(): State
	return { speed = 7, phase = 0, radius = 10 }
end
function Motion.setSpeed(state: State, value: any): boolean
	if typeof(value) ~= "number" or value ~= value or value < 0 or value > 20 then
		return false
	end
	state.speed = value
	return true
end
function Motion.step(state: State, dt: number): number
	state.phase = (state.phase + math.max(dt, 0) * state.speed / state.radius) % (2 * math.pi)
	return math.sin(state.phase) * state.radius
end
return Motion
