--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Foundation = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Foundation"))

print(Foundation.message("server"))
