--!strict
-- Gun-side check build only: a look at each part of the gun side (docs/art/general-shop.md). Output lines start with
-- GUNCHECK; tools/lobby/gun_check.ps1 captures each shot.
local Players = game:GetService("Players")

local STOPS: { { name: string, from: Vector3, at: Vector3 } } = {
	{ name = "bridgeEnd", from = Vector3.new(-78, 8, 9), at = Vector3.new(-100, 0, 0) },
	{ name = "kerbClose", from = Vector3.new(-106, 4, 15), at = Vector3.new(-111, 0, 7) },
	{ name = "arrival", from = Vector3.new(-96, 9, 4), at = Vector3.new(-200, 12, 0) },
	{ name = "pathClose", from = Vector3.new(-104, 6, 14), at = Vector3.new(-118, 0, 0) },
	{ name = "pathSide", from = Vector3.new(-114, 5, 30), at = Vector3.new(-114, 1, 2) },
	{ name = "pathFlora", from = Vector3.new(-98, 7, -34), at = Vector3.new(-118, 2, 4) },
	{ name = "velvetClose", from = Vector3.new(-118, 7, 78), at = Vector3.new(-130, 0, 95) },
	{ name = "velvetWide", from = Vector3.new(-100, 14, 120), at = Vector3.new(-170, 2, 110) },
	{ name = "stones", from = Vector3.new(-128, 10, 16), at = Vector3.new(-156, 3, 0) },
	{ name = "stoneSide", from = Vector3.new(-146, 5, 13), at = Vector3.new(-150, 3, 0) },
	{ name = "shopFront", from = Vector3.new(-150, 9, 0), at = Vector3.new(-186, 12, 0) },
	{ name = "shopSign", from = Vector3.new(-166, 12, 3), at = Vector3.new(-182, 14, 0) },
	{ name = "signFar", from = Vector3.new(-128, 8, 2), at = Vector3.new(-182, 14, 0) },
	{ name = "matClose", from = Vector3.new(-170, 7, 7), at = Vector3.new(-178, 0.5, 0) },
	{ name = "doorClose", from = Vector3.new(-170, 6, 9), at = Vector3.new(-182, 5, 0) },
	{ name = "podCorner", from = Vector3.new(-186, 27, 26), at = Vector3.new(-208, 23, 10) },
	{ name = "shopSideL", from = Vector3.new(-168, 10, 42), at = Vector3.new(-200, 10, 8) },
	{ name = "shopSideR", from = Vector3.new(-168, 10, -42), at = Vector3.new(-200, 10, -8) },
	{ name = "holeDown", from = Vector3.new(-138, 30, 44), at = Vector3.new(-200, -60, 0) },
	{ name = "rimCrystals", from = Vector3.new(-152, 6, 52), at = Vector3.new(-228, -8, -58) },
	{ name = "spireMush", from = Vector3.new(-162, -48, 24), at = Vector3.new(-200, -55, 0) },
	{ name = "spireTop", from = Vector3.new(-160, -16, 26), at = Vector3.new(-200, -22, 0) },
	{ name = "bridgeTop", from = Vector3.new(-92, 22, 0.5), at = Vector3.new(-96, 0, 0) },
	{ name = "wallA", from = Vector3.new(-178, -30, 34), at = Vector3.new(-232, -45, -72) },
	{ name = "wallB", from = Vector3.new(-218, -34, -22), at = Vector3.new(-140, -50, 44) },
	{ name = "wallClose", from = Vector3.new(-200, -40, 40), at = Vector3.new(-200, -42, 95) },
	{ name = "spire", from = Vector3.new(-160, -40, 38), at = Vector3.new(-200, -50, 0) },
	{ name = "floor", from = Vector3.new(-160, -104, 40), at = Vector3.new(-200, -118, -6) },
	{ name = "overview", from = Vector3.new(-86, 64, 96), at = Vector3.new(-200, -10, 0) },
	{ name = "zoneSlabsA", from = Vector3.new(-62, 22, -58), at = Vector3.new(-150, 0, -172) },
	{ name = "zoneSlabsB", from = Vector3.new(-84, 20, 66), at = Vector3.new(-160, 0, 158) },
}

task.spawn(function()
	local player = Players.LocalPlayer
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	while not workspace:GetAttribute("HubSolid") do
		task.wait(0.5)
	end
	print("GUNCHECK solid ready")
	-- The ground the path crosses to reach the rope bridge (owner, 2026-11-04): the first solid art hit straight down.
	local art = workspace:WaitForChild("HubArt")
	local only = RaycastParams.new()
	only.FilterType = Enum.RaycastFilterType.Include
	only.FilterDescendantsInstances = { art }
	for radius = 82, 106, 3 do
		local row = {}
		for side = -12, 12, 4 do
			local hit = workspace:Raycast(Vector3.new(-radius, 30, side), Vector3.new(0, -60, 0), only)
			table.insert(row, if hit then string.format("%.2f", hit.Position.Y) else "-")
		end
		print(`GUNCHECK ground r={radius} {table.concat(row, " ")}`)
	end
	task.wait(10)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	print("GUNCHECK tour starts")
	for _, stop in STOPS do
		camera.CFrame = CFrame.lookAt(stop.from, stop.at)
		task.wait(2.5)
		print(`GUNCHECK shot {stop.name}`)
		task.wait(1)
	end
	camera.CameraType = Enum.CameraType.Custom
	print("GUNCHECK PASS tour ends")
end)
