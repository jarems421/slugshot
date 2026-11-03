--!strict
-- Engine raycast regression fixtures; runs only in the movement test place.
local shared = game:GetService("ReplicatedStorage"):WaitForChild("MovementExperiment")
local Config = require(shared.Config)
local Traversal =
	require(game:GetService("StarterPlayer").StarterPlayerScripts.MovementSandbox.Traversal)
local settings = Config.Traversal.WallRun
local fixture = Instance.new("Folder")
fixture.Name = "WallSurfaceTestFixtures"
fixture.Parent = workspace
local offset = Vector3.new(400, 500, 400)
local function block(position: Vector3, size: Vector3): Part
	local part = Instance.new("Part")
	part.Size, part.Position = size, offset + position
	part.Anchored = true
	part.Parent = fixture
	return part
end
local rays = RaycastParams.new()
rays.FilterType = Enum.RaycastFilterType.Include
rays.FilterDescendantsInstances = { fixture }
rays.RespectCanCollide = true
local function sample(position: Vector3): (RaycastResult?, string)
	return Traversal.followWall(
		offset + position,
		Vector3.xAxis,
		-Vector3.zAxis,
		34,
		settings,
		rays
	)
end
local function expectKind(actual: string, expected: string)
	assert(actual == expected, "Expected " .. expected .. ", got " .. actual)
end
local success, message = pcall(function()
	local wall = block(Vector3.new(-2, 0, 0), Vector3.new(4, 40, 40))
	local hit, kind = sample(Vector3.new(2.1, 0, 0))
	assert(hit and hit.Instance == wall, "Flat support must stay attached")
	expectKind(kind, "surface")
	local bump = block(Vector3.new(0.4, 0, -5), Vector3.new(0.8, 40, 2))
	hit, kind = sample(Vector3.new(2.1, 0, 0))
	assert(hit and hit.Instance == bump, "Small protrusion must be anticipated")
	expectKind(kind, "step")
	bump:Destroy()
	local deep = block(Vector3.new(0.75, 0, -5), Vector3.new(1.5, 40, 2))
	hit, kind = sample(Vector3.new(2.1, 0, 0))
	assert(kind ~= "step", "Large protrusions must not be treated as small ledges")
	deep:Destroy()
	local inside = block(Vector3.new(0, 0, -4.2), Vector3.new(12, 40, 4))
	hit, kind = sample(Vector3.new(2.1, 0, 0))
	assert(hit and hit.Instance == inside, "Inside corner must turn before collision")
	expectKind(kind, "inside")
	inside:Destroy()
	hit, kind = sample(Vector3.new(2.1, 0, -20.2))
	assert(hit and hit.Instance == wall, "Outside corner must find the adjacent end face")
	expectKind(kind, "outside")
	hit = sample(Vector3.new(2.1, 0, -26))
	assert(hit == nil, "A distant wall end must not be bridged")
	wall:SetAttribute("NoParkour", true)
	hit = sample(Vector3.new(2.1, 0, 0))
	assert(hit == nil, "Continuation must respect NoParkour")
	wall:SetAttribute("NoParkour", false)
	wall.Anchored = false
	hit = sample(Vector3.new(2.1, 0, 0))
	assert(hit == nil, "Moving parts must not carry the wall run")
end)
fixture:Destroy()
assert(success, tostring(message))
print(
	"[Movement tests] PASS: wall support, bounded bumps, inside/outside corners, gaps and opt-outs"
)
