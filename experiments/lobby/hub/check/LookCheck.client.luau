--!strict
-- Look check build only (build_hub.py --look): a camera tour of the lobby's built look, with frame rate and the outlines
-- drawn in each view, then the character beside a lantern, a crystal and on the island. Round 7 (owner, 2026-11-06: like
-- Minecraft shaders; the outlines too strong through the mist; the roof over the volcano blank) chose the look from three
-- set-ups compared here, and round 8 the calmer light on characters (docs/art/lobby-hub.md). Output lines start with
-- GUNCHECK so tools/lobby/gun_check.ps1 captures each shot.
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local VIEWS: { { name: string, from: Vector3, at: Vector3 } } = {
	{ name = "plaza", from = Vector3.new(0, 12, 150), at = Vector3.new(0, 25, 0) },
	-- Round 12 (owner, 2026-11-07): the plaza in front of the portals a little too glowy; the pit under the spawn island
	-- basic, its mushrooms old designs, its falls weird.
	{ name = "pitOverview", from = Vector3.new(105, 45, -30), at = Vector3.new(0, -30, 10) },
	{ name = "pitFall", from = Vector3.new(-2, 14, 92), at = Vector3.new(60, -25, 50) },
	{ name = "pitFallClose", from = Vector3.new(38, -12, 28), at = Vector3.new(66, -22, 59) },
	{ name = "pitShroom", from = Vector3.new(-3, 10, 90), at = Vector3.new(25, -10, 60) },
	{ name = "pitUnder", from = Vector3.new(55, -40, 10), at = Vector3.new(0, 5, 0) },
	-- Round 11 (owner, 2026-11-07): the upper wall, roof, mountain top and storm too dark; the rock cut open at its top by
	-- the far bridge; the shop's cobbles too dark.
	{ name = "upperWall", from = Vector3.new(-20, 10, -60), at = Vector3.new(-150, 120, -250) },
	{ name = "roof", from = Vector3.new(100, 30, -100), at = Vector3.new(220, 190, -150) },
	{ name = "mountainTop", from = Vector3.new(150, 25, 30), at = Vector3.new(300, 130, 0) },
	-- Then: the mountain plain, with only side mushrooms growing out of it.
	{ name = "mountainLeft", from = Vector3.new(140, 45, -60), at = Vector3.new(270, 60, -60) },
	{ name = "mountainRight", from = Vector3.new(150, 30, 120), at = Vector3.new(260, 50, 50) },
	-- Then: from the island the lighting only lasts half the screen (the alcove above the mountain).
	{ name = "islandMountain", from = Vector3.new(40, 22, -6), at = Vector3.new(300, 115, 5) },
	{ name = "storm", from = Vector3.new(60, 40, 60), at = Vector3.new(0, 230, 0) },
	{ name = "rockTop", from = Vector3.new(60, 40, 135), at = Vector3.new(52, 2, 108) },
	{ name = "rockPit", from = Vector3.new(54, 25, 70), at = Vector3.new(54, 8, 111) },
	{ name = "rockOut", from = Vector3.new(95, 20, 115), at = Vector3.new(54, 8, 111) },
	{ name = "shopPath", from = Vector3.new(-70, 14, 25), at = Vector3.new(-125, 0, 0) },
	{ name = "shopMat", from = Vector3.new(-150, 16, 25), at = Vector3.new(-178, 2, 0) },
	-- Round 9 (owner, 2026-11-07): the views of the owner's screenshots.
	{ name = "shopGround", from = Vector3.new(-105, 12, -45), at = Vector3.new(-195, 14, 15) },
	{ name = "groveMountain", from = Vector3.new(55, 22, -10), at = Vector3.new(300, 70, 0) },
	{ name = "bridgeFar", from = Vector3.new(10, 24, 82), at = Vector3.new(0, 0, 150) },
	{ name = "plazaFront", from = Vector3.new(0, 14, -55), at = Vector3.new(0, 14, -165) },
	{ name = "pathSides", from = Vector3.new(0, 30, 100), at = Vector3.new(0, 0, 200) },
	-- Round 10 (owner, 2026-11-07): crystals high on the wall, the arch's runes, the shop's cap.
	{ name = "wallHigh", from = Vector3.new(-60, 60, -60), at = Vector3.new(-174, 160, -261) },
	{ name = "wallHighFar", from = Vector3.new(120, 90, 160), at = Vector3.new(220, 150, 230) },
	{ name = "archUp", from = Vector3.new(0, 20, -60), at = Vector3.new(0, 95, -157) },
	{ name = "shopCap", from = Vector3.new(-120, 40, 40), at = Vector3.new(-195, 35, 5) },
	{ name = "volcanoRoof", from = Vector3.new(10, 40, -60), at = Vector3.new(0, 205, -270) },
	{ name = "island", from = Vector3.new(-40, 22, 40), at = Vector3.new(30, 8, -20) },
	{ name = "islandHigh", from = Vector3.new(130, 70, 130), at = Vector3.new(0, 0, 0) },
	{ name = "mouth", from = Vector3.new(0, 30, 40), at = Vector3.new(0, 90, 300) },
	{ name = "mouthInside", from = Vector3.new(0, 40, 240), at = Vector3.new(60, 175, 285) },
	{ name = "mouthSide", from = Vector3.new(60, 30, 215), at = Vector3.new(138, 55, 262) },
	{ name = "path", from = Vector3.new(0, 9, 106), at = Vector3.new(0, 2, 290) },
	{ name = "sideShrooms", from = Vector3.new(0, 20, 300), at = Vector3.new(60, 10, 420) },
	{ name = "sideShroomsWall", from = Vector3.new(140, 25, 160), at = Vector3.new(200, 30, 210) },
	{ name = "ring", from = Vector3.new(90, 16, 60), at = Vector3.new(200, 4, 140) },
	{ name = "eyeUp", from = Vector3.new(60, 14, 60), at = Vector3.new(0, 150, 20) },
	{ name = "mountain", from = Vector3.new(110, 9, 0), at = Vector3.new(300, 80, 0) },
	{ name = "wall", from = Vector3.new(-110, 40, 140), at = Vector3.new(-166, 60, 222) },
	{ name = "grove", from = Vector3.new(120, 12, -30), at = Vector3.new(200, 20, 40) },
	{ name = "shop", from = Vector3.new(-100, 14, 30), at = Vector3.new(-190, 10, 0) },
}

-- Roblox's menu sometimes opens over a run (at a forced low graphics level the window also minimizes) and covers every
-- capture; gun_check.ps1 closes it when asked.
local asked = 0
local function menuClosed()
	while GuiService.MenuIsOpen do
		asked += 1
		print(`GUNCHECK menu open {asked}`)
		task.wait(1.5)
	end
end

local function fps(): number
	local frames, start = 0, os.clock()
	local c = RunService.RenderStepped:Connect(function()
		frames += 1
	end)
	task.wait(1.5)
	c:Disconnect()
	return frames / (os.clock() - start)
end

task.spawn(function()
	local ok, problem = pcall(function()
		while not workspace:GetAttribute("HubSolid") do
			task.wait(0.5)
		end
		task.wait(4)
		local counts = { PointLight = 0, shadows = 0 }
		for _, d in workspace:GetDescendants() do
			if d:IsA("PointLight") then
				counts.PointLight += 1
				if d.Shadows then
					counts.shadows += 1
				end
			end
		end
		print(`GUNCHECK light point {counts.PointLight} shadowed {counts.shadows}`)
		print(
			`GUNCHECK light sun {Lighting:GetSunDirection()} shadows {Lighting.GlobalShadows} brightness {Lighting.Brightness}`
		)
		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Scriptable
		print("GUNCHECK tour starts")
		-- The hub's mist takes about 25 seconds to fill.
		task.wait(20)
		-- The character beside a lantern, a crystal and on the island (owner, 2026-11-06: characters too glowy near lights;
		-- every character outlined in black; shadows to be seen).
		local player = game:GetService("Players").LocalPlayer
		local character = player.Character or player.CharacterAdded:Wait()
		local root = character:WaitForChild("HumanoidRootPart") :: BasePart
		root.Anchored = true
		-- The camera script fades the character when the camera is moved by script; keep it shown.
		local shown = RunService.RenderStepped:Connect(function()
			for _, part in character:GetDescendants() do
				if part:IsA("BasePart") then
					part.LocalTransparencyModifier = 0
				end
			end
		end)
		local function ground(x: number, z: number): number
			local params = RaycastParams.new()
			params.FilterDescendantsInstances = { character }
			params.FilterType = Enum.RaycastFilterType.Exclude
			local hit = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -160, 0), params)
			return if hit then hit.Position.Y else 0
		end
		local lantern = (
				workspace:WaitForChild("HubArt"):WaitForChild("FarLanterns") :: Model
			):GetChildren()[1] :: Model
		local lanternAt = lantern:GetPivot().Position
		local crystalAt = Vector3.new(150, 0, 60)
		for _, crystal in (workspace.HubArt:WaitForChild("GroveCrystals") :: Model):GetChildren() do
			if crystal:IsA("Model") then
				local at = crystal:GetPivot().Position
				local r = math.sqrt(at.X * at.X + at.Z * at.Z)
				if
					at.Y < 6
					and r > 110
					and r < 250
					and crystal:FindFirstChildWhichIsA("PointLight", true)
				then
					crystalAt = at
					break
				end
			end
		end
		local inward = Vector3.new(-crystalAt.X, 0, -crystalAt.Z).Unit
		-- Where the character stands, and where the camera looks from, relative to the character.
		local spots = {
			{
				name = "charLantern",
				stand = Vector3.new(lanternAt.X * 0.55, 0, lanternAt.Z + 2),
				eye = Vector3.new(0, 3, -13),
			},
			{
				name = "charCrystal",
				stand = crystalAt + inward * 6,
				eye = inward * 12 + Vector3.new(0, 3, 0),
			},
			{ name = "charIsland", stand = Vector3.new(6, 0, 8), eye = Vector3.new(13, 6, 2) },
		}
		local function shoot(name: string)
			task.wait(2.5)
			menuClosed()
			print(`GUNCHECK shot {name}`)
			task.wait(1)
		end
		for _, spot in spots do
			local y = ground(spot.stand.X, spot.stand.Z)
			root.CFrame = CFrame.new(spot.stand.X, y + 3, spot.stand.Z)
			camera.CFrame =
				CFrame.lookAt(root.Position + spot.eye, root.Position + Vector3.new(0, 0.5, 0))
			shoot(`built_{spot.name}`)
		end
		shown:Disconnect()
		root.Anchored = false
		for _, view in VIEWS do
			camera.CFrame = CFrame.lookAt(view.from, view.at)
			task.wait(2)
			menuClosed()
			local rate = fps()
			local count = 0
			for _, d in workspace:GetDescendants() do
				if d:IsA("Highlight") and d.Enabled then
					count += 1
				end
			end
			print(`GUNCHECK light built {view.name} fps {math.round(rate)} highlights {count}`)
			menuClosed()
			print(`GUNCHECK shot built_{view.name}`)
			task.wait(1)
		end
	end)
	print(if ok then "GUNCHECK PASS tour ends" else `GUNCHECK FAIL {problem}`)
end)
