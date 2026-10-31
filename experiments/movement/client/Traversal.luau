--!strict
-- Ledge and wall detection for jump-triggered traversal (mantle, vault, wall hop/run).
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
local Clips = require(game:GetService("ReplicatedStorage"):WaitForChild("MovementExperiment").Clips)
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
	return math.max(2.2, Clips.standHeight(humanoid, root))
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

-- Forward rays at several heights above the feet and in lanes across the body
-- (Slugshot addition, not Place1): one knee-height ray missed thin or floating
-- ledges, and ledges met off-centre. The lowest height with a usable ledge wins,
-- nearest ray first. The top is probed 1.2 studs in from the face, or closer to the
-- edge for a thin top.
local LEDGE_HEIGHTS = { 0.58, 1.6, 2.6, 3.6 }
local LEDGE_LANES = { 0, -0.7, 0.7 }
local TOP_DEPTHS = { 1.2, 0.7 }

-- The ledge on top of a wall face hit by a forward ray, or nil.
local function ledgeAbove(
	wallHit: RaycastResult,
	normal: Vector3,
	feetY: number,
	offset: number,
	settings: any,
	rays: RaycastParams,
	overlap: OverlapParams
): Ledge?
	local wall = wallHit.Instance :: BasePart
	for _, depth in TOP_DEPTHS do
		local inside = wallHit.Position - normal * depth
		local topHit = workspace:Raycast(
			Vector3.new(inside.X, feetY + settings.MaxHeight + 1.4, inside.Z),
			Vector3.new(0, -(settings.MaxHeight + 2.2), 0),
			rays
		)
		if
			not topHit
			or not solid(topHit.Instance)
			or topHit.Normal.Y < 0.72
			or optedOut(topHit.Instance, MANTLE_OPT_OUT)
		then
			continue
		end
		local top = topHit.Instance :: BasePart
		local height = topHit.Position.Y - feetY
		local landing = topHit.Position - normal * 0.32
		if
			height >= settings.MinHeight
			and height <= settings.MaxHeight
			and clearanceOpen(landing, math.clamp(offset + 2.3, 4.4, 6.7), wall, top, overlap)
		then
			local target = Vector3.new(landing.X, topHit.Position.Y + offset + 0.12, landing.Z)
			return {
				target = CFrame.lookAt(target, target - normal),
				height = height,
				wall = wallHit.Position,
				normal = normal,
			}
		end
	end
	return nil
end

-- A climbable ledge ahead of the movement direction (or `direction`), or nil.
function Traversal.findLedge(
	humanoid: Humanoid,
	root: BasePart,
	settings: any,
	rays: RaycastParams,
	overlap: OverlapParams,
	direction: Vector3?
): Ledge?
	local move = horizontal(direction or humanoid.MoveDirection)
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
	local across = move:Cross(Vector3.yAxis)
	for _, rise in LEDGE_HEIGHTS do
		local faces: { { any } } = {}
		for _, lane in LEDGE_LANES do
			local origin = Vector3.new(root.Position.X, feetY + rise, root.Position.Z)
				+ across * lane
			local hit = workspace:Raycast(origin, move * settings.Reach, rays)
			if
				hit
				and solid(hit.Instance)
				and math.abs(hit.Normal.Y) <= 0.4
				and not optedOut(hit.Instance, MANTLE_OPT_OUT)
			then
				local normal = safeUnit(horizontal(hit.Normal), -move)
				if move:Dot(-normal) >= 0.45 then
					table.insert(faces, { hit, normal })
				end
			end
		end
		table.sort(faces, function(a, b)
			return a[1].Distance < b[1].Distance
		end)
		for _, face in faces do
			local ledge = ledgeAbove(face[1], face[2], feetY, offset, settings, rays, overlap)
			if ledge then
				return ledge
			end
		end
	end
	return nil
end

-- For a found ledge: if the obstacle is thin with open ground beyond, the landing
-- stand point past it and the obstacle top height. (Slugshot addition, not Place1.)
function Traversal.findVault(
	humanoid: Humanoid,
	root: BasePart,
	ledge: Ledge,
	settings: any,
	rays: RaycastParams,
	overlap: OverlapParams
): (CFrame?, number)
	local offset = Traversal.standOffset(humanoid, root)
	local topY = ledge.target.Y - offset - 0.12
	-- The floor under the character, which may already be mid-jump.
	local below = workspace:Raycast(root.Position, Vector3.new(0, -(offset + 10), 0), rays)
	local floorY = if below then below.Position.Y else topY - ledge.height
	local into = -ledge.normal
	local depth: number? = nil
	local step = 0.6
	while step <= settings.MaxDepth do
		local probe = ledge.wall + into * step
		local hit = workspace:Raycast(
			Vector3.new(probe.X, topY + 0.6, probe.Z),
			Vector3.new(0, -1.2, 0),
			rays
		)
		if not hit then
			depth = step
			break
		end
		step += 0.4
	end
	if not depth then
		return nil, topY
	end
	local land = ledge.wall + into * (depth + settings.LandDistance)
	local ground = workspace:Raycast(
		Vector3.new(land.X, topY + 0.5, land.Z),
		Vector3.new(0, -(ledge.height + 2.5), 0),
		rays
	)
	if not ground or ground.Normal.Y < 0.72 or math.abs(ground.Position.Y - floorY) > 1.5 then
		return nil, topY
	end
	local size = Vector3.new(2.35, offset + 2, 1.85)
	local center = ground.Position + Vector3.new(0, size.Y * 0.5 + 0.14, 0)
	for _, part in workspace:GetPartBoundsInBox(CFrame.new(center), size, overlap) do
		if part.CanCollide then
			return nil, topY
		end
	end
	local target = Vector3.new(land.X, ground.Position.Y + offset + 0.12, land.Z)
	return CFrame.lookAt(target, target + into), topY
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

-- Continuation probes are deliberately narrower than initial attachment: only
-- anchored, opted-in vertical faces near the current wall may carry the run.
function Traversal.followWall(
	position: Vector3,
	away: Vector3,
	direction: Vector3,
	speed: number,
	settings: any,
	rays: RaycastParams
): (RaycastResult?, string)
	local surface = settings.Surface
	local function probe(origin: Vector3, vector: Vector3): RaycastResult?
		local hit = workspace:Raycast(origin, vector, rays)
		if
			hit
			and solid(hit.Instance)
			and math.abs(hit.Normal.Y) < 0.35
			and not optedOut(hit.Instance, WALL_HOP_OPT_OUT)
		then
			return hit
		end
		return nil
	end
	local current: RaycastResult? = nil
	for _, height in { 0, surface.ProbeHeight, -surface.ProbeHeight } do
		local hit = probe(position + Vector3.yAxis * height, -away * settings.Reach)
		if hit and horizontal(hit.Normal).Unit:Dot(away) > 0.7 then
			current = hit
			break
		end
	end
	if speed >= settings.Cling.Below then
		local ahead = math.min(surface.LookAhead, speed * 0.16)
		-- A parallel raised face steers the body outward in advance. Deep offsets
		-- are obstacles, rather than permission to snap onto arbitrary nearby walls.
		local raised = probe(position + direction * ahead, -away * settings.Reach)
		if current and raised and horizontal(raised.Normal).Unit:Dot(away) > 0.95 then
			local step = (raised.Position - current.Position):Dot(away)
			if step > 0.05 and step <= surface.MaxStep then
				return raised, "step"
			end
		end
		-- Inside corner: turn before colliding with the next wall, at body clearance.
		local front = probe(position, direction * (settings.Hug + 0.7))
		if
			front
			and horizontal(front.Normal).Unit:Dot(direction) < -0.7
			and math.abs(horizontal(front.Normal).Unit:Dot(away)) < 0.72
		then
			return front, "inside"
		end
		-- Outside corner: once side support ends, reach just beyond the old face,
		-- then cast backwards into its end face. The controller rounds the shared
		-- edge at Hug radius instead of driving diagonally through the solid wall.
		if not current then
			local origin = position - away * (settings.Hug + 0.6) + direction * surface.CornerReach
			local outer = probe(origin, -direction * (surface.CornerReach + 0.7))
			if
				outer
				and horizontal(outer.Normal).Unit:Dot(direction) > 0.7
				and math.abs(horizontal(outer.Normal).Unit:Dot(away)) < 0.72
			then
				return outer, "outside"
			end
		end
	end
	return current, "surface"
end

return table.freeze(Traversal)
