--!strict
-- Upload-free Motor6D proxy. This does not prove FBX/Bone import or skin deformation.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("SlugAssets")
local Types = require(Shared.Types)
local NativeFixture = {}

local function xyz(value: { number }): Vector3
	return Vector3.new(value[1], value[3], -value[2])
end

local function part(name: string, size: Vector3, color: Color3, model: Model): Part
	local item = Instance.new("Part")
	item.Name = name
	item.Size = size
	item.Color = color
	item.CanCollide = false
	item.CanTouch = false
	item.CanQuery = false
	item.Massless = true
	item.Parent = model
	return item
end

function NativeFixture.create(species: Types.Species, form: Types.Form, rig: Types.Rig): Model
	assert(species.placeholder, "Native fixtures are for labeled placeholders only")
	local model = Instance.new("Model")
	model.Name = species.id .. "_PLACEHOLDER"
	model:SetAttribute("RigId", rig.id)
	local origin = part("Origin", Vector3.one * 0.1, Color3.new(), model)
	origin.Transparency = 1
	origin.Anchored = true
	model.PrimaryPart = origin
	local parts: { [string]: Part } = {}
	local positions: { [string]: Vector3 } = {}
	local bodyColor = species.palette.body
	local featureColor = species.palette.feature
	local size = xyz(form.size) * Vector3.new(1, 1, -1)
	for _, spec in rig.bones do
		local position = xyz(spec.position) * size
		local dimensions = size * 0.45
		if spec.name == "head" or spec.name == "crest" then
			dimensions = size * 0.65 * form.headScale
		elseif spec.name == "jaw" then
			dimensions = size * Vector3.new(0.6, 0.12, 0.25)
		elseif string.find(spec.name, "wing", 1, true) then
			dimensions = size * Vector3.new(0.7, 0.1, 0.4)
		elseif spec.name == "body_lower" or spec.name == "core" then
			dimensions = size * Vector3.new(0.9, 0.7, 0.7)
		end
		local body = part(
			spec.name .. "_proxy",
			dimensions,
			Color3.new(bodyColor[1], bodyColor[2], bodyColor[3]),
			model
		)
		body.Shape = Enum.PartType.Ball
		body.CFrame = CFrame.new(position)
		if spec.name == "root" then
			body.Transparency = 1
		elseif string.find(spec.name, "wing", 1, true) then
			body.Shape = Enum.PartType.Block
			body.Color = Color3.new(featureColor[1], featureColor[2], featureColor[3])
		end
		local joint = Instance.new("Motor6D")
		joint.Name = spec.name
		joint.Part0 = if spec.parent then parts[spec.parent] else origin
		joint.Part1 = body
		joint.C0 =
			CFrame.new(position - (if spec.parent then positions[spec.parent] else Vector3.zero))
		joint.Parent = body
		parts[spec.name], positions[spec.name] = body, position
	end
	for socketName, socket in rig.sockets do
		local attachment = Instance.new("Attachment")
		attachment.Name = socketName
		attachment.Position = xyz(socket.position) * size - positions[socket.bone]
		attachment.Parent = parts[socket.bone]
	end
	for _, feature in form.features do
		local socket = rig.sockets[feature.socket]
		local point = xyz(socket.position) * size
		if feature.kind == "eye" then
			point = Vector3.new(point.X * form.eyeSpacing, point.Y, point.Z)
		end
		point += xyz(feature.offset)
		local color = species.palette[feature.material]
		local item = part(
			feature.id,
			xyz(feature.scale) * Vector3.new(1, 1, -1),
			Color3.new(color[1], color[2], color[3]),
			model
		)
		item.Shape = if feature.kind == "eye" then Enum.PartType.Ball else Enum.PartType.Block
		item.CFrame = CFrame.new(point)
		local weld = Instance.new("Weld")
		weld.Part0, weld.Part1 = parts[socket.bone], item
		weld.C0 = CFrame.new(point - positions[socket.bone])
		weld.Parent = item
	end
	local controller = Instance.new("AnimationController")
	controller.Parent = model
	Instance.new("Animator").Parent = controller
	return model
end

return NativeFixture
