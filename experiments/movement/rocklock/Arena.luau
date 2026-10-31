--!strict
-- Geometry is baked into the isolated place, so it is visible in Edit and Play.
-- This replaces only the movement lab's map factory at build time.
local Arena = {}

function Arena.create(): Model
	return workspace:WaitForChild("Rocklock") :: Model
end

return table.freeze(Arena)
