--!strict
-- Owner's isolated Studio art review. Reuse existing private source art and load
-- only the revised authored draft. No writes to lobby, inventory or experiences.
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Motion = require(script.Parent.Motion)
local LookPack = require(ReplicatedStorage:WaitForChild("LookPack"))
local layout = require(ServerStorage:WaitForChild("TrainingLayout")) :: any
local hub = require(ServerStorage:WaitForChild("HubAssets")) :: any
local lobby = require(ServerStorage:WaitForChild("LobbyAssets")) :: any
local draft = require(ServerStorage:WaitForChild("TrainingDraft")) :: { model: number }
LookPack.applyBase()
LookPack.applyMood(LookPack.Moods.Training)
local Lighting = game:GetService("Lighting")
Lighting.Brightness = 1.6
Lighting.ClockTime = 13.5 -- neutral preview key; the shared cavern preset starts at midnight
Lighting.Ambient, Lighting.OutdoorAmbient =
	Color3.fromRGB(120, 124, 131), Color3.fromRGB(120, 124, 131)
Lighting.EnvironmentDiffuseScale = 0.5
Lighting.ExposureCompensation = 0
Lighting.GlobalShadows = false -- stable art-review fill; roof must not black out the island
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
if atmosphere then
	atmosphere.Density, atmosphere.Haze = 0.15, 1.1
end
local art = Instance.new("Model")
art.Name, art.Parent = "TrainingArt", workspace
-- A sealed cavern has no skylight. Even, shadow-free fills keep the stone and
-- targets readable at every graphics setting without brightening them to Neon.
local function fill(position: Vector3, brightness: number)
	local holder = Instance.new("Part")
	holder.Name, holder.Size = "TrainingFill", Vector3.one
	holder.Anchored, holder.Transparency, holder.CanCollide, holder.CanQuery = true, 1, false, false
	holder.Position, holder.Parent = position, art
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows =
		Color3.fromRGB(236, 239, 231), 60, brightness, false
	light.Parent = holder
end
for i = 0, 15 do
	local a = i * math.pi / 8
	fill(Vector3.new(math.sin(a) * 280, 45, math.cos(a) * 280), 0.7)
end

local function v3(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end
local function bounds(model: Model): (Vector3, Vector3)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in model:GetChildren() do
		if p:IsA("MeshPart") then
			lo, hi = lo:Min(p.Position - p.Size / 2), hi:Max(p.Position + p.Size / 2)
		end
	end
	return lo, hi
end
local function load(id: number, reference: any): Model
	local container = InsertService:LoadAsset(id)
	local model = Instance.new("Model")
	for _, item in container:GetDescendants() do
		if item:IsA("MeshPart") and reference[item.Name] then
			item.Parent = model
		end
	end
	container:Destroy()
	-- Fit using source coordinates, rather than trusting glTF importer scale/turn.
	local lo, hi = bounds(model)
	local wantLo, wantHi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, spec in reference do
		wantLo, wantHi = wantLo:Min(v3(spec.min)), wantHi:Max(v3(spec.max))
	end
	local size, want = hi - lo, wantHi - wantLo
	model:ScaleTo(
		model:GetScale() * math.max(want.X, want.Y, want.Z) / math.max(size.X, size.Y, size.Z)
	)
	lo, hi = bounds(model)
	local center, targetCenter = (lo + hi) / 2, (wantLo + wantHi) / 2
	local best, error = CFrame.identity, math.huge
	for _, turn in { CFrame.identity, CFrame.Angles(0, math.pi, 0) } do
		local total = 0
		for name, spec in reference do
			local part = model:FindFirstChild(name)
			if part and part:IsA("MeshPart") then
				local wantCenter = (v3(spec.min) + v3(spec.max)) / 2
				total += (
					turn:VectorToWorldSpace(part.Position - center) - (wantCenter - targetCenter)
				).Magnitude
			end
		end
		if total < error then
			error, best = total, turn
		end
	end
	model:PivotTo(CFrame.new(targetCenter) * best * CFrame.new(-center) * model:GetPivot())
	if error > 1 then
		-- Older rubble imports recentered the loose groups independently. Restore
		-- their recorded bounds individually after choosing the common axis turn.
		for name, spec in reference do
			local part = model:FindFirstChild(name)
			if part and part:IsA("MeshPart") then
				part.CFrame = CFrame.new((v3(spec.min) + v3(spec.max)) / 2) * part.CFrame.Rotation
				part.Size = v3(spec.max) - v3(spec.min)
			end
		end
	end
	print(
		string.format(
			"[Training] normalized %d meshes; center fit %.3f",
			#model:GetChildren(),
			error
		)
	)
	return model
end
local function style(part: MeshPart, template: Instance?, color: Color3, emissive: number?)
	for _, child in part:GetChildren() do
		if child:IsA("SurfaceAppearance") then
			child:Destroy()
		end
	end
	part.Anchored, part.CanTouch, part.CanCollide = true, false, false
	part.CanQuery, part.CastShadow = true, true
	part.TextureID, part.Material, part.Color = "", Enum.Material.SmoothPlastic, color
	if string.find(part.Name, "_Ink", 1, true) then
		part.Color, part.Material = LookPack.INK, Enum.Material.Neon
		part.CanQuery, part.CastShadow = false, false
	elseif template then
		local surface = template:Clone() :: SurfaceAppearance
		surface.EmissiveStrength = emissive or 0
		surface.Parent = part
	end
end
local prototypes: { [string]: Model } = {}
for key, reference in layout.sourceBounds do
	local info = hub.assets[key] or lobby.assets[key]
	local model = load(info.model, reference)
	local templates =
		ServerStorage:WaitForChild(if hub.assets[key] then "HubMaterials" else "LobbyMaterials")
	for _, p in model:GetChildren() do
		if p:IsA("MeshPart") then
			local group = if info.parts then info.parts[p.Name] else info.groups[p.Name]
			style(
				p,
				templates:FindFirstChild(key .. "/" .. p.Name),
				Color3.new(1, 1, 1),
				if group then group.emissive else 0
			)
		end
	end
	prototypes[key] = model
end
-- Blender Z-up -> Roblox Y-up: x'=x, y'=z, z'=-y.
local axes = CFrame.fromMatrix(Vector3.zero, Vector3.xAxis, -Vector3.zAxis, Vector3.yAxis)
for _, spec in layout.source do
	local original = prototypes[spec.key]:FindFirstChild(spec.group)
	if not original or not original:IsA("MeshPart") then
		continue
	end
	local part = original:Clone()
	local m = spec.matrix
	local x = Vector3.new(m[1], m[5], m[9])
	local y = Vector3.new(m[2], m[6], m[10])
	local z = Vector3.new(m[3], m[7], m[11])
	local scale = x.Magnitude
	local transform =
		CFrame.fromMatrix(Vector3.new(m[4], m[8], m[12]), x / scale, y / scale, z / scale)
	transform = axes * transform * axes:Inverse()
	local position = transform.Position + transform:VectorToWorldSpace(part.Position * scale)
	part.CFrame = CFrame.new(position) * transform.Rotation * part.CFrame.Rotation
	part.Size *= scale
	part.Name, part.Parent = spec.name, art
end
for _, model in prototypes do
	model:Destroy()
end
local authored = load(draft.model, layout.authored)
local mover = Instance.new("Model")
mover.Name, mover.Parent = "MovingTarget", art
local function srgb(n: number): number
	return if n <= 0.0031308 then 12.92 * n else 1.055 * n ^ (1 / 2.4) - 0.055
end
for _, part in authored:GetChildren() do
	if not part:IsA("MeshPart") then
		continue
	end
	local spec = layout.authored[part.Name]
	if not spec then
		warn("[Training] unknown authored part", part.Name)
		continue
	end
	local template: Instance? = nil
	if spec.paint then
		template = ServerStorage.TrainingMaterials:FindFirstChild("StonePaint")
	elseif spec.sourceMaterial then
		local from = spec.sourceMaterial
		template = ServerStorage.HubMaterials:FindFirstChild(from.key .. "/" .. from.group)
	end
	local color = if template
		then Color3.new(1, 1, 1)
		else Color3.new(srgb(spec.color[1]), srgb(spec.color[2]), srgb(spec.color[3]))
	style(part, template, color, spec.emissive)
	part.CanCollide = string.sub(part.Name, 1, 7) == "COURSE_"
		or part.Name == "TARGET_RaisedBase"
		or string.find(part.Name, "_Stone", 1, true) ~= nil
	if string.sub(part.Name, 1, 14) == "TARGET_STRAFE_" then
		part.Parent = mover
	else
		part.Parent = art
	end
end
authored:Destroy()
local state, home = Motion.new(), mover:GetPivot()
local remote = Instance.new("RemoteEvent")
remote.Name, remote.Parent = "TrainingTargetSpeed", ReplicatedStorage
workspace:SetAttribute("TrainingTargetSpeed", state.speed)
local requests: { [Player]: number } = {}
remote.OnServerEvent:Connect(function(player: Player, value: any)
	local now = os.clock()
	if now - (requests[player] or -math.huge) < 0.08 then
		return
	end
	requests[player] = now
	if Motion.setSpeed(state, value) then
		workspace:SetAttribute("TrainingTargetSpeed", state.speed)
	end
end)
Players.PlayerRemoving:Connect(function(player)
	requests[player] = nil
end)
RunService.Heartbeat:Connect(function(dt)
	mover:PivotTo(home + Vector3.new(Motion.step(state, dt), 0, 0))
end)
workspace:SetAttribute("TrainingReady", true)
print(`[Training] READY: {#art:GetChildren()} pieces, speed {state.speed}`)
