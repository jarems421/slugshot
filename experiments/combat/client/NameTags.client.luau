--!strict
-- Other players' name tags in the PvP UI's look (owner, 2026-11-06), replacing Roblox's default name: a slate plate
-- with an ink edge, the display name in Oswald and a stripe in team colour, blue for teammates and red for enemies.
-- Walls hide a tag, as they do the player. A tag also hides inside a Mistbank: anyone in one is hidden from outside,
-- and from inside you only see the tags of players within the mist's view distance.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CombatModule = ReplicatedStorage:WaitForChild("Combat")
local Abilities = require(CombatModule:WaitForChild("Abilities"))
local Theme = require(script.Parent:WaitForChild("PvpTheme"))

local player = Players.LocalPlayer
local layer = Theme.new("Folder", { Name = "NameTags", Parent = player:WaitForChild("PlayerGui") })

local TEAMMATE = Color3.fromRGB(120, 190, 255)
local ENEMY = Theme.HealthLow
local MIST_VIEW = Abilities.Kits.Aquabeek.passive.View

type Tag = { gui: BillboardGui, head: BasePart, stripe: Frame }
local tags: { [Player]: Tag } = {}

local function drop(other: Player)
	local tag = tags[other]
	if tag then
		tag.gui:Destroy()
		tags[other] = nil
	end
end

local function build(other: Player, character: Model)
	drop(other)
	local head = character:WaitForChild("Head", 10)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not head or not head:IsA("BasePart") or not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local gui = Theme.new("BillboardGui", {
		Name = other.Name,
		Adornee = head,
		Size = UDim2.fromOffset(150, 30),
		StudsOffset = Vector3.new(0, 2.3, 0),
		MaxDistance = 90,
		AlwaysOnTop = false,
		LightInfluence = 0,
		ResetOnSpawn = false,
		Parent = layer,
	})
	local plate = Theme.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.1,
		Parent = gui,
	})
	Theme.corner(plate, 7)
	Theme.edge(plate, 2)
	local stripe = Theme.new("Frame", {
		Position = UDim2.fromOffset(5, 6),
		Size = UDim2.new(0, 4, 1, -12),
		BorderSizePixel = 0,
		Parent = plate,
	})
	Theme.corner(stripe, 2)
	Theme.label(plate, other.DisplayName, Theme.TitleBold, 17, {
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -20, 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextStrokeColor3 = Theme.Ink,
		TextStrokeTransparency = 0.4,
	})
	tags[other] = { gui = gui, head = head, stripe = stripe }
end

local function watch(other: Player)
	if other == player then
		return
	end
	other.CharacterAdded:Connect(function(character)
		build(other, character)
	end)
	if other.Character then
		task.spawn(build, other, other.Character)
	end
end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(drop)
for _, other in Players:GetPlayers() do
	watch(other)
end

-- Team colour and mist hiding, ten times a second.
local since = 0
RunService.Heartbeat:Connect(function(dt)
	since += dt
	if since < 0.1 then
		return
	end
	since = 0
	local camera = workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	local viewerInMist = Abilities.insideMist(eye)
	for other, tag in tags do
		if not tag.head.Parent then
			drop(other)
			continue
		end
		tag.stripe.BackgroundColor3 = if Abilities.allies(player, other) then TEAMMATE else ENEMY
		tag.gui.Enabled = if viewerInMist
			then (tag.head.Position - eye).Magnitude <= MIST_VIEW
			else not Abilities.insideMist(tag.head.Position)
	end
end)
