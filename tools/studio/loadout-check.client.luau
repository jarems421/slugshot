--!strict
-- Only mapped by build_loadout_check.py. Copies of Floppy exercise sparse slots.
local R = game:GetService("RunService")
local P = game:GetService("Players").LocalPlayer
local RS = game:GetService("ReplicatedStorage")
local scripts = P:WaitForChild("PlayerScripts")
local probe = scripts:WaitForChild("CombatExperimentProbe") :: BindableFunction
local movement = scripts:WaitForChild("MovementSandbox")
local first = (require :: any)(movement:WaitForChild("FirstPerson"))
local inspect = (require :: any)(movement:WaitForChild("SlugInspect"))
local keys = (require :: any)(movement:WaitForChild("Keybinds"))
local remote = RS:WaitForChild("SlugshotCombat") :: RemoteEvent

local function waitFor(test: () -> boolean, label: string)
	local deadline = os.clock() + 25
	repeat
		if test() then
			return
		end
		task.wait()
	until os.clock() > deadline
	error(label)
end

local function capture(name: string)
	print("LOADOUTCHECK shot " .. name)
	task.wait(1.3)
end

local sampledRoot = CFrame.identity
local sampledAttachment: Weld? = nil
R:BindToRenderStep("LoadoutInspectEvidence", Enum.RenderPriority.Character.Value + 30, function()
	if sampledAttachment then
		sampledRoot = sampledAttachment.C0
	end
end)
local ok, problem = pcall(function()
	local character = P.Character or P.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	local backpack = P:WaitForChild("Backpack")
	waitFor(function()
		return character:FindFirstChildOfClass("Tool") ~= nil
			or backpack:FindFirstChildOfClass("Tool") ~= nil
	end, "gun missing")
	local tool = (
		character:FindFirstChildOfClass("Tool") or backpack:FindFirstChildOfClass("Tool")
	) :: Tool
	humanoid:EquipTool(tool)
	task.wait(2)
	assert(keys.get("firstPerson", 1) == "V" and keys.get("inspect", 1) == "R", "key defaults")
	assert(
		keys.get("nextSlug", 1) == "WheelDown" and keys.get("previousSlug", 1) == "WheelUp",
		"wheel defaults"
	)
	probe:Invoke("Select", 3)
	assert(probe:Invoke("State").selectedSlot == 1, "empty slot selected")
	for _, slot in { 2, 5, 1 } do
		probe:Invoke("Cycle", 1)
		assert(probe:Invoke("State").selectedSlot == slot, "sparse wrap")
		waitFor(function()
			return tool:GetAttribute("SelectedSlugSlot") == slot
		end, "server selection")
	end
	probe:Invoke("Cycle", -1)
	assert(probe:Invoke("State").selectedSlot == 5, "backward wrap")
	probe:Invoke("Select", 1)
	probe:Invoke("Press")
	probe:Invoke("Select", 2)
	local before = probe:Invoke("State").lastSent
	probe:Invoke("Release")
	assert(probe:Invoke("State").lastSent == before, "switch released a charge")
	probe:Invoke("Select", 1)
	probe:Invoke("Press")
	task.wait(0.1)
	probe:Invoke("Release")
	waitFor(function()
		return probe:Invoke("State").lastAccepted > before
	end, "slot1 shot not accepted")
	probe:Invoke("Select", 2)
	assert(probe:Invoke("State").remaining == 0, "cooldown leaked into slot2")
	probe:Invoke("Select", 1)
	assert(probe:Invoke("State").remaining > 0, "slot1 cooldown bypass")
	task.wait(1.6)
	print("LOADOUTCHECK key V")
	waitFor(function()
		return first.active()
	end, "real V did not enter first person")
	print("LOADOUTCHECK key 2")
	waitFor(function()
		return probe:Invoke("State").selectedSlot == 2
	end, "real 2 did not select")
	print("LOADOUTCHECK wheel down")
	waitFor(function()
		return probe:Invoke("State").selectedSlot == 5
	end, "wheel down did not select")
	assert(first.active(), "wheel changed camera mode")
	print("LOADOUTCHECK wheel up")
	waitFor(function()
		return probe:Invoke("State").selectedSlot == 2
	end, "wheel up did not select")
	print("LOADOUTCHECK key R")
	waitFor(function()
		return inspect.elapsed(character) ~= nil
	end, "real R did not inspect")
	local loaded = tool:FindFirstChild("Floppy")
	local attachment = loaded and loaded:FindFirstChildWhichIsA("Weld", true)
	assert(attachment and attachment:IsA("Weld"), "loaded attachment missing")
	sampledAttachment = attachment :: Weld
	local rest = sampledAttachment.C0
	task.wait(1.9)
	assert(sampledRoot ~= rest, "slug did not hop/turn")
	-- Upright he is stuck to the chamber's floor: the life is in the rig, not the attachment.
	local spine = (loaded :: Instance):FindFirstChild("body_upper", true) :: Bone
	local turning = spine.Transform
	local visual = (workspace.CurrentCamera :: Camera):FindFirstChild("FirstPersonBodyVisual")
	assert(visual and visual:FindFirstChild("Handle"), "first person gun missing")
	capture("first-person-look")
	task.wait(0.1)
	assert(spine.Transform ~= turning, "slug pose frozen")
	capture("first-person-wiggle")
	task.wait(2)
	assert(inspect.elapsed(character) == nil, "inspect did not finish")
	probe:Invoke("Inspect")
	waitFor(function()
		return inspect.elapsed(character) ~= nil
	end, "second inspect")
	probe:Invoke("Press")
	assert(inspect.elapsed(character) == nil, "fire did not interrupt inspect")
	probe:Invoke("Select", 1) -- cancel the held shot without firing
	print("LOADOUTCHECK key V")
	waitFor(function()
		return not first.active()
	end, "real V did not exit first person")
	local min, max = P.CameraMinZoomDistance, P.CameraMaxZoomDistance
	print("LOADOUTCHECK wheel down")
	waitFor(function()
		return probe:Invoke("State").selectedSlot == 2
	end, "third person wheel")
	assert(
		not first.active() and min == P.CameraMinZoomDistance and max == P.CameraMaxZoomDistance,
		"wheel zoomed"
	)
	probe:Invoke("Inspect")
	waitFor(function()
		return inspect.elapsed(character) ~= nil
	end, "third person inspect")
	task.wait(1.8)
	local camera = workspace.CurrentCamera :: Camera
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame =
		CFrame.lookAt(root.Position + Vector3.new(4, 2.2, -6), root.Position + Vector3.new(0, 1, 0))
	capture("third-person-look")
	camera.CameraType = Enum.CameraType.Custom
	humanoid:UnequipTools()
	task.wait(0.2)
	assert(inspect.elapsed(character) == nil, "holster left inspect running")
	if loaded then
		for _, item in loaded:GetDescendants() do
			if item:IsA("Weld") then
				local base = item:GetAttribute("InspectRestC0")
				if typeof(base) == "CFrame" then
					assert(
						(item.C0.Position - base.Position).Magnitude < 1e-5,
						"holster retained a moved slug"
					)
				end
			end
		end
	end
	probe:Invoke("Select", 1)
	waitFor(function()
		return tool.Parent == character
	end, "slot key failed to equip")
	keys.set("nextSlug", 1, "Q")
	print("LOADOUTCHECK key Q")
	waitFor(function()
		return probe:Invoke("State").selectedSlot == 2
	end, "rebound next slug")
	keys.reset()
	probe:Invoke("Select", 1)
	P:SetAttribute("PvpMenu", "Inventory")
	probe:Invoke("Select", 2)
	assert(probe:Invoke("State").selectedSlot == 1, "menu leaked selection")
	P:SetAttribute("PvpMenu", nil)
	local rejected = false
	local connection = remote.OnClientEvent:Connect(function(kind: string, packet: any)
		if kind == "Rejected" and packet.id == 987654 then
			rejected = true
		end
	end)
	remote:FireServer(
		"Fire",
		{ id = 987654, slot = 2, origin = Vector3.zero, direction = -Vector3.zAxis, charge = 1 }
	)
	waitFor(function()
		return rejected
	end, "server accepted unselected slot")
	connection:Disconnect()
	assert(inspect.weight(0) == 0 and inspect.weight(inspect.Duration) == 0, "inspect seam")
	first.setActive(true)
	local reload = RS:WaitForChild("LoadoutReload") :: RemoteFunction
	reload:InvokeServer()
	waitFor(function()
		return P.Character ~= nil and P.Character ~= character
	end, "respawn missing")
	local respawned = P.Character :: Model
	respawned:WaitForChild("Humanoid")
	task.wait(1)
	assert(not first.active() and inspect.elapsed(respawned) == nil, "respawn kept camera/inspect")
	assert(P.CameraMinZoomDistance == P.CameraMaxZoomDistance, "respawn restored wheel zoom")
	waitFor(function()
		return backpack:FindFirstChildOfClass("Tool") ~= nil
			or respawned:FindFirstChildOfClass("Tool") ~= nil
	end, "respawn gun missing")
	probe:Invoke("Select", 1)
	waitFor(function()
		return respawned:FindFirstChildOfClass("Tool") ~= nil
	end, "respawn equip")
	capture("complete")
	print(
		"LOADOUTCHECK PASS sparse slots, real keys/wheel, cooldowns, inspect, interruptions, rebinding, respawn, server rejection"
	)
end)
if not ok then
	warn("LOADOUTCHECK FAIL " .. tostring(problem))
end
