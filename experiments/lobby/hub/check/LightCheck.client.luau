--!strict
-- Lighting check build only (build_hub.py --light; owner, 2026-11-05: looking up lit the cavern up). Roblox's automatic
-- graphics level falls when frames are slow (an unfocused Studio window runs at 15 a second), and lower levels light the far
-- wall and roof more simply. The same spot is captured looking level, up, and up at the Sky Well's rune ring, for the lobby's
-- own lighting and with each effect turned off in turn; gun_check.ps1 -Unfocused gives the slow run to compare with.
-- Output lines start with GUNCHECK, so tools/lobby/gun_check.ps1 captures each shot.
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local FROM = Vector3.new(0, 8, 112)
local VIEWS = {
	level = Vector3.new(-110, 30, 300),
	up = Vector3.new(-110, 150, 300),
	ring = Vector3.new(-110, 260, 300),
}

local function frameRate(): number
	local frames, spent = 0, 0
	local connection = RunService.RenderStepped:Connect(function(dt: number)
		frames += 1
		spent += dt
	end)
	task.wait(1)
	connection:Disconnect()
	return frames / math.max(spent, 1e-3)
end

-- Roblox's menu sometimes opens over a run and dims every capture; gun_check.ps1 closes it when asked.
local asked = 0
local function menuClosed()
	while GuiService.MenuIsOpen do
		asked += 1
		print(`GUNCHECK menu open {asked}`)
		task.wait(1.5)
	end
end

local function tour(variant: string)
	local camera = workspace.CurrentCamera
	for _, view in { "level", "up", "ring" } do
		camera.CFrame = CFrame.lookAt(FROM, VIEWS[view])
		task.wait(4)
		menuClosed()
		print(`GUNCHECK light {variant} {view} fps {math.round(frameRate())}`)
		print(`GUNCHECK shot {variant}-{view}`)
		task.wait(1)
	end
end

task.spawn(function()
	local player = Players.LocalPlayer
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	while not workspace:GetAttribute("HubSolid") do
		task.wait(0.5)
	end
	-- Let the art's maps finish loading before the first capture.
	task.wait(20)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	print("GUNCHECK tour starts")
	tour("base")
	-- Round 3's candidates (2026-11-05), only when asked: no colour grade (Roblox drops post effects at low levels), and the
	-- darkness put back with light instead.
	if workspace:GetAttribute("LightCheckCandidates") then
		local grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
		if grade then
			grade.Enabled = false
		end
		for _, c in { { 100, 0.9 }, { 88, 0.8 }, { 76, 0.7 }, { 64, 0.6 } } do
			Lighting.Ambient = Color3.fromRGB(c[1], c[1] - 2, c[1] + 12)
			Lighting.OutdoorAmbient = Lighting.Ambient
			Lighting.Brightness = c[2]
			tour(`a{c[1]}`)
		end
	end
	camera.CameraType = Enum.CameraType.Custom
	print("GUNCHECK PASS tour ends")
end)
