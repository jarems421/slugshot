--!strict
-- Display place: large models of Floppy and both Inferno forms, so the owner can inspect their faces and motion up
-- close. Asset ids live only in ignored private-assets. Bone motion runs on the client.
local InsertService = game:GetService("InsertService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local FloppyAppearance = (require :: any)(script.Parent.FloppyAppearance)
local floppyAsset = (require :: any)(ReplicatedStorage:WaitForChild("FloppyAsset"))
local asset = (require :: any)(ReplicatedStorage:WaitForChild("InfernoAsset"))
local materials = ServerStorage:WaitForChild("InfernoMaterials")

local DISPLAY_SCALE = 10
local INK = Color3.fromRGB(46, 16, 14) -- dark maroon: this slug has no black in it (owner)
local MOUTH_INK = Color3.fromRGB(60, 14, 10)
local GLOW = Color3.fromRGB(255, 170, 90)
-- Strength 1: the eyes keep their yellow-to-red burn instead of blowing out to white.
local VISIBILITY_FLOOR = 0.05
local EMISSIVE_FLOOR = 0.05 -- tools/slugs/upload_inferno.py

local function load(id: number, name: string): Model?
	local ok, container = pcall(InsertService.LoadAsset, InsertService, id)
	if not ok then
		warn(`{name}: LoadAsset failed: {container}`)
		return nil
	end
	local model = Instance.new("Model")
	model.Name = name
	for _, child in (container :: Instance):GetChildren() do
		child.Parent = model
	end
	(container :: Instance):Destroy()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	model.Parent = workspace
	return model
end

-- Turn a model to face -Z, toward the players, whatever way its import came in. Its left and right bones give its front.
local function faceSpawn(model: Model, leftName: string, rightName: string)
	local left = model:FindFirstChild(leftName, true)
	local right = model:FindFirstChild(rightName, true)
	if left and right and left:IsA("Bone") and right:IsA("Bone") then
		local front = (right.WorldPosition - left.WorldPosition).Unit:Cross(Vector3.yAxis)
		if front.Z > 0 then
			model:PivotTo(model:GetPivot() * CFrame.Angles(0, math.pi, 0))
		end
	end
end

-- A screen-space outline holds its shape from every angle and through every flip, which a hull around a bending,
-- carved mesh could not. Roblox limits how many Highlights draw at once, so a crowded scene needs a plan for this.
local function outline(model: Model, colour: Color3)
	local highlight = Instance.new("Highlight")
	highlight.Name = "Outline"
	highlight.FillTransparency = 1
	highlight.OutlineColor = colour
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = model
	highlight.Parent = model
end

local function place(model: Model, x: number, floor: number, z: number)
	model:ScaleTo(DISPLAY_SCALE)
	-- Measured from the skinned meshes: the import's RootPart is a fixed block that isn't part of the creature.
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, part in model:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		if part:IsA("MeshPart") and string.sub(part.Name, -4) ~= "_Ink" then
			local half = part.Size / 2
			low = low:Min(part.Position - half)
			high = high:Max(part.Position + half)
		else
			(part :: BasePart).Transparency = 1
		end
	end
	local centre = (low + high) / 2
	model:PivotTo(model:GetPivot() + Vector3.new(x - centre.X, floor - low.Y, z - centre.Z))
end

local function dressInferno(model: Model)
	local dressed = 0
	for _, part in model:GetDescendants() do
		if not part:IsA("MeshPart") then
			continue
		end
		for _, child in part:GetChildren() do
			if child:IsA("SurfaceAppearance") then
				child:Destroy()
			end
		end
		part.TextureID = ""
		part.Reflectance = 0
		if string.sub(part.Name, -8) == "MouthInk" or string.sub(part.Name, -9) == "MouthLine" then
			-- Flat ink. The line starts clear; the client brings it in as he clenches.
			part.Color = MOUTH_INK
			part.Material = Enum.Material.SmoothPlastic
			part.CastShadow = false
			part.Transparency = if string.sub(part.Name, -9) == "MouthLine" then 1 else 0
		elseif string.sub(part.Name, -5) == "Mouth" or string.sub(part.Name, -4) == "Eyes" then
			local template = materials:FindFirstChild(part.Name)
			assert(template and template:IsA("SurfaceAppearance"), `no material for {part.Name}`)
			part.Color = Color3.new(1, 1, 1)
			part.Material = Enum.Material.SmoothPlastic
			part.CastShadow = false
			local surface = template:Clone()
			surface.Name = "InfernoMaterial"
			surface.EmissiveStrength = 1
			surface.Parent = part
		else
			local template = materials:FindFirstChild(part.Name)
			assert(template and template:IsA("SurfaceAppearance"), `no material for {part.Name}`)
			part.Color = Color3.new(1, 1, 1)
			part.Material = Enum.Material.SmoothPlastic
			local surface = template:Clone()
			surface.Name = "InfernoMaterial"
			surface.EmissiveStrength = VISIBILITY_FLOOR / EMISSIVE_FLOOR
			surface.Parent = part
			dressed += 1
		end
	end
	assert(dressed == 1, `{model.Name} expected one textured body, found {dressed}`)
	local head = model:FindFirstChild("head", true)
	if head then
		local light = Instance.new("PointLight")
		light.Name = "SlugGlow"
		light.Color = GLOW
		light.Brightness = 0.3
		light.Range = 5 * DISPLAY_SCALE
		light.Shadows = false
		light.Parent = head
	end
end

local function report(model: Model)
	local meshes, bones = 0, 0
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") then
			meshes += 1
		elseif d:IsA("Bone") then
			bones += 1
		end
	end
	local _, size = model:GetBoundingBox()
	print(`{model.Name}: {meshes} meshes, {bones} bones, {size.X} x {size.Y} x {size.Z} studs`)
end

-- The flame is part of the body mesh and moves with the client's bones, which also place the glow behind it. This is
-- the light it throws.
local function tailFire(model: Model)
	local tail = model:FindFirstChild("flame_1", true)
	if not (tail and tail:IsA("Bone")) then
		warn("InfernoDragon has no flame_1 bone")
		return
	end
	local light = Instance.new("PointLight")
	light.Color = GLOW
	light.Brightness = 0.5
	light.Range = 3 * DISPLAY_SCALE
	light.Shadows = false
	light.Parent = tail
end

-- Everyone starts in front of the models, looking at them.
local function standInFront(character: Model)
	character:PivotTo(CFrame.lookAt(Vector3.new(0, 4, -26), Vector3.new(0, 6, 0)))
end
local function playerJoined(player: Player)
	player.CharacterAdded:Connect(function(character)
		task.wait()
		standInFront(character)
	end)
	if player.Character then
		standInFront(player.Character)
	end
end
Players.PlayerAdded:Connect(playerJoined)
for _, player in Players:GetPlayers() do
	playerJoined(player)
end

local floppy = load(floppyAsset.model, "Floppy")
if floppy then
	FloppyAppearance.apply(floppy)
	faceSpawn(floppy, "eye_L", "eye_R")
	place(floppy, -20, 0, 0)
	outline(floppy, Color3.fromRGB(14, 14, 18))
	report(floppy)
end

local inferno = load(asset.base.model, "Inferno")
if inferno then
	dressInferno(inferno)
	faceSpawn(inferno, "antenna_L", "antenna_R")
	place(inferno, 0, 0, 0)
	outline(inferno, INK)
	report(inferno)
end

local dragon = load(asset.dragon.model, "InfernoDragon")
if dragon then
	dressInferno(dragon)
	faceSpawn(dragon, "antenna_L", "antenna_R")
	place(dragon, 28, 4, 0)
	outline(dragon, INK)
	tailFire(dragon)
	report(dragon)
end
