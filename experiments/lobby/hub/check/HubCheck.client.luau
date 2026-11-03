--!strict
-- Check build only: a short look at chosen views, logging real render costs at each. Output lines start with HUBCHECK.
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")

local STOPS: { { name: string, from: Vector3, at: Vector3 } } = {
	{ name = "lavaFlowA", from = Vector3.new(-115, 80, -205), at = Vector3.new(0, 85, -268) },
	{ name = "lavaFlowB", from = Vector3.new(-115, 80, -205), at = Vector3.new(0, 85, -268) },
	{ name = "grovePath", from = Vector3.new(75, 9, 0), at = Vector3.new(285, 70, 0) },
	{ name = "grovePond", from = Vector3.new(112, 7, -24), at = Vector3.new(190, 14, 6) },
	{ name = "groveFront", from = Vector3.new(100, 14, 0), at = Vector3.new(230, 60, 0) },
	{ name = "groveLeft", from = Vector3.new(150, 16, -95), at = Vector3.new(245, 40, 20) },
	{ name = "grovePeaks", from = Vector3.new(80, 50, 0), at = Vector3.new(270, 100, 0) },
	{ name = "groveTree", from = Vector3.new(105, 7, -28), at = Vector3.new(140, 8, -28) },
	{ name = "groveFern", from = Vector3.new(120, 6, 70), at = Vector3.new(140, 1, 55) },
	{ name = "streamHoleGo", from = Vector3.new(205, 95, -22), at = Vector3.new(258, 101, -2) },
	{ name = "streamHole", from = Vector3.new(205, 95, -22), at = Vector3.new(258, 101, -2) },
	{ name = "streamMid", from = Vector3.new(170, 45, -30), at = Vector3.new(235, 42, -2) },
	{ name = "pondClose", from = Vector3.new(118, 9, -30), at = Vector3.new(165, 0, 0) },
	{ name = "plantsClose", from = Vector3.new(108, 6, 58), at = Vector3.new(135, 2, 44) },
	{ name = "streamFoot", from = Vector3.new(148, 8, -14), at = Vector3.new(200, 14, -2) },
	{ name = "plaza", from = Vector3.new(0, 14, -95), at = Vector3.new(0, 70, -250) },
	{ name = "groveSlugs", from = Vector3.new(170, 3.4, -43), at = Vector3.new(174, 1, -46) },
	{ name = "crack", from = Vector3.new(-34, 9, -103), at = Vector3.new(-40, 0, -112) },
	{ name = "stormUp", from = Vector3.new(0, 9, 12), at = Vector3.new(0, 200, -10) },
	{ name = "ring", from = Vector3.new(-105, 12, -105), at = Vector3.new(-10, 200, -10) },
	{ name = "spawn", from = Vector3.new(0, 9, -12), at = Vector3.new(0, 90, -240) },
}

local function read(name: string): number
	local ok, value = pcall(function()
		return (Stats :: any)[name]
	end)
	return if ok and typeof(value) == "number" then value else -1
end

task.spawn(function()
	local player = Players.LocalPlayer
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	while not workspace:GetAttribute("HubSolid") do
		task.wait(0.5)
	end
	print("HUBCHECK solid ready")
	-- The slug side has no flat ground under its art, so it must be solid all over.
	local holes, tested = {}, 0
	for angle = 42, 133, 7 do
		for radius = 92, 296, 17 do
			local x, z = math.sin(math.rad(angle)) * radius, -math.cos(math.rad(angle)) * radius
			tested += 1
			if not workspace:Raycast(Vector3.new(x, 215, z), Vector3.new(0, -240, 0)) then
				table.insert(holes, string.format("%d/%d", angle, radius))
			end
		end
	end
	print(`HUBCHECK groveFloor tested={tested} holes={#holes} {table.concat(holes, " ")}`)
	local slugs = workspace:WaitForChild("HubArt"):FindFirstChild("GroveSlugs")
	-- Running on the mountain: how often the surface drops or jumps sharply between points two studs apart.
	local only = RaycastParams.new()
	only.FilterType = Enum.RaycastFilterType.Include
	only.FilterDescendantsInstances =
		{ workspace:WaitForChild("HubArt"):WaitForChild("hub-grove-solid") }
	local steps, sharp, previous = 0, 0, {}
	for x = 170, 300, 2 do
		local row = {}
		for z = -130, 130, 2 do
			local hit = workspace:Raycast(Vector3.new(x, 210, z), Vector3.new(0, -215, 0), only)
			local y = hit and hit.Position.Y
			row[z] = y
			local before = previous[z]
			if y and before and y > 2 and before > 2 then
				steps += 1
				if math.abs(y - before) > 7 then
					sharp += 1
				end
			end
		end
		previous = row
	end
	print(`HUBCHECK groveSurface steps={steps} sharp={sharp}`)
	-- Whether what's baked into the grove touches what you stand on. On the ground, negative means sunk in and positive floating.
	local scale = game:GetService("ReplicatedStorage"):WaitForChild("LobbyScale")
	local feet = require(scale:WaitForChild("grove_feet")) :: any
	local grove = CFrame.new(155, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
	local report = function(name: string, gaps: { number })
		table.sort(gaps)
		print(
			string.format(
				"HUBCHECK groveFeet %s n=%d median=%.2f p90=%.2f worst=%.2f",
				name,
				#gaps,
				gaps[math.ceil(#gaps / 2)] or 0,
				gaps[math.ceil(#gaps * 0.9)] or 0,
				gaps[#gaps] or 0
			)
		)
	end
	local art = workspace:WaitForChild("HubArt")
	local under = RaycastParams.new()
	under.FilterType = Enum.RaycastFilterType.Include
	under.FilterDescendantsInstances = { art:WaitForChild("hub-grove-ground") }
	local gaps = {}
	for _, foot in feet.ground do
		local at = grove * Vector3.new(foot[1], foot[2], foot[3])
		local hit = workspace:Raycast(at + Vector3.new(0, 30, 0), Vector3.new(0, -60, 0), under)
		if hit then
			table.insert(gaps, at.Y - hit.Position.Y)
		end
	end
	report("ground", gaps)
	gaps = {}
	for _, foot in feet.mountain do
		local at = grove * Vector3.new(foot[1], foot[2], foot[3])
		local axis = grove * Vector3.new(0, foot[2], feet.axisZ)
		local inward = (axis - at).Unit
		-- From outside the rock inward: positive means buried, negative floating. This hits collision, which sits a little outside the drawn rock.
		local from = at - inward * 30
		local hit = workspace:Raycast(from, inward * 60, only)
		if hit then
			table.insert(gaps, 30 - hit.Distance)
		end
	end
	report("mountain", gaps)
	-- How far the mountain's collision stands above what's drawn, seen from above: the air you'd run on.
	gaps = {}
	for _, top in feet.heights do
		local at = grove * Vector3.new(top[1], top[2], top[3])
		local hit = workspace:Raycast(Vector3.new(at.X, 215, at.Z), Vector3.new(0, -230, 0), only)
		if hit then
			table.insert(gaps, hit.Position.Y - at.Y)
		end
	end
	report("collisionAboveRock", gaps)
	local function tops(name: string): number
		local model = art:FindFirstChild(name)
		local most = 0
		for _, part in if model then model:GetDescendants() else {} do
			if part:IsA("MeshPart") then
				most = math.max(most, part.Position.Y + part.Size.Y / 2)
			end
		end
		return most
	end
	print(
		string.format(
			"HUBCHECK tops mountain=%.0f volcano=%.0f gate=%.0f",
			tops("hub-grove-mountain"),
			tops("hub-volcano"),
			tops("hub-arch")
		)
	)
	print(`HUBCHECK groveTrees count={#(art:WaitForChild("GroveTrees", 5) or art):GetChildren()}`)
	print(
		`HUBCHECK groveProps flora={#(art:FindFirstChild("GroveFlora") or art):GetChildren()} crystals={#(
			art:FindFirstChild("GroveCrystals") or art
		):GetChildren()}`
	)
	-- Running through the pond: moved by hand, since only the movement controller moves a character properly.
	local root = (player.Character :: Model):WaitForChild("HumanoidRootPart") :: BasePart
	local home = root.CFrame
	task.wait(2)
	local before = workspace:GetAttribute("GrovePondSplashes") or 0
	for frame = 1, 60 do
		root.CFrame = CFrame.new(148 + frame * 0.32, -1, -6)
		root.AssemblyLinearVelocity = Vector3.zero
		task.wait()
	end
	print(`HUBCHECK pondSplashes {(workspace:GetAttribute("GrovePondSplashes") or 0) - before}`)
	root.CFrame = home
	local reach = 180
	for _, tree in (art:FindFirstChild("GroveTrees") or art):GetChildren() do
		if tree:IsA("Model") then
			local at, size = tree:GetBoundingBox()
			for _, side in { -1, 1 } do
				local edge = at.Position
					+ at.Rotation * Vector3.new(side * size.X / 2, 0, side * size.Z / 2)
				reach = math.min(reach, math.deg(math.atan2(edge.X, -edge.Z)))
			end
		end
	end
	print(
		`HUBCHECK trees nearest the volcano side reach {math.floor(reach)} degrees (its side ends at 40)`
	)
	print(
		`HUBCHECK sketched mushrooms left {workspace.LobbyScale:FindFirstChild("VeylumeOvergrowth") ~= nil}`
	)
	print(`HUBCHECK groveSlugs count={if slugs then #slugs:GetChildren() else 0}`)
	task.wait(12)
	print("HUBCHECK tour starts")
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	for _, stop in STOPS do
		camera.CFrame = CFrame.lookAt(stop.from, stop.at)
		task.wait(2)
		print(
			string.format(
				"HUBCHECK %s tris=%d draws=%d texMB=%.0f meshMB=%.0f",
				stop.name,
				read("SceneTriangleCount"),
				read("SceneDrawcallCount"),
				Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsTexture),
				Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsMeshParts)
			)
		)
		print(`HUBCHECK shot {stop.name}`)
		task.wait(1)
	end
	camera.CameraType = Enum.CameraType.Custom
	-- The diffuse storm flashes at both ends of their range; no bolt emitter remains.
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = CFrame.lookAt(Vector3.new(-30, 20, -30), Vector3.new(0, 280, 0))
	local holder = workspace:WaitForChild("HubArt"):WaitForChild("StormFlash") :: BasePart
	local bloom = holder:WaitForChild("Bloom") :: ParticleEmitter
	assert(holder:FindFirstChild("Zap") == nil, "solid storm bolt emitter still exists")
	local flowCount = 0
	for _, flow in game:GetService("CollectionService"):GetTagged("HubLavaFlow") do
		assert(flow:IsA("Beam"), "lava flow is not a scrolling ribbon")
		assert(
			math.abs(flow.TextureSpeed - 0.28) < 0.001,
			"lava flow speed differs from the slow-flow brief"
		)
		assert(flow.Attachment0 and flow.Attachment1, "lava flow has no endpoints")
		assert(
			flow.Attachment0.WorldPosition.Y > flow.Attachment1.WorldPosition.Y,
			"lava flows uphill"
		)
		flowCount += 1
	end
	assert(flowCount == 20, "missing lava flow ribbons")
	print(`HUBCHECK lava flow ribbons={flowCount} speed=0.28; storm bolts=0 diffuse bloom retained`)
	for index, radius in { 30, 72 } do
		local base = holder:GetAttribute("VeilY") :: number
		holder.Position = Vector3.new(radius, base - 25 + 90 * (1 - radius / 96) ^ 1.7 - 52, 0)
		bloom:Emit(1)
		task.wait(0.08)
		print(`HUBCHECK shot flash{index}`)
		task.wait(2)
	end
	camera.CameraType = Enum.CameraType.Custom
	print("HUBCHECK tour ends")
end)
