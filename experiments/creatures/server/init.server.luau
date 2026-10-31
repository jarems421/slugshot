--!strict
-- Empty preview world only; no movement, projectile simulation or gameplay.
local Players = game:GetService("Players")
Players.CharacterAutoLoads = false
local floor = Instance.new("Part")
floor.Name = "CreaturePreviewFloor"
floor.Anchored = true
floor.Size = Vector3.new(40, 1, 40)
floor.Position = Vector3.new(0, -0.5, 0)
floor.Color = Color3.fromRGB(46, 51, 60)
floor.Parent = workspace
print("Slug preview lab: original technical placeholders only; FBX import is a separate gate")
