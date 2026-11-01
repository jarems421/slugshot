--!strict
-- Native rigid-part fixture deformation. Imported skinned rigs use Options.onDeform.
local Squash = {}
export type Deformer = {
	parts: { [BasePart]: Vector3 },
	joints: { [Instance]: { CFrame } },
	attachments: { [Attachment]: Vector3 },
}

function Squash.new(model: Model): Deformer
	local data: Deformer = { parts = {}, joints = {}, attachments = {} }
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			data.parts[item] = item.Size
		elseif item:IsA("Motor6D") or item:IsA("Weld") then
			data.joints[item] = { item.C0, item.C1 }
		elseif item:IsA("Attachment") then
			data.attachments[item] = item.Position
		end
	end
	return data
end

local function scaled(frame: CFrame, factor: Vector3): CFrame
	return CFrame.new(frame.Position * factor) * frame.Rotation
end

function Squash.apply(data: Deformer, amount: number)
	local stretch = math.clamp(1 + amount, 0.5, 1.5)
	local factor = Vector3.new(stretch, 1 / (stretch * stretch), stretch)
	for part, size in data.parts do
		part.Size = size * factor
	end
	for joint, frames in data.joints do
		if joint:IsA("Motor6D") or joint:IsA("Weld") then
			local target = joint :: Motor6D
			target.C0, target.C1 = scaled(frames[1], factor), scaled(frames[2], factor)
		end
	end
	for attachment, position in data.attachments do
		attachment.Position = position * factor
	end
end

return Squash
