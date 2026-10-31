--!strict
local Players = game:GetService("Players")
local scripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
local preview = scripts:WaitForChild("CreaturePreview")
local Visual = require(preview:WaitForChild("Visual"))
local parent = Instance.new("Folder")
parent.Name = "CreatureFixtureTests"
parent.Parent = workspace

local function expectForm(value: Visual.Handle, name: string)
	assert(value.active == name, "Expected active form: " .. name)
end

local handle = Visual.new("placeholder", { parent = parent })
assert(handle.models.protoform.Parent == parent, "Protoform starts visible")
assert(handle.models.transformed.Parent == nil, "Transformed starts hidden")
assert(not handle:playAttack(), "Attack before transformation is harmless")
handle:idle(CFrame.new(1, 2, 3), 3.125)
expectForm(handle, "protoform")
local spin = handle:update(CFrame.new(1, 2, 3), 0.2, 0.8, false)
assert(spin.stage == "spin" and spin.squash > 0, "Spin and deformation envelope")
handle:update(CFrame.new(1, 2, 3), 0.55, 0.8, false)
expectForm(handle, "transformed")
assert(
	handle.models.protoform.Parent == nil and handle.models.transformed.Parent == parent,
	"Exactly one form visible"
)
handle:update(CFrame.new(1, 2, 3), 0.56, 10, false)
expectForm(handle, "transformed")
assert(handle:playAttack(), "Transformed attack slot plays")
handle:update(CFrame.new(1, 2, 3), 0.7, 10, false)
handle:resumeSequence()
handle:update(CFrame.new(1, 2, 3), 0.71, 10, false)
for _, model in handle.models do
	assert(
		not model:FindFirstChildOfClass("Humanoid"),
		"Creatures are independent of humanoid rigs"
	)
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") then
			assert(
				not child.CanCollide and not child.CanQuery and not child.CanTouch,
				"Visuals must not determine collision"
			)
		end
	end
end
handle:destroy()
handle:destroy()
assert(#parent:GetChildren() == 0, "Destroy cleans up both forms")
for _ = 1, 20 do
	local trial = Visual.new("placeholder", { parent = parent })
	local sample = trial:update(CFrame.identity, 0.001, 0.06, true)
	assert(sample.transformed and sample.progress == 1, "Early impact finishes immediately")
	trial:destroy()
end
assert(#parent:GetChildren() == 0, "Repeated transitions leave no fixture models")
parent:Destroy()
print(
	"PASS: native creature visual lifecycle, idle, independent rigs, impact, no collision and repeated cleanup"
)
