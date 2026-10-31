--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SlugAssets")
local Timeline = require(Shared.Timeline)
local Definitions = require(Shared.Definitions)
local p = Definitions.species.placeholder.transformation

assert(Timeline.sample(p, 0, 0.8, false).stage == "launch", "Launch stage")
assert(Timeline.sample(p, 0.2, 0.8, false).stage == "spin", "Spin stage")
assert(Timeline.sample(p, 0.4, 0.8, false).stage == "energy", "Energy stage")
assert(Timeline.sample(p, 0.55, 0.8, false).stage == "transition", "Transition stage")
assert(Timeline.sample(p, 0.8, 0.8, false).stage == "reveal", "Reveal stage")
assert(
	Timeline.sample(p, 0.1, 1, false, 0.7).transformed,
	"Updated estimate must not reverse a rig swap"
)
for _, estimate in { 0, 0.001, 0.06, 0.8, 10 } do
	local impact = Timeline.sample(p, 0.001, estimate, true)
	assert(
		impact.transformed and impact.progress == 1 and impact.stage == "impact",
		"Impact finishes visuals immediately"
	)
	assert(
		Timeline.sample(p, estimate, estimate, false).transformed,
		"Visual complete by estimated impact"
	)
end
local disabled = table.clone(p)
disabled.enabled = false
assert(not Timeline.sample(disabled, 1, 0.06, true).transformed, "Non-transforming exception")
local firstSlug = Definitions.species["flopper-inspired"].transformation
assert(
	not firstSlug.enabled and not Timeline.sample(firstSlug, 0.01, 0.06, true).transformed,
	"First slug stays in protoform at impact"
)
assert(not pcall(Timeline.sample, p, -1, 1, false), "Negative elapsed rejected")
assert(not pcall(Timeline.sample, p, 0, 0 / 0, false), "NaN estimate rejected")
print(
	"PASS: creature timeline stages, zero/close/long flight, impact, no-transform and invalid inputs"
)
