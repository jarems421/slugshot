--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Motion = require(ServerScriptService.Training.Motion)
local function run()
	local a, b = Motion.new(), Motion.new()
	for _ = 1, 60 do
		Motion.step(a, 1 / 30)
	end
	for _ = 1, 240 do
		Motion.step(b, 1 / 120)
	end
	assert(math.abs(a.phase - b.phase) < 1e-8, "frame-rate motion mismatch")
	assert(Motion.setSpeed(a, 0))
	local x = Motion.step(a, 0)
	for _ = 1, 30 do
		assert(Motion.step(a, 1 / 30) == x, "stationary target moved")
	end
	local invalid: { any } = { -1, 21, math.huge, -math.huge, "7", {} }
	for _, value in invalid do
		assert(not Motion.setSpeed(a, value), "invalid target speed accepted")
	end
	assert(not Motion.setSpeed(a, 0 / 0), "NaN accepted")
	assert(Motion.setSpeed(a, 20))
	assert(math.abs(Motion.step(a, 0) - x) < 1e-8, "resume snapped")
	while workspace:GetAttribute("TrainingReady") ~= true do
		task.wait(0.1)
	end
	local art = workspace.TrainingArt
	assert(art:FindFirstChild("RUNE_Run_Head"), "running rune missing")
	assert(art:FindFirstChild("RUNE_Target_Ring_1.95"), "target rune missing")
	local floor, edge, room = 0, 0, 0
	for _, p in art:GetDescendants() do
		if string.sub(p.Name, 1, 6) == "FLOOR_" then
			floor += 1
		elseif string.sub(p.Name, 1, 5) == "EDGE_" then
			edge += 1
		elseif string.sub(p.Name, 1, 5) == "ROOM_" then
			room += 1
		end
		assert(not string.find(p.Name, "LABEL_", 1, true), "floor wording survived")
	end
	assert(floor > 40 and edge == 48 and room >= 60, "arena geometry incomplete")
	print(
		`[TRAININGCHECK] server PASS: {floor} floor stones, {edge} rim rocks, {room} enclosure parts; motion, pause, resume, invalid input`
	)
	workspace:SetAttribute("TrainingServerCheck", true)
end
local ok, problem = pcall(run :: () -> any)
if not ok then
	warn(`[TRAININGCHECK] FAIL server: {problem}`)
end
