--!strict
-- Disposable native visual review; never mapped to the regular range.
local P = game:GetService("Players").LocalPlayer
local R = game:GetService("RunService")
local H = game:GetService("HttpService")
local scripts = P:WaitForChild("PlayerScripts")
local probe = scripts:WaitForChild("MovementExperimentProbe") :: BindableFunction
local movement = scripts:WaitForChild("MovementSandbox")
local first = (require :: any)(movement:WaitForChild("FirstPerson"))
local ads = (require :: any)(movement:WaitForChild("Ads"))
local tune = (require :: any)(movement:WaitForChild("Tuning")).values
local sight = (require :: any)(scripts:WaitForChild("Combat"):WaitForChild("AdsSight"))
local function shot(name: string)
	local camera = workspace.CurrentCamera :: Camera
	local visual = camera:FindFirstChild("FirstPersonBodyVisual")
	local holo = camera:FindFirstChild("AdsHologram")
	local mechanismTop, frameBottom = math.huge, -math.huge
	local function edge(part: BasePart, low: boolean): number
		local value = if low then math.huge else -math.huge
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					local pixel = camera:WorldToViewportPoint(
						part.CFrame:PointToWorldSpace(part.Size * Vector3.new(x, y, z) / 2)
					)
					value = if low then math.min(value, pixel.Y) else math.max(value, pixel.Y)
				end
			end
		end
		return value
	end
	if visual then
		for _, part in visual:GetChildren() do
			if
				part:IsA("BasePart")
				and part.Transparency < 0.95
				and (
					string.find(part.Name, "AdsDoor")
					or string.find(part.Name, "AdsProng")
					or part.Name == "AdsEmitter"
					or part.Name == "AdsLens"
					or part:IsA("MeshPart")
				)
			then
				mechanismTop = math.min(mechanismTop, edge(part, true))
			end
		end
	end
	if holo then
		for _, part in holo:GetChildren() do
			if part:IsA("BasePart") and part.Transparency < 0.95 then
				frameBottom = math.max(frameBottom, edge(part, false))
			end
		end
	end
	if mechanismTop < math.huge and frameBottom > -math.huge then
		print("ADSCHECK bounds " .. H:JSONEncode({
			phase = name,
			boxGapPixels = mechanismTop - frameBottom,
		}))
	end
	print("ADSCHECK shot " .. name)
	task.wait(1.6)
end
local function waitFor(test: () -> boolean, seconds: number, label: string)
	local untilAt = os.clock() + seconds
	repeat
		if test() then
			return
		end
		task.wait(0.03)
	until os.clock() > untilAt
	error(label)
end
local camera = workspace.CurrentCamera :: Camera
local oldOpen, oldClose = tune.adsOpenTime, tune.adsCloseTime
local display: Model? = nil
local connection: RBXScriptConnection? = nil
print("ADSCHECK started")
local ok, err = pcall(function()
	waitFor(function()
		return probe:Invoke("State").ready
	end, 20, "Avatar not ready")
	local character = P.Character :: Model
	local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
	local backpack = P:WaitForChild("Backpack")
	waitFor(function()
		return character:FindFirstChildOfClass("Tool") ~= nil
			or backpack:FindFirstChildOfClass("Tool") ~= nil
	end, 30, "No gun")
	local tool = (
		character:FindFirstChildOfClass("Tool") or backpack:FindFirstChildOfClass("Tool")
	) :: Tool
	humanoid:EquipTool(tool)
	task.wait(2)
	local handle = tool:FindFirstChild("Handle") :: BasePart
	local model = Instance.new("Model")
	model.Name = "AdsMountReviewFixture"
	display = model
	local origin = Vector3.new(1000, 100, 1000)
	for _, part in tool:GetChildren() do
		if part:IsA("BasePart") and part ~= handle then
			local copy = part:Clone()
			for _, child in copy:GetDescendants() do
				if child:IsA("JointInstance") or child:IsA("Constraint") or child:IsA("Light") then
					child:Destroy()
				end
			end
			copy.Anchored = true
			copy.CanCollide = false
			copy.CanQuery = part:IsA("MeshPart") and not string.find(part.Name, "_Ink")
			copy.CFrame = CFrame.new(origin) * handle.CFrame:ToObjectSpace(part.CFrame)
			copy.Parent = model
		end
	end
	model.Parent = workspace
	local rays = RaycastParams.new()
	rays.FilterType = Enum.RaycastFilterType.Include
	rays.FilterDescendantsInstances = { model }
	rays.RespectCanCollide = false
	local roof = {}
	for _, z in { -0.15, -0.35, -0.5, -0.6, -0.7, -0.8 } do
		local hit = workspace:Raycast(origin + Vector3.new(0, 2, z), Vector3.new(0, -3, 0), rays)
		table.insert(
			roof,
			{ z = z, y = hit and hit.Position.Y - origin.Y, name = hit and hit.Instance.Name }
		)
	end
	print("ADSCHECK roof " .. H:JSONEncode(roof))
	camera.CameraType = Enum.CameraType.Scriptable
	connection = R.RenderStepped:Connect(function()
		camera.CFrame =
			CFrame.lookAt(origin + Vector3.new(2.3, 1.2, 1.2), origin + Vector3.new(0, 0.4, -0.6))
		camera.FieldOfView = 35
	end)
	shot("closed-side")
	if connection then
		connection:Disconnect()
		connection = nil
	end
	model:Destroy()
	display = nil
	camera.CameraType = Enum.CameraType.Custom
	first.setActive(true)
	task.wait(1)
	tune.adsOpenTime = 2
	ads.set(true)
	for _, phase in { 0.2, 0.4, 0.6, 0.8, 1 } do
		tune.adsOpenTime = 2
		waitFor(function()
			return sight.progress() >= phase - 0.001
		end, 5, "Open phase timeout")
		tune.adsOpenTime = 1e9
		task.wait(0.15)
		shot("open-" .. tostring(phase))
	end
	ads.set(false)
	for _, phase in { 0.8, 0.6, 0.4, 0.2, 0 } do
		tune.adsCloseTime = 2
		waitFor(function()
			return sight.progress() <= phase + 0.001
		end, 5, "Close phase timeout")
		tune.adsCloseTime = 1e9
		task.wait(0.15)
		shot("close-" .. tostring(phase))
	end
	tune.adsOpenTime, tune.adsCloseTime = oldOpen, oldClose
	ads.set(true)
	waitFor(function()
		return sight.progress() >= 0.999
	end, 2, "Full-speed open timed out")
	local combat = scripts:WaitForChild("CombatExperimentProbe") :: BindableFunction
	combat:Invoke("Press")
	task.wait(0.75)
	shot("charged")
	combat:Invoke("Release")
	waitFor(function()
		local state = combat:Invoke("State")
		return state.lastSent > 0 and state.lastAccepted == state.lastSent
	end, 3, "ADS shot was not accepted")
	ads.set(false)
	waitFor(function()
		return sight.progress() <= 0.001
	end, 2, "Full-speed close timed out")
	for _ = 1, 3 do
		ads.set(true)
		task.wait(0.06)
		ads.set(false)
		task.wait(0.06)
	end
	ads.set(false)
	task.wait(0.5)
	assert(sight.progress() == 0, "Interrupted opening did not reset")
	humanoid:UnequipTools()
	task.wait(0.4)
	local holo = camera:FindFirstChild("AdsHologram")
	if holo then
		for _, part in holo:GetChildren() do
			if part:IsA("BasePart") then
				assert(part.Transparency == 1, "Holster left a frame visible")
			end
		end
	end
	print("ADSCHECK PASS: stages, full-speed cycles, ADS shot acknowledgement and holster cleanup")
end)
if connection then
	connection:Disconnect()
end
if display then
	display:Destroy()
end
camera.CameraType = Enum.CameraType.Custom
ads.set(false)
tune.adsOpenTime = oldOpen
tune.adsCloseTime = oldClose
first.setActive(false)
if not ok then
	warn("ADSCHECK FAIL " .. tostring(err))
end
