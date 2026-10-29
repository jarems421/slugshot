--!strict
-- Ledge and wall detection for jump-triggered traversal (mantle, wall hop).
-- Adapted from ParkourTraversalController in the Place1 movement system,
-- https://github.com/alexkkork/place1-movement-system at
-- 87da75e2f2528291ebf65c4cbc52d1ce83c2f527: the ray layout, ledge/clearance
-- checks, wall-surface search and NoParkour/NoClimb/NoMantle/NoWallHop opt-outs.
-- Movement, animation and server validation are this lab's own.
--
-- MIT License
--
-- Copyright (c) 2026 alexkkork
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
local Traversal = {}

export type Ledge = {
	target: CFrame, -- root CFrame standing on the ledge, facing into it
	height: number, -- ledge top above the feet, studs
	wall: Vector3, -- wall face point at knee height
	normal: Vector3, -- flat outward wall normal
}

local function horizontal(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function safeUnit(vector: Vector3, fallback: Vector3): Vector3
	return if vector.Magnitude > 1e-4 then vector.Unit else fallback
end

local function optedOut(instance: Instance, names: { string }): boolean
	local cursor: Instance? = instance
	while cursor do
		for _, name in names do
			if cursor:GetAttribute(name) == true then
				return true
			end
		end
		cursor = cursor.Parent
	end
	return false
end

local MANTLE_OPT_OUT = { "NoParkour", "NoClimb", "NoMantle" }
local WALL_HOP_OPT_OUT = { "NoParkour", "NoClimb", "NoWallHop" }

function Traversal.params(character: Model): (RaycastParams, OverlapParams)
	local rays = RaycastParams.new()
	rays.FilterType = Enum.RaycastFilterType.Exclude
	rays.FilterDescendantsInstances = { character }
	rays.IgnoreWater = true
	rays.RespectCanCollide = true
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	overlap.RespectCanCollide = true
	overlap.MaxParts = 32
	return rays, overlap
end

-- Root height above the feet when standing.
function Traversal.standOffset(humanoid: Humanoid, root: BasePart): number
	return math.max(2.2, humanoid.HipHeight + root.Size.Y * 0.5)
end

local function solid(part: Instance): boolean
	return part:IsA("BasePart") and part.Anchored and part.CanCollide
end

local function clearanceOpen(
	position: Vector3,
	height: number,
	wall: BasePart,
	top: BasePart,
	overlap: OverlapParams
): boolean
	local size = Vector3.new(2.35, height, 1.85)
	local center = position + Vector3.new(0, height * 0.5 + 0.14, 0)
	for _, part in workspace:GetPartBoundsInBox(CFrame.new(center), size, overlap) do
		if part.CanCollide and part ~= wall and part ~= top then
			return false
		end
	end
	return true
end

-- A climbable ledge ahead of the movement direction, or nil.
function Traversal.findLedge(
	humanoid: Humanoid,
	root: BasePart,
	settings: any,
	rays: RaycastParams,
	overlap: OverlapParams
): Ledge?
	local move = horizontal(humanoid.MoveDirection)
	if move.Magnitude < 0.12 then
		return nil
	end
	move = move.Unit
	local offset = Traversal.standOffset(humanoid, root)
	local feetY = root.Position.Y - offset
	local ground = workspace:Raycast(
		root.Position + Vector3.new(0, 0.1, 0),
		Vector3.new(0, -(offset + 1.25), 0),
		rays
	)
	if ground and ground.Normal.Y > 0.55 then
		feetY = ground.Position.Y
	end
	local origin = Vector3.new(root.Position.X, feetY + 0.58, root.Position.Z)
	local wallHit = workspace:Raycast(origin, move * settings.Reach, rays)
	if not wallHit or not solid(wallHit.Instance) or math.abs(wallHit.Normal.Y) > 0.4 then
		return nil
	end
	local wall = wallHit.Instance :: BasePart
	if optedOut(wall, MANTLE_OPT_OUT) then
		return nil
	end
	local normal = safeUnit(horizontal(wallHit.Normal), -move)
	if move:Dot(-normal) < 0.45 then
		return nil
	end
	local inside = wallHit.Position - normal * 1.2
	local topHit = workspace:Raycast(
		Vector3.new(inside.X, feetY + settings.MaxHeight + 1.4, inside.Z),
		Vector3.new(0, -(settings.MaxHeight + 2.2), 0),
		rays
	)
	if not topHit or not solid(topHit.Instance) or topHit.Normal.Y < 0.72 then
		return nil
	end
	local top = topHit.Instance :: BasePart
	if optedOut(top, MANTLE_OPT_OUT) then
		return nil
	end
	local height = topHit.Position.Y - feetY
	if height < settings.MinHeight or height > settings.MaxHeight then
		return nil
	end
	local landing = topHit.Position - normal * 0.32
	if not clearanceOpen(landing, math.clamp(offset + 2.3, 4.4, 6.7), wall, top, overlap) then
		return nil
	end
	local target = Vector3.new(landing.X, topHit.Position.Y + offset + 0.12, landing.Z)
	return {
		target = CFrame.lookAt(target, target - normal),
		height = height,
		wall = wallHit.Position,
		normal = normal,
	}
end

-- The nearest kickable wall around an airborne character, or nil.
function Traversal.findWall(
	humanoid: Humanoid,
	root: BasePart,
	settings: any,
	rays: RaycastParams
): RaycastResult?
	local directions: { Vector3 } = {}
	local function add(candidate: Vector3)
		candidate = horizontal(candidate)
		if candidate.Magnitude < 0.1 then
			return
		end
		candidate = candidate.Unit
		for _, direction in directions do
			if direction:Dot(candidate) > 0.96 then
				return
			end
		end
		table.insert(directions, candidate)
	end
	local look, right = root.CFrame.LookVector, root.CFrame.RightVector
	local velocity = root.AssemblyLinearVelocity
	add(humanoid.MoveDirection)
	add(velocity)
	add(look)
	add(-look)
	add(right)
	add(-right)
	add(-velocity)
	local best: RaycastResult? = nil
	local bestDistance = math.huge
	local origin = root.Position + Vector3.new(0, 0.25, 0)
	for _, direction in directions do
		local hit = workspace:Raycast(origin, direction * settings.Reach, rays)
		if
			hit
			and solid(hit.Instance)
			and math.abs(hit.Normal.Y) < 0.35
			and not optedOut(hit.Instance, WALL_HOP_OPT_OUT)
		then
			local distance = (hit.Position - origin).Magnitude
			if distance < bestDistance then
				best, bestDistance = hit, distance
			end
		end
	end
	return best
end

return table.freeze(Traversal)
