--!strict
-- Original procedural R15 study. No third-party clips/IDs or physics rotation.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local shared = game:GetService("ReplicatedStorage"):WaitForChild("MovementExperiment")
local Config = require(shared.Config)
local Math = require(shared.MotionMath)
local Presentation = {}
type AnimationJoint = Motor6D | AnimationConstraint

function Presentation.start()
	local rigs: { [Model]: { [string]: AnimationJoint } } = {}
	local phases: { [Model]: number } = {}
	local rendered: { [AnimationJoint]: CFrame } = {}
	local function watch(character: Model)
		local joints = {}
		local count = 0
		for _, item in character:GetDescendants() do
			if item:IsA("Motor6D") or item:IsA("AnimationConstraint") then
				joints[item.Name] = item
				rendered[item] = CFrame.identity
				count += 1
			end
		end
		rigs[character] = joints
		phases[character] = 0
		character:SetAttribute("PresentationJointCount", count)
	end
	local function watchPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.defer(watch, character)
		end)
		if player.Character then
			watch(player.Character)
		end
	end
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	RunService.PreSimulation:Connect(function(dt)
		local now = workspace:GetServerTimeNow()
		for character, joints in rigs do
			if not character.Parent then
				for _, joint in joints do
					rendered[joint] = nil
				end
				rigs[character] = nil
				phases[character] = nil
				continue
			end
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not root or not humanoid then
				continue
			end
			local v = root.AssemblyLinearVelocity
			local speed = Vector3.new(v.X, 0, v.Z).Magnitude
			local runWeight = math.clamp(speed / 18, 0, 1)
			phases[character] = (
				phases[character]
				+ dt
					* 2
					* math.pi
					* math.clamp(speed / Config.Presentation.StrideLength, 0.6, 3)
			) % (2 * math.pi)
			local phase = phases[character]
			local swing = math.sin(phase) * runWeight
			local airborne = humanoid.FloorMaterial == Enum.Material.Air
			local poses: { [string]: CFrame } = {
				Root = CFrame.new(0, math.abs(math.sin(phase)) * 0.06 * runWeight, 0),
				Waist = CFrame.Angles(-0.1 * runWeight, swing * 0.06, 0),
				Neck = CFrame.Angles(0.07 * runWeight, -swing * 0.04, 0),
				LeftHip = CFrame.Angles(swing * Config.Presentation.HipSwing, 0, 0),
				RightHip = CFrame.Angles(-swing * Config.Presentation.HipSwing, 0, 0),
				LeftKnee = CFrame.Angles(-math.max(0, -swing) * 1.0, 0, 0),
				RightKnee = CFrame.Angles(-math.max(0, swing) * 1.0, 0, 0),
				LeftShoulder = CFrame.Angles(-swing * Config.Presentation.ArmSwing, 0, -0.08),
				RightShoulder = CFrame.Angles(swing * Config.Presentation.ArmSwing, 0, 0.08),
				LeftElbow = CFrame.Angles(0.65 * runWeight, 0, 0),
				RightElbow = CFrame.Angles(0.65 * runWeight, 0, 0),
			}
			if airborne then
				poses.LeftHip = CFrame.Angles(0.3, 0, -0.05)
				poses.RightHip = CFrame.Angles(-0.2, 0, 0.05)
				poses.LeftKnee = CFrame.Angles(-0.65, 0, 0)
				poses.RightKnee = CFrame.Angles(-0.35, 0, 0)
			end
			local action = character:GetAttribute("MovementAction")
			local started = character:GetAttribute("MovementActionTime") or -math.huge
			local duration = if action == "Evade"
				then Config.Evade.Duration
				else Config.Flourish.Duration
			local t = (now - started) / duration
			local visualPitch = 0
			if t >= 0 and t < 1 then
				local turn = 2 * math.pi * (t * t * (3 - 2 * t))
				if action == "Flourish" then
					visualPitch = -turn
					poses.Root = CFrame.Angles(visualPitch, 0, 0)
				else
					local direction = root.CFrame:VectorToObjectSpace(
						character:GetAttribute("MovementDirection") or root.CFrame.LookVector
					)
					poses.Root = CFrame.new(0, -0.3 * math.sin(t * math.pi), 0)
						* CFrame.fromAxisAngle(Vector3.new(-direction.Z, 0, direction.X).Unit, turn)
				end
				poses.LeftHip, poses.RightHip = CFrame.Angles(0.9, 0, 0), CFrame.Angles(0.9, 0, 0)
				poses.LeftKnee, poses.RightKnee =
					CFrame.Angles(-1.7, 0, 0), CFrame.Angles(-1.7, 0, 0)
			end
			if character:GetAttribute("Aiming") then
				local pitch = character:GetAttribute("AimPitch") or 0
				poses.RightShoulder = CFrame.Angles(1.35 - pitch, 0, 0.05)
				poses.LeftShoulder = CFrame.Angles(1.15 - pitch, 0, -0.25)
				poses.RightElbow, poses.LeftElbow =
					CFrame.Angles(0.2, 0, 0), CFrame.Angles(0.5, 0, 0)
			end
			for name, joint in joints do
				rendered[joint] = rendered[joint]:Lerp(
					poses[name] or CFrame.identity,
					Math.alpha(Config.Presentation.BlendRate, dt)
				)
				joint.Transform = rendered[joint]
			end
			character:SetAttribute("RenderedVisualPitch", visualPitch)
			character:SetAttribute("RenderedRunWeight", runWeight)
		end
	end)
end

return Presentation
