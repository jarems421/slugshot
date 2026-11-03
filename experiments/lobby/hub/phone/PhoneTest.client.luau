--!strict
-- Phone test build only (tools/lobby/build_hub.py --phone): measures the device at fixed views at both detail levels, then
-- shows a card of results to read back. It stays out of the normal place.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local UserInputService = game:GetService("UserInputService")

local SETTLE, MEASURE = 2, 5
local VIEWS: { { name: string, from: Vector3, at: Vector3 } } = {
	{ name = "Spawn", from = Vector3.new(0, 9, -12), at = Vector3.new(0, 90, -240) },
	{ name = "Storm", from = Vector3.new(0, 9, 12), at = Vector3.new(0, 200, -10) },
	{ name = "Bridge", from = Vector3.new(0, 5, -92), at = Vector3.new(0, 62, -220) },
	{ name = "Portals", from = Vector3.new(0, 14, -118), at = Vector3.new(0, 24, -161) },
	{ name = "Volcano", from = Vector3.new(-95, 75, -55), at = Vector3.new(0, 120, -265) },
	{ name = "Across", from = Vector3.new(0, 12, 150), at = Vector3.new(0, 60, -200) },
	{ name = "Pit", from = Vector3.new(-30, 14, -30), at = Vector3.new(-70, -12, -75) },
	{ name = "Falling", from = Vector3.new(8, -70, 8), at = Vector3.new(0, 0, 0) },
}

type Result = { fps: number, low: number, tris: number, draws: number }

local started = os.clock()
local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "PhoneTest"
gui.DisplayOrder = 1000
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function readStat(name: string): number
	local ok, value = pcall(function()
		return (Stats :: any)[name]
	end)
	return if ok and typeof(value) == "number" then value else -1
end

local banner = Instance.new("TextLabel")
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 6)
banner.Size = UDim2.new(0.8, 0, 0, 30)
banner.BackgroundColor3 = Color3.fromRGB(16, 18, 30)
banner.BackgroundTransparency = 0.15
banner.TextColor3 = Color3.fromRGB(255, 225, 160)
banner.Font = Enum.Font.GothamBold
banner.TextSize = 14
banner.TextWrapped = true
banner.Text = "Phone test: loading the lobby..."
banner.Parent = gui

local function peakMemory(peak: number): number
	return math.max(peak, Stats:GetTotalMemoryUsageMb())
end

local function measure(
	view: { from: Vector3, at: Vector3 },
	camera: Camera,
	peak: number
): (Result, number)
	camera.CFrame = CFrame.lookAt(view.from, view.at)
	task.wait(SETTLE)
	local times: { number } = {}
	local connection = RunService.RenderStepped:Connect(function(dt: number)
		table.insert(times, dt)
	end)
	task.wait(MEASURE)
	connection:Disconnect()
	local total = 0
	for _, dt in times do
		total += dt
	end
	table.sort(times, function(a: number, b: number): boolean
		return a > b
	end)
	local worst, count = 0, math.max(math.floor(#times / 100), 1)
	for index = 1, math.min(count, #times) do
		worst += times[index]
	end
	return {
		fps = if total > 0 then #times / total else 0,
		low = if worst > 0 then count / worst else 0,
		tris = readStat("SceneTriangleCount"),
		draws = readStat("SceneDrawcallCount"),
	},
		peakMemory(peak)
end

local function showCard(lines: { string }, again: () -> ())
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromScale(0.96, 0.96)
	card.BackgroundColor3 = Color3.fromRGB(10, 11, 20)
	card.BackgroundTransparency = 0.04
	card.Parent = gui
	local height = workspace.CurrentCamera.ViewportSize.Y
	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, -16, 1, -math.max(height * 0.13, 40))
	text.Position = UDim2.fromOffset(8, 4)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Font = Enum.Font.RobotoMono
	text.TextSize = math.clamp(math.floor(height / (#lines + 4)), 10, 20)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Top
	text.Text = table.concat(lines, "\n")
	text.Parent = card
	local function button(label: string, x: number, pressed: () -> ())
		local made = Instance.new("TextButton")
		made.AnchorPoint = Vector2.new(0.5, 1)
		made.Position = UDim2.new(x, 0, 1, -6)
		made.Size = UDim2.new(0.4, 0, 0, math.max(height * 0.1, 32))
		made.BackgroundColor3 = Color3.fromRGB(70, 60, 130)
		made.TextColor3 = Color3.new(1, 1, 1)
		made.Font = Enum.Font.GothamBold
		made.TextSize = 15
		made.Text = label
		made.Parent = card
		made.Activated:Connect(function()
			card:Destroy()
			pressed()
		end)
	end
	button("Close and play", 0.27, function() end)
	button("Run again", 0.73, again)
end

local function runTest()
	local camera = workspace.CurrentCamera
	banner.Visible = true
	camera.CameraType = Enum.CameraType.Scriptable
	local results: { [string]: { Result } } = { Low = {}, High = {} }
	local peak, done, total = 0, 0, #VIEWS * 2
	for _, level in { "Low", "High" } do
		local wanted = level == "Low"
		-- Set both ways, so this counts as a choice even if it's already at this level.
		workspace:SetAttribute("HubReduceDetail", not wanted)
		workspace:SetAttribute("HubReduceDetail", wanted)
		for _, view in VIEWS do
			done += 1
			banner.Text =
				`Phone test: hands off, about {(total - done + 1) * (SETTLE + MEASURE)} s left. {level} detail, {view.name} ({done}/{total})`
			results[level][#results[level] + 1], peak = measure(view, camera, peak)
		end
	end
	camera.CameraType = Enum.CameraType.Custom
	banner.Visible = false
	local quality = "?"
	pcall(function()
		quality = (UserSettings():GetService("UserGameSettings") :: any).SavedQualityLevel.Name
	end)
	local size = camera.ViewportSize
	local lines = {
		"SLUGSHOT PHONE TEST 1",
		`Screen {math.floor(size.X)}x{math.floor(size.Y)}  touch {UserInputService.TouchEnabled}  graphics {quality}`,
		string.format(
			"Memory peak %.0f MB  textures %.0f  meshes %.0f",
			peak,
			Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsTexture),
			Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsMeshParts)
		),
		string.format(
			"Loaded in %.0f s  solid %s/%s failed  art failed %s",
			workspace:GetAttribute("PhoneTestLoaded") or -1,
			tostring(workspace:GetAttribute("HubSolidFailed") or "?"),
			tostring(workspace:GetAttribute("HubSolidParts") or "?"),
			tostring(workspace:GetAttribute("HubArtFailed") or "?")
		),
		"View      LOW fps (worst)   HIGH fps (worst)  tris k",
	}
	for index, view in VIEWS do
		local a, b = results.Low[index], results.High[index]
		lines[#lines + 1] = string.format(
			"%-9s %4.0f (%3.0f)        %4.0f (%3.0f)      %4.0f",
			view.name,
			a.fps,
			a.low,
			b.fps,
			b.low,
			b.tris / 1000
		)
	end
	print(table.concat(lines, "\n"))
	showCard(lines, function()
		task.spawn(runTest)
	end)
	print("HUBCHECK shot card")
	task.wait(1)
	print("HUBCHECK tour ends")
end

task.spawn(function()
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	local deadline = os.clock() + 180
	while not workspace:GetAttribute("HubSolid") and os.clock() < deadline do
		task.wait(0.5)
	end
	workspace:SetAttribute("PhoneTestLoaded", os.clock() - started)
	print(`PHONETEST place {game.PlaceId} universe {game.GameId}`)
	banner.Text = "Phone test: letting everything finish loading..."
	task.wait(20)
	runTest()
end)
