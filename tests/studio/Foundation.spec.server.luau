--!strict
-- Included only in test.project.json. Never part of the normal place.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Foundation = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Foundation"))

assert(
	Foundation.message("server") == "[Slugshot] server foundation ready",
	"Server message mismatch"
)
assert(
	Foundation.message("client") == "[Slugshot] client foundation ready",
	"Client message mismatch"
)
assert(table.isfrozen(Foundation), "Foundation must not be mutable")
print("[Slugshot tests] PASS: shared module contract")
