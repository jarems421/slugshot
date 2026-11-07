--!strict
-- Approved study C, composed with the current shared gun inspection.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Rig = require(script.Rig)
local Surface = require(script.Surface)
local Flow = require(script.Flow)
local Breath = require(script.Breath)
local player = Players.LocalPlayer
local movement = script.Parent:WaitForChild("MovementSandbox", 5)
if not movement then
	return
end
local Inspect = (require :: any)(movement:WaitForChild("SlugInspect"))
local firstModule = movement:FindFirstChild("FirstPerson")
local First = if firstModule then (require :: any)(firstModule) else nil
local states: { [Model]: any } = {}
local pending: { [Model]: boolean } = {}
local RETRY = 4 -- seconds before asking again when the mesh memory budget is full

local function setup(model: Model)
	if states[model] or pending[model] then
		return
	end
	local tool = model:FindFirstAncestorOfClass("Tool")
	local handle = tool and tool:FindFirstChild("Handle")
	if not tool or not handle or not handle:IsA("BasePart") then
		return
	end
	pending[model] = true
	task.spawn(function()
		local state: any = nil
		local short = false
		local ok, problem = xpcall(function(): any
			-- The model can replicate before its skeleton and chamber attributes.
			local deadline = os.clock() + 15
			while
				not (
					model:FindFirstChild("antenna_R", true)
					and model:FindFirstChild("mouth_tail_R", true)
					and model:GetAttribute("ChamberSize")
				)
			do
				if os.clock() > deadline or not model:IsDescendantOf(game) then
					return
				end
				task.wait(0.05)
			end
			local rig = Rig.new(model, handle)
			local lip = model:FindFirstChild("InfernoMouth", true) :: MeshPart
			local ink = model:FindFirstChild("InfernoMouthInk", true) :: MeshPart
			-- Nothing on the model changes until every mesh is held, so a full budget leaves
			-- Burpy whole and still, and the next try starts clean.
			local meshes = Surface.reserve(ink, lip, rig.body)
			if not meshes then
				short = true
				return nil
			end
			state = {
				rig = rig,
				tool = tool,
				lip = lip,
				line = model:FindFirstChild("InfernoMouthLine", true),
				surface = lip:FindFirstChildOfClass("SurfaceAppearance"),
				active = false,
			}
			state.ink =
				Surface.ink(rig, ink, lip, rig.parts[ink]:ToObjectSpace(rig.parts[lip]), meshes)
			state.breath = Breath.new(rig, meshes.body)
			state.fire = Surface.fire(meshes.fire)
			state.fire.part.Parent = workspace.CurrentCamera
			if not model:IsDescendantOf(game) then
				error("model removed while preparing")
			end
			states[model] = state
			model:SetAttribute("InspectReady", true)
			return nil
		end, debug.traceback)
		pending[model] = nil
		if short then
			task.delay(RETRY, function()
				if model:IsDescendantOf(game) then
					setup(model)
				end
			end)
		elseif not ok then
			if state then
				if state.fire then
					state.fire.part:Destroy()
					state.fire.mesh:Destroy()
				end
				if state.ink then
					state.ink.mesh:Destroy()
					state.ink.lip.mesh:Destroy()
				end
				if state.breath then
					state.breath.mesh:Destroy()
				end
			end
			warn("Inferno inspect preparation: " .. tostring(problem))
		end
	end)
end

local function consider(item: Instance)
	if item:IsA("Model") and item.Name == "InfernoLoaded" then
		setup(item)
	end
end
for _, item in workspace:GetDescendants() do
	consider(item)
end
workspace.DescendantAdded:Connect(consider)
local backpack = player:WaitForChild("Backpack")
for _, item in backpack:GetDescendants() do
	consider(item)
end
backpack.DescendantAdded:Connect(consider)

local function reset(state: any)
	Rig.reset(state.rig)
	Breath.step(state.breath, 0)
	Surface.stepInk(state.ink, 0)
	if state.surface then
		state.surface.Color = Color3.new(1, 1, 1)
		state.surface.EmissiveTint = Color3.new(1, 1, 1)
	end
	state.fire.part.Transparency = 1
	state.fire.localFrame = nil
	if state.line then
		state.line.Transparency = if state.lip.Transparency < 1 then 0.15 else 1
	end
	state.active = false
	state.rig.model:SetAttribute("InspectMouthAmount", 0)
	state.rig.model:SetAttribute("InspectGroundGap", 0)
end

RunService:BindToRenderStep(
	"InfernoInspectPose",
	Enum.RenderPriority.Character.Value + 2,
	function()
		for model, state in states do
			if not model:IsDescendantOf(game) then
				state.fire.part:Destroy()
				state.fire.mesh:Destroy()
				state.ink.mesh:Destroy()
				state.ink.lip.mesh:Destroy()
				state.breath.mesh:Destroy()
				states[model] = nil
				continue
			end
			local character = state.tool.Parent
			local elapsed = if character
					and character:IsA("Model")
					and state.tool:GetAttribute("SelectedSlugId") == "Inferno"
				then Inspect.creatureElapsed(character)
				else nil
			if elapsed then
				state.time = elapsed
				state.active = true
				local action = Rig.step(
					state.rig,
					elapsed,
					Flow.ease(elapsed / 0.24)
						* (
							1
							- Flow.ease(
								(elapsed - Inspect.InfernoLower - 0.26)
									/ (Inspect.InfernoDuration - Inspect.InfernoLower - 0.26)
							)
						)
				)
				Surface.stepInk(state.ink, Flow.ease(action.mouth))
				Breath.step(state.breath, action.inhale + 0.14 * action.resting)
				if state.line then
					state.line.Transparency = 0.15 + 0.85 * Flow.ease(action.mouth / 0.45)
				end
				local cavity = Flow.ease((action.mouth - 0.36) / 0.64)
				local colour = Color3.new(1, 1, 1):Lerp(Color3.new(0.13, 0.028, 0.012), cavity)
				if state.surface then
					state.surface.Color = colour
					state.surface.EmissiveTint = colour
				end
			elseif state.active then
				reset(state)
			end
		end
	end
)

RunService:BindToRenderStep(
	"InfernoInspectFlame",
	Enum.RenderPriority.Character.Value + 11,
	function()
		for _, state in states do
			if state.active then
				local rig = state.rig
				local localFrame = rig.handle.CFrame:ToObjectSpace(Rig.flameFrame(rig))
				if state.time <= Flow.End then
					state.fire.localFrame = localFrame
				else
					-- Stop following the recovering lips after emission ends.
					localFrame = state.fire.localFrame or localFrame
				end
				local frame = rig.handle.CFrame * localFrame
				local scale = 0.75 * rig.scale / Flow.GameScale
				local radius = math.min(rig.size.X, rig.size.Y) * 0.5 * 0.98
				local origin = localFrame.Position - rig.centre
				local mouthRadius = math.max(0.001, Vector2.new(origin.X, origin.Y).Magnitude)
				local radialSign = if localFrame.ZVector:Dot(Vector3.new(origin.X, origin.Y, 0))
						>= 0
					then 1
					else -1
				-- Sweep around the chamber rather than straight into its nearest wall.
				-- Radial thickness and height remain analytically bounded for every vertex.
				for i = 0, 28 do
					for j = 0, 14 do
						local p = Flow.vertex(state.time, i / 28, j / 14)
						local v = localFrame:VectorToWorldSpace(p)
						local depth = p.Z * radialSign
						if depth > 1e-8 then
							scale = math.min(scale, (radius - mouthRadius) / depth)
						elseif depth < -1e-8 then
							scale = math.min(scale, -mouthRadius / depth)
						end
						if math.abs(v.Z) > 1e-8 then
							scale = math.min(
								scale,
								((if v.Z > 0 then 1 else -1) * rig.size.Z * 0.46 - origin.Z) / v.Z
							)
						end
					end
				end
				local camera = workspace.CurrentCamera
				if camera then
					state.fire.part.Parent = camera
					if state.tool.Parent == player.Character and First and First.active() then
						local visual = camera:FindFirstChild("FirstPersonBodyVisual")
						local handle = visual and visual:FindFirstChild("Handle")
						if handle and handle:IsA("BasePart") then
							frame = handle.CFrame * localFrame
						end
					end
				end
				Surface.step(
					state.fire,
					state.time,
					frame,
					math.max(0.001, scale),
					mouthRadius,
					radialSign,
					{
						radius = radius,
						minY = (origin.Z - rig.size.Z * 0.46) / math.max(0.001, scale),
						maxY = (origin.Z + rig.size.Z * 0.46) / math.max(0.001, scale),
					}
				)
				rig.model:SetAttribute("InspectFlameDetached", state.time > Flow.End)
				rig.model:SetAttribute("InspectFlameScale", math.max(0.001, scale))
				rig.model:SetAttribute(
					"InspectFlameOriginRadius",
					Vector2.new(origin.X, origin.Y).Magnitude
						/ (math.min(rig.size.X, rig.size.Y) * 0.5)
				)
			end
		end
	end
)
