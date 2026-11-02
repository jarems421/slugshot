--!strict
-- Mobile check build only (tools/lobby/mobile_check.py): takes each device look through fixed views, logging costs and asking
-- the runner for a picture of each. The graphics level is set by the check's plugin, because game scripts aren't allowed to.
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")

-- Studio's panels take this much of the window around the game's view.
local CHROME_X, CHROME_Y = 200, 295
local LOOKS: { { name: string, width: number, height: number, level: number } } = {
	{ name = "WeakPhone", width = 844, height = 390, level = 1 },
	{ name = "Phone", width = 844, height = 390, level = 5 },
	{ name = "iPad", width = 1180, height = 820, level = 10 },
}
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
	task.wait(10)
	-- The desktop help and buttons aren't part of what's being judged.
	for _, item in (player:WaitForChild("PlayerGui") :: PlayerGui):GetChildren() do
		if item:IsA("ScreenGui") then
			item.Enabled = false
		end
	end
	-- Touch devices settle on low detail, so that is what gets measured.
	workspace:SetAttribute("HubReduceDetail", true)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	for _, look in LOOKS do
		print(`HUBCHECK size {look.width + CHROME_X} {look.height + CHROME_Y}`)
		workspace:SetAttribute("MobileCheckQuality", look.level)
		camera.CFrame = CFrame.lookAt(VIEWS[1].from, VIEWS[1].at)
		task.wait(6)
		for _, view in VIEWS do
			camera.CFrame = CFrame.lookAt(view.from, view.at)
			task.wait(3)
			print(
				string.format(
					"HUBCHECK view %s %s %d %d tris=%d draws=%d tex=%.0f mesh=%.0f",
					look.name,
					view.name,
					camera.ViewportSize.X,
					camera.ViewportSize.Y,
					read("SceneTriangleCount"),
					read("SceneDrawcallCount"),
					Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsTexture),
					Stats:GetMemoryUsageMbForTag(Enum.DeveloperMemoryTag.GraphicsMeshParts)
				)
			)
			print(`HUBCHECK shot {look.name}_{view.name}`)
			task.wait(1)
		end
	end
	camera.CameraType = Enum.CameraType.Custom
	print("HUBCHECK tour ends")
end)
