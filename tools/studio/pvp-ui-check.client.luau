--!strict
-- Check place only (tools/build_pvp_ui_check.py): walks the health bar and settings menu and logs a line at each
-- moment worth capturing, for tools/studio/pvp_ui_check.ps1. Never part of a normal build.
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local probe =
	player:WaitForChild("PlayerScripts"):WaitForChild("MovementExperimentProbe") :: BindableFunction

local function shot(name: string, hold: number)
	print(`UICHECK shot {name}`)
	task.wait(hold)
end

player:WaitForChild("PlayerGui"):WaitForChild("Settings")
task.wait(6)
shot("hud-full", 2)
for hit = 1, 3 do
	probe:Invoke("Hurt")
	task.wait(0.12)
	shot(`hud-hit{hit}`, 2.5)
end
-- A real key press, sent by the capture script (F opens the inventory since 2026-11-06).
print("UICHECK key F")
task.wait(1.5)
print(`UICHECK key result {player:GetAttribute("PvpMenu") or "nothing opened"}`)
if player:GetAttribute("PvpMenu") ~= "Inventory" then
	player:SetAttribute("PvpMenu", "Inventory")
	player:SetAttribute("CombatSettingsOpen", true)
	task.wait(1)
end
shot("inventory", 2.5)
player:SetAttribute("PvpMenu", "Settings")
player:SetAttribute("CombatSettingsOpen", true)
task.wait(1.2)
shot("controls", 2.5)
player:SetAttribute("SettingsTestPage", "Gameplay")
task.wait(1.2)
shot("gameplay", 1)
player:SetAttribute("FieldOfView", 105)
task.wait(0.15)
shot("gameplay-swash", 2.5)
player:SetAttribute("FieldOfView", 65)
task.wait(0.03)
shot("gameplay-left", 2.5)
player:SetAttribute("SettingsTestPage", "Crosshair")
task.wait(1.2)
shot("crosshair", 2.5)

-- The hit reaction: the angle of each joint actually rendered, against the same joint just before the hit.
player:SetAttribute("PvpMenu", nil)
player:SetAttribute("CombatSettingsOpen", false)
-- Your own body only reacts out of first person, so hold the camera out.
player.CameraMinZoomDistance = 12
probe:Invoke("Respawn")
task.wait(6)
local character = player.Character :: Model
local RunService = game:GetService("RunService")
local rootJoint = character:WaitForChild("HumanoidRootPart"):WaitForChild("RootJoint") :: Motor6D
local torso = character:WaitForChild("Torso")
local neck = torso:WaitForChild("Neck") :: Motor6D
local arm = torso:WaitForChild("Left Shoulder") :: Motor6D
local movement = player:WaitForChild("PlayerScripts"):WaitForChild("MovementSandbox")
local Tuning = (require :: any)(movement:WaitForChild("Tuning"))
local HitReaction = (require :: any)(movement:WaitForChild("HitReaction"))
local controls: { [string]: { [number]: CFrame } } = {}
local function measure(label: string, control: boolean?)
	local before = { rootJoint.Transform, neck.Transform, arm.Transform }
	local health = (character:FindFirstChildOfClass("Humanoid") :: Humanoid).Health
	if not control then
		probe:Invoke("Hurt")
	end
	local peak = { 0, 0, 0 }
	local spring = 0
	local extra = 0
	local series = {}
	local started = os.clock()
	while os.clock() - started < 0.5 do
		RunService.Heartbeat:Wait()
		spring = math.max(spring, HitReaction.level())
		-- Against the same moment of the same move unhit, which leaves only what the hit added.
		local bucket = math.floor((os.clock() - started) * 30)
		series[bucket] = rootJoint.Transform
		local unhit = controls[label] and controls[label][bucket]
		if unhit then
			local _, angle = unhit:ToObjectSpace(rootJoint.Transform):ToAxisAngle()
			extra = math.max(extra, math.deg(angle))
		end
		for index, joint in { rootJoint, neck, arm } do
			local _, angle = (before[index]:ToObjectSpace(joint.Transform)):ToAxisAngle()
			peak[index] = math.max(peak[index], math.deg(angle))
		end
	end
	if control then
		controls[string.gsub(label, ", no hit", "")] = series
	end
	local damage = health - (character:FindFirstChildOfClass("Humanoid") :: Humanoid).Health
	print(
		`UICHECK reaction {label}: damage {math.round(damage)}, spring {math.round(spring * 100) / 100}, state {character:GetAttribute(
			"MovementAction"
		) or "-"}, chest added {math.round(extra)}, chest {math.round(peak[1])}, head {math.round(
			peak[2]
		)}, arm {math.round(peak[3])}`
	)
	task.wait(1)
end
local function respawned()
	probe:Invoke("Respawn")
	task.wait(6)
	character = player.Character :: Model
	rootJoint = character:WaitForChild("HumanoidRootPart"):WaitForChild("RootJoint") :: Motor6D
	torso = character:WaitForChild("Torso")
	neck = torso:WaitForChild("Neck") :: Motor6D
	arm = torso:WaitForChild("Left Shoulder") :: Motor6D
end
measure("standing")
measure("standing")
measure("standing")
respawned()
Tuning.values.hitClip = 0
measure("standing, spring only")
measure("standing, spring only")
measure("standing, spring only")
Tuning.values.hitClip = 0.5
respawned()
-- Controls first: the same moves unhit, since a jump or slide turns the joints by itself.
probe:Invoke("Jump")
task.wait(0.15)
measure("jumping, no hit", true)
task.wait(1)
probe:Invoke("Jump")
task.wait(0.15)
measure("jumping")
task.wait(1)
probe:Invoke("Sprint", true)
probe:Invoke("Move", { direction = Vector3.new(0, 0, -1), duration = 1.6 })
task.wait(1)
print(`UICHECK reaction slide started: {probe:Invoke("Slide")}`)
task.wait(0.12)
measure("sliding, no hit", true)
probe:Invoke("Sprint", false)
task.wait(2)
probe:Invoke("Sprint", true)
probe:Invoke("Move", { direction = Vector3.new(0, 0, -1), duration = 1.6 })
task.wait(1)
print(`UICHECK reaction slide started: {probe:Invoke("Slide")}`)
task.wait(0.12)
measure("sliding")
probe:Invoke("Sprint", false)
task.wait(2)
probe:Invoke("Respawn")
task.wait(6)
character = player.Character :: Model

-- Stills: slowed right down so the capture lands on the peak, seen from the front.
Tuning.values.hitRecovery = 0.08
local camera = workspace.CurrentCamera
local body = (character:WaitForChild("HumanoidRootPart") :: BasePart).CFrame
camera.CameraType = Enum.CameraType.Scriptable
camera.CFrame = CFrame.lookAt(body * Vector3.new(0, 0.6, -9), body.Position)
shot("react-before", 1.5)
local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
for _ = 1, 3 do
	local health = humanoid.Health
	probe:Invoke("Hurt")
	task.wait(1)
	shot(`react-{math.round(health - humanoid.Health)}`, 8)
end
print("UICHECK done")
